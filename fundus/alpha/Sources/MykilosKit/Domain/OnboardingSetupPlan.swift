import Foundation

public struct OnboardingSetupPunkt: Identifiable, Equatable, Sendable {
    public enum Art: String, Sendable { case geteilt, persoenlich }
    public enum Status: String, Sendable { case erledigt, offen }
    public let id: String
    public let title: String
    public let art: Art
    public let status: Status

    public let essenziell: Bool

    public init(id: String, title: String, art: Art, status: Status, essenziell: Bool) {
        self.id = id; self.title = title; self.art = art; self.status = status
        self.essenziell = essenziell
    }
}

public struct OnboardingSetupZustand: Sendable, Equatable {
    public var claudeVerbunden: Bool
    public var googleVerbunden: Bool
    public var clickUpVerbunden: Bool

    public var identitaetBestaetigt: Bool

    public init(claudeVerbunden: Bool = false,
                googleVerbunden: Bool = false, clickUpVerbunden: Bool = false,
                identitaetBestaetigt: Bool = false) {
        self.claudeVerbunden = claudeVerbunden
        self.googleVerbunden = googleVerbunden
        self.clickUpVerbunden = clickUpVerbunden
        self.identitaetBestaetigt = identitaetBestaetigt
    }
}

public enum OnboardingSetupPlan {
    public static func points(_ z: OnboardingSetupZustand) -> [OnboardingSetupPunkt] {
        func s(_ b: Bool) -> OnboardingSetupPunkt.Status { b ? .erledigt : .offen }
        return [
            OnboardingSetupPunkt(id: "google", title: "Google verbinden (dein Konto)",
                                 art: .persoenlich, status: s(z.googleVerbunden), essenziell: true),
            OnboardingSetupPunkt(id: "claude", title: "Assistent verbinden",
                                 art: .persoenlich, status: s(z.claudeVerbunden), essenziell: true),
            OnboardingSetupPunkt(id: "clickup", title: "ClickUp verbinden (optional)",
                                 art: .persoenlich, status: s(z.clickUpVerbunden), essenziell: false),
            OnboardingSetupPunkt(id: "identitaet", title: "Identität bestätigen",
                                 art: .persoenlich, status: s(z.identitaetBestaetigt), essenziell: true)
        ]
    }

    public static func istFertig(_ z: OnboardingSetupZustand) -> Bool {
        points(z).filter(\.essenziell).allSatisfy { $0.status == .erledigt }
    }

    public static func naechsterOffener(_ z: OnboardingSetupZustand) -> OnboardingSetupPunkt? {
        let offen = points(z).filter { $0.status == .offen }
        return offen.first(where: \.essenziell) ?? offen.first
    }

    public static func fortschritt(_ z: OnboardingSetupZustand) -> (erledigt: Int, total: Int) {
        let ess = points(z).filter(\.essenziell)
        return (ess.filter { $0.status == .erledigt }.count, ess.count)
    }
}
