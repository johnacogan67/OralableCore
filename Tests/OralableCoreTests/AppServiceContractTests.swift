import XCTest
@testable import OralableCore

final class AppServiceContractTests: XCTestCase {
    func testCanonicalBundleIdentifiers() {
        XCTAssertEqual(OralableAppServiceContract.BundleIdentifier.consumer, "com.jacdental.oralable")
        XCTAssertEqual(OralableAppServiceContract.BundleIdentifier.professional, "com.jacdental.oralable.professionals")
        XCTAssertEqual(OralableAppServiceContract.BundleIdentifier.consumerTests, "com.jacdental.oralable.tests")
        XCTAssertEqual(OralableAppServiceContract.BundleIdentifier.professionalUITests, "com.jacdental.oralable.professionals.uitests")
    }

    func testStoreKitCatalogContainsSixDistinctProducts() {
        let products = OralableAppServiceContract.StoreKit.consumerProductIdentifiers
            .union(OralableAppServiceContract.StoreKit.professionalProductIdentifiers)

        XCTAssertEqual(products.count, 6)
        XCTAssertTrue(products.contains("com.jacdental.oralable.premium.monthly"))
        XCTAssertTrue(products.contains("com.jacdental.oralable.practice.yearly"))
    }

    func testCloudKitMigrationUsesCanonicalProfessionalFields() {
        XCTAssertEqual(OralableAppServiceContract.CloudKit.containerIdentifier, "iCloud.com.jacdental.oralable.shared")
        XCTAssertEqual(OralableAppServiceContract.CloudKit.Field.professionalID, "professionalID")
        XCTAssertEqual(OralableAppServiceContract.CloudKit.Field.legacyDentistID, "dentistID")
        XCTAssertEqual(OralableAppServiceContract.CloudKit.Field.professionalName, "professionalName")
        XCTAssertEqual(OralableAppServiceContract.CloudKit.Field.legacyDentistName, "dentistName")
    }

    func testHealthKitScopeIsExplicitlyLimited() {
        XCTAssertEqual(OralableAppServiceContract.HealthKit.writableQuantityTypes, ["heartRate", "oxygenSaturation"])
        XCTAssertEqual(OralableAppServiceContract.HealthKit.minimumSampleIntervalSeconds, 5)
        XCTAssertTrue(OralableAppServiceContract.HealthKit.nonWritableData.contains("sleep stages"))
    }
}
