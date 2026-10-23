import AppKit
import DrawingKit
import SwiftUI

@MainActor
final class MenuAction: NSObject {
    let run: () -> Void

    init(_ run: @escaping () -> Void) { self.run = run }

    @objc func fire() { run() }
}

struct SecondaryClick: NSViewRepresentable {
    let handle: (CGPoint, NSView) -> Void

    func makeNSView(context: Context) -> Catcher { Catcher(handle) }

    func updateNSView(_ view: Catcher, context: Context) { view.handle = handle }

    final class Catcher: NSView {
        var handle: (CGPoint, NSView) -> Void

        init(_ handle: @escaping (CGPoint, NSView) -> Void) {
            self.handle = handle
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent, Self.secondary(event) else { return nil }
            return super.hitTest(point)
        }

        private static func secondary(_ event: NSEvent) -> Bool {
            event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        }

        override func rightMouseDown(with event: NSEvent) {
            handle(convert(event.locationInWindow, from: nil), self)
        }

        override func mouseDown(with event: NSEvent) {
            if Self.secondary(event) { handle(convert(event.locationInWindow, from: nil), self) }
        }
    }
}

@MainActor
enum CabinetMenu {
    static func item(_ title: String, on: Bool = false, _ run: @escaping () -> Void) -> NSMenuItem {
        let box = MenuAction(run)
        let entry = NSMenuItem(title: title, action: #selector(MenuAction.fire), keyEquivalent: "")
        entry.target = box
        entry.representedObject = box
        entry.state = on ? .on : .off
        return entry
    }

    static func group(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        entry.submenu = menu
        return entry
    }

    static func build(_ model: DrawsModel) -> NSMenu? {
        guard let spot = model.primary, let spec = model.kitchen, let pack = model.kitchenPack,
              let cab = try? spec.cabinet(spot) else { return nil }
        let now = spec.resolve(cab, pack: pack)
        let menu = NSMenu()
        menu.addItem(group(word("draws.menu.type"), CabinetKind.allCases.map { kind in
            item(word("draws.cabinet.\(kind.rawValue)"), on: cab.kind == kind) { model.retype(kind) }
        }))
        let splits: [NSMenuItem] = Split.presets.compactMap { preset in
            if case .appliance = preset {
                return group(word("draws.split.appliance"), Appliance.allCases.map { a in
                    item(pack.appliance[a.rawValue]?.name ?? a.rawValue) { model.split(.appliance(a)) }
                })
            }
            return item(word("draws.split.\(preset.name)")) { model.split(preset) }
        }
        menu.addItem(group(word("draws.menu.split"), splits))
        menu.addItem(item(word("draws.menu.flip")) { model.flip() })
        menu.addItem(.separator())
        menu.addItem(item(word("draws.menu.before")) { model.insert(.before) })
        menu.addItem(item(word("draws.menu.after")) { model.insert(.after) })
        menu.addItem(item(word("draws.menu.duplicate")) { model.duplicate() })
        menu.addItem(item(word("draws.menu.remove")) { model.remove() })
        menu.addItem(.separator())
        func codes(_ key: String, _ current: String, _ make: @escaping (String) -> Setting) -> NSMenuItem {
            group(word(key), model.codes.map { code in
                item(model.materialName(code), on: code == current) { model.apply(make(code)) }
            })
        }
        menu.addItem(group(word("draws.menu.material"), [
            codes("draws.edit.front", now.front, Setting.front), codes("draws.edit.carcass", now.carcass, Setting.carcass),
            codes("draws.edit.worktop", now.worktop, Setting.worktop), codes("draws.edit.plinthMaterial", now.plinthMaterial, Setting.plinthMaterial)
        ]))
        menu.addItem(group(word("draws.menu.features"), [
            group(word("draws.edit.grip"), GripStyle.allCases.map { v in
                item(word("draws.grip.\(v.rawValue)"), on: now.grip == v) { model.apply(.grip(v)) }
            }),
            group(word("draws.edit.style"), FrontStyle.allCases.map { v in
                item(word("draws.style.\(v.rawValue)"), on: now.style == v) { model.apply(.style(v)) }
            }),
            group(word("draws.edit.plinth"), PlinthStyle.allCases.map { v in
                item(word("draws.plinth.\(v.rawValue)"), on: now.plinth == v) { model.apply(.plinth(v)) }
            }),
            item(word("draws.edit.edge"), on: now.edge) { model.apply(.edge(!now.edge)) }
        ]))
        menu.addItem(.separator())
        menu.addItem(item(word("draws.menu.reset")) { model.reset() })
        return menu
    }
}
