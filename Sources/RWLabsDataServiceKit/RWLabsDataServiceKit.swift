//
//  RWLabsDataServiceKit.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabs
//

import Foundation

/// RWLabsDataServiceKit - An async/await networking library for RWLabs apps
///
/// ## Quick Start
///
/// 1. **Configure the API per environment:**
/// ```swift
/// struct AppConfig: APIConfigurationProtocol {
///     let baseURLs = BaseURLs(
///         local: URL(string: "http://localhost:3000")!,
///         staging: URL(string: "https://staging-api.example.com")!,
///         production: URL(string: "https://api.example.com")!
///     )
///     var metadata: ClientMetadata {
///         .current(apiVersion: "application/api.example.v1", deviceIdentifier: deviceID)
///     }
///     var encoder: JSONEncoder { .myAPI }   // your backend's conventions, defined in the app
///     var decoder: JSONDecoder { .myAPI }
/// }
/// ```
///
/// 2. **Create a client:**
/// ```swift
/// let config = AppConfig()
/// let headers = config.metadata.headers.merging(config.additionalHeaders) { $1 }
/// let client = URLSessionHTTPClient(
///     baseURL: config.baseURL,
///     encoder: config.encoder,
///     decoder: config.decoder,
///     interceptors: [
///         HeadersInterceptor { headers },
///         UnauthorizedInterceptor { await session.logOut() },
///         LoggingInterceptor()
///     ]
/// )
/// ```
///
/// 3. **Declare endpoints next to their response types:**
/// ```swift
/// extension Request where Response == User {
///     static func user(id: Int) -> Self { .get("users/\(id)") }
/// }
/// ```
///
/// 4. **Send requests:**
/// ```swift
/// do {
///     let user = try await client.send(.user(id: 123))
/// } catch .http(statusCode: 404, _, _) {
///     // not found
/// } catch {
///     // other NetworkError
/// }
/// ```
///
/// Apps define their own repository protocols over `HTTPClient` so a
/// persistence layer can be added behind them later.
public struct RWLabsDataServiceKit {
    /// Current version of RWLabsDataServiceKit
    public static let version = "1.0.0"

    /// Package name
    public static let name = "RWLabsDataServiceKit"
}
