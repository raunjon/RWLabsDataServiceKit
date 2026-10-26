//
//  APIConfiguration.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation
import RWLabsFoundation

/// Describes how an app talks to its API: which environment it targets, the
/// base URL of each environment, the metadata sent with every request, and
/// the coders for request and response bodies
///
/// Conform an app-side type to keep API settings next to the rest of the
/// app's environment-specific configuration, or use `DefaultAPIConfiguration`.
/// Build the client from it once (`baseURL`, `encoder`, `decoder`, and
/// `metadata.headers` through a `HeadersInterceptor`); build a new client if
/// the environment changes.
///
/// Example:
/// ```swift
/// struct AppConfig: APIConfigurationProtocol {
///     let baseURLs = BaseURLs(
///         local: URL(string: "http://localhost:3000")!,
///         staging: URL(string: "https://staging-api.thirtyplus.com")!,
///         production: URL(string: "https://api.thirtyplus.com")!
///     )
///     var metadata: ClientMetadata {
///         .current(apiVersion: "application/api.thirtyplus.v1", deviceIdentifier: DeviceID.persisted)
///     }
///     var encoder: JSONEncoder { .myAPI }   // the app's own coders
///     var decoder: JSONDecoder { .myAPI }
/// }
/// ```
public protocol APIConfigurationProtocol {
    /// Environment this configuration targets (defaults to `AppEnvironment.current()`)
    var environment: AppEnvironment { get }

    /// Base URL for every environment
    var baseURLs: BaseURLs { get }

    /// App and device details sent as `X-*` headers
    var metadata: ClientMetadata { get }

    /// Extra headers sent with every request (defaults to none)
    var additionalHeaders: [String: String] { get }

    /// Encoder for request bodies (no default: key and date conventions belong to the backend)
    var encoder: JSONEncoder { get }

    /// Decoder for response bodies, including `APIError` bodies
    var decoder: JSONDecoder { get }

    /// Country, currency, locale and time zone for display formatting (defaults to `Region.current`)
    ///
    /// The client does not use it. Apply it app-wide once at launch with
    /// `Region.current = configuration.region`.
    var region: Region { get }
}

public extension APIConfigurationProtocol {
    var environment: AppEnvironment { .current() }

    var additionalHeaders: [String: String] { [:] }

    var region: Region { .current }

    /// Base URL for `environment`
    var baseURL: URL { baseURLs[environment] }
}

/// Base URL per environment
public struct BaseURLs: Sendable, Equatable {
    public var local: URL
    public var staging: URL
    public var production: URL

    public init(local: URL, staging: URL, production: URL) {
        self.local = local
        self.staging = staging
        self.production = production
    }

    public subscript(environment: AppEnvironment) -> URL {
        switch environment {
        case .local: local
        case .staging: staging
        case .production: production
        }
    }
}

/// Ready-made `APIConfigurationProtocol` for apps that don't need their own type
///
/// Uses plain `JSONEncoder()` / `JSONDecoder()` (camelCase keys, default date
/// strategy). Conform your own type instead when the backend needs other coders.
///
/// Example:
/// ```swift
/// let configuration = DefaultAPIConfiguration(
///     baseURLs: .init(
///         local: URL(string: "http://localhost:3000")!,
///         staging: URL(string: "https://staging-api.thirtyplus.com")!,
///         production: URL(string: "https://api.thirtyplus.com")!
///     ),
///     apiVersion: "application/api.thirtyplus.v1",
///     deviceIdentifier: DeviceID.persisted
/// )
/// ```
public struct DefaultAPIConfiguration: APIConfigurationProtocol, Sendable {
    public var environment: AppEnvironment
    public var baseURLs: BaseURLs
    public var metadata: ClientMetadata
    public var additionalHeaders: [String: String]
    public var region: Region
    public let encoder: JSONEncoder = .init()
    public let decoder: JSONDecoder = .init()
    
    public init(config: APIConfigurationProtocol) {
        self.init(
            environment: config.environment,
            region: config.region,
            baseURLs: config.baseURLs,
            metadata: config.metadata,
            additionalHeaders: config.additionalHeaders
        )
    }
    
    public init(
        environment: AppEnvironment = .current(),
        region: Region = .current,
        baseURLs: BaseURLs,
        metadata: ClientMetadata,
        additionalHeaders: [String: String] = [:]
    ) {
        self.region = region
        self.environment = environment
        self.baseURLs = baseURLs
        self.metadata = metadata
        self.additionalHeaders = additionalHeaders
    }

    /// Creates a configuration with metadata read from the running app
    public init(
        environment: AppEnvironment = .current(),
        region: Region = .current,
        baseURLs: BaseURLs,
        apiVersion: String,
        deviceIdentifier: String,
        additionalHeaders: [String: String] = [:]
    ) {
        self.init(
            environment: environment,
            region: region,
            baseURLs: baseURLs,
            metadata: .current(apiVersion: apiVersion, deviceIdentifier: deviceIdentifier),
            additionalHeaders: additionalHeaders
        )
    }
}

// MARK: - Client Metadata

/// App and device details sent with every request
public struct ClientMetadata: Sendable, Equatable {
    public var platform: String
    /// Should be stable across launches (e.g. persisted in the Keychain)
    public var deviceIdentifier: String
    public var appVersion: String
    public var osVersion: String
    public var apiVersion: String

    public init(platform: String, deviceIdentifier: String, appVersion: String, osVersion: String, apiVersion: String) {
        self.platform = platform
        self.deviceIdentifier = deviceIdentifier
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.apiVersion = apiVersion
    }

    /// Reads platform, app version and OS version from the running process
    public static func current(apiVersion: String, deviceIdentifier: String, bundle: Bundle = .main) -> Self {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = os.patchVersion == 0
            ? "\(os.majorVersion).\(os.minorVersion)"
            : "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        return Self(
            platform: currentPlatform,
            deviceIdentifier: deviceIdentifier,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
            osVersion: osVersion,
            apiVersion: apiVersion
        )
    }

    /// The `X-*` headers RWLabs backends expect
    public var headers: [String: String] {
        [
            "X-Device-Identifier": deviceIdentifier,
            "X-Platform": platform,
            "X-Accept": "application/json",
            "X-App-Version": appVersion,
            "X-OS-Version": osVersion,
            "X-Api-Version": apiVersion
        ]
    }

    private static var currentPlatform: String {
        #if os(iOS)
        "ios"
        #elseif os(macOS)
        "macos"
        #elseif os(tvOS)
        "tvos"
        #elseif os(watchOS)
        "watchos"
        #elseif os(visionOS)
        "visionos"
        #else
        "unknown"
        #endif
    }
}

