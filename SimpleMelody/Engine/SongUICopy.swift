// Engine/SongUICopy.swift
// v1.8.0: lyrics-preview caption source + single-song delete counts (including 译文).

import Foundation

enum PreviewCaptionSource: String, CaseIterable, Equatable {
    case notes
    case translation
}

enum LyricsPreviewCaption {
    /// Empty chosen field stays hidden (`nil`).
    static func text(notes: String, translation: String, source: PreviewCaptionSource) -> String? {
        let raw = source == .notes ? notes : translation
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }
}

enum SongDeleteSummary {
    static func translationCount(_ translations: [String]) -> Int {
        translations.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    /// Detail line under the trash title for a single song.
    static func formatCountsLine(
        sectionCount: Int,
        ideaCount: Int,
        translationCount: Int,
        includeLabel: String,
        sectionsLabel: String,
        ideasLabel: String,
        translationsLabel: String
    ) -> String {
        "\(includeLabel) \(sectionCount) \(sectionsLabel) · \(ideaCount) \(ideasLabel) · \(translationCount) \(translationsLabel)"
    }
}
