import Foundation
import LastysCore
import UserNotifications

/// Delivers Moment reminders as local notifications. Each call replaces every pending reminder.
final class NotificationReminderScheduler: ReminderScheduler, @unchecked Sendable {
    /// iOS keeps at most 64 pending notifications per app; the soonest win.
    private static let limit = 64
    private let center = UNUserNotificationCenter.current()
    private let lock = NSLock()
    /// The previous replacement: each waits for the one before, so the last set given always wins.
    private var previous: Task<Void, Never>?

    func replaceAll(with reminders: [Reminder]) {
        let soonest = Array(reminders.sorted { $0.fires < $1.fires }.prefix(Self.limit))
        lock.withLock {
            let before = previous
            previous = Task { [center] in
                await before?.value
                await Self.replace(with: soonest, in: center)
            }
        }
    }

    private static func replace(with soonest: [Reminder], in center: UNUserNotificationCenter) async {
        do {
            center.removeAllPendingNotificationRequests()
            guard !soonest.isEmpty else { return }
            // Ask the first time there is something to remind about.
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            for (index, reminder) in soonest.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = Self.body(for: reminder.when)
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fires)
                let request = UNNotificationRequest(
                    identifier: "moment-\(reminder.momentID.uuidString)-\(index)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    private static func body(for when: Reminder.When) -> String {
        switch when {
        case .inDays(let days): return String(localized: "In \(days) days")
        case .tomorrow: return String(localized: "Tomorrow")
        case .today: return String(localized: "Today")
        }
    }
}

/// Reminds nobody, for SwiftUI previews.
struct PreviewReminderScheduler: ReminderScheduler {
    func replaceAll(with reminders: [Reminder]) {}
}
