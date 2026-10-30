extension IMAPSMTPClient: SenderPort {
    func senders() async throws -> [Participant] {
        [Participant(name: account.displayName == account.address ? "" : account.displayName, address: account.address)]
    }
}
