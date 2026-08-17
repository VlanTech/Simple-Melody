// Models/Song.swift
// 歌曲、段落、读音、灵感数据模型（SwiftData）

import Foundation
import SwiftData
import SwiftUI

// MARK: - 歌曲

@Model
final class Song {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var album: String
    /// 语言代码（逗号分隔）："ja" 日语 / "zh-Hans" 简中 / "zh-Hant" 繁中 / "en" 英语 / "ko" 韩语 等
    /// v1.1 支持多语言混写
    var languagesString: String
    var bpm: Int?
    /// 音乐调式，如 "C Major" / "A Minor"
    var musicalKey: String?
    /// v1.6: 节拍（如 "4/4" / "3/4" / "6/8"），默认 "4/4"
    var beat: String = "4/4"
    /// 逗号分隔的标签
    var tagsString: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \SongSection.song)
    var sections: [SongSection] = []

    @Relationship(deleteRule: .cascade, inverse: \SongIdea.song)
    var ideas: [SongIdea] = []

    /// v1.5: 歌曲所属文件夹（nil = 根目录）
    var folder: SongFolder?

    init(
        title: String,
        artist: String = "",
        album: String = "",
        languages: [String] = ["ja"],
        bpm: Int? = nil,
        musicalKey: String? = nil,
        beat: String = "4/4",
        tags: [String] = [],
        sortOrder: Int = 0,
        folder: SongFolder? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.album = album
        self.languagesString = languages.joined(separator: ",")
        self.bpm = bpm
        self.musicalKey = musicalKey
        self.beat = beat
        self.tagsString = tags.joined(separator: ",")
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortOrder = sortOrder
        self.folder = folder
    }

    var tags: [String] {
        get { tagsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { tagsString = newValue.joined(separator: ",") }
    }

    /// v1.1：语言列表（多选支持，v1.5：旧 code 标准化）
    var languages: [String] {
        get {
            languagesString.split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .normalizedLanguageCodes()
        }
        set { languagesString = newValue.joined(separator: ",") }
    }

    /// 主要语言（用于 UI 展示和默认行为，第一个）
    var primaryLanguage: String {
        languages.first ?? "ja"
    }

    /// 是否包含日语（用于自动注音等逻辑）
    var hasJapanese: Bool {
        languages.contains { $0.hasPrefix("ja") }
    }

    var orderedSections: [SongSection] {
        sections.sorted { $0.order < $1.order }
    }

    var orderedIdeas: [SongIdea] {
        ideas.sorted { $0.order < $1.order }
    }

    /// 完整正文（导出用）
    var fullBody: String {
        orderedSections
            .map { "\($0.marker)\n\($0.body)\n" }
            .joined(separator: "\n")
    }

    /// 字数统计（仅歌词正文，不含标签）
    var totalCharacters: Int {
        orderedSections.reduce(0) { $0 + $1.body.count }
    }
}

// MARK: - 段落

@Model
final class SongSection {
    @Attribute(.unique) var id: UUID
    var order: Int
    /// 类型名，对应 SectionTypePreset.name，如 "Verse" / "Custom"
    var typeName: String
    /// 自定义段落名（当 typeName == "Custom" 时使用）
    var customName: String
    /// 用户自定义的标签字符串（如 "[Verse 1]"），为空时使用预设默认
    var customTag: String
    var notes: String
    /// 段落标签，例如 "[Verse 1]"
    var marker: String
    var colorHex: String
    /// 段落正文（歌词）
    var body: String
    /// 是否折叠
    var isCollapsed: Bool

    @Relationship(deleteRule: .cascade, inverse: \PronunciationAnnotation.section)
    var annotations: [PronunciationAnnotation] = []

    var song: Song?

    init(
        order: Int,
        typeName: String = "Verse",
        body: String = "",
        customName: String = "",
        customTag: String = "",
        notes: String = ""
    ) {
        self.id = UUID()
        self.order = order
        self.typeName = typeName
        self.customName = customName
        self.customTag = customTag
        self.notes = notes
        self.body = body
        self.isCollapsed = false

        let preset = SectionTypePreset.find(named: typeName)
        self.colorHex = preset?.colorHex ?? "#5B9BD5"
        self.marker = customTag.isEmpty ? (preset?.defaultTag ?? "[\(typeName)]") : customTag
    }

