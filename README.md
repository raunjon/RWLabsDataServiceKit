# RWLabsDataServiceKit

An async/await networking library for RWLabs apps, plus a small set of formatting helpers.

The package has two products:

| Product | What it is | Depends on |
|---|---|---|
| `RWLabsDataServiceKit` | HTTP client, typed errors, interceptors, per-environment API configuration | `RWLabsFoundation` |
| `RWLabsFoundation` | Region (country, currency, locale, time zone) presets for every country, date and currency formatting, relative time, small conveniences | nothing |

## Requirements

- iOS 15+ / macOS 12+
- Xcode 16+ (swift-tools-version 6.0; the package builds in Swift 5 language mode)

## Installation

Releases are tagged with semantic versions. Add the package by version:

```swift
dependencies: [
    .package(url: "https://github.com/raunjon/RWLabsDataServiceKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "RWLabsDataServiceKit", package: "RWLabsDataServiceKit"),
            .product(name: "RWLabsFoundation", package: "RWLabsDataServiceKit")
        ]
    )
]
```

In Xcode: File → Add Package Dependencies…, enter the repository URL, choose **Up to Next Major Version** from `1.0.0`, and add both products to the app target. Link `RWLabsFoundation` explicitly if you import it, rather than relying on it coming in through `RWLabsDataServiceKit`.

To work on the library and an app at the same time, drag the local `RWLabsDataServiceKit` folder into the app's Xcode project: the local copy overrides the versioned dependency until you remove it.

## Quick start

### 1. Describe your API

Conform one app-side type to `APIConfigurationProtocol`. It can hold your other environment-specific settings too.

```swift
import RWLabsDataServiceKit
import RWLabsFoundation

struct AppConfig: APIConfigurationProtocol {
    static let shared = AppConfig()

    // environment defaults to AppEnvironment.current() (APP_ENVIRONMENT in Info.plist)
    let baseURLs = BaseURLs(
        local: URL(string: "http://localhost:3000")!,
        staging: URL(string: "https://staging-api.example.com")!,
        production: URL(string: "https://api.example.com")!
    )

    var metadata: ClientMetadata {
        .current(apiVersion: "application/api.example.v1", deviceIdentifier: DeviceID.persisted)
    }

    // Your backend's key and date conventions (see "Coders" below)
    var encoder: JSONEncoder { .myAPI }
    var decoder: JSONDecoder { .myAPI }

    var region: Region { .india }

    // Non-API settings can live here as well
    var analyticsKey: String { environment == .production ? "prod-key" : "dev-key" }
}
```

If you don't need your own type, use `DefaultAPIConfiguration`. It uses plain `JSONEncoder()` / `JSONDecoder()`:

```swift
let config = DefaultAPIConfiguration(
    region: .india,
    baseURLs: BaseURLs(local: …, staging: …, production: …),
    apiVersion: "application/api.example.v1",
    deviceIdentifier: DeviceID.persisted
)
```

| Requirement | Default |
|---|---|
| `baseURLs` | required |
| `metadata` | required |
| `encoder` / `decoder` | required |
| `environment` | `AppEnvironment.current()` |
| `additionalHeaders` | `[:]` |
| `region` | `Region.current` |

### 2. Create one client at launch

Build the client from the configuration once, and apply the region for formatting:

```swift
let config = AppConfig.shared
let headers = config.metadata.headers.merging(config.additionalHeaders) { $1 }

let client = URLSessionHTTPClient(
    baseURL: config.baseURL,
    encoder: config.encoder,
    decoder: config.decoder,
    interceptors: [
        HeadersInterceptor {
            var all = headers
            if let token = await AuthStore.shared.token {
                all["X-Auth-Token"] = token
            }
            return all
        },
        UnauthorizedInterceptor { await AuthStore.shared.logOut() },
        LoggingInterceptor()
    ]
)

Region.current = config.region
```

- `metadata.headers` gives the `X-Device-Identifier`, `X-Platform`, `X-Accept`, `X-App-Version`, `X-OS-Version` and `X-Api-Version` headers.
- `HeadersInterceptor`'s closure runs before every request, so a refreshed token is picked up.
- `UnauthorizedInterceptor` runs on any 401 or 403.
- `LoggingInterceptor` logs requests and responses in DEBUG builds, with the auth token redacted. Put it last so it logs the final headers.

Wrap this in a factory in your app (for example `URLSessionHTTPClient.myApp(configuration:token:onUnauthorized:)`) so every target builds the client the same way. If the environment changes at runtime (for example from a debug menu), build a new client.

### 3. Declare endpoints next to their models

