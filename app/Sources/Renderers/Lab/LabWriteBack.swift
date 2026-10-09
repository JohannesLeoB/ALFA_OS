import Foundation

/// Writes the changed control values into the code, where the code declares the variable.
public enum LabWriteBack {
    /// The draft with every changed value written into the tabs that the art shows.
    public static func apply(_ controls: [LabControl], to draft: LabDraft) -> LabDraft {
        var result = draft
        for control in controls where control.isChanged {
            for tab in draft.tabs {
                result.setText(replace(control.name, with: control.value.css, in: result.text(tab)), for: tab)
            }
        }
        return result
    }

    /// Replaces the value of each declaration of `name` in `text`. A name that only ends another name does not match.
    static func replace(_ name: String, with value: String, in text: String) -> String {
        let pattern = "(?<![A-Za-z0-9_-])(" + NSRegularExpression.escapedPattern(for: name) + "\\s*:\\s*)[^;{}\"'`\\n]+"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let whole = NSRange(text.startIndex..., in: text)
        let result = NSMutableString(string: text)
        for match in expression.matches(in: text, range: whole).reversed() {
            let prefixEnd = match.range(at: 1).location + match.range(at: 1).length
            let valueRange = NSRange(location: prefixEnd, length: match.range.location + match.range.length - prefixEnd)
            result.replaceCharacters(in: valueRange, with: value)
        }
        return result as String
    }
}
