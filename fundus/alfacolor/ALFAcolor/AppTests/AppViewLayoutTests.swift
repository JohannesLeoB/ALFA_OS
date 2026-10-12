import AppKit
import BoardModel
import CodePlayer
import Document
import SwiftUI
import Testing

/// The real sidebar, inspector and main window. Nothing may reach over the edge of its column, a label may not
/// break inside a word, and the content of a column may not decide the size of the window.
@MainActor
struct AppViewLayoutTests {
    /// Widths in which the columns are probed: narrowest, standard, widest.
    nonisolated static let sidebarWidths: [CGFloat] = [200, 240, 320]
    nonisolated static let inspectorWidths: [CGFloat] = [260, 300, 380]
    nonisolated static let windowWidths: [CGFloat] = [960, 1280]
    static let sidebarRange: ClosedRange<CGFloat> = 200...320
    static let inspectorRange: ClosedRange<CGFloat> = 260...380
    static let windowSize = CGSize(width: 1280, height: 800)
    static let minimumWindowWidth: CGFloat = 1000
    /// Left and right inset of a row in a grouped form: the column minus the room of the row.
    static let formRowInset: CGFloat = 40

    static func sidebarFor(_ s: DocumentSession) -> some View { sidebar(s) }
    static func inspectorFor(_ s: DocumentSession) -> some View { inspector(s) }

    private static func sidebar(_ session: DocumentSession) -> some View {
        SidebarView(store: session.store, shell: ShellState())
    }

    private static func inspector(_ session: DocumentSession) -> some View {
        let canvas = CanvasController(store: session.store)
        return InspectorView(canvas: canvas, interaction: CanvasInteraction(controller: canvas), shell: ShellState())
    }

    // MARK: Sidebar

    @Test("sidebar keeps its content inside its column", arguments: sidebarWidths)
    func sidebar(width: CGFloat) {
        let findings = LayoutProbe.inspect(Self.sidebar(AppFixture.session()), width: width)
        #expect(findings.isEmpty, "sidebar at \(Int(width)) points: \(findings)")
    }

    // MARK: Inspector

    @Test("inspector keeps its content inside its column, code card selected", arguments: inspectorWidths)
    func inspector(width: CGFloat) {
        let findings = LayoutProbe.inspect(Self.inspector(AppFixture.session()), width: width)
        #expect(findings.isEmpty, "inspector at \(Int(width)) points: \(findings)")
    }

    /// Each block of the inspector is asked for its ideal width; it may not want more than the room of a
    /// form row. A fixed width inside a form row reaches over the column and is cut at both edges, and the view walk
    /// cannot see it, because SwiftUI draws the text itself.
    @Test("the notes of the inspector fit the room of a form row", arguments: inspectorWidths)
    func notesFitFormRow(width: CGFloat) {
        let store = AppFixture.session().store
        let notes = NotesListView(store: store, itemIDs: store.selectedItems.map(\.id))
        let room = width - Self.formRowInset
        let ideal = LayoutProbe.idealWidth(of: notes)
        #expect(ideal <= room + LayoutProbe.tolerance, "notes ask for \(ideal) points in a row of \(room)")
    }

    @Test("the inspector pass covers the fields of the card")
    func inspectorPassIsNotEmpty() {
        let texts = LayoutProbe.labels(in: Self.inspector(AppFixture.session()), width: 300)
        // Values of the position fields, the version date and the source are real text views; labels are drawn by SwiftUI.
        #expect(texts.contains("320"))
        #expect(texts.contains("CC BY 4.0"))
        #expect(texts.contains { $0.contains("Okt. 2026") })
    }

    // MARK: Worst case: long names, huge numbers, a version with a preview

    nonisolated static let narrowSidebarWidths: [CGFloat] = [140, 190, 240]

    @Test("sidebar keeps its content inside its column, long names", arguments: narrowSidebarWidths)
    func sidebarWorst(width: CGFloat) {
        let findings = LayoutProbe.inspect(Self.sidebar(AppFixture.session(worst: true)), width: width)
        #expect(findings.isEmpty, "sidebar at \(Int(width)) points: \(findings)")
    }

