import Foundation
import MykilosKit

public struct DatenschutzExport: Codable, Equatable, Sendable {
    public var erstelltAm: Date
    public var profil: UserProfile?
    public var notizen: [String]
    public var aufgaben: [String]

    public var chatNachrichtenJeBereich: [String: Int]

    public init(
        erstelltAm: Date = Date(), profil: UserProfile?, notizen: [String],
        aufgaben: [String], chatNachrichtenJeBereich: [String: Int]
    ) {
        self.erstelltAm = erstelltAm
        self.profil = profil
        self.notizen = notizen
        self.aufgaben = aufgaben
        self.chatNachrichtenJeBereich = chatNachrichtenJeBereich
    }
}

@MainActor
public enum DatenschutzExportService {
    public static func erstelle(
        profile: ProfileStore,
        notes: AssistantNotesStore,
        tasks: AssistantTasksStore,
        chat: ChatStore,
        projectNumbers: [String]
    ) async -> DatenschutzExport {
        let notizen: [String]
        do { notizen = try await notes.all().map(\.body) } catch { notizen = [] }
        let aufgaben: [String]
        do { aufgaben = try await tasks.all().map(\.title) } catch { aufgaben = [] }

        var counts: [String: Int] = [:]
        let areas: [ChatScope] = [.home] + projectNumbers.map { .project($0) }
        for area in areas {
            do {
                try chat.loadIfNeeded(area)
                counts[area.rawKey] = chat.messages(for: area).count
            } catch {
            }
        }

        return DatenschutzExport(
            profil: profile.profile,
            notizen: notizen,
            aufgaben: aufgaben,
            chatNachrichtenJeBereich: counts
        )
    }
}
