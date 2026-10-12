import Foundation

public enum SpeiseplanNachladen {
    public static let bildStunde = 11

    public static func naechsterZeitpunkt(
        nach geladenAm: Date,
        kalender: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        guard let heuteMittag = kalender.date(
            bySettingHour: bildStunde, minute: 0, second: 0, of: geladenAm) else { return nil }
        if geladenAm < heuteMittag { return heuteMittag }
        return kalender.date(byAdding: .day, value: 1, to: heuteMittag)
    }

    public static func wartezeit(nach geladenAm: Date, jetzt: Date,
                                 kalender: Calendar = Calendar(identifier: .gregorian)) -> TimeInterval? {
        guard let target = naechsterZeitpunkt(nach: geladenAm, kalender: kalender) else { return nil }
        return max(0, target.timeIntervalSince(jetzt))
    }
}
