//
//  APIConfigurationTests.swift
//  RWLabsDataServiceKitTests
//

import Foundation
import Testing
import RWLabsFoundation
@testable import RWLabsDataServiceKit

@Suite struct APIConfigurationTests {

    private let metadata = ClientMetadata(
        platform: "ios",
        deviceIdentifier: "device-1",
        appVersion: "2.3.0",
        osVersion: "18.3",
        apiVersion: "application/api.test.v1"
    )

    private func baseURLs(staging: URL = URL(string: "https://staging.example.com")!) -> BaseURLs {
        .init(
            local: URL(string: "http://localhost:3000")!,
            staging: staging,
            production: URL(string: "https://api.example.com")!
        )
    }

    @Test(arguments: [
        (AppEnvironment.local, "http://localhost:3000"),
        (.staging, "https://staging.example.com"),
        (.production, "https://api.example.com")
    ])
    func baseURLFollowsEnvironment(environment: AppEnvironment, expected: String) {
        let configuration = DefaultAPIConfiguration(environment: environment, baseURLs: baseURLs(), metadata: metadata)
        #expect(configuration.baseURL.absoluteString == expected)
    }

    @Test func environmentFallsBackWhenInfoPlistKeyIsMissing() {
        let bundle = Bundle(for: BundleToken.self)
        #expect(AppEnvironment.current(infoPlistKey: "MISSING_KEY", bundle: bundle) == .production)
        #expect(AppEnvironment.current(infoPlistKey: "MISSING_KEY", bundle: bundle, fallback: .staging) == .staging)
    }

    @Test func currentMetadataReadsOSVersionAndPlatform() {
        let current = ClientMetadata.current(apiVersion: "v1", deviceIdentifier: "abc")
        #expect(current.deviceIdentifier == "abc")
        #expect(current.apiVersion == "v1")
        #expect(current.osVersion.hasPrefix("\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)."))
        #expect(!current.platform.isEmpty)
    }

    @Test func metadataProducesTheStandardHeaders() {
        #expect(metadata.headers == [
            "X-Device-Identifier": "device-1",
            "X-Platform": "ios",
            "X-Accept": "application/json",
            "X-App-Version": "2.3.0",
            "X-OS-Version": "18.3",
            "X-Api-Version": "application/api.test.v1"
        ])
    }

    @Test func defaultConfigurationUsesPlainCoders() throws {
        let configuration = DefaultAPIConfiguration(environment: .staging, baseURLs: baseURLs(), metadata: metadata)

        let data = try configuration.encoder.encode(["fullName": "Ada"])
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["fullName"] as? String == "Ada")
    }

    @Test func clientBuiltFromConfigurationSendsMetadataAndAdditionalHeaders() async throws {
        let server = StubServer(StubResponse(status: 204))
        let configuration = DefaultAPIConfiguration(
            environment: .staging,
            baseURLs: baseURLs(staging: server.baseURL),
            metadata: metadata,
            additionalHeaders: ["X-Request-Source": "tests", "X-Platform": "override"]
        )
        let client = URLSessionHTTPClient.configured(by: configuration, session: server.session)

        let _: EmptyResponse = try await client.send(.get("me"))

        let request = try #require(server.requests.first)
        #expect(request.url.absoluteString == "https://\(server.host)/api/me")
        #expect(request.header("X-Device-Identifier") == "device-1")
        #expect(request.header("X-App-Version") == "2.3.0")
        #expect(request.header("X-OS-Version") == "18.3")
        #expect(request.header("X-Api-Version") == "application/api.test.v1")
        #expect(request.header("X-Request-Source") == "tests")
        #expect(request.header("X-Platform") == "override")
    }
}

// MARK: - App-style conformer

/// What an app would write: API settings alongside other environment config,
/// relying on the protocol's defaults for `additionalHeaders`
private struct AppConfig: APIConfigurationProtocol {
    var environment: AppEnvironment = .staging
    var stagingURL = URL(string: "https://staging.example.com")!

    var baseURLs: BaseURLs {
        BaseURLs(
            local: URL(string: "http://localhost:3000")!,
            staging: stagingURL,
            production: URL(string: "https://api.example.com")!
        )
    }

    var metadata: ClientMetadata {
        ClientMetadata(platform: "ios", deviceIdentifier: "device-1", appVersion: "2.3.0", osVersion: "18.3", apiVersion: "v1")
    }

    var encoder: JSONEncoder { .snakeCase }

    var decoder: JSONDecoder { .snakeCase }

    // Non-API, environment-specific setting living in the same type
    var analyticsKey: String { environment == .production ? "prod-key" : "dev-key" }

    var region: Region { .india }
}

/// Defines only the required members, so every default applies
private struct MinimalConfig: APIConfigurationProtocol {
    let baseURLs = BaseURLs(
        local: URL(string: "http://localhost:3000")!,
        staging: URL(string: "https://staging.example.com")!,
        production: URL(string: "https://api.example.com")!
    )
    let metadata = ClientMetadata(platform: "ios", deviceIdentifier: "d", appVersion: "1", osVersion: "18", apiVersion: "v1")
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
}