```swift
struct Product: Codable, Sendable, Identifiable {
    let id: Int
    let displayName: String   // "display_name" with a snake_case decoder
    let priceCents: Int
}

extension Request where Response == [Product] {
    static func products(category: String, page: Int? = nil) -> Self {
        .get("products", query: ["category": category, "page": page])   // nil values are dropped
    }
}

extension Request where Response == Product {
    static func createProduct(_ draft: ProductDraft) -> Self {
        .post("products", body: draft)   // encoded with the client's encoder
    }
}

extension Request where Response == EmptyResponse {
    static func deleteProduct(id: Int) -> Self {
        .delete("products/\(id)")         // 204 / empty bodies decode to EmptyResponse
    }
}
```

`Request` has `.get`, `.post`, `.put`, `.patch` and `.delete` shortcuts. Every method accepts query parameters, and POST, PUT, PATCH and DELETE accept a body. For full control, use `Request(method:path:query:headers:body:timeout:)`. `Body` is either `.json(value)` or `.data(data, contentType:)`.

Paths are appended to the base URL. A path containing `://` is used as an absolute URL. Query items are appended to any query already in the path, sorted by name.

### 4. Send requests

```swift
let products = try await client.send(.products(category: "lighting"))
```

## Repositories

The library does not ship a repository base type. Define the protocol your view models need, and implement it over `HTTPClient`. A cached or persistence-backed implementation can replace it later without touching the view models.

