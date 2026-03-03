//
//  SettingsView.swift
//  The Mirror
//

import SwiftUI
import AVFoundation

/// Main app screen with controls for starting/stopping the timer and configuring quote set and sound.
struct SettingsView: View {

    @EnvironmentObject private var engine: TimerEngine
    @State private var audioPlayer: AVAudioPlayer?

    private static let cream = Color(hex: "#fef7ed")
    private static let gold = Color(hex: "#B8976C")
    private static let goldDim = Color(hex: "#B8976C").opacity(0.6)

    var body: some View {
        ZStack {
            Self.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Logo
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.bottom, 16)

                // Title
                Text("The Mirror")
                    .font(.custom("Georgia", size: 28))
                    .foregroundStyle(Self.gold)

                Text("a timer for presence and awareness")
                    .font(.custom("Georgia-Italic", size: 13))
                    .foregroundStyle(Self.goldDim)
                    .padding(.top, 4)
                    .padding(.bottom, 48)

                // ---- Controls ----
                VStack(spacing: 32) {

                    // Quote Set
                    controlSection(label: "Quote Set") {
                        quoteSetSegmentedControl
                    }

                    // Sound
                    controlSection(label: "Sound — hold Bowl to preview") {
                        soundSegmentedControl
                    }

                    // Interval display
                    if engine.isRunning {
                        Text("Next notification in ~\(engine.minutesUntilNext) min")
                            .font(.custom("Georgia-Italic", size: 13))
                            .foregroundStyle(Self.goldDim)
                    }
                }
                .padding(.horizontal, 36)

                Spacer()

                // Start / Stop button
                Button(action: {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        engine.start()
                    }
                }) {
                    Text(engine.isRunning ? "Stop" : "Start")
                        .font(.custom("Georgia", size: 22))
                        .foregroundStyle(Self.cream)
                        .frame(width: 160, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(engine.isRunning ? Self.goldDim : Self.gold)
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .confirmationDialog("Were you present?", isPresented: $engine.awaitingInput) {
            Button("Present") { engine.respondToPrompt(.present) }
            Button("Distracted") { engine.respondToPrompt(.distracted) }
        }
    }

    // MARK: - Quote set segment control

    private var quoteSetSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(QuoteSetID.allCases, id: \.self) { set in
                let selected = engine.quoteSet == set
                Text(set.displayName)
                    .font(.custom("Georgia", size: 14))
                    .foregroundStyle(selected ? Self.cream : Self.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? Self.gold : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.setQuoteSet(set)
                    }
            }
        }
        .background(Self.goldDim.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.goldDim, lineWidth: 0.5))
    }

    // MARK: - Sound segment control

    /// Segmented control for sound preference; long-press Bowl to preview.
    private var soundSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(SoundPreference.allCases, id: \.self) { pref in
                let selected = engine.sound == pref
                Text(pref.displayName)
                    .font(.custom("Georgia", size: 14))
                    .foregroundStyle(selected ? Self.cream : Self.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? Self.gold : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.setSound(pref)
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        if pref == .bowl { playBowlSound() }
                    }
            }
        }
        .background(Self.goldDim.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.goldDim, lineWidth: 0.5))
    }

    /// Plays the bowl sound from the app bundle as a preview.
    private func playBowlSound() {
        guard let url = Bundle.main.url(forResource: "bowl", withExtension: "caf") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }

    // MARK: - Helper

    /// Renders a labelled section with a title above and the provided content below.
    @ViewBuilder
    private func controlSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("Georgia", size: 13))
                .foregroundStyle(Self.goldDim)
                .textCase(.uppercase)
                .tracking(1.5)
            content()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TimerEngine.shared)
}
