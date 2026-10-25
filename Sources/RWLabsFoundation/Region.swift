//
//  Region.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

/// Country, currency, locale and time zone used as display defaults by the
/// formatting helpers (`toCurrency`, `Date.toString`, `Utils.getLastPosted`, ...)
///
/// Set `Region.current` once at launch, e.g. from the user's profile:
/// ```swift
/// Region.current = .india
/// 1234.5.toCurrency()          // "₹1,234.50"
/// Region.current.countryName() // "India"
/// ```
/// Parsing fixed-format strings (`String.toDate`) is not affected; it always
/// uses `Locale.posix`.
public struct Region: Sendable, Hashable, Identifiable {
    /// ISO 3166-1 alpha-2 country code, e.g. `IN`
    public var countryCode: String

    /// ISO 4217 currency code, e.g. `INR`
    public var currencyCode: String

    /// Locale for numbers, month names and relative times
    public var locale: Locale

    /// Time zone dates are displayed in
    public var timeZone: TimeZone

    public var id: String { countryCode }

    public init(countryCode: String, currencyCode: String, locale: Locale, timeZone: TimeZone) {
        self.countryCode = countryCode
        self.currencyCode = currencyCode
        self.locale = locale
        self.timeZone = timeZone
    }

    /// Gregorian calendar in this region's time zone and locale
    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        return calendar
    }

    /// Country name, e.g. "India" (in `displayLocale`, defaulting to this region's locale)
    public func countryName(in displayLocale: Locale? = nil) -> String? {
        (displayLocale ?? locale).localizedString(forRegionCode: countryCode)
    }

    /// Currency name, e.g. "Indian Rupee"
    public func currencyName(in displayLocale: Locale? = nil) -> String? {
        (displayLocale ?? locale).localizedString(forCurrencyCode: currencyCode)
    }

    /// Currency symbol as written in this region's locale, e.g. "₹"
    public var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol
    }
}

// MARK: - Presets
//
// One preset per country (`Region.india`, `Region.unitedStates`, ...) and
// `Region.all` are generated in Region+Countries.swift.

public extension Region {
    /// The preset for an ISO 3166-1 alpha-2 code (case-insensitive), e.g. `Region(countryCode: "in")`
    init?(countryCode: String) {
        guard let region = Self.byCountryCode[countryCode.uppercased()] else { return nil }
        self = region
    }

    private static let byCountryCode = Dictionary(uniqueKeysWithValues: all.map { ($0.countryCode, $0) })

    /// The device's own settings; falls back to India's codes when the device reports none
    static var device: Region {
        let locale = Locale.autoupdatingCurrent
        let countryCode: String?
        let currencyCode: String?
        if #available(iOS 16, macOS 13, *) {
            countryCode = locale.region?.identifier
            currencyCode = locale.currency?.identifier
        } else {
            countryCode = locale.regionCode
            currencyCode = locale.currencyCode
        }
        return Region(
            countryCode: countryCode ?? india.countryCode,
            currencyCode: currencyCode ?? india.currencyCode,
            locale: locale,
            timeZone: .autoupdatingCurrent
        )
    }

    /// INR with the device's locale and time zone (the helpers' behaviour before `Region` existed)
    static let `default` = Region(
        countryCode: "IN",
        currencyCode: "INR",
        locale: .autoupdatingCurrent,
        timeZone: .autoupdatingCurrent
    )
}

// MARK: - Current

public extension Region {
    /// Region the formatting helpers default to. Starts as `Region.default`.
    static var current: Region {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }

    private static let storage = LockedValue(Region.default)
}

/// Minimal lock-protected box for global mutable state
final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

extension TimeZone {
    /// Time zone for a generated preset; falls back to GMT if this OS release lacks the identifier
    static func zone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0)!
    }
}
