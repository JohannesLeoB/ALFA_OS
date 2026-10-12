import Foundation

/// A token value as one line of text, for tables and lists. The text is the value itself, not code.
public enum TokenText {
    public static func value(_ value: TokenValue) -> String {
        switch value {
        case .color(let c):
            return c.hex
        case .dimension(let x, let unit):
            return "\(TokenExport.fmt(x)) \(unit)"
        case .number(let x):
            return TokenExport.fmt(x)
        case .duration(let ms):
            return "\(TokenExport.fmt(ms)) ms"
        case .fontFamily(let names):
            return names.joined(separator: ", ")
        case .fontWeight(let w):
            return String(w)
        case .cubicBezier(let a, let b, let c, let d):
            return "\(TokenExport.fmt(a)), \(TokenExport.fmt(b)), \(TokenExport.fmt(c)), \(TokenExport.fmt(d))"
        case .typography(let t):
            return "\(t.fontFamily.joined(separator: ", ")), \(TokenExport.fmt(t.fontSize)) px, \(t.fontWeight), \(TokenExport.fmt(t.lineHeight))"
        }
    }
}
