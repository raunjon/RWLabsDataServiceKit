//
//  InterceptorTests.swift
//  RWLabsDataServiceKitTests
//

import Foundation
import Testing
@testable import RWLabsDataServiceKit

@Suite struct InterceptorTests {

    @Test func headersInterceptorAddsHeadersWithoutOverridingRequestHeaders() async throws {
        let server = StubServer(StubResponse(status: 204))
        let client = server.client(interceptors: [
            HeadersInterceptor { ["X-Auth-Token": "secret", "X-Platform": "ios"] }
        ])

        let request = Request<EmptyResponse>(method: .get, path: "me", headers: ["X-Platform": "watchos"])
        _ = try await client.send(request)

        let recorded = try #require(server.requests.first)
        #expect(recorded.header("X-Auth-Token") == "secret")
        #expect(recorded.header("X-Platform") == "watchos")
    }

    @Test func headersAreReadOnEveryRequest() async throws {
        let server = StubServer(StubResponse(status: 204))
        let tokens = Recorder<String>()
        let client = server.client(interceptors: [
            HeadersInterceptor {
                let token = "token-\(tokens.values.count)"
                tokens.append(token)
                return ["X-Auth-Token": token]
            }
        ])

        let _: EmptyResponse = try await client.send(.get("a"))
        let _: EmptyResponse = try await client.send(.get("b"))

        #expect(server.requests.map { $0.header("X-Auth-Token") } == ["token-0", "token-1"])
    }

    @Test func unauthorizedInterceptorRunsHandlerAndRethrows() async throws {
        let server = StubServer(.json(401, #"{"message": "Expired"}"#))
        let calls = Recorder<Void>()
        let client = server.client(interceptors: [UnauthorizedInterceptor { calls.append(()) }])

        do {
            let _: EmptyResponse = try await client.send(.get("me"))
            Issue.record("Expected an error")
        } catch {
            #expect(error.isUnauthorized)
            #expect(error.apiError?.message == "Expired")
        }
        #expect(calls.values.count == 1)
        #expect(server.requests.count == 1)
    }

    @Test func unauthorizedInterceptorCanRetryWithFreshHeaders() async throws {
        let server = StubServer { request, _ in
            request.header("X-Auth-Token") == "fresh" ? .json(#"{"ok": true}"#) : .json(401, "{}")
        }
        let token = Recorder<String>()
        let client = server.client(interceptors: [
            HeadersInterceptor { ["X-Auth-Token": token.values.last ?? "stale"] },
            UnauthorizedInterceptor(retry: true) { token.append("fresh") }
        ])

        let response: [String: Bool] = try await client.send(.get("me"))

        #expect(response == ["ok": true])
        #expect(server.requests.map { $0.header("X-Auth-Token") } == ["stale", "fresh"])
    }

    @Test func retryHappensAtMostOnce() async throws {
        let server = StubServer(.json(401, "{}"))
        let client = server.client(interceptors: [UnauthorizedInterceptor(retry: true) {}])

        do {
            let _: EmptyResponse = try await client.send(.get("me"))
            Issue.record("Expected an error")
        } catch {
            #expect(error.statusCode == 401)
        }
        #expect(server.requests.count == 2)
    }

    @Test func interceptorErrorsAbortTheRequest() async throws {
        struct Reject: Interceptor {
            func adapt(_ request: URLRequest) async throws(NetworkError) -> URLRequest {
                throw .invalidURL("rejected")
            }
        }
        let server = StubServer(StubResponse(status: 204))

        do {
            let _: EmptyResponse = try await server.client(interceptors: [Reject()]).send(.get("me"))
            Issue.record("Expected an error")
        } catch {
            guard case .invalidURL("rejected") = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(server.requests.isEmpty)
    }

    @Test func loggingInterceptorPassesRequestsThrough() async throws {
        let server = StubServer(.json(#"{"ok": true}"#))
        let client = server.client(interceptors: [LoggingInterceptor()])

        let response: [String: Bool] = try await client.send(.post("echo", body: ["a": 1]))

        #expect(response == ["ok": true])
    }
}
