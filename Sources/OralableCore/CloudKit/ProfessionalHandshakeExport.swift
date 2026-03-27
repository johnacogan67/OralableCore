//
//  ProfessionalHandshakeExport.swift
//  OralableCore
//
//  JSON payload for Oralable → OralableForProfessionals clinical sharing.
//

import Foundation

// MARK: - Hourly rollup (TFI + SASHB + Temporalis averages)

/// One hour of clinical rollup for professional review.
public struct ProfessionalHourlyRollupExport: Codable, Sendable, Equatable {
    public let hourIndex: Int
    public let segmentStart: Date
    public let segmentEnd: Date
    /// Temporalis fatigue index (0–100 %) averaged over the hour when available.
    public let tfiPercent: Double
    public let sashbHypoxicBurden: Double
    public let quiet: Double
    public let phasic: Double
    public let tonic: Double
    public let rescue: Double
    public let rescueEventCount: Int

    public init(
        hourIndex: Int,
        segmentStart: Date,
        segmentEnd: Date,
        tfiPercent: Double,
        sashbHypoxicBurden: Double,
        quiet: Double,
        phasic: Double,
        tonic: Double,
        rescue: Double,
        rescueEventCount: Int
    ) {
        self.hourIndex = hourIndex
        self.segmentStart = segmentStart
        self.segmentEnd = segmentEnd
        self.tfiPercent = tfiPercent
        self.sashbHypoxicBurden = sashbHypoxicBurden
        self.quiet = quiet
        self.phasic = phasic
        self.tonic = tonic
        self.rescue = rescue
        self.rescueEventCount = rescueEventCount
    }
}

// MARK: - Full handshake payload

/// Container shared with the professional app (CloudKit, AirDrop, or secure copy).
public struct ProfessionalHandshakeExport: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    /// Stable link id; use with `displayCode` for clinician lookup.
    public let linkUUID: UUID
    /// Six-character uppercase code derived from `linkUUID` for manual entry.
    public let displayCode: String
    public let exportedAt: Date
    public let sharedSession: SharedSessionData
    public let hourlyRollups: [ProfessionalHourlyRollupExport]

    public init(
        schemaVersion: Int = 1,
        linkUUID: UUID,
        displayCode: String,
        exportedAt: Date = Date(),
        sharedSession: SharedSessionData,
        hourlyRollups: [ProfessionalHourlyRollupExport]
    ) {
        self.schemaVersion = schemaVersion
        self.linkUUID = linkUUID
        self.displayCode = displayCode
        self.exportedAt = exportedAt
        self.sharedSession = sharedSession
        self.hourlyRollups = hourlyRollups
    }
}

// MARK: - Link code

public enum ClinicianLinkCodeFormatter {
    /// Uppercase hex from the first three bytes of the UUID (six characters).
    public static func sixCharacterCode(linkUUID: UUID) -> String {
        let u = linkUUID.uuid
        return String(format: "%02X%02X%02X", u.0, u.1, u.2)
    }
}
