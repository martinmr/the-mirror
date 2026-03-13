//
//  NotificationManager.swift
//  The Mirror
//

import UserNotifications
import UIKit
import Foundation

/// Singleton that manages notification permissions, scheduling, and response handling.
final class NotificationManager: NSObject {

    /// The shared singleton instance.
    static let shared = NotificationManager()

    /// Serial queue for scheduling notifications off the main thread.
    private let schedulingQueue = DispatchQueue(label: "mirror.scheduling")

    // MARK: - Notification identifiers

    private enum ID {
        static let main = "mirror.main"
        static let category = "mirror.category"
        static func timeout(_ n: Int) -> String { "mirror.timeout.\(n)" }
    }

    // MARK: - Action identifiers

    /// Identifiers for the two notification action buttons.
    enum Action: String {
        case present = "PRESENT"
        case distracted = "DISTRACTED"
    }

    // MARK: - Setup

    /// Registers the notification category, sets the delegate, and requests authorization. Call
    /// once at launch.
    func setUp() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let presentAction = UNNotificationAction(
            identifier: Action.present.rawValue,
            title: "Present",
            options: []
        )
        let distractedAction = UNNotificationAction(
            identifier: Action.distracted.rawValue,
            title: "Distracted",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: ID.category,
            actions: [presentAction, distractedAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NotificationManager] Auth error: \(error)")
            }
        }
    }

    // MARK: - Schedule

    /// Cancels pending notifications and schedules a new main notification plus follow-ups. No-op
    /// if not running.
    func scheduleNext() {
        guard Persistence.isRunning else { return }

        let intervalSecs = Persistence.intervalMinutes * 60.0
        let spacingSecs = max(10.0, Persistence.intervalMinutes / 2.0) * 60.0
        let sound = notificationSound()
        let quoteSet = Persistence.quoteSet

        Persistence.lastScheduledAt = Date()
        Persistence.nextFireDate = Date().addingTimeInterval(intervalSecs)

        schedulingQueue.async { [self] in
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()

            schedule(identifier: ID.main, at: intervalSecs, sound: sound, quoteSet: quoteSet, center: center)

            for i in 1...60 {
                let delay = intervalSecs + Double(i) * spacingSecs
                schedule(identifier: ID.timeout(i), at: delay, sound: sound, quoteSet: quoteSet, center: center)
            }

            DispatchQueue.main.async {
                TimerEngine.shared.syncFromPersistence()
            }
        }
     }

    /// Schedules a single notification with the given identifier, delay, and sound.
    private func schedule(
        identifier: String,
        at delay: TimeInterval,
        sound: UNNotificationSound?,
        quoteSet: QuoteSetID,
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = "The Mirror Timer"
        content.body = QuoteStore.nextQuote(for: quoteSet)
        content.categoryIdentifier = ID.category
        content.sound = sound

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error { print("[NotificationManager] Schedule error (\(identifier)): \(error)") }
        }
    }

    // MARK: - Foreground recovery

    /// Re-schedules the notification chain if no notifications are pending. No-op if not running.
    func ensureNotificationPending() {
        guard Persistence.isRunning else { return }

        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            let hasPending = requests.contains { $0.identifier.hasPrefix("mirror.") }
            if !hasPending {
                DispatchQueue.main.async {
                    self?.scheduleNext()
                }
            }
        }
    }

    // MARK: - Backoff algorithm

    /// Returns the next interval in minutes by scaling current by multiplier, clamping to [5, 60],
    /// and adding jitter.
    func nextInterval(current: Double, multiplier: Double) -> Double {
        let raw = current * multiplier
        let max_clamped = min(90.0, raw)
        let jitter = Double.random(in: 0.9...1.2)
        let min_clamped = max(5.0, max_clamped * jitter)
        return floor(min_clamped)
    }

    // MARK: - Sound helper

    /// Returns the UNNotificationSound for the user's sound preference.
    private func notificationSound() -> UNNotificationSound? {
        switch Persistence.sound {
        case .tingsha:
            if Bundle.main.url(forResource: "tingsha", withExtension: "caf") != nil {
                return UNNotificationSound(named: UNNotificationSoundName(rawValue: "tingsha.caf"))
            }
            return .default
        case .bowl:
            if Bundle.main.url(forResource: "bowl", withExtension: "caf") != nil {
                return UNNotificationSound(named: UNNotificationSoundName(rawValue: "bowl.caf"))
            }
            return .default
        }
    }

}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// When the app is foregrounded, suppresses the banner and triggers the in-app prompt instead.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard Persistence.isRunning else {
            completionHandler([])
            return
        }

        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        DispatchQueue.main.async {
            TimerEngine.shared.awaitingInput = true
        }
        completionHandler([.sound])
    }

    /// Handles a notification action and reschedules the next notification chain.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard Persistence.isRunning else { return }

        let actionID = response.actionIdentifier

        switch actionID {
        case UNNotificationDefaultActionIdentifier:
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            DispatchQueue.main.async {
                TimerEngine.shared.awaitingInput = true
            }

        case Action.present.rawValue:
            let next = nextInterval(current: Persistence.intervalMinutes, multiplier: 2.0)
            Persistence.intervalMinutes = next
            scheduleNext()

        case Action.distracted.rawValue:
            let next = nextInterval(current: Persistence.intervalMinutes, multiplier: 0.5)
            Persistence.intervalMinutes = next
            scheduleNext()

        case UNNotificationDismissActionIdentifier:
            break

        default:
            break
        }
    }
}
