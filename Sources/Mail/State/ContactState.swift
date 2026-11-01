import Foundation
import Observation

@MainActor @Observable
public final class ContactState {
    public private(set) var items: [Contact] = [] { didSet { book?.save(items) } }
    public var editing: String?

    @ObservationIgnored private let book: (any ContactBookPort)?

    public init(book: (any ContactBookPort)? = nil) {
        self.book = book
        items = book?.load() ?? []
    }

    func contact(_ address: String) -> Contact? {
        items.first { $0.address.lowercased() == address.lowercased() }
    }

    func save(name: String, address: String) -> ToastKind {
        let shown = name.isEmpty ? address : name
        if contact(address) != nil { return .contactExists(shown) }
        items.append(Contact(id: UUID().uuidString, name: name, address: address))
        return .contactSaved(shown)
    }

    public func edit(_ id: String, name: String? = nil, address: String? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let name { items[index].name = name }
        if let address { items[index].address = address }
    }

    public func remove(_ id: String) -> ToastKind {
        items.removeAll { $0.id == id }
        if editing == id { editing = nil }
        return .contactRemoved
    }

    public func add() {
        let added = Contact(id: UUID().uuidString, name: "", address: "")
        items.append(added)
        editing = added.id
    }
}
