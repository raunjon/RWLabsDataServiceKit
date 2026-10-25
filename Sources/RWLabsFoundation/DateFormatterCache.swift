//
//  DateFormatterCache.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public extension Locale {
    /// Fixed locale for machine-readable dates (API strings, storage keys)
    static let posix = Locale(identifier: "en_US_POSIX")
}

public extension TimeZone {
    /// India Standard Time, for display
    static let ist = TimeZone(identifier: "Asia/Kolkata")!
}

/// Reuses `DateFormatter`s, which are expensive to create, per format/locale/time zone
enum DateFormatterCache {
    private static let lock = NSLock()
    // DateFormatter is thread-safe; it is not marked Sendable, hence nonisolated(unsafe).
    nonisolated(unsafe) private static var formatters: [String: DateFormatter] = [:]

    static func formatter(format: String, locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let key = "\(format)|\(locale.identifier)|\(timeZone.identifier)"
        return lock.withLock {
            if let formatter = formatters[key] {
                return formatter
            }
            let formatter = DateFormatter()
            if locale == .posix {
                formatter.calendar = Calendar(identifier: .gregorian)
            }
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = format
            formatters[key] = formatter
            return formatter
        }
    }
}