private struct Product: Codable, Equatable, Sendable {
    let id: Int
    let displayName: String
    let priceCents: Int
}

private extension Request where Response == [Product] {
    static func products(category: String, page: Int? = nil) -> Self {
        .get("products", query: ["category": category, "page": page])
    }
}

private protocol ProductRepository: Sendable {
    func products(in category: String) async throws(NetworkError) -> [Product]
}

private struct RemoteProductRepository: ProductRepository {
    let client: any HTTPClient

    func products(in category: String) async throws(NetworkError) -> [Product] {
        try await client.send(.products(category: category))
    }
}

@Suite struct AppConfigurationConformerTests {

    @Test func protocolDefaultsApply() {
        let config = MinimalConfig()
        #expect(config.environment == AppEnvironment.current())
        #expect(config.additionalHeaders.isEmpty)
        #expect(config.baseURL == config.baseURLs[config.environment])
    }

    @Test func appConfigDrivesARepositoryCall() async throws {
        let server = StubServer(.json(#"[{"id": 1, "display_name": "Lamp", "price_cents": 4500}]"#))
        let config = AppConfig(stagingURL: server.baseURL)
        let client = URLSessionHTTPClient.configured(
            by: config,
            session: server.session,
            interceptors: [HeadersInterceptor { ["X-Auth-Token": "secret"] }]
        )
        let repository: any ProductRepository = RemoteProductRepository(client: client)

        let products = try await repository.products(in: "lighting")

        #expect(products == [Product(id: 1, displayName: "Lamp", priceCents: 4500)])
        #expect(config.analyticsKey == "dev-key")
        let request = try #require(server.requests.first)
        #expect(request.url.absoluteString == "https://\(server.host)/api/products?category=lighting")
        #expect(request.header("X-Auth-Token") == "secret")
        #expect(request.header("X-Api-Version") == "v1")
    }
}

// MARK: - Custom coding

/// A backend that uses camelCase keys and epoch-second dates
private struct CamelCaseBackendConfig: APIConfigurationProtocol {
    var environment: AppEnvironment = .staging
    var stagingURL: URL

    var baseURLs: BaseURLs {
        BaseURLs(local: stagingURL, staging: stagingURL, production: stagingURL)
    }

    var metadata: ClientMetadata {
        ClientMetadata(platform: "ios", deviceIdentifier: "d", appVersion: "1", osVersion: "18", apiVersion: "v1")
    }

    var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

private struct Event: Codable, Equatable, Sendable {
    let eventName: String
    let startsAt: Date
}

@Suite struct CustomCodingConfigurationTests {

    @Test func clientUsesTheConfiguredDecoderAndEncoder() async throws {
        let server = StubServer(.json(#"{"eventName": "Launch", "startsAt": 1767323045}"#))
        let client = URLSessionHTTPClient.configured(
            by: CamelCaseBackendConfig(stagingURL: server.baseURL),
            session: server.session
        )
        let draft = Event(eventName: "Draft", startsAt: Date(timeIntervalSince1970: 0))

        let event: Event = try await client.send(.post("events", body: draft))

        #expect(event == Event(eventName: "Launch", startsAt: Date(timeIntervalSince1970: 1_767_323_045)))
        let body = try #require(server.requests.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["eventName"] as? String == "Draft")
        #expect(json["startsAt"] as? Double == 0)
    }
}

@Suite struct BaseItemTests {
    private struct Item: BaseItem {
        let id: Int
        var title: String
    }

    @Test func itemsWithSameIDButDifferentContentAreNotEqual() {
        let original = Item(id: 1, title: "Draft")
        var edited = original
        edited.title = "Published"

        #expect(original != edited)
        #expect(Set([original, edited]).count == 2)
    }
}

private final class BundleToken {}

// MARK: - Region

@Suite struct ConfigurationRegionTests {
    private let baseURLs = BaseURLs(
        local: URL(string: "http://localhost:3000")!,
        staging: URL(string: "https://staging.example.com")!,
        production: URL(string: "https://api.example.com")!
    )
    private let metadata = ClientMetadata(platform: "ios", deviceIdentifier: "d", appVersion: "1", osVersion: "18", apiVersion: "v1")

    @Test func initStoresRegionWithoutChangingTheGlobal() {
        // No other test sets Japan, so seeing it in Region.current would mean the init leaked it
        let configuration = DefaultAPIConfiguration(region: .japan, baseURLs: baseURLs, metadata: metadata)

        #expect(configuration.region == .japan)
        #expect(Region.current != .japan)
    }

    @Test func initFromConformerCopiesItsRegion() {
        let configuration = DefaultAPIConfiguration(config: AppConfig())

        #expect(configuration.region == .india)
        #expect(configuration.environment == .staging)
    }

    @Test func conformersWithoutRegionStillBuildAClient() async throws {
        let server = StubServer(StubResponse(status: 204))
        let config = CamelCaseBackendConfig(stagingURL: server.baseURL)

        let _: EmptyResponse = try await URLSessionHTTPClient.configured(by: config, session: server.session).send(.get("ping"))

        #expect(server.requests.count == 1)
    }
}
