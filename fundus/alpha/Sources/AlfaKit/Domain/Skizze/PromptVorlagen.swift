import Foundation

public enum PromptVorlagen {
    public static let szene =
        "Nimm das angehängte Ausgangsfoto als verbindliche Grundlage. Erhalte Kameraperspektive, "
        + "Bildausschnitt, Lichtstimmung, Raumgeometrie und alle nicht benannten Bestandteile "
        + "(Fenster, Boden, Decke, Wände, Personen) exakt. Verändere ausschließlich die unten "
        + "benannten Volumen und Flächen."

    public static let verbote =
        "Keine zusätzlichen Möbel, keine Deko-Objekte, kein Text, keine Logos, keine Wasserzeichen. "
        + "Verändere die Perspektive nicht, verzerre keine Proportionen, erfinde keine Räume hinzu. "
        + "Halte dich strikt an die angehängten Referenzbilder für Material und Farbe."

    public static let titelSzene = "SZENE"
    public static let titelGeometrie = "GEOMETRIE"
    public static let titelMaterialien = "MATERIALIEN"
    public static let titelStil = "STIL"
    public static let titelVerbote = "VERBOTE"

    public static func volltext(szene: String, geometrie: String, materialien: String,
                                stil: String, verbote: String) -> String {
        [
            "\(titelSzene)\n\(szene)",
            "\(titelGeometrie)\n\(geometrie)",
            "\(titelMaterialien)\n\(materialien)",
            "\(titelStil)\n\(stil)",
            "\(titelVerbote)\n\(verbote)"
        ].joined(separator: "\n\n")
    }
}
