import AppKit
import AppTheme
import SwiftUI

/// Measures views without showing them. The host window sits far outside every screen, is fully transparent,
/// never becomes key and is never ordered front. The app is not activated and makes no sound.
///
/// Two measurements, because SwiftUI draws text in two ways:
/// - `fitted` asks the hosting controller for the size of a view at a proposed width. Text that does not fit
///   wraps, so the height shows it; a view that needs more room than offered reports a width above the offer.
/// - `inspect` lays the view out in a fixed width and walks the AppKit views behind it. Lists and forms put their
///   controls and labels into real views, so a control that leaves the column or wraps to many lines is found there.
@MainActor
enum LayoutProbe {
    /// Far outside all displays, so that no part of the window can be seen.
    static let offscreenOrigin = CGPoint(x: -20000, y: -20000)

    /// Slack for rounding, in points.
    static let tolerance: CGFloat = 1

    /// One thing that does not hold in a layout.
    struct Finding: CustomStringConvertible {
        enum Kind: String {
            /// A view reaches over the left or right edge of its column.
            case outsideColumn
            /// A label wraps and is narrower than its longest word, so a word breaks inside.
            case brokenLabel
            /// A control is more than two lines tall: its text wrapped to many short lines.
            case tooManyLines
            /// A view reaches over the right edge of the list row that holds it.
            case outsideRow
        }

        let kind: Kind
        let viewType: String
        let frame: CGRect
        let detail: String

        var description: String { "\(kind.rawValue) \(viewType) \(frame.integral) \(detail)" }
    }

    // MARK: Fitted size of a view

    /// Size of `view` when `width` is offered; nil offers any width. The height is unlimited.
    static func fitted<V: View>(_ view: V, width: CGFloat?) -> CGSize {
        installAppStrings()
        let controller = NSHostingController(rootView: AnyView(view.environment(\.theme, theme)))
        return controller.sizeThatFits(in: CGSize(width: width ?? 100_000, height: 100_000))
    }

    /// The width `view` asks for when nothing limits it. A view with a fixed width reports that width; a view that
    /// takes whatever it is offered reports the width of its content. It reads the real layout, so it also sees
    /// content that SwiftUI draws itself, which the view walk of `inspect` cannot see.
    static func idealWidth<V: View>(of view: V) -> CGFloat {
        let box = WidthBox()
        let measured = view
            .fixedSize(horizontal: true, vertical: false)
            .background(GeometryReader { proxy in Color.clear.preference(key: WidthKey.self, value: proxy.size.width) })
            .onPreferenceChange(WidthKey.self) { box.width = $0 }
        return layOut(measured, width: 4000, height: 900) { _ in box.width }
    }

    /// True when `view` needs more than `width`.
    static func exceeds<V: View>(_ view: V, width: CGFloat) -> Bool {
        fitted(view, width: width).width > width + tolerance
    }

    /// Height of one line of the system font.
    static var lineHeight: CGFloat {
        NSLayoutManager().defaultLineHeight(for: NSFont.systemFont(ofSize: NSFont.systemFontSize))
    }

    /// How many lines `view` takes at `width`.
    static func lines<V: View>(of view: V, width: CGFloat) -> Int {
        Int((fitted(view, width: width).height / lineHeight).rounded())
    }

    /// True when a word of `text` is wider than `width`, so that it cannot stay whole on a line.
    static func breaksInsideWord(_ text: String, font: NSFont = .systemFont(ofSize: NSFont.systemFontSize), width: CGFloat) -> Bool {
        widestWord(text, font: font) > width + tolerance
    }

    private static func widestWord(_ text: String, font: NSFont) -> CGFloat {
        text.split(whereSeparator: { $0.isWhitespace })
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
    }

    // MARK: Walking the views

    /// Lays `view` out in a column of `width` and reports what does not hold.
    static func inspect<V: View>(_ view: V, width: CGFloat, height: CGFloat = 900) -> [Finding] {
        layOut(view, width: width, height: height) { root in
            var findings: [Finding] = []
            collect(root, root: root, into: &findings)
            return findings
        }
    }

