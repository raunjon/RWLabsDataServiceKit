# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RWLabsDataServiceKit is a dependency-free Swift package providing the async/await networking layer for RWLabs/ThirtyPlus apps, with a SwiftData persistence layer planned later. Apps consume it via a local path dependency (`.package(path: "../RWLabsDataServiceKit")`), so public API changes directly affect sibling app projects. RWLabsExamples vendors its own older copy under `Libraries/` and does not track this package.

## Build & test

```bash
swift build
```

```bash
swift test
```

Run a single test with `swift test --filter <Suite>/<testName>`. To check iOS as well, use the `RWLabsDataServiceKit-Package` scheme (runs both test targets) with a simulator id from `xcodebuild -scheme RWLabsDataServiceKit-Package -showdestinations` (names are ambiguous across installed runtimes):

```bash
xcodebuild test -scheme RWLabsDataServiceKit-Package -destination 'platform=iOS Simulator,id=<simulator-id>'
```

Tests use Swift Testing. Locale-formatted output (currency, relative dates) differs between ICU versions on iOS and macOS, so compare it loosely (e.g. ignore whitespace). `Tests/.../Support/StubServer.swift` serves canned responses through a `URLProtocol` keyed by a unique host per server, so suites run in parallel safely; build new networking tests on it rather than hitting the network.

Package: swift-tools 6.0 in Swift 5 language mode (`swiftLanguageModes: [.v5]`), iOS 15+ / macOS 12+. Typed throws (`throws(NetworkError)`) is used throughout.

## Architecture

Two products: `RWLabsDataServiceKit` (networking, depends on `RWLabsFoundation`) and `RWLabsFoundation` (formatting/convenience helpers, must not depend on the networking library). The package has been refactored folder by folder; only `Utilities/Log.swift` has not been reviewed. README.md is the user-facing guide; keep its examples in sync with API changes.

### Core (`Sources/RWLabsDataServiceKit/Core`)

- **`Request<Response: Decodable>`**: value type (method, path, query items, headers, body, timeout). Endpoints are declared as static factories in `extension Request where Response == X`. `QueryParameters` drops `nil` values and sorts keys. Paths are appended to the client's base URL unless they contain `://`; query items are appended to any query already in the path. `EmptyResponse` decodes from an empty body (204).
- **`HTTPClient`**: `send(_:) async throws(NetworkError) -> R`. `URLSessionHTTPClient` takes `baseURL`, `session`, `encoder`/`decoder` (default `.rwlabs` in `Extensions/JSONCoding+RWLabs.swift`: snake_case keys both ways; dates encode as ISO 8601 UTC and decode via `RWLabsDateCoding`: ISO 8601 fast path, then cached `yyyy-MM-dd HH:mm:ss zzz` and date-only-as-UTC-midnight fallbacks) and `interceptors`. A second `send(_:progress:)` streams via `bytes(for:)`; with no content length, progress reports only 1.0 at the end.
- **Pipeline per attempt:** build `URLRequest` (per-request headers applied first) → each interceptor's `adapt` in order → load → each interceptor's `handle` on every response (2xx included) → retry once if any returned `.retry` → non-2xx throws `.http` with `APIError` decoded if possible (`nil` when the body has none of its fields) → decode `R`.
- **`APIError`** (`Models/APIError.swift`): `Sendable` struct decoded leniently (a bad field never drops the body): `message` (top-level, `error.message`, or `error` string), `status` (number or string, either level), `code`, `fieldErrors` from `errors` (dict or list → `"base"`). Field names are read through a keyed container so the decoder's key strategy applies consistently across OS releases (`[String: _]` dictionary keys are not converted on newer Foundation). `NetworkError` is a `LocalizedError`; `.http` descriptions prefer the server message.
- **`NetworkError`**: `invalidURL`, `encoding`, `transport(URLError)`, `cancelled` (task or URLSession cancellation), `http(statusCode:error:data:)`, `decoding(DecodingError, data:)`. Helpers: `statusCode`, `apiError`, `isUnauthorized`. Interceptors also throw `NetworkError`. Wrapping `send` in a `Task` erases the typed error to `any Error`.
- **Built-in interceptors**: `HeadersInterceptor` (closure called on every attempt; never overwrites headers already on the request), `UnauthorizedInterceptor(retry:)` (401/403 handler, optionally retries once), `LoggingInterceptor` (DEBUG-only via `Log.network`, redacts `X-Auth-Token`/`Authorization`).
- Responses are not delivered on the main thread; `@MainActor` callers hop back automatically. There is no caching in Core.

