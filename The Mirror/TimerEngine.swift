//
//  TimerEngine.swift
//  The Mirror
//

import Foundation
import Combine

/// UI-facing state holder for the notification timer.
///
/// Publishes the current timer and settings state so SwiftUI views can react
/// to changes. All scheduling is delegated to ``NotificationManager``; this
/// class reads from and writes to ``Persistence`` as the source of truth.
final class TimerEngine: ObservableObject {

    /// The shared singleton instance.
    static let shared = TimerEngine()

    /// Whether the notification chain is currently active.
    @Published var isRunning: Bool = Persistence.isRunning

    /// The current notification interval in minutes.
    @Published var intervalMinutes: Double = Persistence.intervalMinutes

    /// The active quote set.
    @Published var quoteSet: QuoteSetID = Persistence.quoteSet

    /// The active sound preference.
    @Published var sound: SoundPreference = Persistence.sound

    private init() {}

    // MARK: - Actions

    /// Resets the interval to its default, marks the timer as running, and
    /// schedules the first notification pair.
    func start() {
        Persistence.resetInterval()
        Persistence.isRunning = true
        syncFromPersistence()
        NotificationManager.shared.scheduleNext()
    }

    /// Marks the timer as stopped and cancels all pending notifications.
    func stop() {
        Persistence.isRunning = false
        UNUserNotificationCenterWrapper.cancelAll()
        syncFromPersistence()
    }

    /// Syncs published state from ``Persistence`` and delegates to
    /// ``NotificationManager/ensureNotificationPending()`` to re-schedule if
    /// the chain broke while the app was in the background.
    func recover() {
        syncFromPersistence()
        NotificationManager.shared.ensureNotificationPending()
    }

    // MARK: - Settings mutations

    /// Persists the selected quote set and updates the published property.
    ///
    /// - Parameter set: The quote set the user selected.
    func setQuoteSet(_ set: QuoteSetID) {
        Persistence.quoteSet = set
        quoteSet = set
    }

    /// Persists the selected sound preference and updates the published property.
    ///
    /// - Parameter pref: The sound preference the user selected.
    func setSound(_ pref: SoundPreference) {
        Persistence.sound = pref
        sound = pref
    }

    // MARK: - Sync

    /// Reads all persisted values and updates the corresponding published
    /// properties so the UI reflects the current state.
    ///
    /// Called on foreground transitions and after any state-mutating action.
    func syncFromPersistence() {
        isRunning = Persistence.isRunning
        intervalMinutes = Persistence.intervalMinutes
        quoteSet = Persistence.quoteSet
        sound = Persistence.sound
    }
}

// MARK: - Thin wrapper so TimerEngine doesn't import UserNotifications

import UserNotifications

private enum UNUserNotificationCenterWrapper {
    /// Removes all pending local notification requests for this app.
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
