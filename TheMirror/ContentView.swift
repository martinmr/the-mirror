//
//  ContentView.swift
//  The Mirror
//
//  Created by Martin Martinez Rivera on 3/2/26.
//

import SwiftUI

/// Root view of the app.
///
/// Renders ``SettingsView`` and triggers foreground recovery via ``TimerEngine/recover()``
/// whenever the app returns from the background.
struct ContentView: View {

    @ObservedObject private var engine = TimerEngine.shared

    var body: some View {
        SettingsView()
            .environmentObject(engine)
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                engine.recover()
            }
    }
}

// MARK: - Color hex helper

extension Color {
    /// Initialises a `Color` from a CSS-style hex string (with or without a leading `#`), e.g.
    /// `"#B8976C"` or `"B8976C"`.
    ///
    /// - Parameter hex: A six-digit hexadecimal colour string.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
