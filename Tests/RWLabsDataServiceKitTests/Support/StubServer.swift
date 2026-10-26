//
//  StubServer.swift
//  RWLabsDataServiceKitTests
//

import Foundation
@testable import RWLabsDataServiceKit

/// A request as received by `StubURLProtocol`
struct RecordedRequest: Sendable {
    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data?

    func header(_ field: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(field) == .orderedSame }?.value
    }
}

/// A canned response
struct StubResponse: Sendable {
    var status: Int = 200
    var headers: [String: String] = [:]
    var body: Data = Data()
    /// Seconds to wait before responding
    var delay: TimeInterval = 0

    static func json(_ status: Int, _ body: String, headers: [String: String] = [:]) -> Self {
        Self(status: status, headers: headers.merging(["Content-Type": "application/json"]) { a, _ in a }, body: Data(body.utf8))
    }

    static func json(_ body: String, headers: [String: String] = [:]) -> Self {
        json(200, body, headers: headers)
    }
}

/// Serves stubbed responses on a unique host so tests can run in parallel.
///
/// The handler receives each request and its zero-based index.
final class StubServer: @unchecked Sendable {
    typealias Handler = @Sendable (RecordedRequest, Int) throws -> StubResponse

    let host = "\(UUID().uuidString.lowercased()).test"
    let session: URLSession
    private let handler: Handler
    private let lock = NSLock()
    private var _requests: [RecordedRequest] = []

    var baseURL: URL { URL(string: "https://\(host)/api")! }

    var requests: [RecordedRequest] {
        lock.withLock { _requests }
    }

    init(_ handler: @escaping Handler) {
        self.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
        StubURLProtocol.register(self, for: host)
    }

    convenience init(_ response: StubResponse) {
        self.init { _, _ in response }
    }

    deinit {
        StubURLProtocol.unregister(host: host)
    }

    func client(interceptors: [any Interceptor] = []) -> URLSessionHTTPClient {
        URLSessionHTTPClient(baseURL: baseURL, session: session, encoder: .snakeCase, decoder: .snakeCase, interceptors: interceptors)
    }

    fileprivate func respond(to request: RecordedRequest) throws -> StubResponse {
        let index = lock.withLock {
            _requests.append(request)
            return _requests.count - 1
        }
        return try handler(request, index)
    }
}

/// Routes requests to the `StubServer` registered for the request's host
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var servers: [String: StubServer] = [:]

    private var pendingResponse: DispatchWorkItem?

    static func register(_ server: StubServer, for host: String) {
        lock.withLock { servers[host] = server }
    }

    static func unregister(host: String) {
        _ = lock.withLock { servers.removeValue(forKey: host) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host,
              let server = Self.lock.withLock({ Self.servers[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let recorded = RecordedRequest(
            url: url,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        )

        let stub: StubResponse
        do {
            stub = try server.respond(to: recorded)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            var headers = stub.headers
            headers["Content-Length"] = String(stub.body.count)
            let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        }
        pendingResponse = work
        DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay, execute: work)
    }

    override func stopLoading() {
        pendingResponse?.cancel()
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// Thread-safe accumulator for values reported from `@Sendable` closures
final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [Value] = []

    var values: [Value] { lock.withLock { _values } }

    func append(_ value: Value) {
        lock.withLock { _values.append(value) }
    }
}
