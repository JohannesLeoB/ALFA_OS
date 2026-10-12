import Foundation
import Observation
import GRDB
import MykilosKit

private struct ActiveTimerRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", projectTitle = "projektTitel", kostenstelle, runSince, pausedAccumulatedSeconds, isPaused, segmentStartedAt }

    static var databaseTableName: String { "activeTimer" }
    static let singletonID = "singleton"

    var id: String
    var projectNumber: String
    var projectTitle: String
    var kostenstelle: String
    var runSince: Double
    var pausedAccumulatedSeconds: Double
    var isPaused: Bool
    var segmentStartedAt: Double

    init(from t: ActiveTimer, userID: String?) {
        let trimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        id = trimmed.isEmpty ? CurrentUserContext.timerFallbackID : trimmed
        projectNumber = t.projectNumber
        projectTitle = t.projectTitle
        kostenstelle = t.kostenstelle
        runSince = t.runSince.timeIntervalSince1970
        pausedAccumulatedSeconds = t.pausedAccumulatedSeconds
        isPaused = t.isPaused
        segmentStartedAt = t.segmentStartedAt.timeIntervalSince1970
    }

    var toDomain: ActiveTimer {
        ActiveTimer(
            projectNumber: projectNumber, projectTitle: projectTitle, kostenstelle: kostenstelle,
            runSince: Date(timeIntervalSince1970: runSince),
            pausedAccumulatedSeconds: pausedAccumulatedSeconds, isPaused: isPaused,
            segmentStartedAt: Date(timeIntervalSince1970: segmentStartedAt))
    }
}

private struct TimeSegmentDraftRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", projectTitle = "projektTitel", kostenstelle, startedAt, endedAt, seconds, userID }

    static var databaseTableName: String { "timeSegmentDrafts" }
    var id: String
    var projectNumber: String
    var projectTitle: String
    var kostenstelle: String
    var startedAt: Double
    var endedAt: Double
    var seconds: Double

    var userID: String?

    init(from d: TimeSegmentDraft, userID: String?) {
        id = d.id.uuidString
        projectNumber = d.projectNumber
        projectTitle = d.projectTitle
        kostenstelle = d.kostenstelle
        startedAt = d.startedAt.timeIntervalSince1970
        endedAt = d.endedAt.timeIntervalSince1970
        seconds = d.seconds
        self.userID = userID
    }

    var toDomain: TimeSegmentDraft? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return TimeSegmentDraft(
            id: uuid, projectNumber: projectNumber, projectTitle: projectTitle, kostenstelle: kostenstelle,
            startedAt: Date(timeIntervalSince1970: startedAt), endedAt: Date(timeIntervalSince1970: endedAt),
            seconds: seconds)
    }
}

private struct TimeSegmentRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", projectTitle = "projektTitel", kostenstelle, startedAt, endedAt, seconds, bookedAt, userID }

    static var databaseTableName: String { "timeSegments" }
    var id: String
    var projectNumber: String
    var projectTitle: String
    var kostenstelle: String
    var startedAt: Double
    var endedAt: Double
    var seconds: Double
    var bookedAt: Double

    var userID: String?

    init(from s: TimeSegment, userID: String?) {
        id = s.id.uuidString
        projectNumber = s.projectNumber
        projectTitle = s.projectTitle
        kostenstelle = s.kostenstelle
        startedAt = s.startedAt.timeIntervalSince1970
        endedAt = s.endedAt.timeIntervalSince1970
        seconds = s.seconds
        bookedAt = s.bookedAt.timeIntervalSince1970
        self.userID = userID
    }

    var toDomain: TimeSegment? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return TimeSegment(
            id: uuid, projectNumber: projectNumber, projectTitle: projectTitle, kostenstelle: kostenstelle,
            startedAt: Date(timeIntervalSince1970: startedAt), endedAt: Date(timeIntervalSince1970: endedAt),
            seconds: seconds, bookedAt: Date(timeIntervalSince1970: bookedAt))
    }
}

private struct ZielkontingentRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case projectNumber = "projektNummer", zielStunden, herkunft, updatedAt }

    static var databaseTableName: String { "projectZielkontingente" }
    var projectNumber: String
    var zielStunden: Double
    var herkunft: String
    var updatedAt: Double

    init(from z: ProjectZielkontingent) {
        projectNumber = z.projectNumber
        zielStunden = z.zielStunden
        herkunft = z.herkunft.rawValue
        updatedAt = z.updatedAt.timeIntervalSince1970
    }

    var toDomain: ProjectZielkontingent? {
        guard let h = ZielkontingentHerkunft(rawValue: herkunft) else { return nil }
        return ProjectZielkontingent(
            projectNumber: projectNumber, zielStunden: zielStunden, herkunft: h,
            updatedAt: Date(timeIntervalSince1970: updatedAt))
    }
}

private struct AppSettingRow: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "appSettings" }
    var key: String
    var value: String
    var updatedAt: Double
}

