//
//  URLSessionHTTPClientTests.swift
//  RWLabsDataServiceKitTests
//

import Foundation
import Testing
@testable import RWLabsDataServiceKit

private struct User: Codable, Equatable, Sendable {
    let id: Int
    let fullName: String
}

private struct NewUser: Encodable, Sendable {
    let fullName: String
    let isAdmin: Bool
}

/// Runs `body` and returns the error it throws, recording an issue if it succeeds
private func error<R>(
    from body: () async throws(NetworkError) -> R,
    sourceLocation: SourceLocation = #_sourceLocation
) async -> NetworkError? {
    do {
        let value = try await body()
        Issue.record("Expected an error, got \(value)", sourceLocation: sourceLocation)
        return nil
    } catch {
        return error
    }
}

@Suite struct URLSessionHTTPClientTests {

    // MARK: - Request building

    @Test func getBuildsURLWithSortedQueryAndDropsNils() async throws {
        let server = StubServer(.json(#"{"id": 1, "full_name": "Ada"}"#))

        let _: User = try await server.client().send(
            .get("/users/1?expand=team", query: ["page": 2, "search": nil, "limit": 10])
        )

        let request = try #require(server.requests.first)
        #expect(request.method == "GET")
        #expect(request.url.absoluteString == "https://\(server.host)/api/users/1?expand=team&limit=10&page=2")
        #expect(request.header("Accept") == "application/json")
        #expect(request.header("Content-Type") == nil)
        #expect(request.body == nil)
    }

    @Test func postEncodesSnakeCaseJSONBody() async throws {
        let server = StubServer(.json(201, #"{"id": 7, "full_name": "Grace"}"#))

        let user: User = try await server.client().send(.post("users", body: NewUser(fullName: "Grace", isAdmin: true)))

        #expect(user == User(id: 7, fullName: "Grace"))
        let request = try #require(server.requests.first)
        #expect(request.method == "POST")
        #expect(request.header("Content-Type") == "application/json")
        let body = try #require(request.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["full_name"] as? String == "Grace")
        #expect(json["is_admin"] as? Bool == true)
    }

    @Test func deleteSendsQueryAndBody() async throws {
        let server = StubServer(StubResponse(status: 204))

        let _: EmptyResponse = try await server.client().send(
            .delete("users/7", query: ["soft": true], body: ["reason": "duplicate"])
        )

        let request = try #require(server.requests.first)
        #expect(request.method == "DELETE")
        #expect(request.url.query == "soft=true")
        #expect(request.body == Data(#"{"reason":"duplicate"}"#.utf8))
    }

    @Test func emptyBodyDecodesToEmptyResponse() async throws {
        let server = StubServer(StubResponse(status: 204))
        let _: EmptyResponse = try await server.client().send(.post("ping"))
        #expect(server.requests.count == 1)
    }

    @Test func invalidURLThrowsBeforeSending() async throws {
        let server = StubServer(.json("{}"))

        let error = await error { () async throws(NetworkError) -> EmptyResponse in
            try await server.client().send(.get("http://[::1"))
        }

        guard case .invalidURL = error else {
            Issue.record("Expected .invalidURL, got \(String(describing: error))")
            return
        }
        #expect(server.requests.isEmpty)
    }

    // MARK: - Responses

    @Test func non2xxThrowsHTTPErrorWithDecodedBody() async throws {
        let server = StubServer(.json(404, #"{"message": "Not found", "error": {"status": 404, "message": "No such user"}}"#))

        let error = await error { () async throws(NetworkError) -> User in
            try await server.client().send(.get("users/99"))
        }

        #expect(error?.statusCode == 404)
        #expect(error?.apiError?.message == "Not found")
        #expect(error?.apiError?.status == 404)
        #expect(error?.localizedDescription == "Not found")
    }

    @Test func non2xxWithUnparseableBodyStillThrowsHTTPError() async throws {
        let server = StubServer(StubResponse(status: 500, body: Data("<html>oops</html>".utf8)))

        let error = await error { () async throws(NetworkError) -> User in
            try await server.client().send(.get("users/1"))
        }

        guard case let .http(statusCode, apiError, data) = error else {
            Issue.record("Expected .http, got \(String(describing: error))")
            return
        }
        #expect(statusCode == 500)
        #expect(apiError == nil)
        #expect(data == Data("<html>oops</html>".utf8))
    }

    @Test func malformedBodyThrowsDecodingError() async throws {
        let server = StubServer(.json(#"{"id": "not-a-number"}"#))

        let error = await error { () async throws(NetworkError) -> User in
            try await server.client().send(.get("users/1"))
        }

        guard case .decoding(.typeMismatch, _) = error else {
            Issue.record("Expected .decoding(.typeMismatch), got \(String(describing: error))")
            return
        }
    }

    @Test func transportFailureThrowsTransportError() async throws {
        let server = StubServer { _, _ in throw URLError(.notConnectedToInternet) }

        let error = await error { () async throws(NetworkError) -> User in
            try await server.client().send(.get("users/1"))
        }

        guard case let .transport(urlError) = error else {
            Issue.record("Expected .transport, got \(String(describing: error))")
            return
        }
        #expect(urlError.code == .notConnectedToInternet)
    }

    @Test func cancellingTheTaskThrowsCancelled() async throws {
        let server = StubServer(StubResponse(status: 200, body: Data("{}".utf8), delay: 5))
        let client = server.client()

        let task = Task { () async throws(NetworkError) -> EmptyResponse in
            try await client.send(.get("slow"))
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        // Task erases typed throws, so the failure comes back as `any Error`
        let result = await task.result
        guard case let .failure(error as NetworkError) = result, case .cancelled = error else {
            Issue.record("Expected .cancelled, got \(result)")
            return
        }
    }

    // MARK: - Progress

    @Test func progressIncreasesAndEndsAtOne() async throws {
        let items = (0..<5_000).map { #"{"id": \#($0), "full_name": "User \#($0)"}"# }
        let server = StubServer(.json("[\(items.joined(separator: ","))]"))
        let progress = Recorder<Double>()

        let users: [User] = try await server.client().send(.get("users"), progress: { progress.append($0) })

        #expect(users.count == 5_000)
        let values = progress.values
        #expect(values.count > 2)
        #expect(values == values.sorted())
        #expect(values.last == 1)
        #expect(values.allSatisfy { (0...1).contains($0) })
    }
}
