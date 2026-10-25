//
//  JSONCodingTests.swift
//  RWLabsDataServiceKitTests
//

import Foundation
import Testing
@testable import RWLabsDataServiceKit

private struct Stamp: Codable, Equatable, Sendable {
    let createdAt: Date
}

/// 2026-01-02T03:04:05Z
private let referenceTimestamp: TimeInterval = 1_767_323_045

@Suite struct JSONCodingTests {

    @Test(arguments: [
        ("2026-01-02T03:04:05Z", referenceTimestamp),
        ("2026-01-02T03:04:05.123Z", referenceTimestamp + 0.123),
        ("2026-01-02T03:04:05+05:30", referenceTimestamp - 19_800),
        ("2026-01-02T03:04:05.123+05:30", referenceTimestamp - 19_800 + 0.123),
        ("2026-01-02T03:04:05+0000", referenceTimestamp),
        ("2026-01-02 03:04:05 UTC", referenceTimestamp),
        ("2026-01-02", 1_767_312_000)
    ])
    func decodesSupportedDateFormats(input: String, expected: TimeInterval) throws {
        let json = Data(#"{"created_at": "\#(input)"}"#.utf8)

        let stamp = try JSONDecoder.rwlabs.decode(Stamp.self, from: json)

        #expect(abs(stamp.createdAt.timeIntervalSince1970 - expected) < 0.001)
    }

    @Test func unparseableDateThrowsWithInputInMessage() {
        let json = Data(#"{"created_at": "next tuesday"}"#.utf8)

        #expect {
            try JSONDecoder.rwlabs.decode(Stamp.self, from: json)
        } throws: { error in
            guard case let DecodingError.dataCorrupted(context) = error else { return false }
            return context.debugDescription.contains("next tuesday")
        }
    }

    @Test func encodesDatesAsISO8601WithSnakeCaseKeys() throws {
        let data = try JSONEncoder.rwlabs.encode(Stamp(createdAt: Date(timeIntervalSince1970: referenceTimestamp)))

        #expect(String(decoding: data, as: UTF8.self) == #"{"created_at":"2026-01-02T03:04:05Z"}"#)
    }

    @Test func datesRoundTripToTheSecond() throws {
        let original = Stamp(createdAt: Date(timeIntervalSince1970: referenceTimestamp))

        let decoded = try JSONDecoder.rwlabs.decode(Stamp.self, from: JSONEncoder.rwlabs.encode(original))

        #expect(decoded == original)
    }

    @Test func requestBodySendsISODates() async throws {
        let server = StubServer(StubResponse(status: 204))

        let _: EmptyResponse = try await server.client().send(
            .post("events", body: Stamp(createdAt: Date(timeIntervalSince1970: referenceTimestamp)))
        )

        let body = try #require(server.requests.first?.body)
        #expect(String(decoding: body, as: UTF8.self) == #"{"created_at":"2026-01-02T03:04:05Z"}"#)
    }

    @Test func badDateInResponseSurfacesAsDecodingError() async throws {
        let server = StubServer(.json(#"{"created_at": "not a date"}"#))

        do {
            let _: Stamp = try await server.client().send(.get("events/1"))
            Issue.record("Expected an error")
        } catch {
            guard case .decoding(.dataCorrupted, _) = error else {
                Issue.record("Expected .decoding(.dataCorrupted), got \(error)")
                return
            }
        }
    }
}
