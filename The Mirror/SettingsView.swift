//
//  SettingsView.swift
//  The Mirror
//

import SwiftUI
import AVFoundation

/// The sole app screen, providing controls for starting/stopping the timer and configuring quote
/// set and sound preferences.
///
/// Reads and writes state through ``TimerEngine``, which is injected as an environment object by
/// ``ContentView``.
struct SettingsView: View {

    @EnvironmentObject private var engine: TimerEngine
    @State private var audioPlayer: AVAudioPlayer?

    private let cream = Color(hex: "#fef7ed")
    private let gold = Color(hex: "#B8976C")
    private let goldDim = Color(hex: "#B8976C").opacity(0.6)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

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
                    .foregroundColor(gold)

                Text("a timer for presence and awareness")
                    .font(.custom("Georgia-Italic", size: 13))
                    .foregroundColor(goldDim)
                    .padding(.top, 4)
                    .padding(.bottom, 48)

                // ---- Controls ----
                VStack(spacing: 32) {

                    // Quote Set
                    controlSection(label: "Quote Set") {
                        Picker("Quote Set", selection: Binding(
                            get: { engine.quoteSet },
                            set: { engine.setQuoteSet($0) }
                        )) {
                            ForEach(QuoteSetID.allCases, id: \.self) { set in
                                Text(set.displayName).tag(set)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorMultiply(gold)
                    }

                    // Sound
                    controlSection(label: "Sound — hold Bowl to preview") {
                        soundSegmentedControl
                    }

                    // Interval display
                    if engine.isRunning {
                        Text("Next notification in ~\(Int(engine.intervalMinutes)) min")
                            .font(.custom("Georgia-Italic", size: 13))
                            .foregroundColor(goldDim)
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
                        .foregroundColor(cream)
                        .frame(width: 160, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(engine.isRunning ? goldDim : gold)
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            engine.syncFromPersistence()
        }
    }

    // MARK: - Sound segment control

    /// Custom segmented control for sound preference. The Bowl segment supports
    /// a long press to preview the sound without leaving the screen.
    private var soundSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(SoundPreference.allCases, id: \.self) { pref in
                let selected = engine.sound == pref
                Text(pref.displayName)
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(selected ? cream : gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? gold : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.setSound(pref)
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        if pref == .bowl { playBowlSound() }
                    }
            }
        }
        .background(goldDim.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(goldDim, lineWidth: 0.5))
    }

    /// Plays `bowl.caf` from the app bundle as an in-app preview.
    private func playBowlSound() {
        guard let url = Bundle.main.url(forResource: "bowl", withExtension: "caf") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }

    // MARK: - Helper

    /// Renders a labelled control section with a spaced title and the provided content view below
    /// it.
    ///
    /// - Parameters:
    ///   - label: The section title, displayed in small caps above the control.
    ///   - content: The control to render below the label.
    @ViewBuilder
    private func controlSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("Georgia", size: 13))
                .foregroundColor(goldDim)
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
