import Foundation

public struct TimeReport: Sendable, Equatable {
    public struct Entry: Sendable, Equatable {
        public let start: Date
        public let customer: String
        public let service: String
        public let seconds: Int
        public let note: String?

        public init(start: Date, customer: String, service: String, seconds: Int, note: String? = nil) {
            self.start = start
            self.customer = customer
            self.service = service
            self.seconds = seconds
            self.note = note
        }
    }

    public let entries: [Entry]
    public let error: String?

    public init(entries: [Entry], error: String? = nil) {
        self.entries = entries
        self.error = error
    }
}
