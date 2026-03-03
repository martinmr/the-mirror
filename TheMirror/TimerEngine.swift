//
//  TimerEngine.swift
//  The Mirror
//

import Foundation
import Combine
import UserNotifications

/// Observable state holder for the notification timer; delegates scheduling to NotificationManager.
@MainActor
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

    /// True while the app is waiting for the user to answer an in-app prompt.
    @Published var awaitingInput = false

    /// When the next notification is expected to fire, or nil if not running.
    @Published var nextFireDate: Date? = Persistence.nextFireDate

    private init() {}

    // MARK: - Actions

    /// Resets the interval, marks the timer as running, and schedules the first notification.
    func start() {
        Persistence.resetInterval()
        Persistence.isRunning = true
        syncFromPersistence()
        NotificationManager.shared.scheduleNext()
        nextFireDate = Persistence.nextFireDate
    }

    /// Stops the timer and cancels all pending notifications.
    func stop() {
        Persistence.isRunning = false
        Persistence.nextFireDate = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        syncFromPersistence()
    }

    /// Syncs state from persistence and re-schedules the notification chain if it broke in the background.
    func recover() {
        syncFromPersistence()
        NotificationManager.shared.ensureNotificationPending()
    }

    /// Handles a Present/Distracted response from the in-app prompt.
    func respondToPrompt(_ action: NotificationManager.Action) {
        awaitingInput = false
        let multiplier = action == .present ? 2.0 : 0.5
        let next = NotificationManager.shared.nextInterval(current: Persistence.intervalMinutes, multiplier: multiplier)
        Persistence.intervalMinutes = next
        syncFromPersistence()
        NotificationManager.shared.scheduleNext()
        nextFireDate = Persistence.nextFireDate
    }

    // MARK: - Settings mutations

    /// Persists the selected quote set and updates the published property.
    func setQuoteSet(_ set: QuoteSetID) {
        Persistence.quoteSet = set
        quoteSet = set
    }

    /// Persists the selected sound preference and updates the published property.
    func setSound(_ pref: SoundPreference) {
        Persistence.sound = pref
        sound = pref
    }

    // MARK: - Sync

    /// Reads all persisted values and refreshes the published properties.
    func syncFromPersistence() {
        isRunning = Persistence.isRunning
        intervalMinutes = Persistence.intervalMinutes
        quoteSet = Persistence.quoteSet
        sound = Persistence.sound
        nextFireDate = Persistence.nextFireDate
    }

}
