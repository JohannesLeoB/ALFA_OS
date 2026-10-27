import Airtable
import Assistant
import Calculation
import ClickUp
import Clockodo
import Foundation
import Hub
import Sevdesk
import Shipping
import Storage

@MainActor
struct ToolShelf {
    let access: any AccessPort
    let setup: any SetupPort
    let keychain: any KeychainPort
    let http: any Assistant.HttpPort
    let text: any TextPort
    let notes: NoteStore
    let todos: TodoStore
    let journal: JournalStore
    let alarm: any AlarmPort
    let receipts: ReceiptStore
    let learning: LearningStore
    let audit: AuditStore
    let workshop: WorkshopFactors
    let personID: String

    func registry() -> ToolRegistry {
        ToolRegistry(tools: local() + google() + clickUp() + clockodo() + sevdesk() + shipping() + airtable())
    }

    private func inlet(_ provider: String, _ capability: Capability? = nil) -> Inlet? {
        setup.inlets.first { inlet in
            inlet.provider == provider && inlet.state.isConnected && (capability.map { inlet.capabilities.contains($0) } ?? true)
        }
    }

    private func local() -> [any ToolPort] {
        [
            CreateNoteTool(notes: notes), UpdateNoteTool(notes: notes), DeleteNoteTool(notes: notes), ListNotesTool(notes: notes),
            CreateTodoTool(todos: todos, alarm: alarm), CompleteTodoTool(todos: todos, alarm: alarm),
            DeleteTodoTool(todos: todos, alarm: alarm), ListTodosTool(todos: todos),
            JournalTool(journal: journal),
            CalculationTool(estimation: estimation(inlet("airtable"))),
        ]
    }

    private func google() -> [any ToolPort] {
        var tools: [any ToolPort] = []
        if let mail = inlet("google", .mail), let port = try? access.port((any MailSearchPort).self, for: mail.id) {
            tools += [ReadMailTool(mail: port), SearchMailTool(mail: port), ProposeMailDraftTool()]
        }
        if let calendar = inlet("google", .calendar), let port = try? access.port((any CalendarPort).self, for: calendar.id) {
            tools += [ListEventsTool(calendar: port), ProposeEventTool(), SuggestEventLinkTool()]
        }
        if let contacts = inlet("google", .contacts), let port = try? access.port((any GoogleContactsPort).self, for: contacts.id) {
            tools += [SearchGoogleContactsTool(contacts: port), ProposeGoogleContactTool()]
        }
        if let files = inlet("google", .files), let port = try? access.port((any Assistant.DrivePort).self, for: files.id) {
            tools.append(ListFolderTool(drive: port))
        }
        return tools
    }

    private func clickUp() -> [any ToolPort] {
        guard let inlet = inlet("clickup") else { return [] }
        let client = ClickUp.ClickUpClient(credentials: ClickUp.CredentialsStore(keychain: keychain, inlet: inlet.id), http: http)
        let board = TaskBoardClient(read: client, write: client)
        return [ListTasksTool(board: board, lists: []), ProposeTaskChangeTool(board: board, lists: [])]
    }

    private func clockodo() -> [any ToolPort] {
        guard let inlet = inlet("clockodo") else { return [] }
        let client = ClockodoClient(credentials: Clockodo.CredentialsStore(keychain: keychain, inlet: inlet.id), http: http)
        return [ListTimeEntriesTool(time: client)]
    }

    private func sevdesk() -> [any ToolPort] {
        inlet("sevdesk") == nil ? [] : [ListDocumentsTool(receipts: receipts)]
    }

    private func shipping() -> [any ToolPort] {
        guard let inlet = inlet("dhl") else { return [] }
        let key = (try? keychain.get(KeySlot(inlet: inlet.id, name: "key"))) ?? nil
        return [TrackShipmentTool(shipments: ShipmentClient(tracking: TrackingClient(apiKey: key, http: http), text: text))]
    }

    private func airtableClient(_ inlet: Inlet?) -> Airtable.AirtableClient? {
        inlet.map { Airtable.AirtableClient(credentials: Airtable.CredentialsStore(keychain: keychain, inlet: $0.id), http: http) }
    }

    private func airtable() -> [any ToolPort] {
        guard let client = airtableClient(inlet("airtable")) else { return [] }
        let articles = ArticleStore(fetch: client)
        let stock = StockStore(fetch: client)
        return [SearchCatalogTool(catalog: articles), ListStockTool(stock: stock),
                ProposeCartItemTool(catalog: articles, stock: stock), ProposeContactChangeTool()]
    }

    private func estimation(_ airtable: Inlet?) -> EstimationEngine {
        let client = airtableClient(airtable)
        let learned = LearnedAnchorStore(store: learning)
        let pdf = PdfAnchorStore(store: learning)
        var primary: any PriceAnchorPort = SeedAnchors()
        if let client {
            let anchors = AnchorStore(source: AnchorRowStore(fetch: client), fallback: SeedAnchors())
            Task { _ = await anchors.warmUp() }
            primary = anchors
        }
        return EstimationEngine(
            anchors: CompositeAnchorStore(primary: primary, learned: learned, pdfLearned: pdf),
            learningStore: learning,
            articlePrices: client.map { ArticleStore(fetch: $0) },
            auditStore: audit,
            parameterPort: client.map { EstimationParameterStore(fetch: $0) },
            workshopFactors: workshop,
            actorUserID: personID)
    }
}
