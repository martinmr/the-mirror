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

    /// Human-readable name for display.
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

    /// Human-readable name for display.
    var displayName: String {
        switch self {
        case .bowl: return "Bowl"
        case .silent: return "Silent"
        }
    }
}

// MARK: - Persistence

/// Static UserDefaults wrapper for all persisted app state.
struct Persistence {

    private enum Keys {
        static let intervalMinutes = "intervalMinutes"
        static let isRunning = "isRunning"
        static let quoteSet = "quoteSet"
        static let sound = "sound"
        static let quoteIndex = "quoteIndex"
        static let lastScheduledAt = "lastScheduledAt"
        static let nextFireDate = "nextFireDate"
    }

    private static let defaults = UserDefaults.standard

    // MARK: Timer state

    /// Notification interval in minutes; defaults to 5.0.
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

    /// Selected quote set; defaults to .mirror.
    static var quoteSet: QuoteSetID {
        get {
            guard let raw = defaults.string(forKey: Keys.quoteSet),
                  let v = QuoteSetID(rawValue: raw) else { return .mirror }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.quoteSet) }
    }

    /// Sequential index into the active quote set.
    static var quoteIndex: Int {
        get { defaults.integer(forKey: Keys.quoteIndex) }
        set { defaults.set(newValue, forKey: Keys.quoteIndex) }
    }

    // MARK: Sound

    /// Selected notification sound; defaults to .bowl.
    static var sound: SoundPreference {
        get {
            guard let raw = defaults.string(forKey: Keys.sound),
                  let v = SoundPreference(rawValue: raw) else { return .bowl }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.sound) }
    }

    // MARK: Schedule metadata

    /// Timestamp of the last scheduled notification batch, or nil if never started.
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

    /// Date when the next notification is expected to fire, or nil if not running.
    static var nextFireDate: Date? {
        get {
            let t = defaults.double(forKey: Keys.nextFireDate)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let d = newValue {
                defaults.set(d.timeIntervalSince1970, forKey: Keys.nextFireDate)
            } else {
                defaults.removeObject(forKey: Keys.nextFireDate)
            }
        }
    }

    // MARK: Reset

    /// Clears the stored interval so the next read returns the default (5 minutes).
    static func resetInterval() {
        defaults.removeObject(forKey: Keys.intervalMinutes)
    }
}
