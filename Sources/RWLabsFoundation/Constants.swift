//
//  Constants.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public struct Unicodes {
    public static let downArrow = "\u{2335}"
    public static let rupee = "₹"
    public static let rightArrow = "->"
    public static let eye = "\u{1F441}"
    public static let bullet = "\u{2022}"
    // There is no closed-eye character in Unicode; use the SF Symbol "eye.slash".
}

public struct DateFormats {
    public static let standard = "yyyy-MM-dd'T'HH:mm:ss"
    public static let calendar = "dd-MM-yyyy"
    public static let pretty = "dd MMM, yyyy"
    public static let prettyWithTime = "EEE, dd MMM, hh:mm a"
    public static let prettyTime = "hh:mm a"
    public static let prettyMonth = "EEE, dd MMM"
    public static let dateMonthYear = "dd MMM, yyyy"
    public static let birthdayDateFormat = "yyyy-MM-dd"
    public static let submittedAt = "yyyy-MM-dd'T'HH:mm:ssZ"
}
