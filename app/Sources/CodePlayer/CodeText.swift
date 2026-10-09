/// The source text that a card shows. Very long files are cut so that the highlighter stays fast.
public enum CodeText {
    /// Most characters the source view shows.
    public static let shownLimit = 60_000

    /// The text to show, and whether it was cut.
    public static func shown(_ code: String) -> (text: String, isCut: Bool) {
        guard code.count > shownLimit else { return (code, false) }
        return (String(code.prefix(shownLimit)), true)
    }
}
