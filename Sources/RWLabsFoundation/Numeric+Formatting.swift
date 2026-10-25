//
//  Numeric+Formatting.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public extension Int {
    /// Locale-aware currency in `Region.current` by default, e.g. `₹1,234.00` for INR in `en_IN`
    func toCurrency(code: String = Region.current.currencyCode, locale: Locale = Region.current.locale) -> String {
        formatted(.currency(code: code).locale(locale))
    }

    func toString() -> String {
        "\(self)"
    }

    /// Two decimal places with locale grouping, e.g. `1,234.00`
    func toCurrencyValue(locale: Locale = Region.current.locale) -> String {
        Double(self).formatted(.number.precision(.fractionLength(2)).locale(locale))
    }

    func toPercentage() -> String {
        "\(self)%"
    }
}

public extension Double {
    /// Locale-aware currency in `Region.current` by default, e.g. `₹1,234.50` for INR in `en_IN`
    func toCurrency(code: String = Region.current.currencyCode, locale: Locale = Region.current.locale) -> String {
        formatted(.currency(code: code).locale(locale))
    }

    func toString() -> String {
        "\(self)"
    }

    func toPercentage() -> String {
        "\(self)%"
    }

    func toString(decimalPoints: Int, replaceZero: Bool = false) -> String {
        if self == 0 && replaceZero {
            return "-"
        }
        return String(format: "%.\(decimalPoints)f", self)
    }

    /// Interprets the value as seconds since 1970
    func toDate() -> Date {
        Date(timeIntervalSince1970: self)
    }
}

public extension Decimal {
    /// Locale-aware currency without floating-point rounding; prefer `Decimal` for money
    func toCurrency(code: String = Region.current.currencyCode, locale: Locale = Region.current.locale) -> String {
        formatted(.currency(code: code).locale(locale))
    }
}

public extension Float {
    func toCurrency(code: String = Region.current.currencyCode, locale: Locale = Region.current.locale) -> String {
        Double(self).toCurrency(code: code, locale: locale)
    }

    func toString() -> String {
        "\(self)"
    }
}

public extension CGFloat {
    func toCurrency(code: String = Region.current.currencyCode, locale: Locale = Region.current.locale) -> String {
        Double(self).toCurrency(code: code, locale: locale)
    }

    func toString() -> String {
        "\(self)"
    }

    func getValueByRemovingMargin(_ margin: CGFloat) -> CGFloat {
        self - margin * 2
    }
}
