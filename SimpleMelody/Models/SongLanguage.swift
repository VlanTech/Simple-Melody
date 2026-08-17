// Models/SongLanguage.swift
// 歌曲可用语言预设（9 种：合并简繁为"中文"）
// v1.5: 简体中文 / 繁体中文 合并为一个"中文"（code 仍是 "zh-Hans" / "zh-Hant" 内部存储，UI 显示 "中文"）

import Foundation
import SwiftUI

/// 歌曲可用的语言预设
struct SongLanguage: Hashable, Identifiable, Codable {
    var id: String { code }
    /// 语言代码（如 "ja"、"en"、"zh"）
    let code: String
    /// 中文名称（同时也作为 L() 的 key）
    let name: String
    /// 英文名称（fallback / 内部使用）
    let englishName: String
    /// SF Symbol（用于 UI 图标）
    let symbol: String

    /// 全部预设（按使用频率排序，v1.5：合并简繁为中文）
    static let all: [SongLanguage] = [
        .init(code: "ja",       name: "日语",       englishName: "Japanese",  symbol: "character.book.closed"),
        .init(code: "zh",       name: "中文",       englishName: "Chinese",   symbol: "textformat"),
        .init(code: "en",       name: "英语",       englishName: "English",   symbol: "globe"),
        .init(code: "ko",       name: "韩语",       englishName: "Korean",    symbol: "character"),
        .init(code: "es",       name: "西班牙语",   englishName: "Spanish",   symbol: "globe.europe.africa"),
        .init(code: "fr",       name: "法语",       englishName: "French",    symbol: "globe.europe.africa"),
        .init(code: "de",       name: "德语",       englishName: "German",    symbol: "globe.europe.africa"),
        .init(code: "it",       name: "意大利语",   englishName: "Italian",   symbol: "globe.europe.africa"),
        .init(code: "pt",       name: "葡萄牙语",   englishName: "Portuguese", symbol: "globe"),
    ]

    /// 旧 code（zh-Hans / zh-Hant）→ 新 code（zh）的映射，用于旧数据迁移
    static let legacyCodeMapping: [String: String] = [
        "zh-Hans": "zh",
        "zh-Hant": "zh",
    ]

    static func find(code: String) -> SongLanguage? {
        // 先查表，再尝试 legacy code
        if let lang = all.first(where: { $0.code == code }) {
            return lang
        }
        if let mapped = legacyCodeMapping[code] {
            return all.first { $0.code == mapped }
        }
        return nil
    }

    /// 本地化的显示名称（跟随当前界面语言切换）
    var localizedDisplayName: String {
        L(name)
    }
}

/// v1.5: 把字符串语言列表里的旧 code 标准化成新 code
extension Array where Element == String {
    func normalizedLanguageCodes() -> [String] {
        self.map { code in
            SongLanguage.legacyCodeMapping[code] ?? code
        }
    }
}