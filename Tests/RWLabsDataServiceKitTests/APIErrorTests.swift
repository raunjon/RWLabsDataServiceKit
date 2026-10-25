//
//  APIErrorTests.swift
//  RWLabsDataServiceKitTests
//

import Foundation
import Testing
@testable import RWLabsDataServiceKit

private func decode(_ json: String) throws -> APIError {
    try JSONDecoder.rwlabs.decode(APIError.self, from: Data(json.utf8))
}

@Suite struct APIErrorDecodingTests {

    @Test func legacyShapePrefersTopLevelMessage() throws {
        let error = try decode(#"{"message": "Not found", "status": "404", "error": {"status": 404, "message": "No such user"}}"#)
        #expect(error == APIError(message: "Not found", status: 404))
    }

    @Test func nestedErrorObjectFillsMissingFields() throws {
        let error = try decode(#"{"error": {"status": 422, "message": "Invalid", "code": "validation_failed"}}"#)
        #expect(error == APIError(message: "Invalid", status: 422, code: "validation_failed"))
    }

    @Test func errorAsAPlainString() throws {
        #expect(try decode(#"{"error": "Invalid token"}"#).message == "Invalid token")
    }

    @Test(arguments: [#"{"status": 401}"#, #"{"status": "401"}"#])
    func statusAsNumberOrString(json: String) throws {
        #expect(try decode(json).status == 401)
    }

    @Test func fieldErrorsKeysFollowTheKeyStrategy() throws {
        let error = try decode(#"{"errors": {"first_name": ["can't be blank"], "email": ["is invalid", "is taken"]}}"#)
        #expect(error.fieldErrors == ["firstName": ["can't be blank"], "email": ["is invalid", "is taken"]])
        #expect(error.message == nil)
    }

    @Test func fieldErrorsAsSingleStrings() throws {
        #expect(try decode(#"{"errors": {"email": "is invalid"}}"#).fieldErrors == ["email": ["is invalid"]])
    }

    @Test func errorListIsStoredUnderBase() throws {
        #expect(try decode(#"{"errors": ["Something went wrong"]}"#).fieldErrors == ["base": ["Something went wrong"]])
    }

    @Test func unexpectedTypesAreSkippedNotFatal() throws {
        let error = try decode(#"{"message": "Hi", "status": {"weird": true}, "code": 42, "errors": 7}"#)
        #expect(error == APIError(message: "Hi", status: nil, code: "42"))
    }

    @Test func unrelatedJSONIsEmpty() throws {
        #expect(try decode(#"{"foo": 1}"#).isEmpty)
    }
}

@Suite struct NetworkErrorDescriptionTests {

    private func httpError(_ status: Int, _ body: String) async -> NetworkError? {
        let server = StubServer(.json(status, body))
        do {
            let _: EmptyResponse = try await server.client().send(.get("thing"))
            return nil
        } catch {
            return error
        }
    }

    @Test func unrelatedBodyGivesNilAPIError() async throws {
        let error = try #require(await httpError(500, #"{"foo": 1}"#))
        #expect(error.statusCode == 500)
        #expect(error.apiError == nil)
    }

    @Test func serverMessageIsTheDescription() async throws {
        let error = try #require(await httpError(422, #"{"error": "Email is taken"}"#))
        #expect(error.localizedDescription == "Email is taken")
    }

    @Test func baseValidationErrorIsUsedWhenThereIsNoMessage() async throws {
        let error = try #require(await httpError(422, #"{"errors": ["Plan limit reached"]}"#))
        #expect(error.localizedDescription == "Plan limit reached")
    }

    @Test func statusTextIsTheFallback() async throws {
        let error = try #require(await httpError(404, "{}"))
        #expect(error.localizedDescription == "Not found")
    }

    @Test func otherCasesHaveReadableDescriptions() {
        #expect(NetworkError.transport(URLError(.notConnectedToInternet)).localizedDescription == URLError(.notConnectedToInternet).localizedDescription)
        #expect(NetworkError.cancelled.localizedDescription == "The request was cancelled.")
        #expect(NetworkError.invalidURL("x").localizedDescription == "The request URL is invalid.")
    }
}
