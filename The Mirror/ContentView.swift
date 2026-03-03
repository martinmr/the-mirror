//
//  ContentView.swift
//  The Mirror
//
//  Created by Martin Martinez Rivera on 3/2/26.
//

import SwiftUI

/// Root view of the app.
///
/// Renders ``SettingsView`` immediately and overlays ``SplashView`` on top, fading it out after 1
/// second. Also triggers foreground recovery via ``TimerEngine/recover()`` whenever the app
/// returns from the background.
struct ContentView: View {

    @State private var showSplash = false
    @StateObject private var engine = TimerEngine.shared

    var body: some View {
        ZStack {
            SettingsView()
                .environmentObject(engine)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                showSplash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            engine.recover()
        }
    }
}

// MARK: - Splash

/// Full-screen launch overlay showing the logo, app name, and subtitle.
///
/// Displayed by ``ContentView`` for 1.5 seconds before fading out.
private struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#fef7ed")
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text("The Mirror")
                    .font(.custom("Georgia", size: 32))
                    .foregroundColor(Color(hex: "#B8976C"))

                Text("a timer for presence and awareness")
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundColor(Color(hex: "#B8976C").opacity(0.8))
            }
        }
    }
}

// MARK: - Color hex helper

extension Color {
    /// Initialises a `Color` from a CSS-style hex string (with or without a
    /// leading `#`), e.g. `"#B8976C"` or `"B8976C"`.
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
