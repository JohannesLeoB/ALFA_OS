import Foundation
import Mail

enum SenderParser {
    static let acceptedStatus = "accepted"

    static func senders(from data: Data) -> [Participant] {
        struct Entry: Decodable {
            var sendAsEmail: String?
            var displayName: String?
            var isDefault: Bool?
            var verificationStatus: String?
        }
        struct Response: Decodable { var sendAs: [Entry]? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        let usable = (decoded.sendAs ?? []).filter {
            $0.sendAsEmail?.isEmpty == false && ($0.verificationStatus == nil || $0.verificationStatus == acceptedStatus)
        }
        let ordered = usable.filter { $0.isDefault == true } + usable.filter { $0.isDefault != true }
        return ordered.enumerated().map { index, entry in
            Participant(id: index, name: entry.displayName ?? "", address: entry.sendAsEmail ?? "")
        }
    }
}
