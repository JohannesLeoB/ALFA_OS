import AppKit
import ShellCore
import SwiftUI

@main
struct DrawsApp: App {
    @State private var model = DrawsModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ShellScreen(model: model)
                .frame(minWidth: CGFloat(Design.Size.laneMinimumLeft * 3), minHeight: CGFloat(Design.Size.blobMenuMinHeight * 3))
                .onAppear { NSApplication.shared.activate() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1512, height: 982)
        .commands {
            CommandGroup(after: .newItem) {
                Button(word("draws.doc.open")) { model.open() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button(word("draws.doc.save")) { model.save() }
                    .keyboardShortcut("s")
                Button(word("draws.doc.saveAs")) { model.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
