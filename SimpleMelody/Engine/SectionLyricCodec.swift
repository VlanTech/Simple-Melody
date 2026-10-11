// 译文和笔记不能同时打开。导出器和段落编辑器、测试都调用这一份。

import Foundation

/// 侧栏互斥：笔记和译文不能同时打开。
enum SectionSidePanel: Equatable {
    case none
    case notes
    case translation

    /// 再点当前已打开的笔记或译文就收起，否则切换过去。
    static func toggling(_ current: SectionSidePanel, targeting: SectionSidePanel) -> SectionSidePanel {
        guard targeting == .notes || targeting == .translation else { return current }
        return current == targeting ? .none : targeting
    }
}

enum SectionHeaderControl: Equatable {
    case notes
    case translation
    case collapse
}

struct SectionPanelState: Equatable {
    var panel: SectionSidePanel
    var collapsed: Bool
}

enum SectionBatchAction {
    /// 按住 Command 时，把所点段落的方向应用到每一段。
    /// 已经处于结果状态的段落不动。
    /// 没按 Command 时只改所点的那一段。打开笔记或译文时，
    /// 只在状态真正变化的段落上关掉另一栏。
    static func apply(
        states: [SectionPanelState],
        clickedIndex: Int,
        control: SectionHeaderControl,
        commandHeld: Bool
    ) -> [SectionPanelState] {
        guard clickedIndex >= 0, clickedIndex < states.count else { return states }
        if !commandHeld {
            var next = states
            next[clickedIndex] = applyOne(states[clickedIndex], control: control)
            return next
        }
        let clicked = states[clickedIndex]
        return states.map { state in
            switch control {
            case .notes:
                if clicked.panel == .notes {
                    return state.panel == .notes
                        ? SectionPanelState(panel: .none, collapsed: state.collapsed)
                        : state
                }
                return state.panel == .notes
                    ? state
                    : SectionPanelState(panel: .notes, collapsed: state.collapsed)
            case .translation:
                if clicked.panel == .translation {
                    return state.panel == .translation
                        ? SectionPanelState(panel: .none, collapsed: state.collapsed)
                        : state
                }
                return state.panel == .translation
                    ? state
                    : SectionPanelState(panel: .translation, collapsed: state.collapsed)
            case .collapse:
                if clicked.collapsed {
                    return state.collapsed
                        ? SectionPanelState(panel: state.panel, collapsed: false)
                        : state
                }
                return state.collapsed
                    ? state
                    : SectionPanelState(panel: state.panel, collapsed: true)
            }
        }
    }

    static func applyOne(_ state: SectionPanelState, control: SectionHeaderControl) -> SectionPanelState {
        switch control {
        case .notes:
            return SectionPanelState(
                panel: SectionSidePanel.toggling(state.panel, targeting: .notes),
                collapsed: state.collapsed
            )
        case .translation:
            return SectionPanelState(
                panel: SectionSidePanel.toggling(state.panel, targeting: .translation),
                collapsed: state.collapsed
            )
        case .collapse:
            return SectionPanelState(panel: state.panel, collapsed: !state.collapsed)
        }
    }
}

struct SectionLyricSnapshot: Equatable {
    var marker: String
    var body: String
    var translation: String
    var notes: String
    var ruby: String = ""
}

/// 一次文本导出写哪些块。歌曲信息始终写入，否则文件无法再导入。
struct SongExportOptions: Equatable {
    var lyrics: Bool = true
    var translation: Bool = true
    var ruby: Bool = true
    var notes: Bool = true
    var ideas: Bool = true

    static let all = SongExportOptions()

    var includesLyricsSection: Bool { lyrics || translation || ruby || notes }
    /// 注音依附歌词；只有注音、没有歌词正文的文件无法往返导入。
    var writesLyricBody: Bool { lyrics || ruby }
    var includesAnything: Bool { includesLyricsSection || ideas }
}

enum SectionLyricCodec {
    /// 导出标签固定，不随界面语言变化，文件才能往返导入。
    static let translationExportLabel = "Translation"
    /// 与创意写回相同：每条注音一行，汉字和读音用全角竖线分开。
    static let rubyExportLabel = "Ruby"

