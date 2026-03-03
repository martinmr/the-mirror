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
        "Are you dreaming right now?",
        "Look at your hands — are they the hands of a dreamer?",
        "This moment, like all moments, could be a dream",
        "The waking state and the dream state share one nature",
        "Recognize the dream within the dream",
        "What is the difference between this and a dream?",
        "In the dream, the dreamer and the dream are not two",
        "Every perception is an opportunity to wake up",
        "The lucid dreamer finds freedom in both worlds",
        "If this were a dream, how would you know?"
    ]

    // MARK: Next Quote

    /// Advances the quote index in ``Persistence`` and returns the next quote for the given set.
    ///
    /// The rotation is sequential and guaranteed never to return the same quote twice in a row
    /// (unless the set contains only one entry).
    ///
    /// - Parameter set: The quote set to draw from.
    /// - Returns: The next quote string.
    static func nextQuote(for set: QuoteSetID) -> String {
        let quotes = quotes(for: set)
        guard quotes.count > 1 else { return quotes.first ?? "" }

        let current = Persistence.quoteIndex % quotes.count
        let next = (current + 1) % quotes.count
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