public struct PendingTakeover: Equatable, Sendable {
    public let laufendesProjekt: String
    public let laufendeKostenstelle: String
    public let laufendeSekunden: Double
    public let neuesProjektNummer: String
    public let neuesProjektTitel: String
    public let neueKostenstelle: String
}

@MainActor
@Observable
public final class TimerStore {
    public private(set) var active: ActiveTimer?
    public private(set) var pendingDrafts: [TimeSegmentDraft] = []
    public private(set) var pendingTakeover: PendingTakeover?
    public private(set) var bookedSegments: [TimeSegment] = []
    public private(set) var zielkontingente: [String: ProjectZielkontingent] = [:]
    public private(set) var pulseIntervalMinutes: Int = 60

    public private(set) var reminderAnchor: Date?
    public private(set) var saveState: SaveState = .idle

    private var queuedStart: (projectNumber: String, projectTitle: String, kostenstelle: String)?

    private let db: GRDBDatabase

    private let userID: String?
    private let now: @MainActor () -> Date

    private static let pulseIntervalKey = "blockB.timer.pulseIntervalMinutes"

    public init(db: GRDBDatabase, userID: String? = CurrentUserContext.current, now: @escaping @MainActor () -> Date = { Date() }) {
        self.db = db
        self.userID = userID
        self.now = now
    }

    private var effectiveUserID: String {
        let t = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? CurrentUserContext.timerFallbackID : t
    }

    public func load() throws {
        let uid = userID
        let eid = effectiveUserID
        active = try db.read { try ActiveTimerRecord.fetchOne($0, key: eid) }?.toDomain
        pendingDrafts = (try db.read { try TimeSegmentDraftRecord.filter(Column("userID") == uid).order(Column("startedAt")).fetchAll($0) })
            .compactMap(\.toDomain)
        bookedSegments = (try db.read { try TimeSegmentRecord.filter(Column("userID") == uid).order(Column("bookedAt").desc).fetchAll($0) })
            .compactMap(\.toDomain)
        let targets = (try db.read { try ZielkontingentRecord.fetchAll($0) }).compactMap(\.toDomain)
        zielkontingente = Dictionary(uniqueKeysWithValues: targets.map { ($0.projectNumber, $0) })
        if let row = try db.read({ try AppSettingRow.fetchOne($0, key: Self.pulseIntervalKey) }),
           let minutes = Int(row.value), minutes > 0 {
            pulseIntervalMinutes = minutes
        }

        if active != nil { reminderAnchor = now() }
    }

    public func elapsedSeconds() -> Double {
        active?.elapsedSeconds(now: now()) ?? 0
    }

    public func currentRunSeconds() -> Double {
        let draftSum = pendingDrafts.reduce(0) { $0 + $1.seconds }
        return draftSum + elapsedSeconds()
    }

    public func start(projectNumber: String, projectTitle: String, kostenstelle: String) throws {
        guard pendingDrafts.isEmpty else { return }

        if let active {
            if active.projectNumber == projectNumber && active.kostenstelle == kostenstelle {
                return
            }
            pendingTakeover = PendingTakeover(
                laufendesProjekt: active.projectTitle,
                laufendeKostenstelle: active.kostenstelle,
                laufendeSekunden: currentRunSeconds(),
                neuesProjektNummer: projectNumber,
                neuesProjektTitel: projectTitle,
                neueKostenstelle: kostenstelle)
            return
        }
        try startFresh(projectNumber: projectNumber, projectTitle: projectTitle, kostenstelle: kostenstelle)
    }

    private func startFresh(projectNumber: String, projectTitle: String, kostenstelle: String) throws {
        let t = now()
        let timer = ActiveTimer(
            projectNumber: projectNumber, projectTitle: projectTitle, kostenstelle: kostenstelle,
            runSince: t, pausedAccumulatedSeconds: 0, isPaused: false, segmentStartedAt: t)
        try persistActive(timer)
        active = timer
        reminderAnchor = t
    }

    public func confirmTakeover() throws {
        guard let takeover = pendingTakeover else { return }
        queuedStart = (takeover.neuesProjektNummer, takeover.neuesProjektTitel, takeover.neueKostenstelle)
        pendingTakeover = nil
        try requestStop()
    }

    public func cancelTakeover() {
        pendingTakeover = nil
    }

    public func pause() throws {
        guard var timer = active, timer.isPaused == false else { return }
        let t = now()
        timer.pausedAccumulatedSeconds += max(0, t.timeIntervalSince(timer.runSince))
        timer.isPaused = true
        try persistActive(timer)
        active = timer
    }

    public func resume() throws {
        guard var timer = active, timer.isPaused else { return }
        timer.runSince = now()
        timer.isPaused = false
        try persistActive(timer)
        active = timer
    }

