import Foundation
import UserNotifications
import MykilosKit

public enum SignalNotificationPreferences {
    private static let enabledKey = "signale.mitteilungen.global"
    private static let lautlosKey = "signale.mitteilungen.lautlos"

    public static var isActive: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    public static var lautlos: Bool {
        get { UserDefaults.standard.bool(forKey: lautlosKey) }
        set { UserDefaults.standard.set(newValue, forKey: lautlosKey) }
    }
}

public enum SignalNotificationDispatcher {
    static func content(fuer signal: WidgetSignal) -> (title: String, text: String)? {
        switch signal {
        case let .offerDetected(projectID, label):
            return ("Neues Angebot erkannt", "\(projectID): \(label)")
        case let .drawingDetected(projectID, label):
            return ("Neue Werkzeichnung erkannt", "\(projectID): \(label)")
        case let .myClickUpTaskDueSoon(projectID, taskName, days):
            let faelligkeit = days == 0 ? "heute fällig" : (days == 1 ? "morgen fällig" : "in \(days) Tagen fällig")
            return ("Eigene Aufgabe \(faelligkeit)", "\(projectID): \(taskName)")
        case .driveFileAdded, .projectFocused, .reviewSuggested, .budgetThresholdCrossed, .deadlineNear:
            return nil
        }
    }

    public static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
        }
    }

    private static let dedupLock = NSLock()
    nonisolated(unsafe) private static var bereitsBenachrichtigt: Set<String> = []

    public static func benachrichtige(fuer signal: WidgetSignal) async {
        guard SignalNotificationPreferences.isActive, let payload = Self.content(fuer: signal) else { return }
        let key = "\(payload.title)|\(payload.text)"
        dedupLock.lock()
        let schonGefeuert = bereitsBenachrichtigt.contains(key)
        if !schonGefeuert { bereitsBenachrichtigt.insert(key) }
        dedupLock.unlock()
        if schonGefeuert { return }
        await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.text
        content.sound = SignalNotificationPreferences.lautlos ? nil : .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
        }
    }

    public static func benachrichtigeSendungZugestellt(projectNumber: String?, label: String) async {
        guard SignalNotificationPreferences.isActive else { return }
        let target = (projectNumber?.isEmpty == false) ? "\(projectNumber!): " : ""
        let payload = (title: "DHL-Sendung zugestellt", text: "\(target)\(label)")
        let key = "\(payload.title)|\(payload.text)"
        dedupLock.lock()
        let schonGefeuert = bereitsBenachrichtigt.contains(key)
        if !schonGefeuert { bereitsBenachrichtigt.insert(key) }
        dedupLock.unlock()
        if schonGefeuert { return }
        await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.text
        content.sound = SignalNotificationPreferences.lautlos ? nil : .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
