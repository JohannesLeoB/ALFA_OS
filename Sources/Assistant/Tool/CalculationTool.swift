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

public struct SearchCatalogTool: ToolPort {
    static let wireName = "search_katalog"
    static let hitLimit = 10

    private let catalog: any CatalogPort

    public init(catalog: any CatalogPort) {
        self.catalog = catalog
    }

    public var name: String { Self.wireName }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var manifestID: String { "AIRTABLE_ARTIKELKATALOG" }
    public var parameters: [ToolParameter] { [ToolParameter("query", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        guard query.isEmpty == false else { return .failure("assistant.catalog.emptyQuery") }
        switch await catalog.search(term: query, limit: Self.hitLimit) {
        case .notConnected:
            return .failure("assistant.catalog.notConnected")
        case .failed(let message):
            return .failure("assistant.catalog.failed", message)
        case .empty:
            return .failure("assistant.catalog.empty")
        case .loading(let count):
            return ToolResult(count > 0 ? .make("assistant.catalog.loadingCount", String(count)) : .make("assistant.catalog.loading"))
        case .matches(let articles):
            guard articles.isEmpty == false else { return ToolResult(.make("assistant.catalog.noHits", query)) }
            var lines: [Phrase] = [.make("assistant.catalog.header", query)]
            lines += articles.map { Self.row($0) }
            return ToolResult(lines: lines)
        }
    }

    static func row(_ article: Article) -> Phrase {
        var parts: [Phrase] = [
            .raw("\u{2022} \(article.manufacturer ?? "\u{2013}") | \(article.label)"),
            .make("assistant.catalog.article", article.articleNumber),
        ]
        if let sale = ListingEngine.money(article.saleNet) { parts.append(.make("assistant.catalog.sale", sale)) }
        if let purchase = ListingEngine.money(article.purchaseNet) { parts.append(.make("assistant.catalog.purchase", purchase)) }
        return .join(parts, "")
    }
}

public struct ListStockTool: ToolPort {
    private let stock: any StockPort

    public init(stock: any StockPort) {
        self.stock = stock
    }

    public var name: String { "list_lager" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("suche")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("suche").lowercased()
        switch await stock.current() {
        case .loading:
            return ToolResult(.make("assistant.stock.loading"))
        case .notConnected:
            return .failure("assistant.stock.notConnected")
        case .failed(let message):
            return .failure("assistant.stock.failed", message)
        case .empty:
            return .failure("assistant.stock.empty")
        case .items(let items):
            let match = query.isEmpty ? items : items.filter { item in
                item.label.lowercased().contains(query)
                    || (item.manufacturer?.lowercased().contains(query) ?? false)
                    || (item.category?.lowercased().contains(query) ?? false)
                    || (item.articleNumber?.lowercased().contains(query) ?? false)
            }
            guard match.isEmpty == false else { return ToolResult(.make("assistant.stock.noMatch", query)) }
            let rows: [Phrase] = match.prefix(ListingEngine.rowLimit).map { item in
                var parts: [Phrase] = [.raw("\u{2022} \(item.label)")]
                if let manufacturer = item.manufacturer, manufacturer.isEmpty == false { parts.append(.raw(" | \(manufacturer)")) }
                if let number = item.articleNumber, number.isEmpty == false { parts.append(.make("assistant.catalog.article", number)) }
                if let quantity = item.quantity { parts.append(.make("assistant.stock.quantity", String(quantity))) }
                if let sale = ListingEngine.money(item.saleNet) { parts.append(.make("assistant.catalog.sale", sale)) }
                return .join(parts, "")
            }
            return ToolResult(lines: ListingEngine.clip(rows, total: match.count))
        }
    }
}

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

public struct ProposeCartItemTool: ToolPort {
    static let matchLimit = 5

    private let catalog: (any CatalogPort)?
    private let stock: (any StockPort)?

    public init(catalog: (any CatalogPort)?, stock: (any StockPort)?) {
        self.catalog = catalog
        self.stock = stock
    }

    public var name: String { "propose_warenkorb" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("artikel", required: true), ToolParameter("menge", kind: .integer)] }

    private enum Found {
        case one(CartDraft, label: String)
        case ambiguous([String])
        case none
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let search = input.text("artikel")
        guard search.isEmpty == false else { return .failure("assistant.cart.noArticle") }
        let quantity = max(input.integer("menge") ?? 1, 1)
        switch await find(search, quantity: quantity) {
        case .none:
            return .failure("assistant.cart.noMatch", search)
        case .ambiguous(let names):
            return .failure("assistant.cart.ambiguous", search, names.joined(separator: " \u{00B7} "))
        case .one(let draft, let label):
            let key = draft.source == .catalog ? "assistant.cart.readyCatalog" : "assistant.cart.readyStock"
            return ToolResult(.make(key, String(quantity), label), cards: [.cartDraft(draft)])
        }
    }

    private func find(_ search: String, quantity: Int) async -> Found {
        if let catalog, case .matches(let articles) = await catalog.search(term: search, limit: Self.matchLimit) {
            let match = Array(articles.prefix(Self.matchLimit))
            if match.count == 1, let article = match.first {
                let draft = CartDraft(label: article.label, articleNumber: article.articleNumber, quantity: quantity,
                                      purchaseNet: article.purchaseNet, saleNet: article.saleNet, source: .catalog,
                                      recordID: article.id)
                return .one(draft, label: article.label)
            }
            if match.count > 1 { return .ambiguous(match.map(\.label)) }
        }
        if let stock, case .items(let items) = await stock.current() {
            let match = items.filter {
                $0.label.localizedCaseInsensitiveContains(search)
                    || ($0.articleNumber?.localizedCaseInsensitiveContains(search) ?? false)
            }.prefix(Self.matchLimit)
            if match.count == 1, let item = match.first {
                let draft = CartDraft(label: item.label, articleNumber: item.articleNumber ?? item.id, quantity: quantity,
                                      purchaseNet: item.purchaseNet, saleNet: item.saleNet, source: .stock, recordID: item.id)
                return .one(draft, label: item.label)
            }
            if match.count > 1 { return .ambiguous(match.map(\.label)) }
        }
        return .none
    }
}

public struct TrackShipmentTool: ToolPort {
    private let shipments: any ShipmentPort

    public init(shipments: any ShipmentPort) {
        self.shipments = shipments
    }

    public var name: String { "verfolge_sendung" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("nummer", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let number = input.text("nummer")
        guard number.isEmpty == false else { return .failure("assistant.shipment.noNumber") }
        do {
            let status = try await shipments.track(number: number)
            var text = "\(status.number): \(status.statusLabel)"
            if let detail = status.detail, detail.isEmpty == false { text += " \u{2014} \(detail)" }
            return ToolResult(.raw(text))
        } catch PortFailure.notConnected {
            return .failure("assistant.shipment.notConnected")
        } catch let failure as PortFailure {
            return ToolResult(.raw(failure.detail), isError: true)
        } catch {
            return .failure("assistant.shipment.failed", error.localizedDescription)
        }
    }
}
