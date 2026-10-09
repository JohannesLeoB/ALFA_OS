import Foundation
import WebKit

/// Draws a loaded card page and returns the image as PNG data. The app draws the page in a window of the preview width.
@available(macOS 26.0, *)
@MainActor
public protocol StillHost {
    func export(_ page: WebPage, width: Double) async throws -> Data
}

/// Exports the page without a window. WebKit then lays the page out at its default width, not at the preview width.
/// Used where no window exists, such as tests.
@available(macOS 26.0, *)
@MainActor
public struct OffscreenStillHost: StillHost {
    public init() {}

    public func export(_ page: WebPage, width: Double) async throws -> Data {
        try await page.exported(as: .image(snapshotWidth: width))
    }
}
