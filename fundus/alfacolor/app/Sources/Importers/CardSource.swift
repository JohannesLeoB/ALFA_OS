import Foundation

/// Turns the text of a source file into script for a card page. Import lines, "use client" markers and export
/// keywords are removed, and the declarations stay. The page provides React and motion as globals.
public enum CardSource {
    /// The script text of one source file.
    public static func script(_ text: String) -> String {
        var code = text
        code = code.replacing(/^[ \t]*["']use client["'];?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        // An import line may run over several lines, but its module name is always in quotes.
        code = code.replacing(/^[ \t]*import\b[^'"]*?\bfrom[ \t]*['"][^'"\n]+['"][ \t]*;?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        code = code.replacing(/^[ \t]*import[ \t]*['"][^'"\n]+['"][ \t]*;?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        // Export lists, with or without a module name.
        code = code.replacing(/^[ \t]*export[ \t]*\{[^}]*\}([ \t]*from[ \t]*['"][^'"\n]+['"])?[ \t]*;?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        code = code.replacing(/^[ \t]*export[ \t]+default[ \t]+[A-Za-z_$][\w$]*[ \t]*;?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        // An object of names as the default export: the names are declared above, the object is dropped.
        code = code.replacing(/^[ \t]*export[ \t]+default[ \t]+\{[^}]*\}[ \t]*;?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        code = code.replacing(/^([ \t]*)export[ \t]+default[ \t]+/.anchorsMatchLineEndings()) { String($0.output.1) }
        code = code.replacing(/^([ \t]*)export[ \t]+/.anchorsMatchLineEndings()) { String($0.output.1) }
        return code
    }
}
