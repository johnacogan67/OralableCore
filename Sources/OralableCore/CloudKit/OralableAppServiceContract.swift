//
//  OralableAppServiceContract.swift
//  OralableCore
//
//  Canonical identifiers for the two iOS apps and their shared Apple-service
//  integration. The versioned workspace contract is
//  cursor_oralable/contracts/oralable_app_services_v1.json.
//

/// Stable service identifiers shared by the consumer and professional apps.
///
/// These strings do not provision an Apple capability. Before activation, the
/// matching configuration must be reviewed in Apple Developer, App Store
/// Connect, and CloudKit Console.
public enum OralableAppServiceContract {
    public enum BundleIdentifier {
        public static let consumer = "com.jacdental.oralable"
        public static let professional = "com.jacdental.oralable.professionals"
        public static let consumerTests = "com.jacdental.oralable.tests"
        public static let consumerUITests = "com.jacdental.oralable.uitests"
        public static let professionalTests = "com.jacdental.oralable.professionals.tests"
        public static let professionalUITests = "com.jacdental.oralable.professionals.uitests"
    }

    public enum StoreKit {
        public static let consumerPremiumMonthly = "com.jacdental.oralable.premium.monthly"
        public static let consumerPremiumYearly = "com.jacdental.oralable.premium.yearly"
        public static let professionalMonthly = "com.jacdental.oralable.professional.monthly"
        public static let professionalYearly = "com.jacdental.oralable.professional.yearly"
        public static let practiceMonthly = "com.jacdental.oralable.practice.monthly"
        public static let practiceYearly = "com.jacdental.oralable.practice.yearly"

        public static let consumerProductIdentifiers: Set<String> = [
            consumerPremiumMonthly,
            consumerPremiumYearly
        ]

        public static let professionalProductIdentifiers: Set<String> = [
            professionalMonthly,
            professionalYearly,
            practiceMonthly,
            practiceYearly
        ]
    }

    public enum CloudKit {
        public static let containerIdentifier = "iCloud.com.jacdental.oralable.shared"

        public enum RecordType {
            public static let shareInvitation = "ShareInvitation"
            public static let sharedPatientData = "SharedPatientData"
            public static let healthDataRecord = "HealthDataRecord"
        }

        public enum Field {
            public static let patientID = "patientID"
            public static let professionalID = "professionalID"
            public static let shareCode = "shareCode"
            public static let createdDate = "createdDate"
            public static let expiryDate = "expiryDate"
            public static let accessGrantedDate = "accessGrantedDate"
            public static let lastDataUpdate = "lastDataUpdate"
            public static let isActive = "isActive"
            public static let professionalName = "professionalName"
            public static let patientName = "patientName"
            public static let recordingDate = "recordingDate"
            public static let sessionDuration = "sessionDuration"
            public static let bruxismEvents = "bruxismEvents"
            public static let averageIntensity = "averageIntensity"
            public static let peakIntensity = "peakIntensity"
            public static let heartRateData = "heartRateData"
            public static let oxygenSaturation = "oxygenSaturation"
            public static let sensorDataCompressed = "sensorDataCompressed"
            public static let sensorDataUncompressedSize = "sensorDataUncompressedSize"

            // Migration aliases. Read after the canonical field, and write only
            // until existing records have been migrated and the removal gate in
            // the workspace contract has been satisfied.
            public static let legacyDentistID = "dentistID"
            public static let legacyDentistName = "dentistName"
        }
    }

    public enum HealthKit {
        public static let writableQuantityTypes = ["heartRate", "oxygenSaturation"]
        public static let nonWritableData = ["sleep stages", "HRV", "diagnosis", "treatment recommendation"]
        public static let minimumSampleIntervalSeconds: Double = 5
    }
}
