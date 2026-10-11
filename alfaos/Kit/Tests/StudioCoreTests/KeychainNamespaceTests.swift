import XCTest
@testable import StudioCore

private final class MemoryKeychain: KeychainAccessing, @unchecked Sendable {
    let namespace: KeychainNamespace
    var content: [String: String] = [:]

    init(namespace: KeychainNamespace) { self.namespace = namespace }

    func load(service: String, account: String) throws -> String? { content["\(service)|\(account)"] }

    @discardableResult
    func store(_ value: String, service: String, account: String) throws -> Bool {
        content["\(service)|\(account)"] = value; return true
    }
}

final class KeychainNamespaceTests: XCTestCase {
    private let studio = KeychainNamespace(bundleIdentifier: "com.example.studio", appName: "Studio")
    private let other = KeychainNamespace(bundleIdentifier: "com.example.other", appName: "Other")

    override func tearDown() { CurrentUserContext.resetForTesting(); super.tearDown() }

    func testServiceNamesAreDerivedFromThePassedNamespace() {
        XCTAssertEqual(studio.servicePrefix, "com.example.studio.")
        XCTAssertEqual(studio.identityService, "com.example.studio.identity")
        XCTAssertEqual(studio.accessLabel, "Studio credentials")
        XCTAssertEqual(PerUserKeychainService.legacy("google", namespace: studio), "com.example.studio.google")
        XCTAssertEqual(PerUserKeychainService.perUser("google", userID: "u1", namespace: studio), "com.example.studio.google.u1")
        XCTAssertEqual(PerUserKeychainService.perUser("google", userID: "  ", namespace: studio), "com.example.studio.google.local")
        XCTAssertNotEqual(
            PerUserKeychainService.perUser("google", userID: "u1", namespace: studio),
            PerUserKeychainService.perUser("google", userID: "u1", namespace: other))
    }

    func testOrphanStateOnlyCountsServicesInsideTheNamespace() {
        func google(_ names: [String], active: String, in namespace: KeychainNamespace) -> KeyInventoryItem? {
            KeychainInventory.build(activeUserID: active, storedServiceNames: names, connected: [:], namespace: namespace)
                .first { $0.integration == .google }
        }
        let foreign = ["com.example.studio.google.old"]
        XCTAssertEqual(google(foreign, active: "new", in: studio)?.orphanReason, .otherIdentity)
        XCTAssertEqual(google(foreign, active: "new", in: studio)?.isOrphaned, true)
        XCTAssertEqual(google(foreign, active: "new", in: other)?.isOrphaned, false)
        XCTAssertEqual(google(["com.example.studio.google"], active: "new", in: studio)?.orphanReason, .legacyShared)
        XCTAssertEqual(google(["com.example.studio.google.local"], active: "new", in: studio)?.orphanReason, .localIdentity)
        XCTAssertEqual(google(foreign, active: "old", in: studio)?.isOrphaned, false)
        XCTAssertNil(google(foreign, active: "old", in: studio)?.orphanReason)
    }

    func testIdentityAnchorLivesInTheNamespaceService() throws {
        let keychain = MemoryKeychain(namespace: studio)
        let anchors = KeychainIdentityAnchorStore(keychain: keychain)
        try anchors.save(userID: "u1", forEmail: " Person@Example.com ")
        XCTAssertEqual(keychain.content["com.example.studio.identity|person@example.com"], "u1")
        XCTAssertEqual(try anchors.userID(forEmail: "person@example.com"), "u1")
        XCTAssertEqual(anchors.service, studio.identityService)
    }

    func testDevicePrimaryIdentityBlocksLegacyMigrationForOtherUsers() throws {
        let keychain = MemoryKeychain(namespace: studio)
        let anchors = KeychainIdentityAnchorStore(keychain: keychain)
        try anchors.ensureDevicePrimary("user-a")
        try keychain.store("secret", service: PerUserKeychainService.legacy("google", namespace: studio), account: "token")

        let blocked = try PerUserKeychainMigrator.loadWithMigration(
            keychain: keychain, base: "google", userID: "user-b", account: "token")
        XCTAssertNil(blocked)

        let allowed = try PerUserKeychainMigrator.loadWithMigration(
            keychain: keychain, base: "google", userID: "user-a", account: "token")
        XCTAssertEqual(allowed, "secret")
        let moved = PerUserKeychainService.perUser("google", userID: "user-a", namespace: studio)
        XCTAssertEqual(keychain.content["\(moved)|token"], "secret")
    }
}
