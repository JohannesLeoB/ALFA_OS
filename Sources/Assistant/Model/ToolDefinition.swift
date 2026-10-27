struct ToolDefinition: Encodable, Equatable, Sendable {
    struct Property: Encodable, Equatable, Sendable {
        let type: String
        let description: String
    }

    struct InputSchema: Encodable, Equatable, Sendable {
        let type = "object"
        let properties: [String: Property]
        let required: [String]
    }

    let name: String
    let description: String
    let inputSchema: InputSchema
    var cacheControl: CacheControl?

    init(tool: any ToolPort, text: any TextPort) {
        var properties: [String: Property] = [:]
        var required: [String] = []
        for parameter in tool.parameters {
            properties[parameter.name] = Property(
                type: parameter.kind.rawValue,
                description: text.text(tool.parameterKey(parameter.name), []))
            if parameter.required { required.append(parameter.name) }
        }
        self.name = tool.name
        self.description = text.text(tool.descriptionKey, [])
        self.inputSchema = InputSchema(properties: properties, required: required)
    }

    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema = "input_schema", cacheControl = "cache_control"
    }
}

struct CacheControl: Encodable, Equatable, Sendable {
    let type = "ephemeral"

    init() {}
}
