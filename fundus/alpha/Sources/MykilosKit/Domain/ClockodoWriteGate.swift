import Foundation

public enum ClockodoWriteGateError: Error, Sendable, Equatable, LocalizedError {
    case zeitPostVerboten

    public var errorDescription: String? {
        "ALPHA bucht Zeiten an Clockodo nur über die manuelle Eingabemaske "
        + "(Zeit → »Zeit manuell buchen«) — nie automatisch, nie als Nebeneffekt."
    }
}

public enum ClockodoWriteGate {
    public static func assertZeitEintragErlaubt(nutzerHatJetztBestaetigt: Bool) throws {
        guard nutzerHatJetztBestaetigt else {
            throw ClockodoWriteGateError.zeitPostVerboten
        }
    }
}
