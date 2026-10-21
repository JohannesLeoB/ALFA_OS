import Assist
import DrawingKit
import Foundation

enum DrawsTools {
    static let number: JSON = ["type": "number"]
    static let text: JSON = ["type": "string"]
    static let flag: JSON = ["type": "boolean"]

    static func list(_ item: JSON) -> JSON { ["type": "array", "items": item] }

    static func choice(_ values: [String]) -> JSON {
        ["type": "string", "enum": .array(values.map { JSON.string($0) })]
    }

    static func object(_ fields: [String: JSON], required: [String] = []) -> JSON {
        ["type": "object", "properties": .object(fields), "required": .array(required.map { JSON.string($0) })]
    }

    static let partFields: [String: JSON] = [
        "id": text, "name": text, "material": text, "role": text, "group": text,
        "given": list(choice(["x", "y", "z", "w", "d", "h"])),
        "x": number, "y": number, "z": number, "w": number, "d": number, "h": number
    ]

    static let motion: JSON = object([
        "type": choice(["slide", "hinge"]), "dx": number, "dy": number, "dz": number,
        "px": number, "py": number, "pz": number, "axis": choice(["x", "y", "z"]), "deg": number
    ], required: ["type"])

    static let cell: JSON = object([
        "id": text, "view": choice(ViewKind.allCases.map(\.rawValue)), "x": number, "y": number, "w": number, "h": number,
        "scale": number, "focus": text, "step": number, "dims": flag
    ], required: ["id", "view", "x", "y", "w", "h"])

    static func all(kinds: [String]) -> [Tool] {
        [
            Tool(name: "get_state",
                 description: "Read the whole model: parts, units, pose, readouts, camera, style, layout, cells, sheet and catalogue. Call it first and whenever you are unsure what is on the canvas.",
                 schema: object([:])),
            Tool(name: "add_parts",
                 description: "Add boxes in one batch, listed from the bottom up. Sizes in mm, x right, y into the depth, z up. The whole batch is refused when one part is invalid.",
                 schema: object(["parts": list(object(partFields, required: ["id", "material", "x", "y", "z", "w", "d", "h"]))], required: ["parts"])),
            Tool(name: "update_part",
                 description: "Change fields of one existing part by id. Only the fields you pass change.",
                 schema: object(partFields, required: ["id"])),
            Tool(name: "remove_part",
                 description: "Remove a part by id, or a unit by its id. Removing a part also takes it out of its unit; a unit left without a front is removed.",
                 schema: object(["id": text, "unit": text])),
            Tool(name: "add_unit",
                 description: "Add or replace a movable unit: drawer, pullout, door, flap or fixed. fronts are the front part ids, body the part ids that move with them. A drawer slides along -y by the inner depth, a door or flap hinges 90 to 110 degrees.",
                 schema: object(["id": text, "kind": choice(UnitKind.allCases.map(\.rawValue)), "fronts": list(text),
                                 "body": list(text), "motion": motion], required: ["id", "kind", "fronts", "motion"])),
            Tool(name: "set_pose",
                 description: "Open or close units. amounts maps a unit id to 0 (closed) up to 1 (fully open).",
                 schema: object(["amounts": ["type": "object", "additionalProperties": number]], required: ["amounts"])),
            Tool(name: "set_camera",
                 description: "Set azimuth and elevation in degrees. kind iso or perspective switches the iso views of the sheet; preset restores the standard iso angles.",
                 schema: object(["azimuth": number, "elevation": number, "kind": choice(["iso", "perspective", "preset"])])),
            Tool(name: "set_style",
                 description: "Set faces (three tones: top, side, front), fill tone or material, edge, outline and shadow weights, the accent part (empty id clears it) and its colour. Accent only the part that is active.",
                 schema: object(["faces": list(text), "fill": choice(["tone", "material"]), "edge": number, "outline": number,
                                 "shadow": number, "accent": text, "accent_color": text, "dimensions": flag])),
            Tool(name: "set_layout",
                 description: "Choose the sheet layout. cells is optional; without it the standard cells of the layout are used.",
                 schema: object(["kind": choice(kinds), "cells": list(cell)], required: ["kind"])),
            Tool(name: "render_preview",
                 description: "Render the current sheet as an image and list defects and overflow. Look at the image. Call it after your changes and before finish.",
                 schema: object(["page": number])),
            Tool(name: "check",
                 description: "Check order cycles, overlapping boxes, cells that overflow and materials without a tint. Fix every finding or record it as an assumption.",
                 schema: object([:])),
            Finish.tool
        ]
    }
}
