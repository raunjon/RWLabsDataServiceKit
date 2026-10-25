//
//  Log.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

/// Centralized logging utility that only logs in debug builds
///
/// This enum provides convenient logging methods for different log levels
/// and categories. Logs are only printed in DEBUG builds.
///
/// Example:
/// ```swift
/// Log.debug("Initializing service")
/// Log.error("Failed to fetch data: \(error)")
/// Log.network("GET /api/users - 200 OK")
/// ```
public enum Log {
    // MARK: - Log Levels
    /// Debug level - general debugging information
    public static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "🔵 DEBUG", file: file, function: function, line: line)
    }

    /// Info level - informational messages
    public static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "ℹ️ INFO", file: file, function: function, line: line)
    }

    /// Warning level - warning messages
    public static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "⚠️ WARNING", file: file, function: function, line: line)
    }

    /// Error level - error messages
    public static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "❌ ERROR", file: file, function: function, line: line)
    }

    /// Success level - success messages
    public static func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "✅ SUCCESS", file: file, function: function, line: line)
    }

    // MARK: - Private Methods

    private static func log(_ message: String, level: String, file: String, function: String, line: Int) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(level) [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }

    // MARK: - Date Formatter

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Convenience Extensions

extension Log {
    /// Network logging for HTTP requests and responses
    public static func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "🌐 NETWORK", file: file, function: function, line: line)
    }

    /// Data/Database operations logging
    public static func data(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "💾 DATA", file: file, function: function, line: line)
    }

    /// UI-related logging
    public static func ui(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: "🎨 UI", file: file, function: function, line: line)
    }
    
    ///Helper Methods
    public static func d(_ message: String, file: String = #file, function: String = #function, line: Int = #line) { Log.debug(message, file: file, function: function, line: line) }
    public static func i(_ message: String, file: String = #file, function: String = #function, line: Int = #line) { Log.info(message, file: file, function: function, line: line) }
    public static func w(_ message: String, file: String = #file, function: String = #function, line: Int = #line) { Log.warning(message, file: file, function: function, line: line) }
    public static func e(_ message: String, file: String = #file, function: String = #function, line: Int = #line) { Log.error(message, file: file, function: function, line: line) }
    public static func s(_ message: String, file: String = #file, function: String = #function, line: Int = #line) { Log.success(message, file: file, function: function, line: line) }
}
