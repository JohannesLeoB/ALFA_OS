import Foundation

/// Writes the changed control values into the code, at the first declaration of each variable.
public enum LabWriteBack {
    /// The draft with every changed value written at its first declaration. The code is read in the order of
    /// style, markup, script, so the first declaration is the first one in that order.
    public static func apply(_ controls: [LabControl], to draft: LabDraft) -> LabDraft {
        var result = draft
        let order = [LabDraft.Tab.css, .html, .script].filter(draft.tabs.contains)
        for control in controls where control.isChanged {
            for tab in order {
                if let text = replaceFirst(control.name, with: control.value.css, in: result.text(tab)) {
                    result.setText(text, for: tab)
                    break
                }
            }
        }
        return result
    }

    /// The draft with the changed property values written as the new defaults of its component. Only React drafts have props.
    public static func applyProps(_ props: [LabProp], to draft: LabDraft) -> LabDraft {
        guard draft.art == .react else { return draft }
        var result = draft
        result.script = LabPropsReader.write(props, to: draft.script)
        return result
    }

    /// Replaces the value of the first declaration of `name` in `text`. nil when there is none.
    /// A name that only ends another name does not match.
    static func replaceFirst(_ name: String, with value: String, in text: String) -> String? {
        let pattern = "(?<![A-Za-z0-9_-])(" + NSRegularExpression.escapedPattern(for: name) + "\\s*:\\s*)[^;{}\"'`\\n]+"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let prefixEnd = match.range(at: 1).location + match.range(at: 1).length
        let valueRange = NSRange(location: prefixEnd, length: match.range.location + match.range.length - prefixEnd)
        let result = NSMutableString(string: text)
        result.replaceCharacters(in: valueRange, with: value)
        return result as String
    }
}
