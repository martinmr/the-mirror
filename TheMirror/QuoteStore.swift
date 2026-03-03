//
//  QuoteStore.swift
//  The Mirror
//

import Foundation

/// Provides quotes for notification bodies and manages sequential rotation across both built-in
/// quote sets.
struct QuoteStore {

    // MARK: Quote Sets

    private static let mirrorQuotes: [String] = [
        "Spur on the horse of awareness with the whip of presence",
        "A mind free of distraction is the basis of all paths",
        "If awareness is not aroused by presence, it cannot function",
        "There is nothing higher or clearer to seek beyond the recognition of our State of pure presence",
        "The moment the thoughts are recognized, they relax into their own condition",
        "The calm state is the essence of the mind and movement is its energy",
        "To meditate only means to maintain presence — there is nothing on which to meditate",
        "We've got eyes with which to see each other, but we need a mirror to see ourselves"
    ]

    private static let dreamYogaQuotes: [String] = [
        "Samsara is like a dream, it’s like a magical illusion.",
        "Nirvana too  is like a dream, it’s like a magical illusion.",
        "Recognize that perceived objects are your own mind, like seeing something in one's dreams.",
        "Since everything is but an illusion, One might as well burst out laughing!",
        "From the day we are born to until the day we die, this entire life is like last night's dream.",
        "The Buddhas have seen this world to be illusory just like a dream.",
        "Feeling is like a bubble, perception is like a mirage, consciousness is like an illusion.",
        "If there were anything greater than nirvāṇa, that too would be like a dream."
    ]

    // MARK: Next Quote

    /// Returns a random quote for the given set, guaranteed never to repeat the previous one
    /// (unless the set contains only one entry).
    ///
    /// - Parameter set: The quote set to draw from.
    /// - Returns: A random quote string.
    static func nextQuote(for set: QuoteSetID) -> String {
        let quotes = quotes(for: set)
        guard quotes.count > 1 else { return quotes.first ?? "" }

        let current = Persistence.quoteIndex % quotes.count
        var next = Int.random(in: 0 ..< quotes.count - 1)
        if next >= current { next += 1 }
        Persistence.quoteIndex = next
        return quotes[next]
    }

    /// Returns the quote at the current index without advancing the index.
    ///
    /// - Parameter set: The quote set to read from.
    /// - Returns: The current quote string.
    static func currentQuote(for set: QuoteSetID) -> String {
        let quotes = quotes(for: set)
        guard !quotes.isEmpty else { return "" }
        return quotes[Persistence.quoteIndex % quotes.count]
    }

    // MARK: Private

    /// Returns the raw array of quotes for a given set.
    ///
    /// - Parameter set: The quote set to look up.
    /// - Returns: The corresponding array of quote strings.
    private static func quotes(for set: QuoteSetID) -> [String] {
        switch set {
        case .mirror: return mirrorQuotes
        case .dreamYoga: return dreamYogaQuotes
        }
    }
}