### Configuration (`Sources/RWLabsDataServiceKit/Configuration`)

- **`AppEnvironment`** (`local`, `staging`, `production`): `.current()` reads `APP_ENVIRONMENT` from Info.plist (case-insensitive) and falls back to `.production`.
- **`APIConfigurationProtocol`**: environment + `BaseURLs` (one per environment) + `ClientMetadata` + `additionalHeaders`; `environment` defaults to `.current()`, `additionalHeaders` to empty, `encoder`/`decoder` to `.rwlabs` (override for a backend with different key or date conventions), and `baseURL` resolves from the environment. Apps conform their own config type so API settings sit with their other environment-specific settings; `APIConfiguration` is the ready-made struct conformer.
- **`ClientMetadata`**: platform, device id (caller supplies a stable one), app version, OS version (from `ProcessInfo`, so no UIKit/MainActor), API version; `headers` produces the `X-*` header set RWLabs backends expect.
- **`URLSessionHTTPClient.rwlabs(configuration:session:token:onUnauthorized:interceptors:)`** takes `some APIConfigurationProtocol`, reads it once (rebuild the client if the environment changes), and is the standard way to build a client: metadata + additional headers + `X-Auth-Token` from `token()`, 401/403 handler, caller interceptors, then logging last.

### Protocols and app-side layering

The library no longer ships Interactor/Repository/Interactable abstractions or a static-config protocol. Apps declare their own repository protocols that view models depend on, implemented over `any HTTPClient` and the `Request` factories, so a persistence-backed implementation can be swapped in later. Remaining protocols: `BaseItem` (`Codable & Identifiable & Hashable`, synthesized equality over all properties) and `Mockable`.

### RWLabsFoundation (`Sources/RWLabsFoundation`)

App-level helpers moved out of the networking library: date parsing/formatting (`String.toDate`, `toISO8601Date`, `Date.toString`, DST-safe `add(days:)`), locale-aware currency (`toCurrency(code:locale:)`, also on `Decimal`), relative time (`Utils.getLastPosted`/`getTimestamp`), JSON conveniences, and `Unicodes`/`DateFormats` constants. Conventions: fixed-format parsing uses `Locale.posix` and is unaffected by region; display formatting (currency code, locale, time zone, calendar) defaults to `Region.current` (country, currency, locale, time zone; starts as `Region.default` = INR with the device's locale/time zone, presets `.india` and `.device`, set once at app launch). Tests that change `Region.current` must restore it and keep its time zone, since suites run in parallel; formatters are cached in `DateFormatterCache`; time-dependent helpers take `now:`/`calendar:` parameters for tests. The networking library keeps only an internal `Data.prettyPrintedJSON` (for logging) and `URL.queryParameters`; do not declare the same extension member in both modules, or call sites importing both become ambiguous.

`Region+Countries.swift` (one `Region` preset per ISO country plus `Region.all`, looked up with `Region(countryCode:)`) is generated; do not edit it by hand. Change `Scripts/GenerateRegions.swift` (primary time zones for multi-zone countries, property-name overrides) and regenerate on macOS:

```bash
swift Scripts/GenerateRegions.swift > Sources/RWLabsFoundation/Region+Countries.swift
```
