import Foundation
import MykilosKit
import MykilosServices

public struct KeychainAdapter: KeychainPort {
    private let store: KeychainStore
    private let prefix: String

    public init(prefix: String = AppKennung.schluesselbundPraefix) {
        self.store = KeychainStore()
        self.prefix = prefix
    }

    public static func service(for slot: KeySlot, prefix: String = AppKennung.schluesselbundPraefix) -> String {
        prefix + "hub." + slot.inlet
    }

    public static func account(for slot: KeySlot) -> String {
        slot.name
    }

    public func put(_ value: String, at slot: KeySlot) throws {
        do {
            try store.store(value, service: Self.service(for: slot, prefix: prefix), account: Self.account(for: slot))
        } catch let error as KeychainStoreError {
            throw Self.map(error)
        }
    }

    public func get(_ slot: KeySlot) throws -> String? {
        do {
            return try store.load(service: Self.service(for: slot, prefix: prefix), account: Self.account(for: slot))
        } catch let error as KeychainStoreError {
            throw Self.map(error)
        }
    }

    public func delete(_ slot: KeySlot) throws {
        do {
            try store.delete(service: Self.service(for: slot, prefix: prefix), account: Self.account(for: slot))
        } catch let error as KeychainStoreError {
            throw Self.map(error)
        }
    }

    static func map(_ error: KeychainStoreError) -> KeychainError {
        switch error {
        case .encodingFailed: .status(-1)
        case .writeFailed(let status), .readFailed(let status), .deleteFailed(let status): .status(status)
        }
    }
}
