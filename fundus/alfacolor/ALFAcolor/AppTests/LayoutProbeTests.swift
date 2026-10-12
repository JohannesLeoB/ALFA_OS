import AppKit
import SwiftUI
import Testing

/// The probe has to find broken layouts before its findings on real views mean anything.
/// Each broken sample is paired with a good one that must pass.
@MainActor
struct LayoutProbeTests {
    private static let label = "Background colour"

    @Test("a label in a column of 12 points wraps inside its word")
    func detectsLetterWrap() {
        let narrow = Text(Self.label).frame(width: 12)
        #expect(LayoutProbe.lines(of: narrow, width: 12) > 3)
        #expect(LayoutProbe.breaksInsideWord(Self.label, width: 12))
    }

    @Test("a label in a column that is wide enough stays on one line")
    func acceptsFittingLabel() {
        let wide = Text(Self.label)
        #expect(LayoutProbe.lines(of: wide, width: 200) == 1)
        #expect(!LayoutProbe.breaksInsideWord(Self.label, width: 200))
        // Cut with an ellipsis, the label is one line in a narrow column too.
        let cut = Text(Self.label).lineLimit(1).frame(width: 12)
        #expect(LayoutProbe.lines(of: cut, width: 12) == 1)
    }

    @Test("content wider than its column is found")
    func detectsOverwideContent() {
        let wide = Text(Self.label).fixedSize().frame(width: 400)
        #expect(LayoutProbe.exceeds(wide, width: 200))
        let fitting = Text(Self.label).frame(width: 150)
        #expect(!LayoutProbe.exceeds(fitting, width: 200))
    }

    @Test("a row of buttons whose labels wrap to many lines is found in a sidebar list")
    func detectsWrappedButtons() {
        let findings = LayoutProbe.inspect(Self.buttonRow(iconOnly: false), width: 200)
        #expect(findings.contains { $0.kind == .tooManyLines }, "findings: \(findings)")
        #expect(LayoutProbe.inspect(Self.buttonRow(iconOnly: true), width: 200).isEmpty)
    }

    @Test("a control that leaves its column is found")
    func detectsControlOutsideColumn() {
        let findings = LayoutProbe.inspect(Self.segmentedForm(items: ["Fit inside the frame", "Fill the whole frame", "Crop to the frame"]), width: 200)
        #expect(findings.contains { $0.kind == .outsideColumn }, "findings: \(findings)")
        #expect(LayoutProbe.inspect(Self.segmentedForm(items: ["Fit", "Fill"]), width: 200).isEmpty)
    }

    private static func buttonRow(iconOnly: Bool) -> some View {
        List {
            Section("Set") {
                HStack {
                    ForEach(["Pipette", "Check contrast", "Text styles", "Export", "Add colour field"], id: \.self) { title in
                        Button {} label: {
                            if iconOnly {
                                Label(title, systemImage: "circle").labelStyle(.iconOnly)
                            } else {
                                Label(title, systemImage: "circle")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private static func segmentedForm(items: [String]) -> some View {
        Form {
            Picker("Fit", selection: .constant(items[0])) {
                ForEach(items, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
    }
}