    /// The texts of the labels and buttons that are laid out in a column of `width`. It shows what a pass covers.
    static func labels<V: View>(in view: V, width: CGFloat, height: CGFloat = 900) -> [String] {
        layOut(view, width: width, height: height) { root in
            var texts: [String] = []
            gatherTexts(root, into: &texts)
            return texts
        }
    }

    // MARK: The whole window

    /// What a laid-out main window shows: the width of its columns and what does not hold inside each column.
    struct ShellReport {
        /// What the window asks for at least, from its content.
        let fitting: CGSize
        let sidebarWidth: CGFloat?
        let inspectorWidth: CGFloat?
        let sidebarFindings: [Finding]
        let inspectorFindings: [Finding]
    }

    /// Lays `view`, the main window, out in a window of `size` and measures its two side columns.
    static func inspectShell<V: View>(_ view: V, size: CGSize) -> ShellReport {
        layOut(view, width: size.width, height: size.height) { root in
            var report = (sidebar: nil as NSView?, inspector: nil as NSView?)
            findColumns(root, into: &report)
            return ShellReport(
                fitting: root.fittingSize,
                sidebarWidth: report.sidebar?.frame.width,
                inspectorWidth: report.inspector?.frame.width,
                sidebarFindings: columnFindings(report.sidebar),
                inspectorFindings: columnFindings(report.inspector)
            )
        }
    }

    private static func columnFindings(_ column: NSView?) -> [Finding] {
        guard let column else { return [] }
        var found: [Finding] = []
        collect(column, root: column, into: &found)
        return found
    }

    private static func findColumns(_ view: NSView, into columns: inout (sidebar: NSView?, inspector: NSView?)) {
        let name = String(describing: type(of: view))
        if name.hasPrefix("NSHostingView"), name.contains("SidebarStyleContext") { columns.sidebar = view }
        if name.hasPrefix("NSHostingView"), name.contains("InspectorStyleContext") { columns.inspector = view }
        for sub in view.subviews { findColumns(sub, into: &columns) }
    }

