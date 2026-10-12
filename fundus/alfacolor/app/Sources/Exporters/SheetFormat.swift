import Foundation
import UniformTypeIdentifiers
import ALFAcolorCore
import Document

/// Errors of the PDF sheet.
public enum SheetError: Error, Equatable, Sendable {
    /// Core Graphics could not write the PDF.
    case drawingFailed
}

/// The PDF sheet: one page per frame, on A4 or A3 landscape, with measures, the colour legend and the pieces.
/// A page for the free items follows the frame pages. The sheet is for people; the mockup package is for code and AI.
public struct SheetFormat: ExchangeFormat {
    public let id = "sheet"
    public let name = String(localized: "exchange.sheet.name")
    public let contentTypes: [UTType] = [.pdf]
    public let capabilities: ExchangeCapabilities = .write
    public let paper: SheetPaper
    public let labels: SheetLabels
    /// Time of the sheet. It goes into the header and the file name.
    public let created: Date

    public init(paper: SheetPaper = .a4, labels: SheetLabels = .localized, created: Date = .now) {
        self.paper = paper
        self.labels = labels
        self.created = created
    }

    public func write(_ document: ALFAcolorDocument, scope: ExchangeScope) throws -> ExchangeOutput {
        let pages = try SheetPages.make(document: document, scope: scope)
        let date = created.formatted(date: .abbreviated, time: .omitted)
        guard let data = SheetDrawing.pdf(pages: pages, paper: paper, title: document.board.title, date: date, labels: labels) else {
            throw SheetError.drawingFailed
        }
        let label = pages.count == 1 ? (pages[0].title ?? "sheet") : "sheet"
        return .file(name: "sheet_\(MockupEntries.fileName(label))_\(Self.localDay(created)).pdf", type: .pdf, data: data)
    }

    /// The day of a time in the time zone of the Mac, as yyyy-mm-dd.
    static func localDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
}
