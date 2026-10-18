import Foundation
import UserNotifications
import AlfaKit

public enum TaskAlarmSound: String, CaseIterable, Codable, Sendable {
    case standard, lautlos

    public var label: String {
        switch self {
        case .standard: return "Standard"
        case .lautlos:  return "Lautlos"
        }
    }

    var unNotificationSound: UNNotificationSound? {
        switch self {
        case .standard: return .default
        case .lautlos:  return nil
        }
    }
}

public enum TaskAlarmPreferences {
    private static let enabledKey = "aufgaben.alarm.global"
    private static let soundKey = "aufgaben.alarm.ton"

    public static var global: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    public static var sound: TaskAlarmSound {
        get { TaskAlarmSound(rawValue: UserDefaults.standard.string(forKey: soundKey) ?? "") ?? .standard }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: soundKey) }
    }
}

public enum TaskAlarmScheduler {
    public static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
        }
    }

    static func sollAlarmieren(_ task: AssistantTask, globalErlaubt: Bool, jetzt: Date) -> Bool {
        guard task.alarmAktiv, task.done == false, globalErlaubt,
              let dueDate = task.dueDate else { return false }
        return dueDate > jetzt
    }

    public static func reschedule(_ task: AssistantTask) async {
        guard sollAlarmieren(task, globalErlaubt: TaskAlarmPreferences.global, jetzt: Date()),
              let dueDate = task.dueDate else {
            cancel(taskID: task.id)
            return
        }

        await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "Aufgabe fällig"
        content.body = task.title
        if let sound = TaskAlarmPreferences.sound.unNotificationSound {
            content.sound = sound
        }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier(for: task.id), content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
        }
    }

    public static func cancel(taskID: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: taskID)])
    }

    private static func identifier(for taskID: String) -> String { "myk.aufgabe.\(taskID)" }
}
