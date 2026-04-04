import UserNotifications
import SwiftData
import AppKit

// MARK: – Action identifiers

private enum NotifAction {
    static let done       = "PLINK_DONE"
    static let snooze     = "PLINK_SNOOZE"
    static let reschedule = "PLINK_RESCHEDULE"
    static let category   = "PLINK_TASK"
}

// MARK: – Mute durations

enum MuteDuration: String, CaseIterable, Identifiable {
    case thirtyMin, oneHour, twoHours, endOfDay
    var id: String { rawValue }

    var label: String {
        switch self {
        case .thirtyMin: return NSLocalizedString("notif.mute.30m", comment: "")
        case .oneHour:   return NSLocalizedString("notif.mute.1h", comment: "")
        case .twoHours:  return NSLocalizedString("notif.mute.2h", comment: "")
        case .endOfDay:  return NSLocalizedString("notif.mute.eod", comment: "")
        }
    }

    var until: Date {
        let now = Date()
        switch self {
        case .thirtyMin: return now.addingTimeInterval(30 * 60)
        case .oneHour:   return now.addingTimeInterval(60 * 60)
        case .twoHours:  return now.addingTimeInterval(2 * 60 * 60)
        case .endOfDay:
            return Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: now)!
            )
        }
    }
}

// MARK: – Manager

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    private override init() { super.init() }

    @Published var authStatus: UNAuthorizationStatus = .notDetermined
    @Published var alertStyle: UNNotificationSetting = .notSupported

    // MARK: Settings (UserDefaults-backed)

    var globalEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "notif.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notif.enabled"); objectWillChange.send() }
    }

    var muteUntil: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: "notif.muteUntil")
            guard ts > 0 else { return nil }
            let d = Date(timeIntervalSince1970: ts)
            return d > Date() ? d : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "notif.muteUntil")
            objectWillChange.send()
        }
    }

    var isMuted: Bool { muteUntil != nil }

    var mutedGroupIDs: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "notif.mutedGroups"),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return Set(arr)
        }
        set {
            let data = try? JSONEncoder().encode(Array(newValue))
            UserDefaults.standard.set(data, forKey: "notif.mutedGroups")
            objectWillChange.send()
        }
    }

    func isGroupEnabled(groupID: String?) -> Bool {
        guard let id = groupID else { return true }
        return !mutedGroupIDs.contains(id)
    }

    // MARK: Setup

    func setup() {
        UNUserNotificationCenter.current().delegate = self

        let done = UNNotificationAction(
            identifier: NotifAction.done,
            title: NSLocalizedString("notif.action.done", comment: ""),
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: NotifAction.snooze,
            title: NSLocalizedString("notif.action.snooze", comment: ""),
            options: []
        )
        let reschedule = UNNotificationAction(
            identifier: NotifAction.reschedule,
            title: NSLocalizedString("notif.action.reschedule", comment: ""),
            options: []
        )
        let cat = UNNotificationCategory(
            identifier: NotifAction.category,
            actions: [done, snooze, reschedule],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([cat])
        Task { await refreshAuthStatus() }
    }

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthStatus()
    }

    func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus  = settings.authorizationStatus
        alertStyle  = settings.alertSetting
    }

    // MARK: Scheduling

    func schedule(for item: TodoItem) {
        cancel(for: item)
        guard item.hasDueTime, let date = item.dueDate,
              !item.isCompleted, !item.isDeleted else { return }

        let fireAt = date.addingTimeInterval(-15 * 60)
        guard fireAt > Date() else { return }
        guard globalEnabled, !isMuted else { return }
        guard isGroupEnabled(groupID: item.group?.id.uuidString) else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body  = notifBody(for: date)
        content.sound = .default
        content.categoryIdentifier = NotifAction.category
        content.userInfo = ["itemID": item.id.uuidString]

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: item.id.uuidString, content: content, trigger: trigger
        )
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("[Plink] Notification scheduling failed: \(error)")
            }
        }
    }

    func cancel(for item: TodoItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }

    /// Call when global settings change (mute on/off, group toggle, kill-switch).
    func rescheduleAll(_ items: [TodoItem]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard globalEnabled, !isMuted else { return }
        items.filter { !$0.isCompleted && !$0.isDeleted }.forEach { schedule(for: $0) }
    }

    private func notifBody(for date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return String(format: NSLocalizedString("notif.body", comment: ""), f.string(from: date))
    }
}

// MARK: – UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action    = response.actionIdentifier
        let itemIDStr = response.notification.request.content.userInfo["itemID"] as? String ?? ""
        Task { @MainActor in await handle(action: action, itemIDStr: itemIDStr) }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    @MainActor
    private func handle(action: String, itemIDStr: String) async {
        guard let uuid = UUID(uuidString: itemIDStr) else { return }
        let ctx = PersistenceController.shared.container.mainContext
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == uuid })
        guard let item = try? ctx.fetch(descriptor).first else { return }

        switch action {
        case NotifAction.done:
            item.isCompleted = true
            item.completedAt = Date()
            cancel(for: item)

        case NotifAction.snooze:
            // Fire another notification 30 min from now without changing the task's dueDate
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body  = notifBody(for: item.dueDate ?? Date())
            content.sound = .default
            content.categoryIdentifier = NotifAction.category
            content.userInfo = ["itemID": itemIDStr]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
            let req = UNNotificationRequest(
                identifier: "\(itemIDStr)_snooze", content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(req)

        case NotifAction.reschedule:
            if let d = item.dueDate {
                item.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: d)
                schedule(for: item)
            }

        default:
            // Tapped the notification body — bring app to front
            NSApp.activate(ignoringOtherApps: true)
        }

        try? ctx.save()
    }
}
