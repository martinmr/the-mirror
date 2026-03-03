//
//  NotificationManager.swift
//  The Mirror
//

import UserNotifications
import Foundation

/// Manages the entire local notification lifecycle: permission request, category registration,
/// scheduling, and response handling.
///
/// The singleton is the `UNUserNotificationCenterDelegate` for the app and writes directly to
/// ``Persistence``, so it operates correctly even when the app is cold-launched by a notification
/// action (before SwiftUI is initialised).
final class NotificationManager: NSObject {

    /// The shared singleton instance.
    static let shared = NotificationManager()

    // MARK: - Notification identifiers

    private enum ID {
        static let main = "mirror.main"
        static let category = "mirror.category"
        static func timeout(_ n: Int) -> String { "mirror.timeout.\(n)" }
    }

    // MARK: - Action identifiers

    /// Raw-value identifiers for the two notification action buttons.
    enum Action: String {
        case present = "PRESENT"
        case distracted = "DISTRACTED"
    }

    // MARK: - Setup

    /// Registers the notification category and its actions, assigns `self` as the
    /// `UNUserNotificationCenter` delegate, and requests authorisation.
    ///
    /// Must be called once at app launch, before any scheduling takes place.
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

    /// Cancels all pending notifications and schedules a main notification plus up to 20 follow-ups.
    ///
    /// - Main fires at the current interval.
    /// - Follow-ups are spaced `min(5, interval/2)` minutes apart after the main, so the chain
    ///   survives even if the user ignores every notification until they next open the app.
    /// - All pending notifications are cancelled when the user responds to any one of them.
    ///
    /// Does nothing if ``Persistence/isRunning`` is `false`.
    func scheduleNext() {
        guard Persistence.isRunning else { return }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let intervalSecs = Persistence.intervalMinutes * 60.0
        let spacingSecs = min(5.0, Persistence.intervalMinutes / 2.0) * 60.0
        let sound = notificationSound()

        schedule(identifier: ID.main, at: intervalSecs, sound: sound, center: center)

        for i in 1...20 {
            let delay = intervalSecs + Double(i) * spacingSecs
            schedule(identifier: ID.timeout(i), at: delay, sound: sound, center: center)
        }

        Persistence.lastScheduledAt = Date()
    }

    private func schedule(
        identifier: String,
        at delay: TimeInterval,
        sound: UNNotificationSound?,
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = "The Mirror"
        content.body = QuoteStore.nextQuote(for: Persistence.quoteSet)
        content.categoryIdentifier = ID.category
        content.sound = sound

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error { print("[NotificationManager] Schedule error (\(identifier)): \(error)") }
        }
    }

    // MARK: - Foreground recovery

    /// Checks whether any notification is still pending and, if not, schedules a new chain.
    ///
    /// Should be called every time the app enters the foreground so that the notification chain can
    /// recover if a background wakeup was terminated by iOS before scheduling completed.
    ///
    /// Does nothing if ``Persistence/isRunning`` is `false`.
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

    /// Computes the next notification interval using exponential backoff with ±25 % jitter, clamped
    /// to [5, 90] minutes.
    ///
    /// - Parameters:
    ///   - current: The current interval in minutes.
    ///   - multiplier: Scaling factor — `2.0` for Present, `0.5` for Distracted.
    /// - Returns: The next interval in minutes, floored to a whole minute for values ≥ 1 minute.
    func nextInterval(current: Double, multiplier: Double) -> Double {
        let raw = current * multiplier
        let jitter = Double.random(in: 0.75...1.25)
        let jittered = raw * jitter
        let clamped = max(5.0, min(90.0, jittered))
        return clamped < 1.0 ? clamped : floor(clamped)
    }

    // MARK: - Sound helper

    /// Returns the `UNNotificationSound` that matches the user's preference.
    ///
    /// Returns `nil` for silent (vibration only) or the bowl sound for `.bowl`.
    ///
    /// Falls back to the system default sound when `bowl.caf` is not bundled.
    private func notificationSound() -> UNNotificationSound? {
        switch Persistence.sound {
        case .silent:
            return nil
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

    /// Allows notifications to be displayed as banners while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Processes the user's response to any notification and schedules the next chain.
    ///
    /// All pending notifications are cancelled on any response. The multiplier applied depends
    /// on the action tapped — Present (×2.0), Distracted (×0.5), or default tap (×2.0).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard Persistence.isRunning else { return }

        let actionID = response.actionIdentifier

        switch actionID {
        case Action.present.rawValue, UNNotificationDefaultActionIdentifier:
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            let next = nextInterval(current: Persistence.intervalMinutes, multiplier: 2.0)
            Persistence.intervalMinutes = next
            scheduleNext()

        case Action.distracted.rawValue:
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
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
