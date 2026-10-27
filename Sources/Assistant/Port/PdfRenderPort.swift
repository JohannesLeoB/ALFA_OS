import Foundation

protocol PdfRenderPort: Sendable {
    func render(title: String, rows: [[String]]) async throws -> Data
}
