import Foundation
import Observation
import Storage

@MainActor
@Observable
final class TimeTableState {
    var manualRows: [TimeSlice] = []
    var period: Period = .week
    public private(set) var bookedIDs: Set<UUID> = []
    public private(set) var rowStates: [UUID: SaveState] = [:]
    public private(set) var customers: [TimeCustomer] = []
    public private(set) var projects: [TimeProject] = []
    public private(set) var activities: [TimeActivity] = []
    public private(set) var entries: [TimeEntry] = []
    public private(set) var masterDataFailure: String?
    public private(set) var entryStates: [Int: SaveState] = [:]

    private let masterData: any MasterDataPort
    private let booking: any BookingPort
    private let booked: BookedRowStore
    private let userID: String
    private let clockodoUserID: Int?
    private let costCenters: [CostCenter]

    init(
        masterData: any MasterDataPort, booking: any BookingPort, booked: BookedRowStore, userID: String,
        clockodoUserID: Int? = nil, costCenters: [CostCenter] = []
    ) {
        self.masterData = masterData
        self.booking = booking
        self.booked = booked
        self.userID = userID
        self.clockodoUserID = clockodoUserID
        self.costCenters = costCenters
    }

    func loadMasterData() async {
        do {
            async let loadedCustomers = masterData.customers()
            async let loadedProjects = masterData.projects()
            async let loadedActivities = masterData.activities()
            customers = try await loadedCustomers.filter(\.isActive).sorted { $0.name < $1.name }
            projects = try await loadedProjects.filter(\.isActive).sorted { $0.name < $1.name }
            activities = try await loadedActivities.filter(\.isActive).sorted { $0.name < $1.name }
            masterDataFailure = nil
        } catch {
            masterDataFailure = Self.describe(error)
        }
    }

    func loadEntries(now: Date = Date()) async {
        let span = period.span(now: now)
        do {
            entries = try await masterData.entries(since: span.since, until: span.until, userID: clockodoUserID)
                .sorted { $0.start > $1.start }
        } catch {
            masterDataFailure = Self.describe(error)
        }
    }

    func loadBooked() throws {
        bookedIDs = try booked.bookedIDs(userID: userID)
    }

    func label(for entry: TimeEntry) -> (customer: String, activity: String) {
        let customer = customers.first { $0.id == entry.customerID }?.name ?? String(entry.customerID)
        let activity = activities.first { $0.id == entry.activityID }?.name ?? String(entry.activityID)
        return (customer, activity)
    }

    func projects(forCustomer customerID: Int?) -> [TimeProject] {
        guard let customerID else { return [] }
        return projects.filter { $0.customerID == customerID }
    }

    func isBooked(_ id: UUID) -> Bool { bookedIDs.contains(id) }

    func addManualRow() {
        manualRows.append(TimeSlice())
    }

    func removeManualRow(_ id: UUID) {
        manualRows.removeAll { $0.id == id }
    }

    func book(
        _ slice: TimeSlice, projects: [BookingEngine.Project], customers: [BookingEngine.Customer], confirmed: Bool
    ) async {
        guard isBooked(slice.id) == false else { return }
        guard slice.end > slice.start else {
            rowStates[slice.id] = .failed("clockodo.table.endBeforeStart")
            return
        }
        let customerID: Int
        let activityID: Int
        let projectID: Int?
        switch slice.origin {
        case .timer:
            switch BookingEngine.resolve(
                projectNumber: slice.projectNumber, costCenter: slice.costCenter, projects: projects,
                customers: customers, costCenters: costCenters) {
            case .success(let target):
                customerID = target.customerID
                activityID = target.activityID
                projectID = nil
            case .failure(let failure):
                rowStates[slice.id] = .failed(failure.key)
                return
            }
        case .manual:
            guard let manualCustomer = slice.customerID, let manualActivity = slice.activityID else {
                rowStates[slice.id] = .failed("clockodo.table.selectionMissing")
                return
            }
            customerID = manualCustomer
            activityID = manualActivity
            projectID = slice.projectID
        }
        rowStates[slice.id] = .saving
        let trimmed = slice.text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let entryID = try await booking.createEntry(
                customerID: customerID, activityID: activityID, projectID: projectID, since: slice.start,
                until: slice.end, billable: slice.billable, text: trimmed.isEmpty ? nil : slice.text,
                confirmed: confirmed)
            try markBooked(slice.id, entryID: entryID)
            rowStates[slice.id] = .saved(Date())
        } catch {
            rowStates[slice.id] = .failed(Self.describe(error))
        }
    }

    func editText(_ entry: TimeEntry, text: String, confirmed: Bool) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        entryStates[entry.id] = .saving
        do {
            try await booking.updateText(id: entry.id, text: trimmed, confirmed: confirmed)
            replace(entry.id) { current in
                TimeEntry(
                    id: current.id, customerID: current.customerID, projectID: current.projectID,
                    activityID: current.activityID, text: trimmed.isEmpty ? nil : trimmed, start: current.start,
                    seconds: current.seconds, billable: current.billable)
            }
            entryStates[entry.id] = nil
        } catch {
            entryStates[entry.id] = .failed(Self.describe(error))
        }
    }

    func setBillable(_ entry: TimeEntry, billable: Bool, confirmed: Bool) async {
        entryStates[entry.id] = .saving
        do {
            try await booking.setBillable(id: entry.id, billable: billable, confirmed: confirmed)
            replace(entry.id) { current in
                TimeEntry(
                    id: current.id, customerID: current.customerID, projectID: current.projectID,
                    activityID: current.activityID, text: current.text, start: current.start,
                    seconds: current.seconds, billable: billable)
            }
            entryStates[entry.id] = nil
        } catch {
            entryStates[entry.id] = .failed(Self.describe(error))
        }
    }

    func delete(_ entry: TimeEntry, confirmed: Bool) async {
        entryStates[entry.id] = .saving
        do {
            try await booking.deleteEntry(id: entry.id, confirmed: confirmed)
            entries.removeAll { $0.id == entry.id }
            entryStates[entry.id] = nil
        } catch {
            entryStates[entry.id] = .failed(Self.describe(error))
        }
    }

    private func replace(_ id: Int, with change: (TimeEntry) -> TimeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index] = change(entries[index])
    }

    private func markBooked(_ id: UUID, entryID: String) throws {
        bookedIDs.insert(id)
        try booked.mark(rowID: id, entryID: entryID, userID: userID)
    }

    static func describe(_ error: any Error) -> String {
        if let failure = error as? RequestFailure { return failure.detail }
        if let failure = error as? WriteFailure { return failure.key }
        return error.localizedDescription
    }
}
