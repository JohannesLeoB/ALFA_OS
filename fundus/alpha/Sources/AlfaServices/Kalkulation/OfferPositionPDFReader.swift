import Foundation
import PDFKit
import MykilosKalkulationsCore

public enum OfferPositionPDFReader {
    public typealias Position = OfferPositionExtractor.ExtractedPosition

    public struct PagedPosition: Sendable {
        public let pageNumber: Int
        public let position: Position
        public init(pageNumber: Int, position: Position) {
            self.pageNumber = pageNumber
            self.position = position
        }
    }

    public static func positions(fromPDFAt url: URL) -> [PagedPosition] {
        guard let doc = PDFDocument(url: url) else { return [] }
        return positions(from: doc)
    }

    public static func positions(fromPDFData data: Data) -> [PagedPosition] {
        guard let doc = PDFDocument(data: data) else { return [] }
        return positions(from: doc)
    }

    static func positions(from doc: PDFDocument) -> [PagedPosition] {
        var result: [PagedPosition] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let text = page.string else { continue }
            for p in OfferPositionExtractor.extractPositions(fromPageText: text) {
                result.append(PagedPosition(pageNumber: i + 1, position: p))
            }
        }
        return result
    }
}
