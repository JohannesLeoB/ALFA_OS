import Hub

public struct SenderChoice: Identifiable, Equatable, Sendable {
    public let inlet: Inlet.ID
    public let sender: Participant

    public var id: String { inlet + "\n" + sender.address.lowercased() }

    public init(inlet: Inlet.ID, sender: Participant) {
        self.inlet = inlet
        self.sender = sender
    }
}