```swift
protocol ProductRepository: Sendable {
    func products(in category: String) async throws(NetworkError) -> [Product]
}

struct RemoteProductRepository: ProductRepository {
    let client: any HTTPClient

    func products(in category: String) async throws(NetworkError) -> [Product] {
        try await client.send(.products(category: category))
    }
}

@MainActor @Observable
final class ProductListViewModel {
    private let repository: any ProductRepository
    var products: [Product] = []
    var errorMessage: String?

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            products = try await repository.products(in: "lighting")
        } catch .http(statusCode: 404, _, _) {
            products = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

Responses are not delivered on the main thread; `@MainActor` callers like the view model above resume on the main actor automatically.

## Errors

`send` uses typed throws, so every failure is a `NetworkError`:

| Case | When |
|---|---|
| `.invalidURL(String)` | The base URL and path don't form a valid URL |
| `.encoding(Error)` | The request body couldn't be encoded |
| `.transport(URLError)` | No HTTP response: offline, timeout, TLS failure, … |
| `.cancelled` | The surrounding `Task` or the URL session cancelled the request |
| `.http(statusCode:error:data:)` | The server answered with a non-2xx status |
| `.decoding(DecodingError, data:)` | The response body didn't match the expected type |

Helpers: `statusCode`, `apiError`, `isUnauthorized` (401 or 403), and `localizedDescription`. For `.http`, `localizedDescription` is the server's message if it sent one, then its first general validation error, then the standard text for the status code ("Not found").

Wrapping `send` in `Task { }` erases the typed error to `any Error`; cast it back with `as? NetworkError`.

### Error bodies

The body of a non-2xx response is decoded leniently into `APIError`. An unexpected field never discards the rest:

```json
{"message": "Not found", "status": "404"}
{"error": "Invalid token"}
{"error": {"status": 422, "message": "Invalid", "code": "validation_failed"}}
{"errors": {"email": ["is invalid", "is taken"], "first_name": "can't be blank"}}
{"errors": ["Plan limit reached"]}
```

| Property | Source |
|---|---|
| `message` | `message`, else `error.message`, else `error` when it is a string |
| `status` | `status` at either level, number or string |
| `code` | `code` at either level |
| `fieldErrors` | `errors` keyed by field. Field names follow the decoder's key strategy, so `first_name` becomes `firstName` with `.convertFromSnakeCase`. A plain list is stored under `"base"`. |

`apiError` is `nil` when the body has none of these fields.

## Interceptors

Interceptors see every request and response:

```swift
public protocol Interceptor: Sendable {
    func adapt(_ request: URLRequest) async throws(NetworkError) -> URLRequest
    func handle(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws(NetworkError) -> InterceptorAction
}
```

Both methods have pass-through defaults. `adapt` runs in order before each attempt. `handle` runs in order on every response, including errors, and can return `.retry` to send the request once more.

Built-in interceptors:

- `HeadersInterceptor { ["X-Header": value] }`: adds headers on every attempt without overwriting headers already on the request.
- `UnauthorizedInterceptor(retry:onUnauthorized:)`: runs a handler on 401/403. With `retry: true`, the request is sent again after the handler finishes, for example after refreshing a token.
- `LoggingInterceptor(redactedHeaders:)`: DEBUG-only request and response logging.

For example, to refresh an expired token and retry once:

```swift
UnauthorizedInterceptor(retry: true) { await AuthStore.shared.refresh() }
```

## Progress

```swift
let report: Report = try await client.send(.report(id: 7)) { progress in
    print("Downloaded \(Int(progress * 100))%")
}
```

Progress goes from 0.0 to 1.0. When the server doesn't send a content length, it is reported once, as 1.0, at the end.

## Environments

`AppEnvironment` has `local`, `staging` and `production`. `AppEnvironment.current()` reads the `APP_ENVIRONMENT` key from Info.plist and falls back to `production`:

1. In each build configuration's xcconfig: `APP_ENVIRONMENT = staging`
2. In Info.plist: `APP_ENVIRONMENT` = `$(APP_ENVIRONMENT)`

To reach a plain-HTTP local server, add `NSAllowsLocalNetworking` under `NSAppTransportSecurity` in the app's Info.plist. The iOS Simulator reaches the Mac's `localhost` directly.

## Coders

The library has no built-in coders: the configuration's `encoder` and `decoder` are used for request bodies, responses and `APIError` bodies. Define your backend's conventions once in the app, for example:

```swift
extension JSONEncoder {
    static var myAPI: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var myAPI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
```

With `.convertFromSnakeCase`, a property named `userID` will not match `user_id`; name it `userId`.

## Testing your app

Depend on `any HTTPClient` (or your own repository protocols), and swap in a fake in tests and previews:

```swift
struct FakeClient: HTTPClient {
    func send<R>(_ request: Request<R>) async throws(NetworkError) -> R {
        switch request.path {
        case "products": return [Product.mock] as! R
        default: throw .http(statusCode: 404, error: nil, data: Data())
        }
    }
}
```

## RWLabsFoundation

### Region

`Region` holds a country code, currency code, locale and time zone. There is a preset for every country, generated from system data:

```swift
Region.india            // IN, INR, en_IN, Asia/Kolkata
Region.unitedStates     // US, USD, en_US, America/New_York
Region.unitedKingdom    // GB, GBP, en_GB, Europe/London
Region(countryCode: "jp")   // lookup by ISO code, case-insensitive
Region.all              // every preset, sorted by code (Identifiable, ready for a picker)
Region.device           // the device's own settings
```

Every preset uses an `en_<country>` locale: English text with the country's number and date formats. Countries spanning several time zones use the capital's or the most populous one.

Each region also gives you `countryName()`, `currencyName()`, `currencySymbol` and a Gregorian `calendar` in its time zone.

`Region.current` is what the formatting helpers default to. It starts as INR with the device's locale and time zone; set it once at launch.

### Formatting helpers

```swift
1234.5.toCurrency()                            // "₹1,234.50" with Region.current = .india
Decimal(string: "19.99")!.toCurrency(code: "USD", locale: Locale(identifier: "en_US"))
date.toString(fromFormat: DateFormats.pretty)  // display: Region.current's locale and time zone
"2026-01-02T03:04:05".toDate()                 // parsing: always en_US_POSIX
"2026-01-02T03:04:05.123+05:30".toISO8601Date()
date.add(days: 1)                              // same wall-clock time across DST changes
Utils.getLastPosted(dateString: createdAt)     // "2 hours ago", or "02 Jan, 2026" after a week
Utils.getTimestamp(dateString: createdAt)      // "5m", "3h", "2d"
```

Parsing fixed-format strings always uses `Locale.posix`, so it works whatever the device's language or 12/24-hour setting. Display formatting uses `Region.current` unless you pass a locale or time zone.

Also included: `Array.chunked(into:)` and `move`, JSON conveniences on `Data`, `Encodable` and `Dictionary`, and `DateFormats` / `Unicodes` constants.

## Development

```bash
swift build
```

```bash
swift test
```

To run every test target on iOS, use the `RWLabsDataServiceKit-Package` scheme with a simulator from `xcodebuild -scheme RWLabsDataServiceKit-Package -showdestinations`:

```bash
xcodebuild test -scheme RWLabsDataServiceKit-Package -destination 'platform=iOS Simulator,id=<simulator-id>'
```

The country presets in `Sources/RWLabsFoundation/Region+Countries.swift` are generated. To change them, edit `Scripts/GenerateRegions.swift` and run, on macOS:

```bash
swift Scripts/GenerateRegions.swift > Sources/RWLabsFoundation/Region+Countries.swift
```
