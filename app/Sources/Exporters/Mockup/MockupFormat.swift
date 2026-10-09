import Foundation
import UniformTypeIdentifiers
import ALFAcolorCore
import Document

/// Errors of the mockup package.
public enum MockupError: Error, Equatable, Sendable {
    /// The scope picks no items and no frames.
    case nothingToExport
}

/// The mockup package: a ZIP with manifest.json, code/, images/, tokens.json, preview.html and LIESMICH.txt.
/// Foreign images are not copied. The manifest keeps their link and license.
public struct MockupFormat: ExchangeFormat {
    public let id = "mockup"
    public let name = "Mockup package"
    public let contentTypes: [UTType] = [.zip]
    public let capabilities: ExchangeCapabilities = .write
    /// Time of the package. It goes into the manifest, the ZIP entries and the file name.
    public let created: Date

    public init(created: Date = .now) {
        self.created = created
    }

    public func write(_ document: ALFAcolorDocument, scope: ExchangeScope) throws -> ExchangeOutput {
        let plan = try MockupPlan(document: document, scope: scope)
        var collected = MockupEntries(document: document, plan: plan)
        for placed in plan.placed {
            collected.add(placed)
        }

        let manifest = MockupManifest(
            title: document.board.title,
            created: created.formatted(.iso8601),
            frames: plan.frames.map { MockupManifest.Frame(id: $0.id.raw, title: $0.title, width: $0.rect.w, height: $0.rect.h) },
            items: collected.entries,
            warnings: collected.warnings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        var zip = ZipWriter()
        try zip.add("manifest.json", data: encoder.encode(manifest))
        for (path, bytes) in collected.files.sorted(by: { $0.key < $1.key }) {
            try zip.add(path, data: bytes)
        }
        try zip.add("tokens.json", data: collected.tokenData())
        let preview = MockupPreview.html(title: document.board.title, frames: manifest.frames,
                                         entries: manifest.items, files: collected.files)
        try zip.add("preview.html", data: Data(preview.utf8))
        try zip.add("LIESMICH.txt", data: Data(Self.readme.utf8))

        return .file(name: fileName(for: plan), type: .zip, data: try zip.archive(modified: created))
    }

    /// mockup_<frame>_<date>.zip for one frame, mockup_sheet_<date>.zip otherwise.
    func fileName(for plan: MockupPlan) -> String {
        let label = plan.frames.count == 1 ? plan.frames[0].title : "sheet"
        return "mockup_\(MockupEntries.safeName(label))_\(String(created.formatted(.iso8601).prefix(10))).zip"
    }

    static let readme = """
    ALFAcolor mockup package
    Status: draft, not contract. The values here are drafts, not tokens.

    Files
    - manifest.json: frames and items. Positions are points. The origin is the top left corner of the frame,
      or of the free sheet for items without a frame.
    - preview.html: open in a browser. It draws each frame as on the canvas.
    - code/: one file per code card. Extra files of a card sit in code/<card>/.
    - images/: own images, named by content hash. Foreign images are not in the package;
      manifest.json gives their link and license.
    - Source and license of each item are in manifest.json (url, license, via). A code card without a license is marked in warnings.
    - tokens.json: the tokens that the items use, as DTCG, grouped by token set.

    For the design and code agents: a frame is a screen or view of that size in points.
    Build from the contract only. Use the code files as a behavior reference, not as values.

    """
}