    @Test("inspector keeps its content inside its column, worst case with a preview", arguments: inspectorWidths)
    func inspectorWorst(width: CGFloat) async {
        let session = AppFixture.session(worst: true)
        await AppFixture.cacheStill(of: session)
        let findings = LayoutProbe.inspect(Self.inspector(session), width: width)
        #expect(findings.isEmpty, "inspector at \(Int(width)) points: \(findings)")
    }

    @Test("a version row with a preview fits the room of a form row", arguments: inspectorWidths)
    func versionRowWithPreview(width: CGFloat) async throws {
        let session = AppFixture.session(worst: true)
        let id = try #require(session.store.selectedItems.first?.id)
        let version = try #require(session.store.document.versions.versions(of: id).first)
        let row = try #require(VersionListing([version]).rows.first)
        let still = try #require(await Self.still(of: version))
        let view = VersionRowView(card: .init(id: id, width: nil), row: row, still: still,
                                  attempt: { _ in }, restore: { true }, delete: { true })
        let ideal = LayoutProbe.idealWidth(of: view)
        #expect(ideal <= width - Self.formRowInset + LayoutProbe.tolerance, "row asks for \(ideal) points in \(width - Self.formRowInset)")
    }

    private static func still(of version: CardVersion) async -> CGImage? {
        await AppFixture.cacheStill(of: AppFixture.session(worst: true))
        return CodeStills.shared.cachedStill(for: CodeCard(language: version.language, files: version.files),
                                             width: CodeCardLayout.pageWidth(previewWidth: nil))
    }

    // MARK: Column widths

    @Test("the columns of the window keep the widths of the design", arguments: windowWidths)
    func columnWidths(windowWidth: CGFloat) throws {
        let size = CGSize(width: windowWidth, height: Self.windowSize.height)
        let report = LayoutProbe.inspectShell(ShellView(session: AppFixture.session()), size: size)
        let sidebar = try #require(report.sidebarWidth)
        let inspector = try #require(report.inspectorWidth)
        #expect(Self.sidebarRange.contains(sidebar), "sidebar \(sidebar), allowed \(Self.sidebarRange)")
        #expect(Self.inspectorRange.contains(inspector), "inspector \(inspector), allowed \(Self.inspectorRange)")
    }

    // MARK: Main window

    @Test("the main window asks for no more than its minimum size, code card selected")
    func windowDoesNotGrow() {
        let report = LayoutProbe.inspectShell(ShellView(session: AppFixture.session()), size: Self.windowSize)
        #expect(report.fitting.width <= Self.minimumWindowWidth, "fitting \(report.fitting)")
    }

    @Test("the inspector column does not depend on the selection and keeps its content inside", arguments: windowWidths)
    func inspectorColumnIgnoresSelection(windowWidth: CGFloat) throws {
        let size = CGSize(width: windowWidth, height: Self.windowSize.height)
        let card = LayoutProbe.inspectShell(ShellView(session: AppFixture.session()), size: size)
        let room = LayoutProbe.inspectShell(ShellView(session: AppFixture.session(selectCard: false)), size: size)
        let cardWidth = try #require(card.inspectorWidth)
        let roomWidth = try #require(room.inspectorWidth)
        #expect(abs(cardWidth - roomWidth) <= LayoutProbe.tolerance, "card \(cardWidth), room \(roomWidth)")
        #expect(card.inspectorFindings.isEmpty, "inspector column: \(card.inspectorFindings)")
    }

    @Test("the sidebar column of the window keeps its content inside")
    func sidebarColumnInWindow() throws {
        let report = LayoutProbe.inspectShell(ShellView(session: AppFixture.session()), size: Self.windowSize)
        _ = try #require(report.sidebarWidth)
        #expect(report.sidebarFindings.isEmpty, "sidebar column of \(report.sidebarWidth ?? 0) points: \(report.sidebarFindings)")
    }
}
