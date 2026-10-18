import Foundation

public enum AssistantModelRouter {
    public static let haiku  = "claude-haiku-4-5-20251001"
    public static let sonnet = "claude-sonnet-4-6"
    public static let opus   = "claude-opus-4-8"

    public static func model(latestUserText: String, toolsEnabled: Bool, schaetzModus: Bool) -> String {
        let text = latestUserText.lowercased()
        if schaetzModus || mentionsEstimation(text) { return opus }
        if toolsEnabled { return sonnet }
        if isComplex(text) { return sonnet }
        return haiku
    }

    public static func tierLabel(_ model: String) -> String {
        let lower = model.lowercased()
        if lower.contains("haiku") { return "HAIKU" }
        if lower.contains("opus") { return "OPUS" }
        if lower.contains("sonnet") { return "SONNET" }
        return model.uppercased()
    }

    static func mentionsEstimation(_ text: String) -> Bool {
        let keywords = ["schätz", "schaetz", "kalkul", "budget", "marge", "kostenvoranschlag",
                        "was kostet", "wieviel kostet", "kosten für", "preis pro", "€", "euro"]
        return keywords.contains { text.contains($0) }
    }

    static func isComplex(_ text: String) -> Bool {
        if text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count > 40 { return true }
        let hard = ["warum", "erkläre", "erklär", "vergleich", "analys",
                    "strategie", "begründ", "schritt für schritt", "plane "]
        return hard.contains { text.contains($0) }
    }
}
