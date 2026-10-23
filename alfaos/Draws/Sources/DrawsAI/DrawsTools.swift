import Assist
import DrawingKit
import DrawsRender
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

    static let shape: JSON = object([
        "kind": choice(["wedge", "taper"]), "slope": choice(["x", "y"]), "start": number, "end": number,
        "bottomW": number, "bottomD": number, "topW": number, "topD": number
    ], required: ["kind"])

    static let partFields: [String: JSON] = [
        "id": text, "name": text, "material": text, "role": text, "group": text, "shape": shape,
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

    static let kitchenFront: JSON = object([
        "type": choice(FrontType.allCases.map(\.rawValue)), "side": choice(["left", "right", "pair"]), "drawers": list(text), "count": number,
        "appliance": choice(["oven", "dishwasher", "fridge", "hob", "sink"]), "height": number, "material": text
    ], required: ["type"])

    static let kitchenFeatures: JSON = object([
        "grip": choice(GripStyle.allCases.map(\.rawValue)), "style": choice(FrontStyle.allCases.map(\.rawValue)),
        "plinth": choice(PlinthStyle.allCases.map(\.rawValue)), "edge": flag
    ])

    static let kitchenMaterials: JSON = object(["front": text, "carcass": text, "worktop": text, "plinth": text])

    static let kitchenCabinet: JSON = object([
        "kind": choice(CabinetKind.allCases.map(\.rawValue)), "width": number, "height": number, "depth": number,
        "fronts": list(kitchenFront), "material": text, "frontMaterial": text,
        "features": kitchenFeatures, "materials": kitchenMaterials
    ], required: ["kind"])

    static let kitchenRun: JSON = object([
        "origin": object(["x": number, "y": number], required: ["x", "y"]), "turn": choice(["0", "90", "180", "270"]),
        "items": list(kitchenCabinet)
    ], required: ["items"])

    static func all(kinds: [String], images: [String] = []) -> [Tool] {
        [
            Tool(name: "get_state",
                 description: "Read the whole model: parts, units, pose, readouts, camera, style, layout, cells, sheet and catalogue. Call it first and whenever you are unsure what is on the canvas.",
                 schema: object([:])),
            Tool(name: "add_parts",
                 description: "Add parts in one batch, listed from the bottom up. Sizes in mm, x right, y into the depth, z up. A part is a box unless it has a shape. shape wedge: the top slopes along slope x or y, start and end are the heights at the low and the high side of that axis, the larger one equals h. shape taper: bottomW, bottomD, topW, topD are the footprints at the bottom and the top, centred on the box; the larger of bottom and top equals w and d. The whole batch is refused when one part is invalid.",
                 schema: object(["parts": list(object(partFields, required: ["id", "material", "x", "y", "z", "w", "d", "h"]))], required: ["parts"])),
            Tool(name: "add_kitchen",
                 description: "Build a kitchen from cabinets instead of boxes. runs are rows of cabinets placed left to right seen from the front; origin is the front left floor point in mm and turn 0, 90, 180 or 270 degrees; a run without origin continues after the corner cabinet that ends the previous run. Any positive width, height and depth is valid; omitted sizes take the standard. fronts list from top to bottom: door (side left, right or pair names the hinge side), drawers (drawers such as low, mid, high, or count), appliance (oven, dishwasher, fridge, hob, sink; hob and sink are inlays in the worktop), open, glass. A top cabinet sits on the cabinet before it. wall, worktop and plinth switch those parts off. Parts and units of an earlier kitchen with the same prefix are replaced. Returns counts, run lengths and the materials used.",
                 schema: object(["runs": list(kitchenRun), "island": kitchenRun, "worktop": flag, "plinth": flag, "wall": flag, "prefix": text,
                                 "features": kitchenFeatures, "materials": kitchenMaterials],
                                required: ["runs"])),
            Tool(name: "edit_cabinet",
                 description: "Edit one or more cabinets of the kitchen by id (r0c3 is run 0, cabinet 3; with a kitchen prefix the id starts with it). Sizes are free, never rounded. op: resize (axis, delta in mm), set (width, height, depth), insert (kind, side before or after), duplicate, remove, move (step left or right within the run; a top cabinet travels with its host), flip (hinge side of single doors), split (door, pair, drawers2, drawers3, drawers4, drawerdoor, oven, dishwasher, fridge, hob, sink, open, glass), type (kind), override (field and value on the cabinets; shared true sets it for the whole kitchen instead), reset (cabinets back to the shared values, optionally one field). Grip handle, channel or push; style flat, frame or glass; plinth panel or legs; edge true or false; front, carcass, worktop and plinthMaterial take a material code. The same operations the user has in the editor; the kitchen is rebuilt after each call.",
                 schema: object(["op": choice(["resize", "set", "insert", "duplicate", "remove", "move", "flip", "split", "type", "override", "reset"]),
                                 "id": text, "ids": list(text), "axis": choice(Extent.allCases.map(\.rawValue)), "delta": number,
                                 "width": number, "height": number, "depth": number, "kind": choice(CabinetKind.allCases.map(\.rawValue)),
                                 "side": choice(["before", "after"]), "step": choice(["left", "right"]), "split": text,
                                 "field": choice(Field.allCases.map(\.rawValue)), "value": text, "shared": flag],
                                required: ["op"])),
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
                 description: "Render the current sheet as an image and list defects and overflow. Look at the image. Call it after your changes and before finish. With mode photo it renders the object as a small photoreal picture with the textures and the light, and returns the image; look at it and correct textures, tile sizes, roughness and light until it looks like the real object.",
                 schema: object(["page": number, "mode": choice(["sheet", "photo"]),
                                 "view": choice(ViewKind.allCases.map(\.rawValue))])),
            Tool(name: "set_texture",
                 description: "Link a material code to a dropped texture image for the photoreal render. Images with the role material are the textures. Look at each image, decide which material it shows and link it. tile_mm is the real size in mm of one repeat of the image, so a wood grain keeps its real size on every part. roughness runs from 0 (mirror) to 1 (matte). normal is an optional second image used as normal map. An empty image removes the link.",
                 schema: object(["material": text, "image": images.isEmpty ? text : choice(images), "normal": text,
                                 "tile_mm": number, "roughness": number], required: ["material", "image"])),
            Tool(name: "set_light",
                 description: "Set the light of the photoreal render: a preset (studio, soft, warm, hard) and optionally the azimuth and elevation of the key light in degrees. Without angles the key light follows the camera.",
                 schema: object(["preset": choice(LightPreset.allCases.map(\.rawValue)), "azimuth": number, "elevation": number])),
            Tool(name: "check",
                 description: "Check order cycles, overlapping boxes, cells that overflow and materials without a tint. Fix every finding or record it as an assumption.",
                 schema: object([:])),
            Finish.tool
        ]
    }
}
