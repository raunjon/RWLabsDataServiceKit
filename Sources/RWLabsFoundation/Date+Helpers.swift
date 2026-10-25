//
//  Date+Helpers.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public extension Date {
    /// Formats the date (the parameter name is historical: it is the output format)
    ///
    /// Defaults to `Region.current`'s time zone and locale, which suits display
    /// strings. Pass `locale: .posix` for machine-readable output.
    func toString(
        fromFormat dateFormat: String = DateFormats.standard,
        timeZone: TimeZone = Region.current.timeZone,
        locale: Locale = Region.current.locale
    ) -> String {
        DateFormatterCache.formatter(format: dateFormat, locale: locale, timeZone: timeZone).string(from: self)
    }

    func toPrettyString(fromFormat format: String = DateFormats.pretty, Today: Bool = false) -> String {
        if isToday() && Today {
            return "Today"
        }
        return toString(fromFormat: format)
    }

    func toPrettyStringWithTime(Today: Bool = false) -> String {
        if isToday() && Today {
            return "Today, " + toString(fromFormat: DateFormats.prettyTime)
        }
        return toString(fromFormat: DateFormats.prettyWithTime)
    }

    func isToday(calendar: Calendar = Region.current.calendar) -> Bool {
        calendar.isDateInToday(self)
    }

    func isCurrentHour(now: Date = Date(), calendar: Calendar = Region.current.calendar) -> Bool {
        calendar.isDate(self, equalTo: now, toGranularity: .hour)
    }

    func nextDate(calendar: Calendar = Region.current.calendar) -> Date {
        add(days: 1, calendar: calendar)
    }

    /// Adds calendar days (DST-safe: same wall-clock time) plus a fixed duration
    ///
    /// Whole days go through `calendar`; fractional days, hours, minutes and
    /// seconds are added as elapsed time.
    func add(days: Double = 0, hours: Double = 0, minutes: Double = 0, seconds: Double = 0, calendar: Calendar = Region.current.calendar) -> Date {
        let wholeDays = days.rounded(.towardZero)
        let start = calendar.date(byAdding: .day, value: Int(wholeDays), to: self) ?? self
        let duration = (days - wholeDays).daysToSeconds() + hours.hoursToSeconds() + minutes.minutesToSeconds() + seconds
        return start.addingTimeInterval(duration)
    }

    func getMonthName(shortName: Bool = true, locale: Locale = Region.current.locale) -> String {
        toString(fromFormat: shortName ? "MMM" : "MMMM", locale: locale)
    }

    func getDay() -> String {
        toString(fromFormat: "dd")
    }
}

public extension TimeInterval {
    func daysToSeconds() -> TimeInterval {
        (self * 24).hoursToSeconds()
    }

    func hoursToSeconds() -> TimeInterval {
        (self * 60).minutesToSeconds()
    }

    func minutesToSeconds() -> TimeInterval {
        self * 60
    }
}
