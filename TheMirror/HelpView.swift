//
//  HelpView.swift
//  The Mirror
//

import SwiftUI

struct HelpView: View {

    @Environment(\.dismiss) private var dismiss

    private static let cream = Color(hex: "#fef7ed")
    private static let gold = Color(hex: "#B8976C")

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Self.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .header(let text, let level):
                            Text(text)
                                .font(.custom("Georgia", size: level == 1 ? 24 : 20))
                                .foregroundStyle(Self.gold)
                        case .paragraph(let text):
                            Text(inlineMarkdown(text))
                                .font(.custom("Georgia", size: 15))
                                .foregroundStyle(Self.gold)
                        case .listItem(let text):
                            HStack(alignment: .top, spacing: 8) {
                                Text("\u{2022}")
                                Text(inlineMarkdown(text))
                            }
                            .font(.custom("Georgia", size: 15))
                            .foregroundStyle(Self.gold)
                        }
                    }
                }
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

    // MARK: - Markdown parsing

    private enum Block {
        case header(String, level: Int)
        case paragraph(String)
        case listItem(String)
    }

    private var blocks: [Block] {
        guard let url = Bundle.main.url(forResource: "help", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        var result: [Block] = []
        let paragraphs = text.components(separatedBy: "\n\n")

        for para in paragraphs {
            let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("## ") {
                result.append(.header(String(trimmed.dropFirst(3)), level: 2))
            } else if trimmed.hasPrefix("# ") {
                result.append(.header(String(trimmed.dropFirst(2)), level: 1))
            } else if trimmed.hasPrefix("- ") {
                let lines = trimmed.components(separatedBy: "\n")
                var currentItem = ""
                for line in lines {
                    if line.hasPrefix("- ") {
                        if !currentItem.isEmpty {
                            result.append(.listItem(currentItem))
                        }
                        currentItem = String(line.dropFirst(2))
                    } else {
                        currentItem += " " + line.trimmingCharacters(in: .whitespaces)
                    }
                }
                if !currentItem.isEmpty {
                    result.append(.listItem(currentItem))
                }
            } else {
                let joined = trimmed.components(separatedBy: "\n").joined(separator: " ")
                result.append(.paragraph(joined))
            }
        }
        return result
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
