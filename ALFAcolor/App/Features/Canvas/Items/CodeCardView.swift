import AppTheme
import BoardModel
import Renderers
import SwiftUI

/// A code card on the canvas: the card frame with the switch in its header, and a body that shows the player,
/// the source or both.
struct CodeCardView: View {
    let presentation: ItemPresentation
    let content: CodeContent
    let detail: DetailLevel
    let zoom: Double

    @State private var model: CodeCardModel

    @Environment(\.theme) private var theme
    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas

    init(presentation: ItemPresentation, content: CodeContent, detail: DetailLevel, zoom: Double) {
        self.presentation = presentation
        self.content = content
        self.detail = detail
        self.zoom = zoom
        _model = State(initialValue: CodeCardModel(content: content))
    }

    var body: some View {
        CardFrame(presentation: presentation, detail: detail, zoom: zoom, accessory: headerControls) { _ in
            CodeCardBody(model: model, detail: detail, zoom: zoom)
        }
        .onChange(of: content) { _, new in
            model.update(new)
        }
    }

    /// The header controls: the switch between player and source for a card that can run, then the button for the lab.
    private var headerControls: AnyView {
        AnyView(HStack(spacing: theme.space(.s2)) {
            if model.state.canPlay {
                CodeViewPicker(model: model)
            }
            Button(action: openLab) {
                Label(LocalizedStringKey("code.lab"), systemImage: "flask")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help(LocalizedStringKey("code.lab"))
            .disabled(shell == nil || canvas == nil)
        })
    }

    /// Opens the lab of this card in the window that shows it.
    private func openLab() {
        guard let shell, let store = canvas?.store else { return }
        shell.openLab(for: presentation.id, store: store)
    }
}

/// The body of a code card: the player, the source, or both side by side.
struct CodeCardBody: View {
    let model: CodeCardModel
    let detail: DetailLevel
    let zoom: Double

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if detail == .full {
            let state = model.state
            if state.showsPlayer && state.showsSource {
                HStack(spacing: 0) {
                    CodePlayer(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Rectangle()
                        .fill(theme.color(.border, scheme))
                        .frame(width: Hairline.width(zoom: zoom, scale: displayScale))
                    CodeSourceView(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if state.showsPlayer {
                CodePlayer(model: model)
            } else {
                CodeSourceView(model: model)
            }
        }
    }
}

/// The page of a card. It rests as a still image with a play button. The button starts the live page,
/// and a stop button brings the still image back.
struct CodePlayer: View {
    let model: CodeCardModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            page(in: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
                .overlay(alignment: model.live == nil ? .center : .bottomTrailing) {
                    control
                }
        }
        .task(id: model.stillRequest) {
            await model.refreshStill()
        }
    }

    /// The live page or the still image, scaled to the width of the frame.
    @ViewBuilder
    private func page(in size: CGSize) -> some View {
        let scale = CodeCardLayout.scale(frameWidth: size.width, pageWidth: model.pageWidth)
        if let live = model.live {
            CodeLiveView(card: live)
                .frame(width: model.pageWidth, height: scale > 0 ? size.height / scale : size.height, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        } else if let still = model.still {
            Image(decorative: still, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, alignment: .topLeading)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        } else {
            Rectangle().fill(theme.color(.surface, scheme))
        }
    }

    @ViewBuilder
    private var control: some View {
        if model.live == nil {
            Button {
                Task { await model.play() }
            } label: {
                icon("play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(LocalizedStringKey("code.play"))
        } else {
            Button {
                model.rest()
            } label: {
                icon("stop.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(LocalizedStringKey("code.stop"))
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(theme.text(.heading).font)
            .foregroundStyle(theme.color(.text, scheme))
            .padding(theme.space(.s2))
            .background(theme.color(.surface, scheme))
    }
}
