import AppTheme
import CodePlayer
import SwiftUI

/// The running page of the lab with its toolbar. The page is shown at the chosen width and zoom, with the guides over it.
struct LabStageView: View {
    let model: LabModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            toolbar
            GeometryReader { proxy in
                stage(in: proxy.size)
            }
        }
        .padding(theme.space(.s3))
    }

    private func stage(in size: CGSize) -> some View {
        let zoom = model.session.zoom
        let pageWidth = LabStage.pageWidth(width: model.session.draft.width, zoom: zoom, frameWidth: size.width)
        let scale = max(LabStage.scale(zoom: zoom, pageWidth: pageWidth, frameWidth: size.width), 0.01)
        return ZStack(alignment: .topLeading) {
            if let blocked = model.session.blocked {
                Text(LocalizedStringKey(blockedKey(blocked)))
                    .themeText(theme.text(.body))
                    .foregroundStyle(theme.color(.textMuted, scheme))
                    .padding(theme.space(.s4))
                    .frame(width: size.width, height: size.height, alignment: .center)
            } else if let live = model.live {
                CodeLiveView(card: live)
                    .frame(width: pageWidth, height: size.height / scale, alignment: .topLeading)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            if model.session.showsGrid {
                LabGridView(step: LabGuides.gridStep * scale)
            }
            if model.session.showsGuides {
                LabGuidesView(scale: scale)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .background(theme.color(.surface, scheme))
    }

    private func blockedKey(_ blocked: LabBlock) -> String {
        "lab.blocked." + blocked.rawValue
    }

    private var toolbar: some View {
        HStack(spacing: theme.space(.s2)) {
            Button(LocalizedStringKey("lab.restart")) { model.restart() }
            zoomPicker
            Toggle(LocalizedStringKey("lab.grid"), isOn: Binding(
                get: { model.session.showsGrid },
                set: { _ in model.toggleGrid() }
            ))
            Toggle(LocalizedStringKey("lab.guides"), isOn: Binding(
                get: { model.session.showsGuides },
                set: { _ in model.toggleGuides() }
            ))
            Toggle(LocalizedStringKey(model.session.isDark ? "lab.background.dark" : "lab.background.light"), isOn: Binding(
                get: { model.session.isDark },
                set: { _ in model.toggleDark() }
            ))
            Spacer()
        }
        .toggleStyle(.button)
        .controlSize(.small)
    }

    private var zoomPicker: some View {
        Picker(selection: Binding(get: { model.session.zoom }, set: { model.setZoom($0) })) {
            ForEach(LabZoom.allCases, id: \.self) { zoom in
                zoomTitle(zoom).tag(zoom)
            }
        } label: {
            Text(LocalizedStringKey("lab.zoom"))
        }
        .labelsHidden()
        .fixedSize()
    }

    private func zoomTitle(_ zoom: LabZoom) -> Text {
        switch zoom {
        case .fit: Text(LocalizedStringKey("lab.zoom.fit"))
        case .half: Text(verbatim: "50 %")
        case .actual: Text(verbatim: "100 %")
        case .double: Text(verbatim: "200 %")
        }
    }
}

/// Lines every `step` points over the page, in the coral token.
struct LabGridView: View {
    let step: Double

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let line = theme.color(.coral, scheme).opacity(0.4)
        Canvas { context, size in
            guard step >= 2 else { return }
            var path = Path()
            var x = 0.0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y = 0.0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(line), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Reference sizes over the page at its scale: a button, a touch target, a text line and a 100-point line.
struct LabGuidesView: View {
    let scale: Double

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: theme.space(.s3)) {
                guide(Text("lab.guide.button \(Int(LabGuides.button))")) {
                    RoundedRectangle(cornerRadius: theme.radius(.s))
                        .fill(theme.color(.accent, scheme))
                        .frame(width: LabGuides.line * scale, height: LabGuides.button * scale)
                }
                guide(Text("lab.guide.touch \(Int(LabGuides.touchTarget))")) {
                    Rectangle()
                        .strokeBorder(theme.color(.coral, scheme), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .frame(width: LabGuides.touchTarget * scale, height: LabGuides.touchTarget * scale)
                }
                guide(Text("lab.guide.text \(Int(LabGuides.text))")) {
                    Rectangle()
                        .fill(theme.color(.coral, scheme))
                        .frame(width: LabGuides.line * scale, height: LabGuides.text * scale)
                }
                guide(Text(LocalizedStringKey("lab.guide.line"))) {
                    Rectangle()
                        .fill(theme.color(.coral, scheme))
                        .frame(width: LabGuides.line * scale, height: 1)
                }
            }
        }
        .padding(theme.space(.s3))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }

    private func guide<Sample: View>(_ title: Text, @ViewBuilder _ sample: () -> Sample) -> some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            sample()
            title
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
        }
    }
}
