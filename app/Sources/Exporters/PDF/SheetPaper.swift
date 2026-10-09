import Foundation

/// Page sizes of the PDF sheet. Both are landscape, in points (1 pt = 1/72 inch).
public enum SheetPaper: String, CaseIterable, Sendable {
    case a4
    case a3

    public var width: Double {
        switch self {
        case .a4: 842
        case .a3: 1191
        }
    }

    public var height: Double {
        switch self {
        case .a4: 595
        case .a3: 842
        }
    }
}
