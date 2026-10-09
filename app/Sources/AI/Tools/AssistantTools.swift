import Foundation

/// What a tool call gives back. A read tool answers at once. A change becomes one proposal; nothing is applied here.
public enum ToolOutcome: Sendable, Equatable {
    /// The answer that the model gets at once. An error answer tells the model why the input was refused.
    case answer(String, isError: Bool)
    /// A change that waits for the decision of the user.
    case proposal(ProposedChange)
}

/// The tools of the assistant: their schemas, and the check of each call. A valid call gives exactly one outcome.
public enum AssistantTools {
    /// The client tools that a request offers, in a fixed order.
    public static let definitions: [AITool] = [
        tool("add_note", "Attach a note to one item of the document.", [
            ("item", text("Item id from the document list.")),
            ("text", text("The note text.")),
        ], required: ["item", "text"]),
        tool("add_tags", "Add tags to one item of the document.", [
            ("item", text("Item id from the document list.")),
            ("tags", list(text("A tag."), max: ToolLimits.tagCount, description: "Tags to add.")),
        ], required: ["item", "tags"]),
        tool("create_code_card", "Propose a new code card with its files.", [
            ("title", text("Title of the card.")),
            ("language", text("Language, for example css or html.")),
            ("files", files()),
        ], required: ["title", "language", "files"]),
        tool("propose_code_change", "Propose a new version of an existing code card. The original stays.", [
            ("item", text("Item id of the code card.")),
            ("language", text("Language of the card.")),
            ("files", files()),
        ], required: ["item", "language", "files"]),
        tool("add_swatches", "Propose new colour fields.", [
            ("swatches", list(swatch(), max: ToolLimits.swatchCount, description: "Colour fields to add.")),
        ], required: ["swatches"]),
        tool("suggest_token_names", "Propose a name for each unnamed colour token.", [
            ("names", list(tokenName(), max: ToolLimits.tokenCount, description: "Token id and name.")),
        ], required: ["names"]),
        tool("place_note_card", "Propose a note card on the canvas.", [
            ("text", text("The text of the card.")),
        ], required: ["text"]),
        tool("delete_items", "Propose removing items. Scope room is the room of the items; collection is every room.", [
            ("items", idList()),
            ("scope", choice(["room", "collection"], description: "room (default) or collection.")),
        ], required: ["items"]),
        tool("move_items", "Propose moving items by a distance in points.", [
            ("items", idList()),
            ("dx", number("Distance to the right in points.")),
            ("dy", number("Distance down in points.")),
        ], required: ["items", "dx", "dy"]),
        tool("add_link_items", "Propose a link item with its address and title.", [
            ("url", text("Web address that starts with http:// or https://.")),
            ("title", text("Title of the link.")),
        ], required: ["url", "title"]),
        tool("download", "Propose downloading a file from a secure web address.", [
            ("url", text("Address that starts with https://.")),
            ("target", choice(["document", "folder"], description: "document or folder.")),
        ], required: ["url", "target"]),
        tool("design_read", "Read a text of the design system (canon or contract). Answers at once.", [
            ("name", text("Name of the text, from the list the app gives.")),
        ], required: ["name"]),
        tool("design_propose_tokens", "Propose new values for tokens of the design contract.", [
            ("tokens", list(designToken(), max: ToolLimits.tokenCount, description: "Token names and colours.")),
        ], required: ["tokens"]),
        tool("tip", "Give a short tip. A chat tip shows in the chat, a lab tip in the lab, a note tip is a note on an item.", [
            ("kind", choice(["chat", "lab", "note"], description: "chat, lab or note.")),
            ("text", text("The tip text.")),
            ("item", text("Item id; needed for a note tip.")),
        ], required: ["kind", "text"]),
    ]

    /// Checks one call and gives its outcome. Unknown tools and broken inputs give an error answer, never a change.
    public static func handle(_ call: AIToolCall, document: DocumentSnapshot, design: any DesignSource) -> ToolOutcome {
        do {
            let input = try ToolInput(call.input, document: document)
            return try outcome(for: call.name, input, design: design)
        } catch let failure as ToolFailure {
            return .answer(failure.message, isError: true)
        } catch {
            return .answer("the tool call could not be read", isError: true)
        }
    }

    // MARK: dispatch

