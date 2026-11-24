import Foundation
import LastysCore
import UserNotifications

/// Delivers Moment reminders as local notifications. Each call replaces every pending reminder.
final class NotificationReminderScheduler: NSObject, ReminderScheduler, UNUserNotificationCenterDelegate, @unchecked Sendable {
    /// iOS keeps at most 64 pending notifications per app; the soonest win.
    private static let limit = 64
    private let center = UNUserNotificationCenter.current()
    private let lock = NSLock()
    /// The previous replacement: each waits for the one before, so the last set given always wins.
    private var previous: Task<Void, Never>?

    override init() {
        super.init()
        // Notices arrive while Lastys is open (it checks when opened), so show them there too.
        center.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

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

    func notifyNow(_ notice: Notice) {
        let content = UNMutableNotificationContent()
        content.title = notice.message
        content.sound = .default
        let request = UNNotificationRequest(identifier: "notice-\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request)
    }

    private static func body(for when: Reminder.When) -> String {
        switch when {
        case .inDays(let days): return AppText.string("In \(days) days")
        case .tomorrow: return AppText.string("Tomorrow")
        case .today: return AppText.string("Today")
        }
    }
}

/// Reminds nobody, for SwiftUI previews.
struct PreviewReminderScheduler: ReminderScheduler {
    func replaceAll(with reminders: [Reminder]) {}
    func notifyNow(_ notice: Notice) {}
}

extension Notice {
    /// One wording for a notice, in the notification and on Home.
    var message: String {
        switch self {
        case .recoveryStarted: return AppText.string("Someone started a Recovery of your Lastys ID. If it wasn't you, cancel it in Me.")
        case .partnerChangedPhone: return AppText.string("Your Partner's Lastys ID moved to a new phone.")
        case .partnerStartedRecovery: return AppText.string("A Recovery of your Partner's Lastys ID has started.")
        }
    }
}
