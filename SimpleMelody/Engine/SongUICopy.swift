// Engine/SongUICopy.swift
// v1.8.0: lyrics-preview caption source + single-song delete counts (including 译文).

import Foundation
import CoreGraphics

enum PreviewCaptionSource: String, CaseIterable, Equatable {
    case notes
    case translation
}

struct LyricTranslationRow: Equatable {
    var lyric: String
    /// Nil when this lyric line has no translation text. The index still matches the lyric line.
    var translation: String?
}

enum LyricsPreviewCaption {
    /// Empty chosen field stays hidden (`nil`). Notes stay one block under the lyrics.
    static func text(notes: String, translation: String, source: PreviewCaptionSource) -> String? {
        let raw = source == .notes ? notes : translation
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    /// Translation preview: line i of the translation sits under line i of the lyrics.
    /// A blank translation line stays nil so later lines do not shift up.
    /// Extra translation lines are kept, with an empty lyric.
    static func translationRows(body: String, translation: String) -> [LyricTranslationRow] {
        let lyricsBlank = body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let translationBlank = translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if lyricsBlank && translationBlank { return [] }
        let lyrics = body.components(separatedBy: "\n")
        let translations = translation.components(separatedBy: "\n")
        let count = max(lyrics.count, translations.count)
        return (0..<count).map { index in
            let lyric = index < lyrics.count ? lyrics[index] : ""
            let raw = index < translations.count ? translations[index] : ""
            let shown = raw.trimmingCharacters(in: .whitespaces).isEmpty ? nil : raw
            return LyricTranslationRow(lyric: lyric, translation: shown)
        }
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

/// 右栏模式。灵感、歌词预览、设置互斥。
enum RightPanelMode: String, Hashable, Codable {
    case off
    case idea
    case preview
    case settings
}

/// 右栏进入 / 离开的边。视图把它映射成已有的 move + opacity。
enum RightColumnEnterEdge: Equatable {
    case leading
    case trailing
    case bottom
    case none
}

struct RightColumnLayout: Equatable {
    var minWidth: CGFloat
    var idealWidth: CGFloat
    var maxWidth: CGFloat
    var enterEdge: RightColumnEnterEdge
    var leaveEdge: RightColumnEnterEdge
}

enum RightColumnMetrics {
    /// 设置页现有布局宽度。只在打开设置时使用。
    static let settingsWidth: CGFloat = 480
    /// 灵感 / 歌词预览的默认宽度，也是这一档里最窄的宽度。
    static let flexibleMin: CGFloat = 320

    static func layout(for mode: RightPanelMode) -> RightColumnLayout {
        switch mode {
        case .off:
            return RightColumnLayout(
                minWidth: 0, idealWidth: 0, maxWidth: 0,
                enterEdge: .none, leaveEdge: .none
            )
        case .idea:
            return RightColumnLayout(
                minWidth: flexibleMin, idealWidth: flexibleMin, maxWidth: flexibleMin,
                enterEdge: .leading, leaveEdge: .trailing
            )
        case .preview:
            return RightColumnLayout(
                minWidth: flexibleMin, idealWidth: flexibleMin, maxWidth: flexibleMin,
                enterEdge: .trailing, leaveEdge: .leading
            )
        case .settings:
            return RightColumnLayout(
                minWidth: settingsWidth, idealWidth: settingsWidth, maxWidth: settingsWidth,
                enterEdge: .bottom, leaveEdge: .bottom
            )
        }
    }
}

/// 界面字号比例。只改文字，不改窗口、分栏或页面尺寸。
enum AppFontMetrics {
    static let defaultScale: CGFloat = 1
    static let minScale: CGFloat = 0.85
    static let maxScale: CGFloat = 1.35
    static let defaultBodySize: CGFloat = 13
    static let mainMinWidth: CGFloat = 1280
    static let mainMinHeight: CGFloat = 680
    static let dialogWidth: CGFloat = 420

    static func clamp(_ scale: CGFloat) -> CGFloat {
        min(maxScale, max(minScale, scale))
    }

    static func size(_ base: CGFloat, scale: CGFloat) -> CGFloat {
        max(9, (base * clamp(scale) * 10).rounded() / 10)
    }

    struct WindowFrame: Equatable {
        var minWidth: CGFloat
        var idealWidth: CGFloat
        var maxWidth: CGFloat
        var minHeight: CGFloat
        var idealHeight: CGFloat
        var maxHeight: CGFloat
    }

    static let changelogFrame = WindowFrame(
        minWidth: 560, idealWidth: 640, maxWidth: 720,
        minHeight: 420, idealHeight: 560, maxHeight: 720
    )

    static let usageGuideFrame = WindowFrame(
        minWidth: 560, idealWidth: 640, maxWidth: 720,
        minHeight: 480, idealHeight: 640, maxHeight: 800
    )

    static let skillExportFrame = WindowFrame(
        minWidth: 720, idealWidth: 800, maxWidth: 920,
        minHeight: 720, idealHeight: 780, maxHeight: 900
    )
}

/// 主窗口进入时铺满当前屏幕的可用区域（菜单栏和 Dock 以外）。不是 macOS 全屏空间。
enum MainWindowLaunch {
    static func frame(fitting visible: CGRect) -> CGRect {
        guard visible.width > 1, visible.height > 1 else {
            return CGRect(
                x: 0,
                y: 0,
                width: AppFontMetrics.mainMinWidth,
                height: AppFontMetrics.mainMinHeight
            )
        }
        return visible
    }
}

/// 用户填写的大模型接入信息。只保存，不发起请求。
struct LLMConnection: Equatable {
    var baseURL: String
    var modelName: String
    var apiKey: String

    static let empty = LLMConnection(baseURL: "", modelName: "", apiKey: "")
}

struct LLMAPIKeyStore {
    static let baseURLKey = "llm.api.baseURL"
    static let modelKey = "llm.api.model"
    static let storageKey = "llm.api.key"
    var defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func current() -> LLMConnection {
        LLMConnection(
            baseURL: defaults.string(forKey: Self.baseURLKey) ?? "",
            modelName: defaults.string(forKey: Self.modelKey) ?? "",
            apiKey: defaults.string(forKey: Self.storageKey) ?? ""
        )
    }

    func save(_ connection: LLMConnection) {
        defaults.set(connection.baseURL, forKey: Self.baseURLKey)
        defaults.set(connection.modelName, forKey: Self.modelKey)
        defaults.set(connection.apiKey, forKey: Self.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.baseURLKey)
        defaults.removeObject(forKey: Self.modelKey)
        defaults.removeObject(forKey: Self.storageKey)
    }
}