    private static func layOut<V: View, Result>(_ view: V, width: CGFloat, height: CGFloat, measure: (NSView) -> Result) -> Result {
        installAppStrings()
        let hosting = NSHostingView(rootView: AnyView(view.environment(\.theme, theme)))
        let window = NSWindow(
            contentRect: CGRect(origin: offscreenOrigin, size: CGSize(width: width, height: height)),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.alphaValue = 0
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.frame = CGRect(x: 0, y: 0, width: width, height: height)
        settle(hosting)
        defer { window.contentView = nil }
        return measure(hosting)
    }

    private static func gatherTexts(_ view: NSView, into texts: inout [String]) {
        if let field = view as? NSTextField, !field.stringValue.isEmpty { texts.append(field.stringValue) }
        if let button = view as? NSButton, !button.title.isEmpty { texts.append(button.title) }
        for sub in view.subviews { gatherTexts(sub, into: &texts) }
    }

    /// Lets lazy lists build their rows: lays out and gives the run loop short turns until the frames stop changing.
    private static func settle(_ root: NSView) {
        var last = ""
        for _ in 0..<40 {
            root.layoutSubtreeIfNeeded()
            let now = signature(root)
            if now == last { return }
            last = now
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private static func signature(_ view: NSView) -> String {
        var parts = ["\(view.frame)"]
        for sub in view.subviews { parts.append(signature(sub)) }
        return parts.joined(separator: "|")
    }

    /// Views that only carry other views or draw chrome. Their frames are not content.
    private static let chrome = ["Scroller", "VisualEffect", "ClipView", "ScrollView", "FocusRing", "ContentBackground", "TableRow", "OutlineList"]

    private static func collect(_ view: NSView, root: NSView, into findings: inout [Finding]) {
        for sub in view.subviews where !sub.isHidden && sub.alphaValue > 0 {
            let name = String(describing: type(of: sub))
            let frame = sub.convert(sub.bounds, to: root)
            let isChrome = chrome.contains { name.contains($0) }
            if !isChrome, frame.width > 0, frame.minX < -tolerance || frame.maxX > root.bounds.width + tolerance {
                findings.append(Finding(kind: .outsideColumn, viewType: name, frame: frame,
                                        detail: "column 0 to \(Int(root.bounds.width))"))
                continue
            }
            if name.hasPrefix("CellHostingView") {
                findings += rowOverflow(of: sub, row: frame, root: root)
            }
            if let finding = wrapFinding(sub, name: name, frame: frame) {
                findings.append(finding)
            }
            collect(sub, root: root, into: &findings)
        }
    }

    /// The views inside a list row that reach over the right edge of the row. The row clips them.
    private static func rowOverflow(of cell: NSView, row: CGRect, root: NSView) -> [Finding] {
        var found: [Finding] = []
        func walk(_ view: NSView) {
            for sub in view.subviews where !sub.isHidden {
                let name = String(describing: type(of: sub))
                let frame = sub.convert(sub.bounds, to: root)
                if !chrome.contains(where: { name.contains($0) }), frame.width > 0, frame.maxX > row.maxX + tolerance {
                    found.append(Finding(kind: .outsideRow, viewType: name, frame: frame, detail: "row ends at \(Int(row.maxX))"))
                }
                walk(sub)
            }
        }
        walk(cell)
        return found
    }

    private static func wrapFinding(_ view: NSView, name: String, frame: CGRect) -> Finding? {
        if let field = view as? NSTextField, !field.stringValue.isEmpty {
            let font = field.font ?? .systemFont(ofSize: NSFont.systemFontSize)
            let oneLine = NSLayoutManager().defaultLineHeight(for: font)
            if frame.height > oneLine * 1.5, breaksInsideWord(field.stringValue, font: font, width: frame.width) {
                return Finding(kind: .brokenLabel, viewType: name, frame: frame, detail: "'\(field.stringValue)'")
            }
            return nil
        }
        if view is NSButton, frame.height > lineHeight * 2 + tolerance {
            return Finding(kind: .tooManyLines, viewType: name, frame: frame,
                           detail: "more than two lines")
        }
        return nil
    }

    // MARK: Environment of the app

    /// The contract of the repository. The test bundle does not carry the contract files, and without them every
    /// space and radius would be zero, so a layout would look tighter than it is in the app.
    private static var theme: Theme {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("gestaltung/vertrag", isDirectory: true)
        return Theme.load(light: folder.appendingPathComponent("tokens.json"),
                          dark: folder.appendingPathComponent("tokens.dunkel.json"))
    }

    /// Texts of the app come from the catalog. In a test process the main bundle is the test runner, so SwiftUI would
    /// show the catalog keys. This sends the lookups of the main bundle to the test bundle, which holds the catalog.
    private static var stringsInstalled = false

    private static func installAppStrings() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        guard !stringsInstalled else { return }
        stringsInstalled = true
        let selector = NSSelectorFromString("localizedAttributedStringForKey:value:table:localization:")
        guard let method = class_getInstanceMethod(Bundle.self, selector) else { return }
        typealias Lookup = @convention(c) (AnyObject, Selector, NSString, NSString?, NSString?, AnyObject?) -> AnyObject?
        let original = unsafeBitCast(method_getImplementation(method), to: Lookup.self)
        let target = Bundle(for: ProbeBundleMarker.self)
        let replacement: @convention(block) (AnyObject, NSString, NSString?, NSString?, AnyObject?) -> AnyObject? = { bundle, key, value, table, localization in
            original(bundle === Bundle.main ? target : bundle, selector, key, value, table, localization)
        }
        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }
}

/// Carries the measured width out of the layout pass.
private final class WidthBox: @unchecked Sendable {
    var width: CGFloat = 0
}

private struct WidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Anchor for the bundle of this test target, which holds the contract files and the catalog.
final class ProbeBundleMarker {}
