//
//  NetworkError.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

/// Every failure `HTTPClient.send` can produce
public enum NetworkError: Error {
    /// The base URL and path did not form a valid URL
    case invalidURL(String)

    /// The request body could not be encoded
    case encoding(any Error)

    /// The request never produced an HTTP response (offline, timeout, TLS, ...)
    case transport(URLError)

    /// The request was cancelled, either via its Task or the URL session
    case cancelled

    /// The server responded with a non-2xx status. `error` is the decoded body when it carries any `APIError` field.
    case http(statusCode: Int, error: APIError?, data: Data)

    /// The response body could not be decoded into the expected type
    case decoding(DecodingError, data: Data)

    /// HTTP status code, when the server responded
    public var statusCode: Int? {
        guard case let .http(statusCode, _, _) = self else { return nil }
        return statusCode
    }

    /// Decoded error body, when the server responded with one
    public var apiError: APIError? {
        guard case let .http(_, error, _) = self else { return nil }
        return error
    }

    /// Whether the server rejected the request's credentials (401 or 403)
    public var isUnauthorized: Bool {
        statusCode == 401 || statusCode == 403
    }
}

// MARK: - LocalizedError

extension NetworkError: LocalizedError {
    /// A message suitable for showing to the user
    ///
    /// For `.http`, the server's message when it sent one, then its first
    /// `"base"` validation error, then the standard text for the status code.
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .encoding:
            return "The request couldn't be prepared."
        case .transport(let error):
            return error.localizedDescription
        case .cancelled:
            return "The request was cancelled."
        case let .http(statusCode, error, _):
            if let message = error?.message ?? error?.fieldErrors["base"]?.first {
                return message
            }
            let text = HTTPURLResponse.localizedString(forStatusCode: statusCode)
            return text.prefix(1).uppercased() + text.dropFirst()
        case .decoding:
            return "The server's response couldn't be read."
        }
    }
}
