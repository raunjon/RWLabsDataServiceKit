//
//  JSONCoding+RWLabs.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

public extension JSONDecoder {
    /// A new decoder configured for RWLabs APIs
    ///
    /// - Keys: snake_case → camelCase (`user_id` → `userId`; a property named
    ///   `userID` will not match).
    /// - Dates: see `RWLabsDateCoding.date(from:)`.
    static var rwlabs: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = RWLabsDateCoding.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date: \"\(value)\". Expected \(RWLabsDateCoding.supportedFormats)"
                )
            }
            return date
        }
        return decoder
    }
}

public extension JSONEncoder {
    /// A new encoder configured for RWLabs APIs
    ///
    /// - Keys: camelCase → snake_case.
    /// - Dates: ISO 8601 in UTC, e.g. `2026-01-02T03:04:05Z`.
    static var rwlabs: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(RWLabsDateCoding.string(from: date))
        }
        return encoder
    }
}

// MARK: - Date Coding

/// Date parsing and formatting shared by `JSONDecoder.rwlabs` and `JSONEncoder.rwlabs`
public enum RWLabsDateCoding {
    /// Human-readable list of accepted formats, used in decoding errors
    public static let supportedFormats = "ISO 8601 (optional fractional seconds), \"yyyy-MM-dd HH:mm:ss zzz\" or \"yyyy-MM-dd\""

    private static let iso8601 = Date.ISO8601FormatStyle()
    private static let iso8601WithFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    // DateFormatter is thread-safe; it is not marked Sendable, hence nonisolated(unsafe).
    nonisolated(unsafe) private static let fallbackFormatters: [DateFormatter] = [
        makeFormatter("yyyy-MM-dd HH:mm:ss zzz"),
        // Calendar dates (e.g. birthdays) decode as midnight UTC
        makeFormatter("yyyy-MM-dd")
    ]

    /// Parses ISO 8601 first (fast path), then the fallback formats
    public static func date(from string: String) -> Date? {
        if let date = try? iso8601WithFractionalSeconds.parse(string) {
            return date
        }
        if let date = try? iso8601.parse(string) {
            return date
        }
        for formatter in fallbackFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    /// Formats a date as ISO 8601 in UTC without fractional seconds
    public static func string(from date: Date) -> String {
        iso8601.format(date)
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter
    }
}
