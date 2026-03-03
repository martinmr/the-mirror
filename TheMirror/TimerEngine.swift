//
//  TimerEngine.swift
//  The Mirror
//

import Foundation
import Combine
import UserNotifications

/// UI-facing state holder for the notification timer.
///
/// Publishes the current timer and settings state so SwiftUI views can react to changes. All
/// scheduling is delegated to ``NotificationManager``; this class reads from and writes to
/// ``Persistence`` as the source of truth.
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

    /// `true` while the app is waiting for the user to answer a plain-tap prompt in-app.
    @Published var awaitingInput = false

    /// Whole minutes until the next notification fires. Only meaningful when `isRunning` is `true`.
    @Published var minutesUntilNext: Int = 0

    /// Fires every 60 seconds while the timer is running to keep ``minutesUntilNext`` current.
    private var countdownTimer: Timer?

    private init() {}

    // MARK: - Actions

    /// Resets the interval to its default, marks the timer as running, and
    /// schedules the first notification pair.
    func start() {
        Persistence.resetInterval()
        Persistence.isRunning = true
        syncFromPersistence()
        NotificationManager.shared.scheduleNext()
        startCountdown()
    }

    /// Marks the timer as stopped and cancels all pending notifications.
    func stop() {
        Persistence.isRunning = false
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        syncFromPersistence()
        stopCountdown()
    }

    /// Syncs published state from ``Persistence`` and delegates to
    /// ``NotificationManager/ensureNotificationPending()`` to re-schedule if the chain broke while
    /// the app was in the background.
    func recover() {
        syncFromPersistence()
        NotificationManager.shared.ensureNotificationPending()
        if isRunning { startCountdown() }
    }

    /// Handles a Present/Distracted response from the in-app prompt shown after a plain tap.
    func respondToPrompt(_ action: NotificationManager.Action) {
        awaitingInput = false
        let multiplier = action == .present ? 2.0 : 0.5
        let next = NotificationManager.shared.nextInterval(current: Persistence.intervalMinutes, multiplier: multiplier)
        Persistence.intervalMinutes = next
        syncFromPersistence()
        NotificationManager.shared.scheduleNext()
        refreshMinutesUntilNext()
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

    /// Reads all persisted values and updates the corresponding published properties so the UI
    /// reflects the current state.
    ///
    /// Called on foreground transitions and after any state-mutating action.
    func syncFromPersistence() {
        isRunning = Persistence.isRunning
        intervalMinutes = Persistence.intervalMinutes
        quoteSet = Persistence.quoteSet
        sound = Persistence.sound
    }

    // MARK: - Countdown

    /// Computes ``minutesUntilNext`` immediately, then starts a 60-second repeating timer that
    /// keeps it up to date while the app is in the foreground.
    private func startCountdown() {
        refreshMinutesUntilNext()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshMinutesUntilNext()
        }
    }

    /// Invalidates the countdown timer and resets ``minutesUntilNext`` to zero.
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        minutesUntilNext = 0
    }

    /// Derives ``minutesUntilNext`` from ``Persistence/lastScheduledAt`` and the current interval,
    /// rounding up so the display reads 1 min until the last second rather than dropping to 0.
    private func refreshMinutesUntilNext() {
        guard let lastScheduled = Persistence.lastScheduledAt else { return }
        let nextFireDate = lastScheduled.addingTimeInterval(Persistence.intervalMinutes * 60)
        let remaining = nextFireDate.timeIntervalSinceNow
        minutesUntilNext = max(0, Int(ceil(remaining / 60)))
    }
}
