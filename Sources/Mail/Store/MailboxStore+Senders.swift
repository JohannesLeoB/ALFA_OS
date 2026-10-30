import Foundation
import Hub

extension MailboxStore {
    static let sendersKey = "senders"

    public func sender(_ inlet: Inlet.ID) -> Participant {
        knownSenders(inlet).first ?? Participant(name: names(inlet).chosen, address: accountAddress(inlet))
    }

    public func knownSenders(_ inlet: Inlet.ID) -> [Participant] {
        let address = accountAddress(inlet)
        guard !address.isEmpty else { return [] }
        let own = names(inlet)
        return SenderEngine.merged(account: address, chosen: own.chosen, profile: own.profile, stored: storedSenders(inlet))
    }

    public func senders(_ inlet: Inlet.ID) async -> [Participant] {
        if let port = (try? transport(inlet)) as? any SenderPort, let found = try? await port.senders() {
            storeSenders(inlet, found)
        }
        return knownSenders(inlet)
    }

    func warmSenders(_ inlet: Inlet.ID) async {
        guard cursor(inlet, Self.sendersKey) == nil else { return }
        _ = await senders(inlet)
    }

    private func accountAddress(_ inlet: Inlet.ID) -> String {
        accounts.first { $0.id == inlet }?.account ?? ""
    }

    private func storedSenders(_ inlet: Inlet.ID) -> [Participant] {
        guard let text = cursor(inlet, Self.sendersKey), let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Participant].self, from: data)) ?? []
    }

    private func storeSenders(_ inlet: Inlet.ID, _ senders: [Participant]) {
        guard let data = try? JSONEncoder().encode(senders), let text = String(data: data, encoding: .utf8) else { return }
        try? setCursor(inlet, Self.sendersKey, text)
    }
}
