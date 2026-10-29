//
//  Interceptor.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation
import RWLabsFoundation

/// What the client should do after an interceptor has seen a response
public enum InterceptorAction: Sendable {
    /// Continue with status validation and decoding
    case proceed
    /// Send the request again (at most once per `send`)
    case retry
}

/// Hooks into every request an `HTTPClient` sends
///
/// `adapt` runs in order before each attempt; `handle` runs in order on every
/// response, including non-2xx ones. Both default to pass-through.
public protocol Interceptor: Sendable {
    func adapt(_ request: URLRequest) async throws(NetworkError) -> URLRequest
    func handle(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws(NetworkError) -> InterceptorAction
}

public extension Interceptor {
    func adapt(_ request: URLRequest) async throws(NetworkError) -> URLRequest {
        request
    }

    func handle(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws(NetworkError) -> InterceptorAction {
        .proceed
    }
}

// MARK: - Headers

/// Adds headers to every request
///
/// The closure is called on every attempt, so values such as auth tokens are
/// always current. Headers already set on the request (e.g. via
/// `Request.headers`) are not overwritten.
public struct HeadersInterceptor: Interceptor {
    private let headers: @Sendable () async -> [String: String]

    public init(_ headers: @escaping @Sendable () async -> [String: String]) {
        self.headers = headers
    }

    public func adapt(_ request: URLRequest) async throws(NetworkError) -> URLRequest {
        var request = request
        for (field, value) in await headers() where request.value(forHTTPHeaderField: field) == nil {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}

// MARK: - Unauthorized

/// Calls a handler when the server responds with 401 or 403
///
/// Use it to log the user out, or to refresh credentials and pass
/// `retry: true` so the request is sent again with the new token.
public struct UnauthorizedInterceptor: Interceptor {
    private let retry: Bool
    private let onUnauthorized: @Sendable () async -> Void

    public init(retry: Bool = false, onUnauthorized: @escaping @Sendable () async -> Void) {
        self.retry = retry
        self.onUnauthorized = onUnauthorized
    }

    public func handle(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws(NetworkError) -> InterceptorAction {
        guard response.statusCode == 401 || response.statusCode == 403 else { return .proceed }
        await onUnauthorized()
        return retry ? .retry : .proceed
    }
}

// MARK: - Logging

/// Logs requests and responses through `Log.network` (DEBUG builds only)
public struct LoggingInterceptor: Interceptor {
    /// Header fields whose values are replaced with `<redacted>`
    public var redactedHeaders: Set<String>

    public init(redactedHeaders: Set<String> = ["X-Auth-Token", "Authorization"]) {
        self.redactedHeaders = Set(redactedHeaders.map { $0.lowercased() })
    }

    public func adapt(_ request: URLRequest) async throws(NetworkError) -> URLRequest {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "nil"
        let headers = (request.allHTTPHeaderFields ?? [:])
            .map { "\($0.key): \(redactedHeaders.contains($0.key.lowercased()) ? "<redacted>" : $0.value)" }
            .sorted()
            .joined(separator: "\n")
        var message = "(\(method)) \(url)\nHEADERS:\n\(headers)"
        if let body = request.httpBody {
            message += "\nBODY:\n\(body.prettyPrintedJSON ?? "<\(body.count) bytes>")"
        }
        Log.network(message)
        return request
    }

    public func handle(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws(NetworkError) -> InterceptorAction {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "nil"
        Log.network("(\(method)) \(url) → \(response.statusCode)\nRESPONSE:\n\(data.prettyPrintedJSON ?? "<\(data.count) bytes>")")
        return .proceed
    }
}
