import AppKit
import DrawingKit
import DrawsAI
import DrawsRender
import Foundation
import ShellCore
import UniformTypeIdentifiers

extension DrawsModel {
    var windowTitle: String {
        let base = fileURL?.lastPathComponent ?? (objectName.isEmpty ? word("draws.lane.sheet") : objectName)
        return dirty ? base + " •" : base
    }

    var fileLabel: String? {
        fileURL.map { dirty ? $0.lastPathComponent + " •" : $0.lastPathComponent }
    }

    func doc() -> DrawsDoc? {
        guard !parts.isEmpty, template != nil else { return nil }
        let packs = DocPacks(ci: ciID, template: choice, style: styleID, material: materialID.isEmpty ? nil : materialID)
        let textures = look.textures.mapValues {
            DocTexture(image: $0.image, normal: $0.normal, tile: $0.tile, roughness: $0.roughness)
        }
        let inputs = attachments.map {
            DocInput(name: $0.name, role: $0.role.rawValue, mediaType: $0.mediaType, note: $0.note, data: $0.data)
        }
        let light = DocLight(preset: look.light.preset.rawValue, azimuth: look.light.azimuth, elevation: look.light.elevation)
        let render = DocRender(layout: layout.rawValue, page: page, azimuth: azimuth, elevation: elevation, tone: fill == .tone,
                               faces: faces, edge: edge, outline: outline, shadow: shadow, shadowOn: shadowOn, accent: accent,
                               accentColor: accentColor, dimensions: dimensions, reach: Proto.perspectiveDistance)
        return DrawsDoc(parts: parts, packs: packs, units: units, pose: pose, cells: cells.map(DocCell.init), textures: textures,
                        inputs: inputs, project: project, variants: variants, blocks: blocks, extra: extra,
                        hidden: hidden.sorted(), light: light, render: render,
                        underlay: underlay.map { DocUnderlay(name: $0, show: underlayShow, export: underlayExport) }, kitchen: kitchen)
    }

    func save() {
        guard let url = fileURL else { return saveAs() }
        write(to: url)
    }

    func saveAs() {
        guard doc() != nil else {
            failure = word("draws.doc.error.empty")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? fileName("svg")
        panel.directoryURL = fileURL?.deletingLastPathComponent() ?? dock.destination(.state, project: number)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    private func write(to url: URL) {
        guard let doc = doc(), let sheet else {
            failure = word("draws.doc.error.empty")
            return
        }
        do {
            try DocFile.write(doc, sheet: exported(sheet)).write(to: url, options: .atomic)
            fileURL = url
            objectName = url.deletingPathExtension().lastPathComponent
            dirty = false
            failure = nil
        } catch {
            failure = word("draws.doc.error.write")
        }
    }

    func drop(_ urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "svg" {
            guard let data = try? Data(contentsOf: url) else {
                failure = word("draws.doc.error.read")
                continue
            }
            do {
                if let doc = try DocFile.read(data) {
                    restore(doc, from: url)
                } else {
                    underlaid(data, named: url.lastPathComponent)
                }
            } catch DocError.newer {
                failure = word("draws.doc.error.newer")
            } catch {
                failure = word("draws.doc.error.read")
            }
        }
    }

    private func underlaid(_ svg: Data, named name: String) {
        guard let png = Self.raster(svg: svg, side: Proto.underlaySide) else {
            failure = word("draws.doc.error.read")
            return
        }
        attachments.removeAll { $0.name == name }
        attachments.append(Attachment(name: name, data: png, mediaType: "image/png", role: .template))
        underlay = name
        underlayShow = true
    }

    static func raster(svg: Data, side: Int) -> Data? {
        guard let image = NSImage(data: svg), image.size.width > 0, image.size.height > 0 else { return nil }
        let k = Double(side) / Double(max(image.size.width, image.size.height))
        let w = max(1, Int((Double(image.size.width) * k).rounded())), h = max(1, Int((Double(image.size.height) * k).rounded()))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                         bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let paper = DesignColors.light.sheet
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(srgbRed: CGFloat(paper.red), green: CGFloat(paper.green), blue: CGFloat(paper.blue), alpha: CGFloat(paper.alpha)).setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    func restore(_ doc: DrawsDoc, from url: URL) {
        let known = dock.templates.packs(.template).first { $0.name == doc.packs.template }
        let cis = dock.templates.packs(.ci), shelf = dock.templates.packs(.material)
        guard let known, let ciRef = cis.first(where: { $0.name == doc.packs.ci }) else {
            failure = word("draws.doc.error.pack")
            return
        }
        do {
            let loaded = try Packs.loadCI(ciRef.folder)
            let stock = try doc.packs.material.flatMap { id in shelf.first { $0.name == id } }.map { try Packs.loadMaterial($0.folder) }
            ready = false
            absorb([])
            choose(known)
            ci = loaded
            ciID = ciRef.name
            if let stock {
                material = stock
                materialID = doc.packs.material ?? ""
            }
            styleID = doc.packs.style ?? styleID
            absorb(doc.extra)
            kitchen = doc.kitchen
            forgetCabinets()
            parts = doc.parts
            replace(units: doc.units)
            pose = doc.pose
            project = doc.project
            variants = doc.variants
            blocks = doc.blocks
            hidden = Set(doc.hidden)
            layout = Kind(rawValue: doc.render.layout) ?? .plan
            cells = doc.cells.isEmpty ? preset() : doc.cells.map(\.cell)
            let r = doc.render
            azimuth = r.azimuth
            elevation = r.elevation
            fill = r.tone ? .tone : .material
            faces = r.faces.isEmpty ? Tone.faces : r.faces
            edge = r.edge ?? loaded.pack.iso.edge
            outline = r.outline ?? loaded.pack.iso.outline
            shadow = r.shadow ?? loaded.pack.iso.shadow * 100
            shadowOn = r.shadowOn
            accent = r.accent
            accentColor = r.accentColor
            dimensions = r.dimensions
            look = Look(textures: doc.textures.mapValues {
                Texture(image: $0.image, normal: $0.normal, tile: $0.tile, roughness: $0.roughness)
            }, light: LightSpec(preset: LightPreset(rawValue: doc.light.preset) ?? .studio, azimuth: doc.light.azimuth,
                                elevation: doc.light.elevation))
            attachments = doc.inputs.map {
                Attachment(name: $0.name, data: $0.data, mediaType: $0.mediaType,
                           role: Attachment.Role(rawValue: $0.role) ?? .reference, note: $0.note)
            }
            underlayShow = doc.underlay?.show ?? false
            underlayExport = doc.underlay?.export ?? false
            underlay = doc.underlay?.name
            selected = nil
            active = nil
            photo = nil
            page = r.page
            objectName = url.deletingPathExtension().lastPathComponent
            fileURL = url
            ready = true
            render()
            dirty = false
        } catch {
            failure = word("draws.doc.error.pack")
        }
    }
}
