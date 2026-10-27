struct ListSamplesTool: ToolPort {
    private let samples: any SamplePort

    init(samples: any SamplePort) {
        self.samples = samples
    }

    var name: String { "list_bemusterung" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .studioKnowledge }
    var documented: Bool { false }
    var parameters: [ToolParameter] { [ToolParameter("projekt", required: true)] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let number = input.text("projekt")
        guard number.isEmpty == false else { return .failure("assistant.samples.noProject") }
        do {
            let listing = try await samples.samples(projectNumber: number)
            guard listing.samples.isEmpty == false else { return ToolResult(.make("assistant.samples.none", number)) }
            let rows: [Phrase] = listing.samples.prefix(ListingEngine.rowLimit).map { sample in
                var text = "\u{2022} \(sample.label)"
                if let manufacturer = sample.manufacturer, manufacturer.isEmpty == false { text += " | \(manufacturer)" }
                if let category = sample.category, category.isEmpty == false { text += " | \(category)" }
                return .raw(text + " | \(sample.statusLabel)")
            }
            var lines = ListingEngine.clip(rows, total: listing.samples.count)
            if listing.defective > 0 { lines.append(.make("assistant.samples.defective", String(listing.defective))) }
            return ToolResult(lines: lines)
        } catch {
            return .failure("assistant.samples.failed", PortFailure.detail(of: error))
        }
    }
}
