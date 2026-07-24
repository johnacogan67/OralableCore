//
//  NRFConnectBLELogger.swift
//  OralableCore
//
//  nRF Connect for Mobile compatible BLE session log (CSV: Timestamp,Source,Level,Line).
//  Use exported files alongside nRF Connect exports for side-by-side comparison.
//

import Foundation

/// Source column values matching nRF Connect exports.
public enum NRFConnectLogSource: String, Sendable {
    case scanner = "Scanner"
    case connectedDevice = "Connected Device"
}

/// Level column values matching nRF Connect exports.
public enum NRFConnectLogLevel: String, Sendable {
    case normal = "Normal"
    case application = "Application"
}

/// Records BLE events in nRF Connect CSV format.
public final class NRFConnectBLELogger: @unchecked Sendable {
    public static let shared = NRFConnectBLELogger()

    /// When false, recording is a no-op.
    public var isEnabled: Bool = true

    /// Log every notify for these UUID suffixes; throttle high-rate PPG/ACC/temp to ~1 Hz.
    public var throttleHighRateNotifications: Bool = true
    public var highRateNotifyMinInterval: TimeInterval = 1.0

    private let queue = DispatchQueue(label: "com.oralable.nrfconnect.ble.logger")
    private var rows: [String] = []
    private var lastHighRateNotifyAt: [String: Date] = [:]

    private static let highRateCharSuffixes: Set<String> = ["3A0FF001", "3A0FF002", "3A0FF003"]

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    // MARK: - Core

    public func clear() {
        queue.sync {
            rows.removeAll()
            lastHighRateNotifyAt.removeAll()
        }
    }

    public func lineCount() -> Int {
        queue.sync { rows.count }
    }

    public func csvContent() -> String {
        queue.sync {
            "Timestamp,Source,Level,Line\n" + rows.joined(separator: "\n") + (rows.isEmpty ? "" : "\n")
        }
    }

    public func exportToFile(filename: String? = nil) throws -> URL {
        let name = filename ?? "Oralable_nRFConnect_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try csvContent().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func log(
        source: NRFConnectLogSource,
        level: NRFConnectLogLevel,
        line: String,
        at date: Date = Date()
    ) {
        guard isEnabled else { return }
        let ts = timestampFormatter.string(from: date)
        let escaped = Self.escapeCSVField(line)
        let row = "\(ts),\(source.rawValue),\(level.rawValue),\"\(escaped)\""
        queue.sync {
            rows.append(row)
        }
    }

    // MARK: - Scanner events

    public func scannerOn() {
        log(source: .scanner, level: .normal, line: "Scanner On.")
    }

    public func scannerOff() {
        log(source: .scanner, level: .normal, line: "Scanner Off.")
    }

    public func deviceScanned() {
        log(source: .scanner, level: .normal, line: "Device Scanned.")
    }

    // MARK: - Connection events

    public func connected() {
        log(source: .connectedDevice, level: .normal, line: "Connected.")
    }

    public func disconnected() {
        log(source: .connectedDevice, level: .normal, line: "Disconnected.")
    }

    // MARK: - GATT discovery

    public func discoveredServices(_ serviceUUIDs: [String]) {
        for uuid in serviceUUIDs {
            log(source: .connectedDevice, level: .normal, line: "Discovered \(Self.normalizeUUID(uuid)) Services.")
        }
    }

    /// nRF Connect logs this between service and characteristic discovery.
    public func serviceDiscoveryReturnedNil() {
        log(source: .connectedDevice, level: .normal, line: "Service Discovery returned nil Services.")
    }

    public func discoveredCharacteristics(_ characteristicUUIDs: [String], forService serviceUUID: String) {
        guard !characteristicUUIDs.isEmpty else { return }
        let normalized = characteristicUUIDs.map { Self.normalizeUUID($0) }
        let body: String
        if normalized.count == 1 {
            body = normalized[0]
        } else {
            let head = normalized.dropLast().joined(separator: ", ")
            body = "\(head), and \(normalized.last!)"
        }
        log(
            source: .connectedDevice,
            level: .normal,
            line: "Discovered \(body) Characteristics for Service \(Self.normalizeUUID(serviceUUID))."
        )
    }

    public func characteristicHasNoDescriptors(_ characteristicUUID: String) {
        log(
            source: .connectedDevice,
            level: .normal,
            line: "\(Self.normalizeUUID(characteristicUUID)) has no Descriptors."
        )
    }

    public func discoveredCCC(for characteristicUUID: String) {
        log(
            source: .connectedDevice,
            level: .normal,
            line: "Discovered Client Characteristic Configuration Descriptors for Characteristic \(Self.normalizeUUID(characteristicUUID))"
        )
    }

    // MARK: - Notify / read / write

    public func settingNotify(_ enabled: Bool, for characteristicUUID: String) {
        log(
            source: .connectedDevice,
            level: .application,
            line: "Setting Boolean \(enabled ? "true" : "false") for Notifying Characteristic \(Self.normalizeUUID(characteristicUUID))"
        )
    }

    public func updatedValue(of characteristicUUID: String, data: Data) {
        let uuid = Self.normalizeUUID(characteristicUUID)
        let suffix = Self.uuidSuffix(uuid)

        if throttleHighRateNotifications,
           Self.highRateCharSuffixes.contains(suffix) {
            let now = Date()
            var shouldLog = false
            queue.sync {
                if let last = lastHighRateNotifyAt[suffix], now.timeIntervalSince(last) < highRateNotifyMinInterval {
                    shouldLog = false
                } else {
                    lastHighRateNotifyAt[suffix] = now
                    shouldLog = true
                }
            }
            guard shouldLog else { return }
        }

        let hex = Self.hexSpaced(data)
        log(source: .connectedDevice, level: .normal, line: "Updated Value of Characteristic \(uuid) to \(hex).")
        log(source: .connectedDevice, level: .application, line: "\"\(hex)\" value received.")
    }

    // MARK: - Formatting helpers

    public static func normalizeUUID(_ uuid: String) -> String {
        let trimmed = uuid.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.count == 36 {
            return trimmed
        }
        if trimmed.count == 4 {
            return "0000\(trimmed)-0000-1000-8000-00805F9B34FB"
        }
        return trimmed
    }

    public static func uuidSuffix(_ uuid: String) -> String {
        let n = normalizeUUID(uuid)
        if let first = n.split(separator: "-").first, first.count == 8 {
            return String(first)
        }
        return n
    }

    /// nRF style: uppercase hex in groups of 4 nibbles, space-separated.
    public static func hexSpaced(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        var parts: [String] = []
        parts.reserveCapacity((data.count + 1) / 2)
        var i = data.startIndex
        while i < data.endIndex {
            let end = data.index(i, offsetBy: 2, limitedBy: data.endIndex) ?? data.endIndex
            parts.append(data[i..<end].map { String(format: "%02X", $0) }.joined())
            i = end
        }
        return parts.joined(separator: " ")
    }

    private static func escapeCSVField(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
