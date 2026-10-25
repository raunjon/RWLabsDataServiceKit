//
//  RWLabsFoundationTests.swift
//  RWLabsFoundationTests
//

import Foundation
import Testing
@testable import RWLabsFoundation

/// 2026-01-02T03:04:05Z
private let reference = Date(timeIntervalSince1970: 1_767_323_045)

private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

@Suite struct ArrayHelperTests {
    @Test func chunkedSplitsWithShorterTail() {
        #expect([1, 2, 3, 4, 5].chunked(into: 2) == [[1, 2], [3, 4], [5]])
        #expect([Int]().chunked(into: 3).isEmpty)
    }

    @Test func moveRepositionsElements() {
        var values = ["a", "b", "c", "d"]
        values.move(from: 0, to: 2)
        #expect(values == ["b", "c", "a", "d"])
        values.move("d", to: 0)
        #expect(values == ["d", "b", "c", "a"])
    }
}

@Suite struct StringHelperTests {
    @Test func isBackspaceMatchesUIKitsEmptyReplacement() {
        #expect("".isBackspace())
        #expect(!"a".isBackspace())
    }

    @Test func appendEmptyDataPadsToLimit() {
        #expect("ab".appendEmptyData(toLimit: 5) == "ab   ")
        #expect("abcdef".appendEmptyData(toLimit: 3) == "abcdef")
    }

    @Test func toDateParsesFixedFormatInGivenZone() {
        let date = "2026-01-02T15:04:05".toDate(timeZone: TimeZone(identifier: "UTC")!)
        #expect(date == reference.addingTimeInterval(12 * 3600))
        #expect("not a date".toDate() == nil)
    }

    @Test func toISO8601DateHandlesOffsetsAndFractions() throws {
        let date = try #require("2026-01-02T03:04:05.123+05:30".toISO8601Date())
        #expect(abs(date.timeIntervalSince(reference) - (0.123 - 19_800)) < 0.001)
        #expect("2026-01-02T03:04:05Z".toISO8601Date() == reference)
    }

    @Test func randomStringHasRequestedLengthAndAlphabet() {
        let value = String.randomString(length: 32)
        #expect(value.count == 32)
        #expect(value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }
}

@Suite struct DateHelperTests {
    @Test func isCurrentHourComparesTheHourNotTheDay() {
        let utc = calendar("UTC")
        let now = reference.addingTimeInterval(26 * 60)   // 03:30Z
        #expect(reference.isCurrentHour(now: now, calendar: utc))
        #expect(!reference.addingTimeInterval(-2 * 3600).isCurrentHour(now: now, calendar: utc))
    }

    @Test func addDaysKeepsWallClockTimeAcrossDST() throws {
        let newYork = calendar("America/New_York")
        // 2026-03-07 12:00 EST; clocks spring forward on 2026-03-08
        let start = try #require(newYork.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12)))

        let next = start.add(days: 1, calendar: newYork)

        #expect(newYork.component(.hour, from: next) == 12)
        #expect(next.timeIntervalSince(start) == 23 * 3600)
    }

    @Test func addCombinesFixedDurations() {
        let utc = calendar("UTC")
        #expect(reference.add(hours: 1, minutes: 30, seconds: 5, calendar: utc) == reference.addingTimeInterval(5_405))
        #expect(reference.add(days: 1.5, calendar: utc) == reference.addingTimeInterval(36 * 3600))
    }

    @Test func toStringUsesGivenZoneAndLocale() {
        #expect(reference.toString(fromFormat: "yyyy-MM-dd HH:mm", timeZone: .ist, locale: .posix) == "2026-01-02 08:34")
    }
}

@Suite struct NumericFormattingTests {
    private let india = Locale(identifier: "en_IN")

    /// ICU versions differ on spacing after the symbol (iOS 18: "₹ 1,234.50", macOS 26: "₹1,234.50")
    private func compact(_ value: String) -> String {
        value.filter { !$0.isWhitespace }
    }

    @Test func currencyIsLocaleAware() {
        #expect(compact(1234.5.toCurrency(code: "INR", locale: india)) == "₹1,234.50")
        #expect(compact(1234.toCurrency(code: "INR", locale: india)) == "₹1,234.00")
        #expect(compact(Float(12).toCurrency(code: "USD", locale: Locale(identifier: "en_US"))) == "$12.00")
        #expect(compact(Decimal(string: "0.1")!.toCurrency(code: "INR", locale: india)) == "₹0.10")
    }

    @Test func currencyValueHasTwoDecimals() {
        #expect(1234.toCurrencyValue(locale: Locale(identifier: "en_US")) == "1,234.00")
    }

    @Test func decimalPoints() {
        #expect(3.14159.toString(decimalPoints: 2) == "3.14")
        #expect(0.0.toString(decimalPoints: 2, replaceZero: true) == "-")
    }
}

@Suite struct JSONHelperTests {
    private struct Payload: Codable {
        let fullName: String
    }

    @Test func dictionaryToDataReturnsNilForInvalidJSON() {
        #expect(["when": Date()].toData() == nil)
        #expect(["name": "Ada"].toData() == Data(#"{"name":"Ada"}"#.utf8))
    }

    @Test func encodableUsesTheGivenEncoder() throws {
        let snakeCase = JSONEncoder()
        snakeCase.keyEncodingStrategy = .convertToSnakeCase

        #expect(Payload(fullName: "Ada").toDict()?["fullName"] as? String == "Ada")
        #expect(Payload(fullName: "Ada").toDict(encoder: snakeCase)?["full_name"] as? String == "Ada")
    }
}

@Suite struct RelativeTimeTests {
    private let dateString = "2026-01-02T03:04:05"
    private var date: Date { dateString.toDate()! }

