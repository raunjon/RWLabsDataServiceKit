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
/// let configuration = APIConfiguration(
///     environment: .current(),   // from APP_ENVIRONMENT in Info.plist
///     baseURLs: .init(
///         local: URL(string: "http://localhost:3000")!,
///         staging: URL(string: "https://staging-api.example.com")!,
///         production: URL(string: "https://api.example.com")!
///     ),
///     apiVersion: "application/api.example.v1",
///     deviceIdentifier: deviceID
/// )
/// ```
///
/// 2. **Create a client:**
/// ```swift
/// let client = URLSessionHTTPClient.rwlabs(
///     configuration: configuration,
///     token: { await session.token },
///     onUnauthorized: { await session.logOut() }
/// )
/// ```
///
/// 3. **Declare endpoints next to their response types:**
/// ```swift
/// struct User: Codable, Sendable {
///     let id: Int
///     let fullName: String   // decoded from "full_name"
/// }
///
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
    public static let version = "2.0.0"

    /// Package name
    public static let name = "RWLabsDataServiceKit"
}
