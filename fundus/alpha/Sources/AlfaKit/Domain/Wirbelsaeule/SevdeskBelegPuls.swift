import Foundation

public enum SevdeskBelegPulsBefund: Equatable, Sendable {
    case nichtsZuTun

    case pdfAblegen

    case empfaengerGeaendert(neueContactID: String)
    case pdfAblegenUndEmpfaengerGeaendert(neueContactID: String)
}

public enum SevdeskBelegPuls {
    public static func values(
        entry: SevdeskBelegEintrag, status: Int?, update: String?, contactID: String?
    ) -> SevdeskBelegPulsBefund {
        let store = status.map { entry.brauchtAblage(neuerStatus: $0, neuesUpdate: update) } ?? false
        let neueID = contactID.flatMap { neu -> String? in
            (neu.isEmpty == false && neu != entry.contactID) ? neu : nil
        }
        switch (store, neueID) {
        case (false, nil): return .nichtsZuTun
        case (true, nil): return .pdfAblegen
        case (false, .some(let id)): return .empfaengerGeaendert(neueContactID: id)
        case (true, .some(let id)): return .pdfAblegenUndEmpfaengerGeaendert(neueContactID: id)
        }
    }

    public static func fortgeschrieben(
        _ entry: SevdeskBelegEintrag, status: Int?, update: String?, pdfJetztAbgelegt: Bool
    ) -> SevdeskBelegEintrag {
        var neu = entry
        if let status { neu.letzterStatus = status }
        if pdfJetztAbgelegt {
            neu.pdfAbgelegt = true
            neu.letztesUpdate = update ?? entry.letztesUpdate
        }
        return neu
    }
}
