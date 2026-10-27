enum ModelRouter {
    static let haiku = "claude-haiku-4-5-20251001"
    static let sonnet = "claude-sonnet-4-6"
    static let opus = "claude-opus-4-8"

    static let estimationKeywords = [
        "sch\u{E4}tz", "schaetz", "kalkul", "budget", "marge", "kostenvoranschlag",
        "was kostet", "wieviel kostet", "kosten f\u{FC}r", "preis pro", "\u{20AC}", "euro",
    ]

    static let complexKeywords = [
        "warum", "erkl\u{E4}re", "erkl\u{E4}r", "vergleich", "analys",
        "strategie", "begr\u{FC}nd", "schritt f\u{FC}r schritt", "plane ",
    ]

    static let complexWordLimit = 40

    static func model(latestUserText: String, toolsEnabled: Bool) -> String {
        let text = latestUserText.lowercased()
        if mentionsEstimation(text) { return opus }
        if toolsEnabled { return sonnet }
        if isComplex(text) { return sonnet }
        return haiku
    }

    static func mentionsEstimation(_ text: String) -> Bool {
        estimationKeywords.contains { text.contains($0) }
    }

    static func isComplex(_ text: String) -> Bool {
        if text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count > complexWordLimit { return true }
        return complexKeywords.contains { text.contains($0) }
    }
}
