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
    }
}
