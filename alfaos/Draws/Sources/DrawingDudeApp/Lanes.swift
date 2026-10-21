import DrawingKit
import ShellCore
import SwiftUI

struct PacksLane: View {
    @Environment(\.style) private var style
    let model: DrawsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Head { HeadTitle(key: "draws.lane.packs"); Spacer(minLength: 0) }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Caption(key: "draws.section.packs")
                    Row(label: say("draws.pack.ci"), detail: word(name(model.ci?.pack.placeholder)))
                    Row(label: say("draws.pack.template"),
                        detail: model.template.map { "\($0.pack.format) · \(word(name($0.pack.placeholder)))" })
                    Caption(key: "draws.section.object")
                    Row(label: Text(verbatim: model.objectName), detail: "\(model.parts.count)")
                    ForEach(model.parts, id: \.id) { p in
                        Row(label: Text(verbatim: p.name), detail: "\(Int(p.w)) × \(Int(p.d)) × \(Int(p.h))",
                            selected: model.accent == p.id) {
                            model.accent = model.accent == p.id ? nil : p.id
                        }
                    }
                    Pill(key: "draws.object.open") { model.open() }
                        .padding(.horizontal, CGFloat(Design.Spacing.step8))
                        .padding(.top, CGFloat(Design.Spacing.step8))
                    if !model.defects.isEmpty {
                        Caption(key: "draws.section.defects")
                        ForEach(model.defects, id: \.self) { d in
                            Row(label: Text(verbatim: d), detailTone: \.signal)
                        }
                    }
                }
                .padding(.horizontal, CGFloat(Design.Spacing.step8))
            }
        }
    }

    private func name(_ placeholder: Bool?) -> String {
        placeholder == true ? "draws.pack.placeholder" : "draws.pack.real"
    }
}

struct SheetLane: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel
    @State private var zoom = 1.0
    @State private var settled = 1.0
    @State private var pan = CGSize.zero
    @State private var panned = CGSize.zero

    var body: some View {
        VStack(spacing: 0) {
            Head {
                HeadTitle(key: "draws.lane.sheet")
                Spacer(minLength: 0)
                Segments(options: [(SheetLayout.threeView, "draws.layout.threeView"), (SheetLayout.iso, "draws.layout.iso")],
                         selection: $model.layout)
            }
            GeometryReader { proxy in
                ZStack {
                    style.color(\.well)
                    if let sheet = model.sheet {
                        canvas(sheet, room: proxy.size)
                    } else if let failure = model.failure {
                        Text(verbatim: failure)
                            .font(style.font(Design.TextSize.small))
                            .foregroundStyle(style.color(\.signal))
                    }
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(MagnifyGesture()
                    .onChanged { zoom = settled * Double($0.magnification) }
                    .onEnded { _ in settled = zoom })
                .simultaneousGesture(DragGesture()
                    .onChanged { pan = CGSize(width: panned.width + $0.translation.width, height: panned.height + $0.translation.height) }
                    .onEnded { _ in panned = pan })
                .onTapGesture(count: 2) { zoom = 1; settled = 1; pan = .zero; panned = .zero }
            }
        }
    }

    private func canvas(_ sheet: Sheet, room: CGSize) -> some View {
        let pad = Design.Spacing.step24
        let fit = min((Double(room.width) - 2 * pad) / sheet.width, (Double(room.height) - 2 * pad) / sheet.height)
        let k = max(0.01, fit * zoom)
        return Canvas { context, _ in
            context.withCGContext { cg in
                cg.scaleBy(x: k, y: k)
                SheetExporter.draw(sheet, in: cg)
            }
        }
        .frame(width: CGFloat(sheet.width * k), height: CGFloat(sheet.height * k))
        .shadowed(style, style.shadow(\.floating), Rectangle())
        .offset(pan)
    }
}

struct SwitchRow: View {
    @Environment(\.style) private var style
    let key: String
    @Binding var on: Bool

    var body: some View {
        HStack {
            say(key)
                .font(style.font(Design.TextSize.body))
                .foregroundStyle(style.color(\.ink))
                .frame(maxWidth: .infinity, alignment: .leading)
            Switch(on: $on)
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.rowHeight))
    }
}

struct ViewsLane: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Head { HeadTitle(key: "draws.lane.views"); Spacer(minLength: 0) }
            VStack(alignment: .leading, spacing: 0) {
                Caption(key: "draws.section.sheet")
                Row(label: say("draws.views.scale"), detail: model.sheet.map { "1:\(Int($0.scale))" } ?? "–")
                Row(label: say("draws.views.format"), detail: model.template?.pack.format)
                Row(label: say("draws.views.method"),
                    detail: model.template.map { word($0.pack.method == .first ? "draws.method.first" : "draws.method.third") })
                SwitchRow(key: "draws.views.dimensions", on: $model.dimensions)
                Caption(key: "draws.section.style")
                SwitchRow(key: "draws.style.outline", on: $model.outline)
                SwitchRow(key: "draws.style.shadow", on: $model.shadow)
                Row(label: say("draws.style.accent"),
                    detail: model.accent.flatMap { id in model.parts.first { $0.id == id }?.name } ?? "–")
                Caption(key: "draws.section.export")
                HStack(spacing: CGFloat(Design.Spacing.step8)) {
                    Pill(key: "draws.export.pdf", accent: true) { model.export(pdf: true) }
                    Pill(key: "draws.export.svg") { model.export(pdf: false) }
                }
                .padding(.horizontal, CGFloat(Design.Spacing.step8))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            Spacer(minLength: 0)
        }
    }
}