    var preset: SectionTypePreset? {
        SectionTypePreset.find(named: typeName)
    }

    var displayName: String {
        if typeName == "Custom", !customName.isEmpty {
            return customName
        }
        return preset?.localizedName ?? typeName
    }

    /// 自动加上序号的标签
    func computeNumberedMarker(globalIndex: Int, occurrences: Int) -> String {
        if !customTag.isEmpty { return customTag }
        // 多次出现的同类型段落加序号
        if occurrences > 1 {
            return preset?.numberedTag(globalIndex) ?? "[\(typeName) \(globalIndex)]"
        }
        return preset?.defaultTag ?? "[\(typeName)]"
    }

    var orderedAnnotations: [PronunciationAnnotation] {
        annotations.sorted { $0.rangeStart < $1.rangeStart }
    }
}

// MARK: - 读音标注

@Model
final class PronunciationAnnotation {
    @Attribute(.unique) var id: UUID
    var rangeStart: Int
    var rangeLength: Int
    var original: String
    var phonetic: String
    /// 是否由自动引擎生成
    var isAutoGenerated: Bool
    /// 语言："ja" / "zh-pinyin" / "en-ipa" / "ko-rr"
    var language: String
    var createdAt: Date

    var section: SongSection?

    init(
        rangeStart: Int,
        rangeLength: Int,
        original: String,
        phonetic: String,
        language: String = "ja",
        isAutoGenerated: Bool = false
    ) {
        self.id = UUID()
        self.rangeStart = rangeStart
        self.rangeLength = rangeLength
        self.original = original
        self.phonetic = phonetic
        self.language = language
        self.isAutoGenerated = isAutoGenerated
        self.createdAt = Date()
    }
}

// MARK: - 灵感 / 设定

@Model
final class SongIdea {
    @Attribute(.unique) var id: UUID
    var order: Int
    var content: String
    /// 类型："Inspiration" / "Setting" / "Background" / "Note"
    var ideaType: String
    var createdAt: Date

    var song: Song?

    init(
        order: Int,
        content: String = "",
        ideaType: String = "Inspiration"
    ) {
        self.id = UUID()
        self.order = order
        self.content = content
        self.ideaType = ideaType
        self.createdAt = Date()
    }

    var typePreset: IdeaTypePreset {
        IdeaTypePreset.find(named: ideaType) ?? .inspiration
    }
}

struct IdeaTypePreset: Hashable, Identifiable {
    var id: String { name }
    let name: String
    let nameKey: String        // v1.4: 翻译表 key
    let symbol: String
    let colorHex: String

    var color: Color { Color(hex: colorHex) ?? .accentColor }

    /// v1.4: 跟随界面语言动态翻译（兼容旧代码引用 .localizedName）
    var localizedName: String { L(nameKey) }

    init(name: String, nameKey: String, symbol: String, colorHex: String) {
        self.name = name
        self.nameKey = nameKey
        self.symbol = symbol
        self.colorHex = colorHex
    }

    static let all: [IdeaTypePreset] = [
        IdeaTypePreset(name: "Inspiration", nameKey: "idea.type.Inspiration", symbol: "lightbulb",  colorHex: "#FFC857"),
        IdeaTypePreset(name: "Setting",     nameKey: "idea.type.Setting",     symbol: "doc.text",   colorHex: "#5B9BD5"),
        IdeaTypePreset(name: "Background",  nameKey: "idea.type.Background",  symbol: "book",       colorHex: "#9B59B6"),
        IdeaTypePreset(name: "Note",        nameKey: "idea.type.Note",        symbol: "note.text",  colorHex: "#50C878"),
    ]

    static func find(named name: String) -> IdeaTypePreset? {
        all.first { $0.name == name }
    }

    static let inspiration = IdeaTypePreset(name: "Inspiration", nameKey: "idea.type.Inspiration", symbol: "lightbulb", colorHex: "#FFC857")
}