    private static func outcome(for name: String, _ input: ToolInput, design: any DesignSource) throws -> ToolOutcome {
        switch name {
        case "add_note":
            return .proposal(.note(
                item: try input.item("item"),
                text: try input.text("text", limit: ToolLimits.noteText)
            ))
        case "add_tags":
            return .proposal(.tags(item: try input.item("item"), tags: try input.tags("tags")))
        case "create_code_card":
            return .proposal(.codeCard(
                title: try input.text("title", limit: ToolLimits.titleLength),
                language: try input.text("language", limit: ToolLimits.languageLength),
                files: try input.files("files")
            ))
        case "propose_code_change":
            return .proposal(.codeVersion(
                item: try input.item("item"),
                language: try input.text("language", limit: ToolLimits.languageLength),
                files: try input.files("files")
            ))
        case "add_swatches":
            let swatches = try input.objects("swatches", max: ToolLimits.swatchCount).map { object in
                Swatch(
                    name: try input.optionalName(object, in: "swatches"),
                    hex: try input.hexValue(object, "hex", in: "swatches")
                )
            }
            return .proposal(.swatches(swatches))
        case "suggest_token_names":
            let names = try input.objects("names", max: ToolLimits.tokenCount).map { object in
                TokenName(
                    id: try input.tokenValue(object, "id", in: "names"),
                    name: try input.tokenNameValue(object, "name", in: "names")
                )
            }
            return .proposal(.tokenNames(names))
        case "place_note_card":
            return .proposal(.noteCard(text: try input.text("text", limit: ToolLimits.noteText)))
        case "delete_items":
            let scope = try input.choice("scope", from: ["room", "collection"], default: "room")
            return .proposal(.delete(items: try input.items("items"), scope: ChangeScope(rawValue: scope) ?? .room))
        case "move_items":
            return .proposal(.move(
                items: try input.items("items"),
                dx: try input.distance("dx"),
                dy: try input.distance("dy")
            ))
        case "add_link_items":
            return .proposal(.link(
                url: try input.url("url", schemes: ["http", "https"]),
                title: try input.text("title", limit: ToolLimits.titleLength)
            ))
        case "download":
            let target = try input.choice("target", from: ["document", "folder"], default: nil)
            return .proposal(.download(
                url: try input.url("url", schemes: ["https"]),
                target: DownloadTarget(rawValue: target) ?? .document
            ))
        case "design_read":
            return try readDesign(try input.text("name", limit: 80), design: design)
        case "design_propose_tokens":
            let tokens = try input.objects("tokens", max: ToolLimits.tokenCount).map { object in
                DesignTokenValue(
                    name: try input.tokenNameValue(object, "name", in: "tokens"),
                    hex: try input.hexValue(object, "value", in: "tokens")
                )
            }
            return .proposal(.designTokens(tokens))
        case "tip":
            let kind = try input.choice("kind", from: ["chat", "lab", "note"], default: nil)
            let tipKind = TipKind(rawValue: kind) ?? .chat
            let item = tipKind == .note ? try input.item("item") : nil
            return .proposal(.tip(
                kind: tipKind,
                text: try input.text("text", limit: ToolLimits.tipText),
                item: item
            ))
        default:
            throw ToolFailure("unknown tool: \(name)")
        }
    }

    private static func readDesign(_ name: String, design: any DesignSource) throws -> ToolOutcome {
        guard design.names.contains(name), let text = design.text(of: name) else {
            throw ToolFailure("unknown design text: \(name)")
        }
        guard text.utf8.count <= ToolLimits.designTextBytes else {
            throw ToolFailure("design text \(name) is larger than \(ToolLimits.designTextBytes) bytes")
        }
        return .answer(text, isError: false)
    }

    // MARK: schemas

    private static func tool(
        _ name: String,
        _ description: String,
        _ properties: [(String, JSONValue)],
        required: [String]
    ) -> AITool {
        let schema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object(Dictionary(uniqueKeysWithValues: properties)),
            "required": .array(required.map { .string($0) }),
            "additionalProperties": .bool(false),
        ])
        return .client(name: name, description: description, inputSchema: schema)
    }

    private static func text(_ description: String) -> JSONValue {
        .object(["type": .string("string"), "description": .string(description)])
    }

    private static func number(_ description: String) -> JSONValue {
        .object(["type": .string("number"), "description": .string(description)])
    }

    private static func choice(_ values: [String], description: String) -> JSONValue {
        .object([
            "type": .string("string"),
            "enum": .array(values.map { .string($0) }),
            "description": .string(description),
        ])
    }

    private static func list(_ items: JSONValue, max: Int, description: String) -> JSONValue {
        .object([
            "type": .string("array"),
            "items": items,
            "minItems": .number(1),
            "maxItems": .number(Double(max)),
            "description": .string(description),
        ])
    }

    private static func idList() -> JSONValue {
        list(text("Item id."), max: ToolLimits.itemCount, description: "Item ids from the document list.")
    }

    private static func files() -> JSONValue {
        .object([
            "type": .string("object"),
            "description": .string("File names as keys, file texts as values."),
            "additionalProperties": text("File text."),
        ])
    }

    private static func swatch() -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "name": text("Name of the field, optional."),
                "hex": text("Colour as #RRGGBB."),
            ]),
            "required": .array([.string("hex")]),
        ])
    }

    private static func tokenName() -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "id": text("Token id from the design set."),
                "name": text("Lower case name with hyphens."),
            ]),
            "required": .array([.string("id"), .string("name")]),
        ])
    }

    private static func designToken() -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "name": text("Lower case token name with hyphens."),
                "value": text("Colour as #RRGGBB."),
            ]),
            "required": .array([.string("name"), .string("value")]),
        ])
    }
}
