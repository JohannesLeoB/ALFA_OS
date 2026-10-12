import CodePlayer
import SwiftUI

/// The switch in the header of a code card: player, source or both.
struct CodeViewPicker: View {
    let model: CodeCardModel

    var body: some View {
        Picker(selection: Binding(get: { model.state.view }, set: { model.show($0) })) {
            Label(LocalizedStringKey("code.view.player"), systemImage: "play.rectangle")
                .labelStyle(.iconOnly)
                .tag(CodeView.player)
            Label(LocalizedStringKey("code.view.source"), systemImage: "chevron.left.forwardslash.chevron.right")
                .labelStyle(.iconOnly)
                .tag(CodeView.source)
            Label(LocalizedStringKey("code.view.both"), systemImage: "rectangle.split.2x1")
                .labelStyle(.iconOnly)
                .tag(CodeView.both)
        } label: {
            Text(LocalizedStringKey("code.view"))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
    }
}
