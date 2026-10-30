import Foundation

enum SenderEngine {
    static func merged(account: String, chosen: String, profile: String, stored: [Participant]) -> [Participant] {
        let own = account.lowercased()
        let named = chosen.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = stored.first { $0.address.lowercased() == own }
        var result: [Participant] = []
        var seen: Set<String> = []
        func add(name: String, address: String) {
            let key = address.lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            result.append(Participant(id: result.count, name: named.isEmpty ? name : named, address: address))
        }
        let primaryName = primary.map(\.name).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        add(name: primaryName, address: account)
        for entry in stored { add(name: entry.name.isEmpty ? primaryName : entry.name, address: entry.address) }
        return result
    }

    static func receiving(_ senders: [Participant], headers: [String]) -> Participant? {
        let addresses = headers.flatMap { AddressListParser.split($0) }.map(AddressEngine.email)
        for address in addresses {
            if let match = senders.first(where: { $0.address.lowercased() == address }) { return match }
        }
        return nil
    }
}
