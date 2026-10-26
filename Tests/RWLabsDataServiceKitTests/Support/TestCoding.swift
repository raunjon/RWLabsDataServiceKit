//
//  TestCoding.swift
//  RWLabsDataServiceKitTests
//

import Foundation
@testable import RWLabsDataServiceKit

// The library ships no default coders (apps supply them through their
// configuration), so tests use snake_case coders like a typical backend.

extension JSONEncoder {
    static var snakeCase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

extension JSONDecoder {
    static var snakeCase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension URLSessionHTTPClient {
    /// Builds a client from a configuration the way an app would with the library alone:
    /// its base URL and coders, plus its metadata and additional headers on every request
    static func configured(
        by configuration: some APIConfigurationProtocol,
        session: URLSession,
        interceptors: [any Interceptor] = []
    ) -> URLSessionHTTPClient {
        let headers = configuration.metadata.headers.merging(configuration.additionalHeaders) { _, additional in additional }
        return URLSessionHTTPClient(
            baseURL: configuration.baseURL,
            session: session,
            encoder: configuration.encoder,
            decoder: configuration.decoder,
            interceptors: [HeadersInterceptor { headers }] + interceptors
        )
    }
}
