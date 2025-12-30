//
//  Date+Extensions.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Date utilities and extensions for sensor data
//

import Foundation

// MARK: - Date Extensions

public extension Date {

    // MARK: - Formatting

    /// Format as time only (HH:mm:ss)
    var timeString: String {
        DateFormatters.time.string(from: self)
    }

    /// Format as time with milliseconds (HH:mm:ss.SSS)
    var preciseTimeString: String {
        DateFormatters.preciseTime.string(from: self)
    }

    /// Format as date only (yyyy-MM-dd)
    var dateString: String {
        DateFormatters.date.string(from: self)
    }

    /// Format as ISO8601 for data export
    var iso8601String: String {
        DateFormatters.iso8601.string(from: self)
    }

    /// Format as short date for display
    var shortDateString: String {
        DateFormatters.shortDate.string(from: self)
    }

    /// Format as medium date for display
    var mediumDateString: String {
        DateFormatters.mediumDate.string(from: self)
    }

    /// Format as full date and time
    var fullString: String {
        DateFormatters.full.string(from: self)
    }

    /// Format for CSV filename (yyyyMMdd_HHmmss)
    var filenameSafeString: String {
        DateFormatters.filename.string(from: self)
    }

    // MARK: - Relative Time

    /// Human-readable relative time (e.g., "5 minutes ago")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Short relative time (e.g., "5m ago")
    var shortRelativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    // MARK: - Date Components

    /// Start of the current day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the current day (23:59:59)
    var endOfDay: Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) ?? self
    }

    /// Start of the current hour
    var startOfHour: Date {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// Start of the current minute
    var startOfMinute: Date {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    // MARK: - Date Calculations

    /// Add seconds to date
    func adding(seconds: TimeInterval) -> Date {
        addingTimeInterval(seconds)
    }

    /// Add minutes to date
    func adding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    /// Add hours to date
    func adding(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    /// Add days to date
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is in the current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    // MARK: - Comparison

    /// Seconds between this date and another
    func seconds(from date: Date) -> TimeInterval {
        timeIntervalSince(date)
    }

    /// Minutes between this date and another
    func minutes(from date: Date) -> Double {
        seconds(from: date) / 60.0
    }

    /// Hours between this date and another
    func hours(from date: Date) -> Double {
        seconds(from: date) / 3600.0
    }

    /// Check if date is within a time interval of another date
    func isWithin(_ interval: TimeInterval, of date: Date) -> Bool {
        abs(timeIntervalSince(date)) <= interval
    }

    // MARK: - Sensor Data Helpers

    /// Round to nearest second
    var roundedToSecond: Date {
        Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate).rounded())
    }

    /// Round to nearest millisecond
    var roundedToMillisecond: Date {
        Date(timeIntervalSinceReferenceDate: (timeIntervalSinceReferenceDate * 1000).rounded() / 1000)
    }

    /// Unix timestamp in milliseconds (useful for sensor data)
    var unixMilliseconds: Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }

    /// Create date from Unix milliseconds
    static func fromUnixMilliseconds(_ ms: Int64) -> Date {
        Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }
}

// MARK: - Date Formatters

/// Cached date formatters for performance
public enum DateFormatters {

    /// Time only: HH:mm:ss
    public static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// Precise time: HH:mm:ss.SSS
    public static let preciseTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// Date only: yyyy-MM-dd
    public static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// ISO8601 format
    public static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Short date
    public static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    /// Medium date
    public static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    /// Full date and time
    public static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    /// Filename safe: yyyyMMdd_HHmmss
    public static let filename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

// MARK: - TimeInterval Extensions

public extension TimeInterval {

    /// Format as duration string (HH:mm:ss)
    var durationString: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Format as compact duration (1h 30m)
    var compactDurationString: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Common time intervals
    static let oneSecond: TimeInterval = 1
    static let oneMinute: TimeInterval = 60
    static let oneHour: TimeInterval = 3600
    static let oneDay: TimeInterval = 86400
    static let oneWeek: TimeInterval = 604800
}
