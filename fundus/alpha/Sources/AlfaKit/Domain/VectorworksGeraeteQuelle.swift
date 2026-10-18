import Foundation

public enum VectorworksGeraeteQuelle {
    static let statusAktuell = "Aktuell"

    public static func aktuellerKorb(
        entries: [WarenkorbEintrag], projectNumber: String
    ) -> WarenkorbEintrag? {
        guard projectNumber.isEmpty == false else { return nil }
        return entries
            .filter { $0.projekt == projectNumber && $0.status == statusAktuell }
            .max { $0.version < $1.version }
    }
}
