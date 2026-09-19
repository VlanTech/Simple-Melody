// Engine/ChangelogFold.swift
// v1.8.0: display-only fold of letter-tagged changelog rows into numeric stems.

import Foundation

struct ChangelogRow: Equatable {
    var version: String
    var date: String
    var isLatest: Bool
    var bodyMarkdown: String
    var bodyMarkdownZHT: String
    var bodyMarkdownEN: String
    var bodyMarkdownJA: String
}

enum ChangelogFold {
    /// "v1.7.10 Extra" → "v1.7.10"; "v1.7.9 GT5" → "v1.7.9"; "v1.7 Beta" → "v1.7".
    static func numericStem(_ version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        var seenV = false
        for ch in trimmed {
            if ch == "v" || ch == "V" {
                if seenV || !result.isEmpty { break }
                result.append("v")
                seenV = true
            } else if ch.isNumber || ch == "." {
                result.append(ch)
            } else {
                break
            }
        }
        while result.last == "." { result.removeLast() }
        if result == "v" || result.isEmpty { return trimmed }
        return result
    }

    /// Keep first-seen stem order (newest-first source). Concatenate bodies. Heading is the stem only.
    static func fold(_ rows: [ChangelogRow]) -> [ChangelogRow] {
        var order: [String] = []
        var groups: [String: [ChangelogRow]] = [:]
        for row in rows {
            let stem = numericStem(row.version)
            if groups[stem] == nil {
                order.append(stem)
                groups[stem] = []
            }
            groups[stem]?.append(row)
        }
        return order.map { stem in
            let members = groups[stem] ?? []
            func join(_ pick: (ChangelogRow) -> String) -> String {
                members.map(pick).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n\n")
            }
            return ChangelogRow(
                version: stem,
                date: members.first?.date ?? "",
                isLatest: members.contains(where: \.isLatest),
                bodyMarkdown: join(\.bodyMarkdown),
                bodyMarkdownZHT: join(\.bodyMarkdownZHT),
                bodyMarkdownEN: join(\.bodyMarkdownEN),
                bodyMarkdownJA: join(\.bodyMarkdownJA)
            )
        }
    }
}

/// Changelog window uses plain `Text`, not Markdown. Convert source markers
/// (`##`, `-`, `**`, `` ` ``) into 【section】 / • bullets the UI actually shows.
enum ChangelogDisplayText {
    static func fromMarkdown(_ raw: String) -> String {
        raw.components(separatedBy: "\n").map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("###### ") {
                return "【\(stripInline(String(trimmed.dropFirst(7))))】"
            }
            if trimmed.hasPrefix("##### ") {
                return "【\(stripInline(String(trimmed.dropFirst(6))))】"
            }
            if trimmed.hasPrefix("#### ") {
                return "【\(stripInline(String(trimmed.dropFirst(5))))】"
            }
            if trimmed.hasPrefix("### ") {
                return "【\(stripInline(String(trimmed.dropFirst(4))))】"
            }
            if trimmed.hasPrefix("## ") {
                return "【\(stripInline(String(trimmed.dropFirst(3))))】"
            }
            if trimmed.hasPrefix("# ") {
                return "【\(stripInline(String(trimmed.dropFirst(2))))】"
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return "• " + stripInline(String(trimmed.dropFirst(2)))
            }
            return stripInline(line)
        }.joined(separator: "\n")
    }

    static func stripInline(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }
}
