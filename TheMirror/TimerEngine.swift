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

    /// Whole minutes until the next notification fires.
    @Published var minutesUntilNext: Int = 0

    /// Repeating timer that keeps minutesUntilNext current while the app is foregrounded.
    private var countdownTimer: Timer?

    private init() {}

    // MARK: - Actions

    /// Resets the interval, marks the timer as running, and schedules the first notification.
    func start() {
        Persistence.resetInterval()
        Persistence.isRunning = true
        syncFromPersistence()
        NotificationManager.shared.scheduleNext()
        startCountdown()
    }

    /// Stops the timer and cancels all pending notifications.
    func stop() {
        Persistence.isRunning = false
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        syncFromPersistence()
        stopCountdown()
    }

    /// Syncs state from persistence and re-schedules the notification chain if it broke in the background.
    func recover() {
        syncFromPersistence()
        NotificationManager.shared.ensureNotificationPending()
        if isRunning { startCountdown() }
    }

    /// Handles a Present/Distracted response from the in-app prompt.
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
    }

    // MARK: - Countdown

    /// Starts a 60-second repeating timer to keep minutesUntilNext up to date.
    private func startCountdown() {
        refreshMinutesUntilNext()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMinutesUntilNext()
            }
        }
    }

    /// Stops the countdown timer and resets minutesUntilNext to zero.
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        minutesUntilNext = 0
    }

    /// Recalculates minutesUntilNext from the last scheduled timestamp, rounding up.
    private func refreshMinutesUntilNext() {
        guard let lastScheduled = Persistence.lastScheduledAt else { return }
        let nextFireDate = lastScheduled.addingTimeInterval(Persistence.intervalMinutes * 60)
        let remaining = nextFireDate.timeIntervalSinceNow
        minutesUntilNext = max(0, Int(ceil(remaining / 60)))
    }
}