    public func switchKostenstelle(to kostenstelle: String) throws {
        guard let timer = active, timer.kostenstelle != kostenstelle else { return }
        let t = now()
        let draft = makeDraft(from: timer, endedAt: t)
        let draftRecord = TimeSegmentDraftRecord(from: draft, userID: userID)
        try db.write { dbc in
            try draftRecord.insert(dbc)
        }
        pendingDrafts.append(draft)
        let next = ActiveTimer(
            projectNumber: timer.projectNumber, projectTitle: timer.projectTitle, kostenstelle: kostenstelle,
            runSince: t, pausedAccumulatedSeconds: 0, isPaused: false, segmentStartedAt: t)
        try persistActive(next)
        active = next
    }

    public func requestStop() throws {
        guard let timer = active else { return }
        let draft = makeDraft(from: timer, endedAt: now())
        let draftRecord = TimeSegmentDraftRecord(from: draft, userID: userID)
        let eid = effectiveUserID
        try db.write { dbc in
            if draft.seconds > 0 { try draftRecord.insert(dbc) }
            _ = try ActiveTimerRecord.deleteOne(dbc, key: eid)
        }
        if draft.seconds > 0 { pendingDrafts.append(draft) }
        active = nil
        reminderAnchor = nil

        if pendingDrafts.isEmpty { runQueuedStartIfNeeded() }
    }

    public func confirmBooking() throws {
        guard pendingDrafts.isEmpty == false else { return }
        saveState = .saving
        let booked = pendingDrafts.map { TimeSegment(fromDraft: $0, bookedAt: now()) }
        let uid = userID
        do {
            try db.write { dbc in
                for seg in booked { try TimeSegmentRecord(from: seg, userID: uid).insert(dbc) }
                try TimeSegmentDraftRecord.filter(Column("userID") == uid).deleteAll(dbc)
            }
            bookedSegments.insert(contentsOf: booked, at: 0)
            pendingDrafts.removeAll()
            saveState = .saved(now())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
        runQueuedStartIfNeeded()
    }

    public func cancelBooking() throws {
        guard pendingDrafts.isEmpty == false else { return }
        let uid = userID
        try db.write { dbc in try TimeSegmentDraftRecord.filter(Column("userID") == uid).deleteAll(dbc) }
        pendingDrafts.removeAll()
        runQueuedStartIfNeeded()
    }

    private func runQueuedStartIfNeeded() {
        guard let q = queuedStart else { return }

        do {
            try startFresh(projectNumber: q.projectNumber, projectTitle: q.projectTitle, kostenstelle: q.kostenstelle)
            queuedStart = nil
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    public func resetReminder() {
        reminderAnchor = now()
    }

    public func shouldPulse() -> Bool {
        guard let anchor = reminderAnchor, let timer = active, timer.isPaused == false else { return false }
        return Self.shouldPulse(
            anchor: anchor, now: now(),
            intervalSeconds: Double(pulseIntervalMinutes) * 60, calmAfterSeconds: 180)
    }

    public static func shouldPulse(anchor: Date, now: Date, intervalSeconds: Double, calmAfterSeconds: Double = 180) -> Bool {
        guard intervalSeconds > 0 else { return false }
        let elapsed = now.timeIntervalSince(anchor)
        guard elapsed >= intervalSeconds else { return false }
        let calm = min(calmAfterSeconds, intervalSeconds)
        let intoMark = elapsed.truncatingRemainder(dividingBy: intervalSeconds)
        return intoMark < calm
    }

    public func setPulseInterval(minutes: Int) throws {
        let m = max(1, minutes)
        let ts = now().timeIntervalSince1970
        try db.write { dbc in
            try AppSettingRow(key: Self.pulseIntervalKey, value: String(m), updatedAt: ts).save(dbc)
        }
        pulseIntervalMinutes = m
    }

    public func zielkontingent(for projectNumber: String) -> ProjectZielkontingent? {
        zielkontingente[projectNumber]
    }

    public func setZielkontingent(projectNumber: String, stunden: Double, herkunft: ZielkontingentHerkunft = .manuell) throws {
        let z = ProjectZielkontingent(projectNumber: projectNumber, zielStunden: max(0, stunden), herkunft: herkunft, updatedAt: now())
        try db.write { dbc in try ZielkontingentRecord(from: z).save(dbc) }
        zielkontingente[projectNumber] = z
    }

    public func gebuchteStunden(for projectNumber: String) -> Double {
        bookedSegments.filter { $0.projectNumber == projectNumber }.reduce(0) { $0 + $1.seconds } / 3600
    }

    private func makeDraft(from timer: ActiveTimer, endedAt: Date) -> TimeSegmentDraft {
        let seconds = timer.elapsedSeconds(now: endedAt)
        return TimeSegmentDraft(
            projectNumber: timer.projectNumber, projectTitle: timer.projectTitle, kostenstelle: timer.kostenstelle,
            startedAt: timer.segmentStartedAt, endedAt: endedAt, seconds: seconds)
    }

    private func persistActive(_ timer: ActiveTimer) throws {
        let record = ActiveTimerRecord(from: timer, userID: userID)
        try db.write { dbc in

            _ = try ActiveTimerRecord.deleteOne(dbc, key: record.id)
            try record.insert(dbc)
        }
    }
}
