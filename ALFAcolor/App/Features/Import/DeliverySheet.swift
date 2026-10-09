import AppKit
import BoardModel
import Importers

/// The review sheet (title in the catalog key delivery.title): the kind, the changes and the warnings of a delivery, with Apply and Cancel.
/// The content comes from `DeliveryReview`; this file only shows it.
@MainActor
enum DeliverySheet {
    static func present(_ delivery: Delivery, store: BoardStore, in window: NSWindow?) {
        let review = DeliveryReview(delivery, tokenSets: store.document.tokenSets)
        let alert = NSAlert()
        alert.messageText = String(localized: "delivery.title")
        alert.informativeText = kindText(delivery)
        alert.addButton(withTitle: String(localized: "delivery.apply"))
        alert.addButton(withTitle: String(localized: "delivery.cancel"))
        alert.accessoryView = detailView(lines(for: delivery, review: review))

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            do {
                try DeliveryApply.apply(delivery, to: store)
            } catch {
                report(error)
            }
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(alert.runModal())
        }
    }

    static func report(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "delivery.failed.title")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private static func kindText(_ delivery: Delivery) -> String {
        switch delivery {
        case .contract: String(localized: "delivery.kind.contract")
        case .mockup: String(localized: "delivery.kind.mockup")
        }
    }

    /// The lines of the review: changes first, then counts, then warnings.
    static func lines(for delivery: Delivery, review: DeliveryReview) -> [String] {
        var lines: [String] = []
        switch delivery {
        case .contract:
            lines.append(String(localized: "delivery.changes"))
            lines += changeLines(review.changes)
            if !review.darkChanges.isEmpty {
                lines.append(String(localized: "delivery.dark"))
                lines += changeLines(review.darkChanges)
            }
        case .mockup:
            lines.append(String(format: String(localized: "delivery.counts"), review.frames, review.pieces))
        }
        if !review.warnings.isEmpty {
            lines.append(String(localized: "delivery.warnings"))
            lines += review.warnings.map { "· " + $0 }
        }
        return lines
    }

    private static func changeLines(_ changes: [TokenChange]) -> [String] {
        if changes.isEmpty { return ["· " + String(localized: "delivery.none")] }
        return changes.map { change in
            let label: String
            switch change.kind {
            case .added: label = String(localized: "delivery.change.added")
            case .changed: label = String(localized: "delivery.change.changed")
            case .removed: label = String(localized: "delivery.change.removed")
            }
            return "· \(label): \(change.id)"
        }
    }

    /// A read-only, scrollable text of the lines, shown below the sheet's text.
    private static func detailView(_ lines: [String]) -> NSView {
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 460, height: 240))
        text.isEditable = false
        text.isSelectable = true
        text.string = lines.joined(separator: "\n")
        text.textContainerInset = NSSize(width: 0, height: 0)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 240))
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        return scroll
    }
}
