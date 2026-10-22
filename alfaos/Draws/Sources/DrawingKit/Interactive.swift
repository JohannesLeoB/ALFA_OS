import CoreGraphics
import Foundation
import Pages

public extension SheetExporter {
    static func interactive(job: Job) throws -> String {
        var closed = job
        closed.pose = [:]
        closed.hold = true
        let sheets = try DrawingEngine.render(closed)
        let at = sheets.firstIndex { !$0.hits.isEmpty } ?? 0
        guard sheets.indices.contains(at) else { throw DrawingError.empty }
        let base = sheets[at]
        let units = job.units.filter { unit in unit.front.contains { base.hits[$0] != nil } }
        var states: [String: Page] = [:], captions: [String: String] = [:], regions: [Region] = []
        for unit in units {
            var open = closed
            open.pose = [unit.id: 1]
            let all = try DrawingEngine.render(open)
            guard all.indices.contains(at) else { throw DrawingError.empty }
            let sheet = all[at]
            states[unit.id] = sheet.page
            captions[unit.id] = readout(unit, job)
            regions += unit.front.flatMap { base.hits[$0] ?? [] }.map { Region(state: unit.id, polygon: $0) }
            regions += unit.front.flatMap { sheet.hits[$0] ?? [] }.map { Region(state: unit.id, polygon: $0, current: true) }
        }
        let name = ["lastName", "project"].compactMap { job.project[$0] }.filter { !$0.isEmpty }.joined(separator: " · ")
        let page = Interactive(title: name.isEmpty ? base.product : name, language: job.template.language, base: base.page,
                               order: units.map(\.id), states: states, regions: regions, captions: captions,
                               idle: job.template.titles["readout.idle"] ?? "", fade: job.template.fade, fonts: base.faces)
        return page.html()
    }

    private static func readout(_ unit: Unit, _ job: Job) -> String {
        guard let r = Readout.make(job.parts, [unit], amounts: [unit.id: 1]).first else { return "" }
        let words = job.template.titles
        func say(_ key: String, _ values: [String: String], _ plain: String) -> String {
            guard let pattern = words[key], !pattern.isEmpty else { return plain }
            return values.keys.sorted().reduce(pattern) { $0.replacingOccurrences(of: "{\($1)}", with: values[$1] ?? "") }
        }
        func whole(_ v: Double) -> String { String(format: "%.0f", v) }
        let width = String(format: "%g", r.width)
        let name = unit.front.compactMap { id in job.parts.first { $0.id == id }?.name }.joined(separator: ", ")
        let travel = r.measure == .mm
            ? say("readout.travel", ["now": whole(r.now), "max": whole(r.max)], "\(whole(r.now)) / \(whole(r.max)) mm")
            : say("readout.angle", ["now": whole(r.now), "max": whole(r.max)], "\(whole(r.now))° / \(whole(r.max))°")
        return [name, say("readout.width", ["w": width], "\(width) mm"), say("readout.fronts", ["n": "\(r.fronts)"], "\(r.fronts)"), travel]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
