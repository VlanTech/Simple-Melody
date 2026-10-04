// Engine/SectionLyricCodec.swift
// v1.7.10 Extra: exclusive 译文/笔记 panel + .smelody.txt translation block.
// SongExporter / SectionEditorView call these; tests compile this same file.

import Foundation

/// Exclusive side panel: notes and translation cannot both be open.
enum SectionSidePanel: Equatable {
    case none
    case notes
    case translation

    /// Tap `targeting` (notes or translation): collapse if already open, otherwise switch.
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
    /// Command applies the clicked section's direction to every section.
    /// Sections already in the resulting state are left unchanged.
    /// Without Command, only `clickedIndex` changes. Opening notes or translation
    /// closes the other panel only on sections whose state actually changes.
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

/// What a `.smelody.txt` write includes. Song Info is always written so the file can import.
struct SongExportOptions: Equatable {
    var lyrics: Bool = true
    var translation: Bool = true
    var ruby: Bool = true
    var notes: Bool = true
    var ideas: Bool = true

    static let all = SongExportOptions()

    var includesLyricsSection: Bool { lyrics || translation || ruby || notes }
    /// Readings attach to lyrics; a ruby-only file cannot round-trip.
    var writesLyricBody: Bool { lyrics || ruby }
    var includesAnything: Bool { includesLyricsSection || ideas }
}

enum SectionLyricCodec {
    /// Stable export label so files round-trip regardless of UI language.
    static let translationExportLabel = "Translation"
    /// Same pair format as Imagine: one `汉字｜读音` line per reading.
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

    /// Indented block. Empty content → no lines (omitted from export).
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

    /// Parse 【Lyrics】 lines (markers + body + optional Ruby / Translation / notes blocks).
    /// Files without a Ruby block stay valid; ruby is empty.
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
