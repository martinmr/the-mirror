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
        static let timeout = "mirror.timeout"
        static let category = "mirror.category"
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

    // MARK: - Schedule next notification pair

    /// Cancels any pending notifications and schedules a new pair:
    /// - **Main** notification at the current interval from now.
    /// - **Timeout** notification at the current interval + 5 minutes from now.
    ///
    /// If the user responds to the main notification, the timeout is cancelled. If the user ignores
    /// the main, the timeout fires and the ignore penalty is applied when the user eventually taps
    /// it.
    ///
    /// Does nothing if ``Persistence/isRunning`` is `false`.
    func scheduleNext() {
        guard Persistence.isRunning else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ID.main, ID.timeout])

        let intervalSecs = Persistence.intervalMinutes * 60.0
        let timeoutSecs = intervalSecs + 5 * 60.0

        let quote = QuoteStore.nextQuote(for: Persistence.quoteSet)
        let sound = notificationSound()

        // Main notification
        let mainContent = UNMutableNotificationContent()
        mainContent.title = "The Mirror"
        mainContent.body = quote
        mainContent.categoryIdentifier = ID.category
        mainContent.sound = sound  // nil = vibrate only
        mainContent.userInfo = ["notifType": "main"]

        let mainTrigger = UNTimeIntervalNotificationTrigger(timeInterval: intervalSecs, repeats: false)
        let mainRequest = UNNotificationRequest(identifier: ID.main, content: mainContent, trigger: mainTrigger)

        // Timeout notification (fires if user ignores main)
        let timeoutContent = UNMutableNotificationContent()
        let timeoutQuote = QuoteStore.nextQuote(for: Persistence.quoteSet)
        timeoutContent.title = "The Mirror"
        timeoutContent.body = timeoutQuote
        timeoutContent.categoryIdentifier = ID.category
        timeoutContent.sound = sound  // nil = vibrate only
        timeoutContent.userInfo = ["notifType": "timeout"]

        let timeoutTrigger = UNTimeIntervalNotificationTrigger(timeInterval: timeoutSecs, repeats: false)
        let timeoutRequest = UNNotificationRequest(identifier: ID.timeout, content: timeoutContent, trigger: timeoutTrigger)

        center.add(mainRequest) { error in
            if let error = error { print("[NotificationManager] Main schedule error: \(error)") }
        }
        center.add(timeoutRequest) { error in
            if let error = error { print("[NotificationManager] Timeout schedule error: \(error)") }
        }

        Persistence.lastScheduledAt = Date()
    }

    // MARK: - Foreground recovery

    /// Checks whether a notification is still pending and, if not, schedules a new one immediately.
    ///
    /// Should be called every time the app enters the foreground so that the notification chain can
    /// recover if a background wakeup was terminated by iOS before scheduling completed.
    ///
    /// Does nothing if ``Persistence/isRunning`` is `false`.
    func ensureNotificationPending() {
        guard Persistence.isRunning else { return }

        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            let hasPending = requests.contains { $0.identifier == ID.main || $0.identifier == ID.timeout }
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
    ///   - multiplier: Scaling factor — `2.0` for Present, `0.5` for Distracted, `0.75` for
    ///     Ignored.
    /// - Returns: The next interval in minutes, floored to a whole minute for values ≥ 1 minute.
    private func nextInterval(current: Double, multiplier: Double) -> Double {
        let raw = current * multiplier
        let jitter = Double.random(in: 0.75...1.25)
        let jittered = raw * jitter
        let clamped = max(5.0, min(90.0, jittered))
        // floor() only makes sense for whole-minute production values; skip it sub-minute
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
            // Use bowl.caf if bundled, fall back to default
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

    /// Processes the user's response to a notification action and schedules the next notification
    /// pair with the appropriate backoff multiplier.
    ///
    /// Response cases:
    /// - **Present** action — cancels the timeout, doubles the interval.
    /// - **Distracted** action — cancels the timeout, halves the interval.
    /// - **Default tap** on the main notification — treated as Present.
    /// - **Default tap** on the timeout notification — applies the ×0.75 ignore penalty.
    /// - **Dismiss** on the main notification — leaves the timeout pending.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard Persistence.isRunning else { return }

        let notifType = response.notification.request.content.userInfo["notifType"] as? String ?? "main"
        let actionID = response.actionIdentifier

        switch actionID {
        case Action.present.rawValue:
            center.removePendingNotificationRequests(withIdentifiers: [ID.timeout])
            let next = nextInterval(current: Persistence.intervalMinutes, multiplier: 2.0)
            Persistence.intervalMinutes = next
            scheduleNext()

        case Action.distracted.rawValue:
            center.removePendingNotificationRequests(withIdentifiers: [ID.timeout])
            let next = nextInterval(current: Persistence.intervalMinutes, multiplier: 0.5)
            Persistence.intervalMinutes = next
            scheduleNext()

        case UNNotificationDefaultActionIdentifier:
            if notifType == "timeout" {
                // Timeout fired: treat original as Ignored (×0.75)
                center.removePendingNotificationRequests(withIdentifiers: [ID.main])
                let next = nextInterval(current: Persistence.intervalMinutes, multiplier: 0.75)
                Persistence.intervalMinutes = next
                scheduleNext()
            } else {
                // Main notification tapped without action — treat as Present
                center.removePendingNotificationRequests(withIdentifiers: [ID.timeout])
                let next = nextInterval(current: Persistence.intervalMinutes, multiplier: 2.0)
                Persistence.intervalMinutes = next
                scheduleNext()
            }

        case UNNotificationDismissActionIdentifier:
            // Main dismissed: leave timeout pending — it will handle the ignore.
            // Timeout dismissed: chain pauses; foreground recovery handles it.
            break

        default:
            break
        }
    }
}
