import Assist
import CoreGraphics
import DrawingKit
import Foundation
import Pages

struct Refusal: Error {
    var message: String

    init(_ message: String) { self.message = message }
}

extension JSON {
    static func strings(_ items: [String]) -> JSON { .array(items.map { JSON.string($0) }) }

    static func num(_ value: Double) -> JSON { .number(value) }
}

public actor DrawsToolbox: Toolbox {
    public nonisolated let tools: [Tool]
    public private(set) var draft: Draft
    private let bench: Bench
    private let apply: @MainActor @Sendable (Draft) -> Void
    private var previewed = false

    public init(draft: Draft, bench: Bench, apply: @escaping @MainActor @Sendable (Draft) -> Void) {
        self.draft = draft
        self.bench = bench
        self.apply = apply
        tools = DrawsTools.all(kinds: bench.kinds)
    }

    public func call(_ name: String, _ input: JSON) async -> ToolResult {
        do {
            switch name {
            case "get_state": return .json(state())
            case "add_parts": return try await change { try $0.addParts(input) }
            case "update_part": return try await change { try $0.updatePart(input) }
            case "remove_part": return try await change { try $0.removePart(input) }
            case "add_unit": return try await change { try $0.addUnit(input) }
            case "set_pose": return try await change { try $0.setPose(input) }
            case "set_camera": return try await change { [bench] in try $0.setCamera(input, bench) }
            case "set_style": return try await change { [bench] in try $0.setStyle(input, bench) }
            case "set_layout": return try await change { [bench] in try $0.setLayout(input, bench) }
            case "render_preview": return try preview(input)
            case "check": return .json(try diagnose())
            case "finish": return try finish(input)
            default: return .error("unknown tool \(name)")
            }
        } catch {
            return .error(Words.message(error))
        }
    }

    private func change(_ edit: (inout Draft) throws -> String) async throws -> ToolResult {
        var next = draft
        let note = try edit(&next)
        if !next.parts.isEmpty { try Validate.parts(next.parts) }
        try Validate.units(next.units, parts: next.parts)
        try Validate.pose(next.pose, units: next.units)
        draft = next
        previewed = false
        await apply(next)
        return .text(note)
    }

    private func finish(_ input: JSON) throws -> ToolResult {
        guard !draft.parts.isEmpty else { throw Refusal("nothing is built yet") }
        guard previewed else { throw Refusal("call render_preview after the last change, then finish") }
        guard let done = Finish(input: input) else { throw Refusal("summary is required") }
        return ToolResult(content: [.text("done")], finish: done)
    }

    private func sheets() throws -> [Sheet] {
        guard !draft.parts.isEmpty else { throw Refusal("nothing is built yet") }
        return try DrawingEngine.render(draft.job(bench))
    }

    private func preview(_ input: JSON) throws -> ToolResult {
        let pages: [Sheet]
        do {
            pages = try sheets()
        } catch DrawingError.overflow {
            return .error("overflow: the views do not fit the sheet; change scale, cells or layout")
        }
        let index = min(max(0, Int(input["page"]?.number ?? 1) - 1), pages.count - 1)
        let sheet = pages[index]
        guard let png = BitmapRenderer(paper: sheet.paper, dpi: min(100, bench.dpi)).render(sheet.document).first else {
            throw Refusal("render failed")
        }
        previewed = true
        let report: JSON = [
            "page": .num(Double(index + 1)), "pages": .num(Double(pages.count)), "scale": .num(sheet.scale),
            "defects": .strings(sheet.defects.filter { !$0.hasPrefix("board.") }), "overflow": false,
            "misfits": .strings(sheet.cells.filter { !$0.fits }.map(\.id)), "readouts": readouts()
        ]
        return ToolResult(content: [.png(png), .json(report)])
    }

    private func diagnose() throws -> JSON {
        let spec = ViewSpec(kind: .iso, azimuth: draft.azimuth, elevation: draft.elevation)
        let cycles = Diagnose.cycles(draft.parts, spec: spec)
        let overlaps = Diagnose.overlaps(draft.parts)
        let tints = Set(draft.parts.map(\.material)).filter { (bench.ci.tints[$0] ?? "").isEmpty }.sorted()
        var misfits: [String] = []
        var defects: [String] = []
        var overflow = false
        do {
            for sheet in try sheets() {
                misfits += sheet.cells.filter { !$0.fits }.map(\.id)
                defects += sheet.defects.filter { !$0.hasPrefix("board.") && !defects.contains($0) }
            }
        } catch DrawingError.overflow {
            overflow = true
        }
        let ok = cycles.isEmpty && overlaps.isEmpty && tints.isEmpty && misfits.isEmpty && defects.isEmpty && !overflow
        return [
            "ok": .bool(ok),
            "orderCycles": .array(cycles.map { JSON.strings($0) }),
            "overlaps": .array(overlaps.map { JSON.strings($0) }),
            "overflowCells": .strings(misfits), "overflow": .bool(overflow),
            "missingTints": .strings(tints), "defects": .strings(defects)
        ]
    }

    private func readouts() -> JSON {
        .array(Readout.make(draft.parts, draft.units, amounts: draft.pose).map { item in
            let fields: [String: JSON] = [
                "unit": .string(item.unit), "kind": .string(item.kind.rawValue), "width": .num(item.width),
                "fronts": .num(Double(item.fronts)), "measure": .string(item.measure.rawValue),
                "now": .num(item.now), "max": .num(item.max), "step": .num(Double(item.step)), "total": .num(Double(item.total))
            ]
            return .object(fields)
        })
    }

    private func state() -> JSON {
        let d = draft
        let style: JSON = [
            "faces": .strings(d.faces), "fill": .string(d.tone ? "tone" : "material"), "edge": .num(d.edge),
            "outline": .num(d.outline), "shadow": .num(d.shadow), "accent": d.accent.map(JSON.string) ?? .null,
            "accent_color": d.accentColor.map(JSON.string) ?? .null, "dimensions": .bool(d.dimensions)
        ]
        let sheet: JSON = [
            "format": .string(bench.template.format), "width": .num(bench.template.width), "height": .num(bench.template.height),
            "left": .num(bench.template.frame.left), "top": .num(bench.template.frame.top),
            "right": .num(bench.template.frame.right), "bottom": .num(bench.template.frame.bottom)
        ]
        let units = d.units.compactMap { try? JSON(encoding: $0) }
        return [
            "parts": .array(d.parts.compactMap { try? JSON(encoding: $0) }), "units": .array(units),
            "pose": .object(d.pose.mapValues { JSON.num($0) }), "readouts": readouts(),
            "camera": ["azimuth": .num(d.azimuth), "elevation": .num(d.elevation)], "style": style,
            "layout": .string(d.layout), "cells": .array(d.cells.map(Words.cell)), "kinds": .strings(bench.kinds), "sheet": sheet,
            "tints": .strings(bench.ci.tints.filter { !$0.value.isEmpty }.keys.sorted()),
            "materials": .strings(bench.material?.materials.map(\.code) ?? [])
        ]
    }
}
