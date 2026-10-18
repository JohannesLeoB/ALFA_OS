import Foundation
import Observation
import AlfaKit

@MainActor
@Observable
public final class DriveProjectFolderWatcher {
    public struct ProjectState: Codable, Sendable, Equatable {
        public var knownFileIDs: Set<String> = []
        public var hasBaseline = false
        public var lastCheck: Date?
        public var lastFind: Date?
        public var lastOpened: Date?
    }

    public enum Grade: String, Sendable { case active, background }

    public static let activeInterval: TimeInterval = 30 * 60
    public static let backgroundInterval: TimeInterval = 3 * 60 * 60
    public static let activeWindow: TimeInterval = 7 * 24 * 60 * 60
    public static let changesInterval: TimeInterval = 5 * 60

    public private(set) var projectStates: [String: ProjectState] = [:]
    private var changesPageToken: String?
    private var driveID: String?
    private var lastChangesCall: Date?

    private let files: GoogleDriveFetching
    private let changes: GoogleDriveChangesReading?
    private let stateFile: URL

    public init(files: GoogleDriveFetching = GoogleDriveClient(),
                changes: GoogleDriveChangesReading? = GoogleDriveClient(),
                stateFile: URL = DatenRoot.root().appendingPathComponent("sondierung.json")) {
        self.files = files
        self.changes = changes
        self.stateFile = stateFile
        loadState()
    }

    public func grade(_ projectNumber: String, isFavourite: Bool, now: Date = Date()) -> Grade {
        if isFavourite { return .active }
        let state = projectStates[projectNumber] ?? ProjectState()
        for moment in [state.lastOpened, state.lastFind] {
            if let moment, now.timeIntervalSince(moment) < Self.activeWindow { return .active }
        }
        return .background
    }

    public func isDue(_ projectNumber: String, isFavourite: Bool, now: Date = Date()) -> Bool {
        guard let last = projectStates[projectNumber]?.lastCheck else { return true }
        let interval = grade(projectNumber, isFavourite: isFavourite, now: now) == .active
            ? Self.activeInterval : Self.backgroundInterval
        return now.timeIntervalSince(last) >= interval
    }

    public func noteProjectOpened(_ projectNumber: String, now: Date = Date()) {
        var state = projectStates[projectNumber] ?? ProjectState()
        state.lastOpened = now
        projectStates[projectNumber] = state
        saveState()
    }

    public struct WatchedFolder: Sendable {
        public let projectNumber: String
        public let folderID: String
        public let isFavourite: Bool
        public init(projectNumber: String, folderID: String, isFavourite: Bool) {
            self.projectNumber = projectNumber; self.folderID = folderID
            self.isFavourite = isFavourite
        }
    }

    public struct CheckOutcome {
        public let signals: [WidgetSignal]
        public let attempted: Bool
        public let failure: (any Error)?

        public init(signals: [WidgetSignal], attempted: Bool, failure: (any Error)? = nil) {
            self.signals = signals
            self.attempted = attempted
            self.failure = failure
        }
    }

    public func check(_ folders: [WatchedFolder], now: Date = Date(),
                      respectSchedule: Bool = true) async -> [WidgetSignal] {
        await checkWithOutcome(folders, now: now, respectSchedule: respectSchedule).signals
    }

    public func checkWithOutcome(_ folders: [WatchedFolder], now: Date = Date(),
                                 respectSchedule: Bool = true) async -> CheckOutcome {
        let watched = folders.filter { $0.folderID.isEmpty == false }
        guard watched.isEmpty == false else { return CheckOutcome(signals: [], attempted: false) }

        if respectSchedule, let feed = await checkViaChangesFeed(watched, now: now) {
            saveState()
            return CheckOutcome(signals: feed.signals, attempted: feed.queried)
        }

        var signals: [WidgetSignal] = []
        var attempted = false
        var failure: (any Error)?
        for folder in watched {
            if respectSchedule,
               isDue(folder.projectNumber, isFavourite: folder.isFavourite, now: now) == false { continue }
            attempted = true
            do {
                signals += try await checkByListing(folder, now: now)
            } catch {
                failure = error
            }
        }
        saveState()
        return CheckOutcome(signals: signals, attempted: attempted, failure: failure)
    }