    @Test(arguments: [
        (30.0, "1m"),
        (59 * 60.0, "59m"),
        (3600.0, "1h"),
        (90 * 60.0, "1h"),
        (2 * 86_400.0, "2d")
    ])
    func compactTimestamp(elapsed: TimeInterval, expected: String) {
        #expect(Utils.getTimestamp(dateString: dateString, now: date.addingTimeInterval(elapsed)) == expected)
    }

    @Test func lastPostedIsRelativeWithinAWeek() {
        let english = Locale(identifier: "en_US")
        #expect(Utils.getLastPosted(dateString: dateString, now: date.addingTimeInterval(2 * 3600), locale: english) == "2 hours ago")
        #expect(Utils.getLastPosted(dateString: dateString, now: date.addingTimeInterval(10 * 86_400), locale: english) == "02 Jan, 2026")
        #expect(Utils.getLastPosted(dateString: nil) == "")
    }
}

@Suite struct RegionTests {
    @Test func indiaPresetDescribesCountryAndCurrency() {
        let india = Region.india
        #expect(india.countryCode == "IN")
        #expect(india.currencyCode == "INR")
        #expect(india.countryName() == "India")
        #expect(india.currencyName() == "Indian Rupee")
        #expect(india.currencySymbol == "₹")
        #expect(india.calendar.timeZone == .ist)
    }

    @Test func namesCanBeLocalizedForAnotherDisplayLocale() {
        let germany = Region(countryCode: "DE", currencyCode: "EUR", locale: Locale(identifier: "de_DE"), timeZone: TimeZone(identifier: "Europe/Berlin")!)
        #expect(germany.countryName() == "Deutschland")
        #expect(germany.countryName(in: Locale(identifier: "en_US")) == "Germany")
        #expect(germany.currencySymbol == "€")
    }

    @Test func calendarUsesTheRegionsTimeZone() {
        // 2026-01-02T20:00Z is already the 3rd in IST (01:30)
        let lateUTC = reference.addingTimeInterval(16 * 3600 + 55 * 60 + 55)
        #expect(Region.india.calendar.component(.day, from: lateUTC) == 3)
        #expect(lateUTC.toString(fromFormat: "dd", timeZone: Region.india.timeZone, locale: .posix) == "03")
    }

    @Test func helpersDefaultToCurrentRegion() {
        let original = Region.current
        defer { Region.current = original }
        #expect(original == .default)

        // Keep the time zone so date tests running in parallel are unaffected
        Region.current = Region(countryCode: "US", currencyCode: "USD", locale: Locale(identifier: "en_US"), timeZone: original.timeZone)

        #expect(Region.current.currencyCode == "USD")
        #expect(1234.5.toCurrency().filter { !$0.isWhitespace } == "$1,234.50")
        #expect(reference.getMonthName(shortName: false, locale: Region.current.locale).count > 0)
    }

    @Test func devicePresetAlwaysHasCodes() {
        let device = Region.device
        #expect(device.countryCode.count == 2)
        #expect(device.currencyCode.count == 3)
    }
}

@Suite struct CountryPresetTests {
    @Test func everyCountryHasAUniquePreset() {
        #expect(Region.all.count >= 245)
        #expect(Set(Region.all.map(\.countryCode)).count == Region.all.count)
        #expect(Region.all.map(\.countryCode) == Region.all.map(\.countryCode).sorted())
    }

    @Test func everyPresetIsComplete() {
        for region in Region.all {
            #expect(region.countryCode.count == 2, "\(region.countryCode)")
            #expect(region.currencyCode.count == 3, "\(region.countryCode)")
            #expect(region.locale.identifier == "en_\(region.countryCode)")
            // GMT means the zone identifier was missing on this OS and the fallback kicked in
            #expect(region.timeZone.identifier != "GMT", "\(region.countryCode) fell back to GMT")
            #expect(region.countryName(in: Locale(identifier: "en_US")) != nil, "\(region.countryCode)")
        }
    }

    @Test(arguments: [
        ("in", "INR", "Asia/Kolkata"),
        ("US", "USD", "America/New_York"),
        ("gb", "GBP", "Europe/London"),
        ("JP", "JPY", "Asia/Tokyo"),
        ("AU", "AUD", "Australia/Sydney"),
        ("ae", "AED", "Asia/Dubai"),
        ("XK", "EUR", "Europe/Belgrade")
    ])
    func lookupByCountryCode(code: String, currency: String, zone: String) throws {
        let region = try #require(Region(countryCode: code))
        #expect(region.currencyCode == currency)
        #expect(region.timeZone.identifier == zone)
    }

    @Test func namedPresetsMatchLookup() {
        #expect(Region(countryCode: "IN") == .india)
        #expect(Region(countryCode: "US") == .unitedStates)
        #expect(Region(countryCode: "GB") == .unitedKingdom)
        #expect(Region(countryCode: "ZZ") == nil)
    }

    @Test func presetsFormatInTheirCurrency() {
        #expect(1234.5.toCurrency(code: Region.unitedKingdom.currencyCode, locale: Region.unitedKingdom.locale).filter { !$0.isWhitespace } == "£1,234.50")
        #expect(1234.toCurrency(code: Region.japan.currencyCode, locale: Region.japan.locale).filter { !$0.isWhitespace } == "¥1,234")
    }
}
