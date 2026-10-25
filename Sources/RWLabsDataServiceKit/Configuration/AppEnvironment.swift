//
//  AppEnvironment.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

/// The backend environment an app build talks to
public enum AppEnvironment: String, CaseIterable, Codable, Sendable {
    case local
    case staging
    case production

    /// Resolves the environment from the app's Info.plist
    ///
    /// Set the key per build configuration, e.g. `APP_ENVIRONMENT = staging`
    /// in an xcconfig and `APP_ENVIRONMENT: $(APP_ENVIRONMENT)` in Info.plist.
    /// Matching is case-insensitive; a missing or unknown value returns `fallback`.
    public static func current(
        infoPlistKey: String = "APP_ENVIRONMENT",
        bundle: Bundle = .main,
        fallback: AppEnvironment = .production
    ) -> AppEnvironment {
        guard let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
              let environment = AppEnvironment(rawValue: value.lowercased()) else {
            return fallback
        }
        return environment
    }
}
