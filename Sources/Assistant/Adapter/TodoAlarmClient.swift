import Core
import Foundation
import UserNotifications

public struct TodoAlarmClient: AlarmPort {
    static let enabledKey = "assistant.alarm.enabled"
    static let soundKey = "assistant.alarm.sound"
    static let titleKey = "assistant.alarm.title"
    static let identifierPrefix = "alfa.todo."

    private let text: any TextPort
    private let suite: String?

    public init(text: any TextPort, suite: String? = nil) {
        self.text = text
        self.suite = suite
    }

    private var defaults: UserDefaults {
        suite.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    var preference: AlarmPreference {
        get {
            AlarmPreference(
                isEnabled: defaults.object(forKey: Self.enabledKey) as? Bool ?? true,
                sound: AlarmPreference.Sound(rawValue: defaults.string(forKey: Self.soundKey) ?? "") ?? .standard)
        }
        nonmutating set {
            defaults.set(newValue.isEnabled, forKey: Self.enabledKey)
            defaults.set(newValue.sound.rawValue, forKey: Self.soundKey)
        }
    }

    static func shouldAlarm(_ todo: Todo, enabled: Bool, now: Date) -> Bool {
        guard todo.alarmActive, todo.done == false, enabled, let due = todo.dueDate else { return false }
        return due > now
    }

    static func identifier(_ todoID: String) -> String { identifierPrefix + todoID }

    public func reschedule(_ todo: Todo) async {
        let current = preference
        guard Self.shouldAlarm(todo, enabled: current.isEnabled, now: Date()), let due = todo.dueDate else {
            await cancel(todoID: todo.id)
            return
        }
        await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = text.text(Self.titleKey, [])
        content.body = todo.title
        if current.sound == .standard { content.sound = .default }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier(todo.id), content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Log.failure("TodoAlarmUnset", detail: String(describing: error))
        }
    }

    public func cancel(todoID: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier(todoID)])
    }

    private func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.failure("TodoAlarmUnauthorized", detail: String(describing: error))
        }
    }
}

struct AlarmPreference: Sendable, Equatable {
    enum Sound: String, CaseIterable, Codable, Sendable {
        case standard
        case silent
    }

    var isEnabled: Bool
    var sound: Sound

    init(isEnabled: Bool = true, sound: Sound = .standard) {
        self.isEnabled = isEnabled
        self.sound = sound
    }
}
