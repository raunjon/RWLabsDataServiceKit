//
//  Request.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

/// HTTP method enumeration
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Query parameters keyed by name. `nil` values are dropped when the URL is built.
public typealias QueryParameters = [String: (any CustomStringConvertible & Sendable)?]

/// A description of an HTTP call and the type its response body decodes to
///
/// Define endpoints as static factories constrained on the response type:
/// ```swift
/// extension Request where Response == [Product] {
///     static func products(page: Int) -> Self {
///         .get("/products", query: ["page": page])
///     }
/// }
/// let products = try await client.send(.products(page: 1))
/// ```
public struct Request<Response: Decodable>: Sendable {
    /// Request body
    public enum Body: Sendable {
        /// JSON-encoded with the client's encoder
        case json(any Encodable & Sendable)
        /// Raw bytes sent as-is with the given content type
        case data(Data, contentType: String)
    }

    /// HTTP method
    public var method: HTTPMethod

    /// Path appended to the client's base URL, or an absolute URL string
    public var path: String

    /// Query items, appended to any query already present in `path`
    public var query: [URLQueryItem]

    /// Per-request headers, applied before interceptors run
    public var headers: [String: String]

    /// Optional request body
    public var body: Body?

    /// Timeout in seconds; `nil` uses the session's default
    public var timeout: TimeInterval?

    public init(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Body? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }

    public init(
        method: HTTPMethod,
        path: String,
        query: QueryParameters,
        headers: [String: String] = [:],
        body: Body? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.init(
            method: method,
            path: path,
            query: Self.queryItems(from: query),
            headers: headers,
            body: body,
            timeout: timeout
        )
    }

    /// Converts parameters to query items sorted by name, dropping `nil` values
    static func queryItems(from parameters: QueryParameters) -> [URLQueryItem] {
        parameters
            .compactMap { key, value in value.map { URLQueryItem(name: key, value: $0.description) } }
            .sorted { $0.name < $1.name }
    }
}

// MARK: - Convenience Constructors

public extension Request {
    static func get(_ path: String, query: QueryParameters = [:]) -> Self {
        Self(method: .get, path: path, query: query)
    }

    static func post(_ path: String, query: QueryParameters = [:], body: (any Encodable & Sendable)? = nil) -> Self {
        Self(method: .post, path: path, query: query, body: body.map(Body.json))
    }

    static func put(_ path: String, query: QueryParameters = [:], body: (any Encodable & Sendable)? = nil) -> Self {
        Self(method: .put, path: path, query: query, body: body.map(Body.json))
    }

    static func patch(_ path: String, query: QueryParameters = [:], body: (any Encodable & Sendable)? = nil) -> Self {
        Self(method: .patch, path: path, query: query, body: body.map(Body.json))
    }

    static func delete(_ path: String, query: QueryParameters = [:], body: (any Encodable & Sendable)? = nil) -> Self {
        Self(method: .delete, path: path, query: query, body: body.map(Body.json))
    }
}

// MARK: - Empty Payload

/// Payload for endpoints that only return success/error (e.g. delete operations)
public struct EmptyPayload: Encodable & Sendable & Equatable {
    init() {}
}

// MARK: - Empty Response

/// Response type for endpoints that return no body (e.g. 204 No Content)
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
