import Calculation

public struct CalculationTool: ToolPort {
    private let estimation: any EstimationPort

    public init(estimation: any EstimationPort) {
        self.estimation = estimation
    }

    public var name: String { "schaetze_projekt" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var manifestID: String { "KALKULATION_LOCAL" }
    public var parameters: [ToolParameter] {
        [
            ToolParameter("beschreibung", required: true),
            ToolParameter("korpusanzahl", kind: .integer),
            ToolParameter("fronten"),
            ToolParameter("schubkaesten_legrabox", kind: .integer),
            ToolParameter("schubkaesten_holz", kind: .integer),
            ToolParameter("werkstatt"),
            ToolParameter("entfernung_km", kind: .number),
        ]
    }

    public func promptKeys(available: Set<String>) -> [String] {
        var keys = [promptKey]
        if available.contains(SearchCatalogTool.wireName) { keys.append(promptKey + ".catalog") }
        return keys
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let description = input.text("beschreibung")
        guard description.isEmpty == false else { return .failure("assistant.estimate.noDescription") }
        let override = EstimateOverride(
            carcassCount: input.integer("korpusanzahl"),
            frontExecution: input.optionalText("fronten"),
            drawersLegrabox: input.integer("schubkaesten_legrabox"),
            drawersSolid: input.integer("schubkaesten_holz"),
            workshop: input.optionalText("werkstatt"),
            distanceKm: input.number("entfernung_km"))
        do {
            let estimate = try await estimation.estimate(projectID: scope.projectID, text: description, override: override)
            return ToolResult(lines: Self.summary(estimate), cards: Self.cards(estimate))
        } catch {
            return .failure("assistant.estimate.failed", error.localizedDescription)
        }
    }

    static func cards(_ estimate: CostEstimate) -> [ContentBlock] {
        var cards: [ContentBlock] = [.estimate(
            estimateID: estimate.estimateID, projectID: estimate.projectID, minNet: estimate.minNet,
            maxNet: estimate.maxNet, midNet: estimate.midNet, confidence: estimate.confidence,
            evidenceCount: estimate.evidenceCount)]
        if estimate.lines.isEmpty == false || estimate.excludes.isEmpty == false {
            cards.append(.estimateBreakdown(estimateID: estimate.estimateID, lines: estimate.lines, excludes: estimate.excludes))
        }
        return cards
    }

    static func summary(_ estimate: CostEstimate) -> [Phrase] {
        let low = ListingEngine.wholeNumber(estimate.minNet)
        let mid = ListingEngine.wholeNumber(estimate.midNet)
        let high = ListingEngine.wholeNumber(estimate.maxNet)
        var lines: [Phrase] = []
        if let model = estimate.modelLabel {
            lines.append(.join([.make("assistant.estimate.modelOpen"), .notice(model),
                                .make("assistant.estimate.modelClose", low, mid, high)], ""))
        } else {
            lines.append(.make("assistant.estimate.header", low, mid, high,
                               String(Int(estimate.confidence * 100)), String(estimate.evidenceCount)))
        }
        for line in estimate.lines {
            if let amount = line.amountNet, line.kind != .open {
                lines.append(.join([.raw("\u{2013} "), .notice(line.label),
                                    .make("assistant.estimate.lineAmount", ListingEngine.wholeNumber(amount))], ""))
            } else {
                lines.append(.join([.raw("\u{2013} "), .notice(line.label), .make("assistant.estimate.lineOpen")], ""))
            }
        }
        for hint in estimate.hints { lines.append(.join([.raw("\u{2022} "), .notice(hint)], "")) }
        return lines
    }
}