    private func checkViaChangesFeed(_ folders: [WatchedFolder], now: Date) async -> (signals: [WidgetSignal], queried: Bool)? {
        guard let changes else { return nil }
        if let last = lastChangesCall, now.timeIntervalSince(last) < Self.changesInterval { return ([], false) }

        guard let pageToken = changesPageToken else {
            guard let drive = try? await changes.driveID(forFolder: folders[0].folderID),
                  let start = try? await changes.startPageToken(driveID: drive) else { return nil }
            driveID = drive
            changesPageToken = start
            lastChangesCall = now
            folders.forEach { noteChecked($0.projectNumber, now: now) }
            return ([], true)
        }

        guard let result = try? await changes.changes(since: pageToken, driveID: driveID) else {
            return nil
        }
        changesPageToken = result.nextPageToken
        lastChangesCall = now

        var folderByID: [String: WatchedFolder] = [:]
        for folder in folders {
            folderByID[folder.folderID] = folder
            noteChecked(folder.projectNumber, now: now)
        }

        var signals: [WidgetSignal] = []
        for change in result.changes {
            guard change.removed == false, let file = change.file,
                  file.mimeType != "application/vnd.google-apps.folder" else { continue }
            guard let folder = change.parentIDs.compactMap({ folderByID[$0] }).first else { continue }
            var state = projectStates[folder.projectNumber] ?? ProjectState()
            guard state.knownFileIDs.contains(file.id) == false else { continue }
            state.knownFileIDs.insert(file.id)
            state.hasBaseline = true
            state.lastFind = now
            projectStates[folder.projectNumber] = state
            signals.append(signal(for: file, projectNumber: folder.projectNumber))
        }
        return (signals, true)
    }

    private func checkByListing(_ folder: WatchedFolder, now: Date) async throws -> [WidgetSignal] {
        let listed = try await files.listFolder(folderID: folder.folderID)
        var state = projectStates[folder.projectNumber] ?? ProjectState()
        state.lastCheck = now
        defer { projectStates[folder.projectNumber] = state }

        let contents = listed.filter { $0.mimeType != "application/vnd.google-apps.folder" }
        guard state.hasBaseline else {
            state.knownFileIDs = Set(contents.map(\.id))
            state.hasBaseline = true
            return []
        }
        let fresh = contents.filter { state.knownFileIDs.contains($0.id) == false }
        guard fresh.isEmpty == false else { return [] }
        state.knownFileIDs.formUnion(fresh.map(\.id))
        state.lastFind = now
        return fresh.map { signal(for: $0, projectNumber: folder.projectNumber) }
    }

    private func noteChecked(_ projectNumber: String, now: Date) {
        var state = projectStates[projectNumber] ?? ProjectState()
        state.lastCheck = now
        state.hasBaseline = true
        projectStates[projectNumber] = state
    }

    private func signal(for file: GoogleDriveFile, projectNumber: String) -> WidgetSignal {
        if DriveOfferWatcher.isOffer(file) {
            return .offerDetected(projectID: projectNumber, label: file.name)
        }
        if DriveOfferWatcher.isWerkzeichnung(file) {
            return .drawingDetected(projectID: projectNumber, label: file.name)
        }
        return .driveFileAdded(projectID: projectNumber, fileName: file.name)
    }

    private struct StoredState: Codable {
        var projectStates: [String: ProjectState] = [:]
        var changesPageToken: String?
        var driveID: String?
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateFile),
              let stored = try? JSONDecoder().decode(StoredState.self, from: data) else { return }
        projectStates = stored.projectStates
        changesPageToken = stored.changesPageToken
        driveID = stored.driveID
    }

    private func saveState() {
        guard let data = try? JSONEncoder().encode(
            StoredState(projectStates: projectStates, changesPageToken: changesPageToken,
                        driveID: driveID)) else { return }
        try? FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: stateFile, options: .atomic)
    }
}
