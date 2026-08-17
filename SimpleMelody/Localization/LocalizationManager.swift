// Localization/LocalizationManager.swift
// 多语言管理
// 支持：简体中文 / 繁体中文 / 英语 / 日语
// 首次启动自动识别系统语言

import SwiftUI
import Combine
import Foundation

/// 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    /// 显示名称（用每种语言自身的写法）
    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    /// 在 UI 中显示的"语言"前缀
    var label: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    /// 从系统 locale 检测最佳匹配
    static func detectFromSystem() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let lower = preferred.lowercased()
        if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk") || lower.hasPrefix("zh-mo") {
            return .traditionalChinese
        }
        if lower.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if lower.hasPrefix("ja") {
            return .japanese
        }
        return .english
    }
}

/// 本地化管理器（单例）
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage

    private let storageKey = "app.language.choice"

    private init() {
        // 先读取已存储的语言
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? ""
        if stored.isEmpty {
            // 首次启动：识别系统语言
            let detected = AppLanguage.detectFromSystem()
            self.language = detected
            UserDefaults.standard.set(detected.rawValue, forKey: storageKey)
        } else if let lang = AppLanguage(rawValue: stored) {
            self.language = lang
        } else {
            self.language = .simplifiedChinese
            UserDefaults.standard.set(AppLanguage.simplifiedChinese.rawValue, forKey: storageKey)
        }
    }

    func setLanguage(_ new: AppLanguage) {
        language = new
        UserDefaults.standard.set(new.rawValue, forKey: storageKey)
    }
}
