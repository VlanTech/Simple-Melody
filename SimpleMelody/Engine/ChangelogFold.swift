// 仅用于显示：把带字母后缀的日志行折成数字版本。数据源已按数字版本合并，这里只是兜底。

import Foundation

struct ChangelogRow: Equatable {
    var version: String
    var date: String
    var isLatest: Bool
    var bodyMarkdown: String
    var bodyMarkdownZHT: String
    var bodyMarkdownEN: String
    var bodyMarkdownJA: String
    var bodyMarkdownKO: String = ""
    var bodyMarkdownES: String = ""
}

enum ChangelogFold {
    /// v1.7.10 Extra 折成 v1.7.10，v1.7.9 GT5 折成 v1.7.9，v1.7 Beta 折成 v1.7。
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

    /// 保持首次出现的词干顺序（源数据从新到旧）。正文拼接，标题只用词干。
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
            let stemDate = members.first(where: { $0.version == stem })?.date
            return ChangelogRow(
                version: stem,
                date: stemDate ?? members.first?.date ?? "",
                isLatest: members.contains(where: \.isLatest),
                bodyMarkdown: join(\.bodyMarkdown),
                bodyMarkdownZHT: join(\.bodyMarkdownZHT),
                bodyMarkdownEN: join(\.bodyMarkdownEN),
                bodyMarkdownJA: join(\.bodyMarkdownJA),
                bodyMarkdownKO: join(\.bodyMarkdownKO),
                bodyMarkdownES: join(\.bodyMarkdownES)
            )
        }
    }
}

/// 更新日志窗口用的是纯文本，不是 Markdown。
/// 把标题记号、列表记号和行内强调换成界面上真正显示的【章节】和项目符号。
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
