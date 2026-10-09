import CodePlayer
import SwiftUI
import WebKit

/// Shows the running page of a code card. Placement on the canvas is added later.
struct CodeLiveView: View {
    let card: LiveCard

    var body: some View {
        WebView(card.page)
    }
}
