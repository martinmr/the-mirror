//
//  Persistence.swift
//  The Mirror
//

import Foundation

// MARK: - Enums

/// Identifies which built-in quote set is active.
enum QuoteSetID: String, CaseIterable {
    case mirror = "mirror"
    case dreamYoga = "dreamYoga"

    /// Human-readable label shown in the UI.
    var displayName: String {
        switch self {
        case .mirror: return "The Mirror"
        case .dreamYoga: return "Dream Yoga"
        }
    }
}

/// The notification sound the user has selected.
enum SoundPreference: String, CaseIterable {
    case bowl = "bowl"
    case silent = "silent"

    /// Human-readable label shown in the UI.
    var displayName: String {
        switch self {
        case .bowl: return "Bowl"
        case .silent: return "Silent"
        }
    }
}

// MARK: - Persistence

/// Thin `UserDefaults` wrapper that centralises all persisted app state.
///
/// All properties are static; there is no instance to create.
struct Persistence {

    private enum Keys {
        static let intervalMinutes = "intervalMinutes"
        static let isRunning = "isRunning"
        static let quoteSet = "quoteSet"
        static let sound = "sound"
        static let quoteIndex = "quoteIndex"
        static let lastScheduledAt = "lastScheduledAt"
    }

    private static let defaults = UserDefaults.standard

    // MARK: Timer state

    /// Current notification interval in minutes.
    ///
    /// Falls back to `5.0` when no value has been stored (i.e. on first launch or after
    /// ``resetInterval()`` clears the key).
    static var intervalMinutes: Double {
        get {
            let v = defaults.double(forKey: Keys.intervalMinutes)
            return v > 0 ? v : 5.0
        }
        set { defaults.set(newValue, forKey: Keys.intervalMinutes) }
    }

    /// Whether the notification chain is currently active.
    static var isRunning: Bool {
        get { defaults.bool(forKey: Keys.isRunning) }
        set { defaults.set(newValue, forKey: Keys.isRunning) }
    }

    // MARK: Quote

    /// The quote set the user has selected. Defaults to `.mirror`.
    static var quoteSet: QuoteSetID {
        get {
            guard let raw = defaults.string(forKey: Keys.quoteSet),
                  let v = QuoteSetID(rawValue: raw) else { return .mirror }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.quoteSet) }
    }

    /// Sequential index into the active quote set, incremented by ``QuoteStore``.
    static var quoteIndex: Int {
        get { defaults.integer(forKey: Keys.quoteIndex) }
        set { defaults.set(newValue, forKey: Keys.quoteIndex) }
    }

    // MARK: Sound

    /// The notification sound the user has selected. Defaults to `.bowl`.
    static var sound: SoundPreference {
        get {
            guard let raw = defaults.string(forKey: Keys.sound),
                  let v = SoundPreference(rawValue: raw) else { return .bowl }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.sound) }
    }

    // MARK: Schedule metadata

    /// The timestamp at which the current notification pair was scheduled, or
    /// `nil` if the timer has never been started.
    static var lastScheduledAt: Date? {
        get {
            let t = defaults.double(forKey: Keys.lastScheduledAt)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let d = newValue {
                defaults.set(d.timeIntervalSince1970, forKey: Keys.lastScheduledAt)
            } else {
                defaults.removeObject(forKey: Keys.lastScheduledAt)
            }
        }
    }

    // MARK: Reset

    /// Clears the stored interval so that the next read returns the default starting value (5
    /// minutes in production).
    ///
    /// Called by ``TimerEngine/start()`` to reset the backoff on every new session.
    static func resetInterval() {
        defaults.removeObject(forKey: Keys.intervalMinutes)
    }
}
