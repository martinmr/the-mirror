//
//  HelpView.swift
//  The Mirror
//

import MarkdownUI
import SwiftUI

/// The theme for rendering the help markdown.
private extension Theme {
    static let mirror = Theme()
        .text {
            FontFamily(.custom("Georgia"))
            FontSize(15)
            ForegroundColor(Color(hex: "#B8976C"))
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamily(.custom("Georgia"))
                    FontSize(24)
                    FontWeight(.bold)
                }
                .markdownMargin(top: 0, bottom: 16)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamily(.custom("Georgia"))
                    FontSize(20)
                    FontWeight(.bold)
                }
                .markdownMargin(top: 24, bottom: 8)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 12)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 4)
        }
}

/// The view that displays the help content loaded from the bundled markdown file.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private static let cream = Color(hex: "#fef7ed")
    private static let gold = Color(hex: "#B8976C")

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Self.cream.ignoresSafeArea()

            ScrollView {
                Markdown(helpText)
                    .markdownTheme(.mirror)
                    .padding(24)
                    .padding(.top, 20)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Self.gold)
                    .padding(16)
            }
        }
    }

    private var helpText: String {
        guard let url = Bundle.main.url(forResource: "help", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "Unable to load help content." }
        return text
    }
}
