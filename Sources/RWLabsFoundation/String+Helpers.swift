//
//  String+Helpers.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public extension String {
    func toURL() -> URL? {
        URL(string: self)
    }

    func toDouble() -> Double? {
        Double(self)
    }

    /// Compact relative time since this date string, e.g. `5m`, `3h`, `2d`
    func timestamp(dateFormat: String = DateFormats.standard, now: Date = Date()) -> String {
        Utils.getTimestamp(dateString: self, dateFormat: dateFormat, now: now)
    }

    /// Whether this is the replacement string UIKit passes for a backspace
    /// (`textField(_:shouldChangeCharactersIn:replacementString:)` sends `""`)
    func isBackspace() -> Bool {
        isEmpty
    }

    /// Pads with trailing spaces up to `limit` characters; longer strings are unchanged
    func appendEmptyData(toLimit limit: Int) -> String {
        count >= limit ? self : padding(toLength: limit, withPad: " ", startingAt: 0)
    }

    func appendPercentage() -> String {
        self + "%"
    }

    func appendDot() -> String {
        self + "."
    }

    /// Parses a fixed-format date string
    ///
    /// Uses `en_US_POSIX`, so parsing works regardless of the device's
    /// language or 12/24-hour setting. Formats without a zone are read in `timeZone`.
    func toDate(dateFormat: String = DateFormats.standard, timeZone: TimeZone = .current) -> Date? {
        DateFormatterCache.formatter(format: dateFormat, locale: .posix, timeZone: timeZone).date(from: self)
    }

    /// Parses ISO 8601 with or without fractional seconds (`2026-01-02T03:04:05Z`, `…05.123+05:30`)
    ///
    /// Replaces `parseUTCToIST()`. A `Date` has no time zone; to show it in
    /// IST, format it with `toString(fromFormat:timeZone: .ist)`.
    func toISO8601Date() -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(self) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(self)
    }

    /// Reformats a date string for display as `dd MMM, yyyy`; returns `self` if it can't be parsed
    func toPrettyDateString(fromFormat dateFormat: String = DateFormats.standard, locale: Locale = Region.current.locale) -> String {
        guard let date = toDate(dateFormat: dateFormat) else { return self }
        return date.toString(fromFormat: DateFormats.dateMonthYear, locale: locale)
    }

    static func randomString(length: Int = 50) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
