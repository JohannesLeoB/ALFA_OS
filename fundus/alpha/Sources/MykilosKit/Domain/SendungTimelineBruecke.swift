import Foundation

public enum SendungTimelineBruecke {
    public static func neuZugestellt(vorher: [Sendung], nachher: [Sendung]) -> [Sendung] {
        let vorherStatus = Dictionary(vorher.map { ($0.trackingNummer, $0.status) },
                                      uniquingKeysWith: { a, _ in a })
        return nachher.filter { neu in
            guard neu.status == .zugestellt else { return false }
            return vorherStatus[neu.trackingNummer] != .zugestellt
        }
    }

    public static func zustellEintraege(
        sendungen: [Sendung], actorUserID: String, jetzt: Date = Date()
    ) -> [AuditEntry] {
        sendungen.compactMap { s in
            guard s.status == .zugestellt,
                  let projekt = s.projectNumber?.trimmingCharacters(in: .whitespaces),
                  projekt.isEmpty == false else { return nil }
            let label = s.label.isEmpty ? s.trackingNummer : s.label
            return AuditEntry(
                timestamp: jetzt, actorUserID: actorUserID, projectID: projekt,
                action: .dhlSendungZugestellt,
                summary: "DHL-Sendung zugestellt — \(label) · \(s.trackingNummer)",
                source: "dhl-tracking", idempotenzKey: "dhl-zugestellt:\(s.trackingNummer)")
        }
    }
}
