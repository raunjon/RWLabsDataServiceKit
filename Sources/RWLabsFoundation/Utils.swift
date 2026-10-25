//
//  Utils.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public struct Utils {
    /// Localized relative time for dates within the last week ("5 minutes ago",
    /// "2 days ago"), otherwise the date as `dd MMM, yyyy`. Returns "" if the
    /// string can't be parsed.
    public static func getLastPosted(
        dateString: String?,
        dateFormat: String = DateFormats.standard,
        now: Date = Date(),
        locale: Locale = Region.current.locale
    ) -> String {
        guard let date = dateString?.toDate(dateFormat: dateFormat) else { return "" }
        let elapsed = now.timeIntervalSince(date)
        guard elapsed < 7.0.daysToSeconds() else {
            return date.toString(fromFormat: DateFormats.dateMonthYear, locale: locale)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .full
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }

    /// Compact relative time: `5m` under an hour (minimum `1m`), `3h` under a
    /// day, otherwise `2d`. Returns "" if the string can't be parsed.
    public static func getTimestamp(dateString: String, dateFormat: String = DateFormats.standard, now: Date = Date()) -> String {
        guard let date = dateString.toDate(dateFormat: dateFormat) else { return "" }
        let elapsed = max(0, now.timeIntervalSince(date))
        switch elapsed {
        case ..<1.0.hoursToSeconds():
            return "\(max(1, Int(elapsed / 1.0.minutesToSeconds())))m"
        case ..<1.0.daysToSeconds():
            return "\(Int(elapsed / 1.0.hoursToSeconds()))h"
        default:
            return "\(Int(elapsed / 1.0.daysToSeconds()))d"
        }
    }
}
