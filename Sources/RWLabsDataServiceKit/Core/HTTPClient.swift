//
//  HTTPClient.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

/// Sends requests and decodes their responses
///
/// Depend on this protocol rather than `URLSessionHTTPClient` so tests can
/// substitute a fake.
public protocol HTTPClient: Sendable {
    func send<R>(_ request: Request<R>) async throws(NetworkError) -> R
}

/// `HTTPClient` backed by `URLSession`
///
/// Example:
/// ```swift
/// let client = URLSessionHTTPClient(
///     baseURL: URL(string: "https://api.example.com")!,
///     interceptors: [
///         HeadersInterceptor { ["X-Auth-Token": await tokenStore.token ?? ""] },
///         UnauthorizedInterceptor { await session.logOut() },
///         LoggingInterceptor()
///     ]
/// )
/// let user: User = try await client.send(.get("/users/123"))
/// ```
public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    // @unchecked: JSONEncoder/JSONDecoder are not marked Sendable on older SDKs,
    // but are never mutated after init and encode/decode is thread-safe.

    public let baseURL: URL
    public let session: URLSession
    public let encoder: JSONEncoder
    public let decoder: JSONDecoder
    public let interceptors: [any Interceptor]

    /// Number of times a request is re-sent when an interceptor returns `.retry`
    static let maxRetries = 1

    /// Bytes received between progress callbacks
    static let progressChunkSize = 16_384

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        interceptors: [any Interceptor] = []
    ) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.interceptors = interceptors
    }

    public func send<R>(_ request: Request<R>) async throws(NetworkError) -> R {
        try await perform(request, progress: nil)
    }

    /// Send a request and report download progress from 0.0 to 1.0
    ///
    /// When the server does not report a content length, progress is only
    /// reported once, as 1.0, when the body has been received.
    public func send<R>(
        _ request: Request<R>,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(NetworkError) -> R {
        try await perform(request, progress: progress)
    }

    // MARK: - Pipeline

    private func perform<R>(
        _ request: Request<R>,
        progress: (@Sendable (Double) -> Void)?
    ) async throws(NetworkError) -> R {
        let baseRequest = try makeURLRequest(for: request)
        var attempt = 0
        while true {
            var urlRequest = baseRequest
            for interceptor in interceptors {
                urlRequest = try await interceptor.adapt(urlRequest)
            }

            let (data, response) = try await load(urlRequest, progress: progress)

            var shouldRetry = false
            for interceptor in interceptors {
                if try await interceptor.handle(response, data: data, for: urlRequest) == .retry {
                    shouldRetry = true
                }
            }
            if shouldRetry && attempt < Self.maxRetries {
                attempt += 1
                continue
            }

            guard (200..<300).contains(response.statusCode) else {
                throw .http(
                    statusCode: response.statusCode,
                    error: (try? decoder.decode(APIError.self, from: data)).flatMap { $0.isEmpty ? nil : $0 },
                    data: data
                )
            }
            return try decode(R.self, from: data)
        }
    }

    func makeURLRequest<R>(for request: Request<R>) throws(NetworkError) -> URLRequest {
        let urlString: String
        if request.path.contains("://") {
            urlString = request.path
        } else {
            let base = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
            let path = request.path.hasPrefix("/") ? String(request.path.dropFirst()) : request.path
            urlString = path.isEmpty ? base : "\(base)/\(path)"
        }

        guard var components = URLComponents(string: urlString) else {
            throw .invalidURL(urlString)
        }
        if !request.query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + request.query
        }
        guard let url = components.url else {
            throw .invalidURL(urlString)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        if let timeout = request.timeout {
            urlRequest.timeoutInterval = timeout
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        switch request.body {
        case .json(let value):
            do {
                urlRequest.httpBody = try encoder.encode(value)
            } catch {
                throw .encoding(error)
            }
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .data(let data, let contentType):
            urlRequest.httpBody = data
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        case nil:
            break
        }

        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        return urlRequest
    }

    private func load(
        _ urlRequest: URLRequest,
        progress: (@Sendable (Double) -> Void)?
    ) async throws(NetworkError) -> (Data, HTTPURLResponse) {
        do {
            let (data, response): (Data, URLResponse)
            if let progress {
                (data, response) = try await loadWithProgress(urlRequest, progress: progress)
            } else {
                (data, response) = try await session.data(for: urlRequest)
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (data, httpResponse)
        } catch let error as URLError where error.code == .cancelled {
            throw .cancelled
        } catch let error as URLError {
            throw .transport(error)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .transport(URLError(.unknown, userInfo: [NSUnderlyingErrorKey: error]))
        }
    }

    private func loadWithProgress(
        _ urlRequest: URLRequest,
        progress: @Sendable (Double) -> Void
    ) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(for: urlRequest)
        let expectedLength = response.expectedContentLength
        var data = Data()
        if expectedLength > 0 {
            data.reserveCapacity(Int(expectedLength))
        }
        for try await byte in bytes {
            data.append(byte)
            if expectedLength > 0, data.count % Self.progressChunkSize == 0 {
                progress(min(Double(data.count) / Double(expectedLength), 1))
            }
        }
        progress(1)
        return (data, response)
    }

    private func decode<R: Decodable>(_ type: R.Type, from data: Data) throws(NetworkError) -> R {
        if data.isEmpty, let empty = EmptyResponse() as? R {
            return empty
        }
        do {
            return try decoder.decode(R.self, from: data)
        } catch let error as DecodingError {
            throw .decoding(error, data: data)
        } catch {
            throw .decoding(
                .dataCorrupted(.init(codingPath: [], debugDescription: error.localizedDescription, underlyingError: error)),
                data: data
            )
        }
    }
}
