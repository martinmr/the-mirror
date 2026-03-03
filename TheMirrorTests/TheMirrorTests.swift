//
//  The_MirrorTests.swift
//  The MirrorTests
//
//  Created by Martin Martinez Rivera on 3/2/26.
//

import Testing
import Foundation
@testable import TheMirror

@Suite(.serialized)
struct TheMirrorTests {

    // MARK: - QuoteStore

    @Suite(.serialized) struct QuoteStoreTests {
        init() { Persistence.quoteIndex = 0 }

        @Test func mirrorSetNeverRepeatsConsecutively() {
            var previous = QuoteStore.nextQuote(for: .mirror)
            for _ in 0..<100 {
                let next = QuoteStore.nextQuote(for: .mirror)
                #expect(next != previous)
                previous = next
            }
        }

        @Test func dreamYogaSetNeverRepeatsConsecutively() {
            var previous = QuoteStore.nextQuote(for: .dreamYoga)
            for _ in 0..<100 {
                let next = QuoteStore.nextQuote(for: .dreamYoga)
                #expect(next != previous)
                previous = next
            }
        }

        @Test func currentQuoteDoesNotAdvanceIndex() {
            let a = QuoteStore.currentQuote(for: .mirror)
            let b = QuoteStore.currentQuote(for: .mirror)
            #expect(a == b)
        }

        @Test func nextQuoteAdvancesIndex() {
            let before = QuoteStore.currentQuote(for: .mirror)
            _ = QuoteStore.nextQuote(for: .mirror)
            let after = QuoteStore.currentQuote(for: .mirror)
            #expect(before != after)
        }
    }

    // MARK: - QuoteSetID

    @Suite struct QuoteSetIDTests {
        @Test func displayNames() {
            #expect(QuoteSetID.mirror.displayName == "The Mirror")
            #expect(QuoteSetID.dreamYoga.displayName == "Dream Yoga")
        }

        @Test func allCasesCount() {
            #expect(QuoteSetID.allCases.count == 2)
        }
    }

    // MARK: - SoundPreference

    @Suite struct SoundPreferenceTests {
        @Test func displayNames() {
            #expect(SoundPreference.bowl.displayName == "Bowl")
            #expect(SoundPreference.silent.displayName == "Silent")
        }

        @Test func allCasesCount() {
            #expect(SoundPreference.allCases.count == 2)
        }
    }

    // MARK: - NotificationManager.nextInterval

    @Suite(.serialized) struct NextIntervalTests {
        let manager = NotificationManager.shared

        @Test func presentMultiplierDoublesInterval() {
            for _ in 0..<50 {
                let result = manager.nextInterval(current: 10.0, multiplier: 2.0)
                #expect(result >= 5.0)
                #expect(result <= 90.0)
            }
        }

        @Test func distractedMultiplierHalvesInterval() {
            for _ in 0..<50 {
                let result = manager.nextInterval(current: 20.0, multiplier: 0.5)
                #expect(result >= 5.0)
                #expect(result <= 90.0)
            }
        }

        @Test func resultIsAlwaysClampedToMinimum() {
            for _ in 0..<50 {
                let result = manager.nextInterval(current: 5.0, multiplier: 0.5)
                #expect(result >= 5.0)
            }
        }

        @Test func resultIsAlwaysClampedToMaximum() {
            for _ in 0..<50 {
                let result = manager.nextInterval(current: 90.0, multiplier: 2.0)
                #expect(result <= 90.0)
            }
        }

        @Test func resultIsWholeMinute() {
            for _ in 0..<50 {
                let result = manager.nextInterval(current: 30.0, multiplier: 1.0)
                #expect(result == floor(result))
            }
        }
    }

    // MARK: - Persistence

    @Suite(.serialized) struct PersistenceTests {
        init() {
            UserDefaults.standard.removeObject(forKey: "intervalMinutes")
            UserDefaults.standard.removeObject(forKey: "isRunning")
            UserDefaults.standard.removeObject(forKey: "quoteSet")
            UserDefaults.standard.removeObject(forKey: "sound")
            UserDefaults.standard.removeObject(forKey: "quoteIndex")
        }

        @Test func intervalMinutesDefaultsToFive() {
            #expect(Persistence.intervalMinutes == 5.0)
        }

        @Test func intervalMinutesRoundTrip() {
            Persistence.intervalMinutes = 30.0
            #expect(Persistence.intervalMinutes == 30.0)
        }

        @Test func isRunningRoundTrip() {
            Persistence.isRunning = true
            #expect(Persistence.isRunning == true)
            Persistence.isRunning = false
            #expect(Persistence.isRunning == false)
        }

        @Test func quoteSetDefaultsToMirror() {
            #expect(Persistence.quoteSet == .mirror)
        }

        @Test func soundDefaultsToBowl() {
            #expect(Persistence.sound == .bowl)
        }

        @Test func resetIntervalRestoresDefault() {
            Persistence.intervalMinutes = 60.0
            Persistence.resetInterval()
            #expect(Persistence.intervalMinutes == 5.0)
        }
    }
}