    static func isTranslationMarker(_ trimmed: String) -> Bool {
        let key = markerKey(trimmed).lowercased()
        switch key {
        case "translation", "译文", "譯文", "訳文",
             "段落译文", "段落譯文", "section translation", "セクションの訳文":
            return true
        default:
            return false
        }
    }

    static func isRubyMarker(_ trimmed: String) -> Bool {
        let key = markerKey(trimmed).lowercased()
        switch key {
        case "ruby", "furigana", "注音", "ふりがな", "振り仮名", "후리가나":
            return true
        default:
            return false
        }
    }

    static func rubyExportText(_ pairs: [(original: String, phonetic: String)]) -> String {
        pairs.compactMap { original, phonetic in
            let base = original.trimmingCharacters(in: .whitespacesAndNewlines)
            let reading = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !base.isEmpty, !reading.isEmpty else { return nil }
            return "\(base)｜\(reading)"
        }
        .joined(separator: "\n")
    }

    static func isNotesMarker(_ trimmed: String, extraLabels: [String] = []) -> Bool {
        let key = markerKey(trimmed)
        let lower = key.lowercased()
        if lower == "notes" || lower == "section notes" { return true }
        if key.contains("段落笔记") || key.contains("段落筆記") { return true }
        if extraLabels.contains(where: { label in
            key == label || key.contains(label) || lower == label.lowercased()
        }) {
            return true
        }
        return false
    }

    /// 缩进块。内容为空就不输出，导出时整段省略。
    static func indentedBlock(label: String, content: String) -> [String] {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var lines = ["", "  \(label):"]
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append("    " + line)
        }
        return lines
    }

    static func encode(
        marker: String,
        body: String,
        translation: String,
        notes: String,
        notesLabel: String,
        ruby: String = "",
        options: SongExportOptions = .all
    ) -> [String] {
        var lines: [String] = [marker]
        if options.writesLyricBody {
            if body.isEmpty {
                lines.append("  ")
            } else {
                lines.append(contentsOf: body.components(separatedBy: "\n"))
            }
        }
        if options.ruby {
            lines += indentedBlock(label: rubyExportLabel, content: ruby)
        }
        if options.translation {
            lines += indentedBlock(label: translationExportLabel, content: translation)
        }
        if options.notes {
            lines += indentedBlock(label: notesLabel, content: notes)
        }
        return lines
    }

    /// 解析歌词行：标记、正文，以及可选的注音、译文、笔记。
    /// 没有注音块的旧文件仍然有效，注音为空。
    static func parseLyrics(_ lines: [String], extraNotesLabels: [String] = []) -> [SectionLyricSnapshot] {
        var snapshots: [SectionLyricSnapshot] = []
        var marker: String?
        var body: [String] = []
        var translation: [String] = []
        var notes: [String] = []
        var ruby: [String] = []
        enum Block { case body, translation, notes, ruby }
        var block: Block = .body

        func flush() {
            guard let marker else { return }
            snapshots.append(SectionLyricSnapshot(
                marker: marker,
                body: body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                translation: translation.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                ruby: ruby.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        func reset() {
            marker = nil
            body = []
            translation = []
            notes = []
            ruby = []
            block = .body
        }

        for raw in lines {
            let line = raw
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") { continue }
            if line.hasPrefix("===") { continue }
            if line.hasPrefix("【") && line.hasSuffix("】") { break }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                flush()
                reset()
                marker = trimmed
                continue
            }
            if isRubyMarker(trimmed) {
                block = .ruby
                continue
            }
            if isTranslationMarker(trimmed) {
                block = .translation
                continue
            }
            if isNotesMarker(trimmed, extraLabels: extraNotesLabels) {
                block = .notes
                continue
            }
            switch block {
            case .translation:
                translation.append(unindent(trimmed))
            case .notes:
                notes.append(unindent(trimmed))
            case .ruby:
                ruby.append(unindent(trimmed))
            case .body:
                body.append(line)
            }
        }
        flush()
        return snapshots
    }

    private static func markerKey(_ trimmed: String) -> String {
        var s = trimmed.trimmingCharacters(in: .whitespaces)
        if s.hasSuffix(":") || s.hasSuffix("：") {
            s.removeLast()
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func unindent(_ trimmed: String) -> String {
        if trimmed.hasPrefix("    ") {
            return String(trimmed.dropFirst(4))
        }
        return trimmed
    }
}
