import Foundation

public enum Anzahl {
    public static func text(_ zahl: Int, _ einzahl: String, _ mehrzahl: String) -> String {
        "\(zahl) \(zahl == 1 ? einzahl : mehrzahl)"
    }
}
