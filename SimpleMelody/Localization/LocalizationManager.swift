// Localization/LocalizationManager.swift
// 多语言管理
// 支持：简体中文 / 繁体中文 / 英语 / 日语 / 韩语 / 西班牙语
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
    case korean = "ko"
    case spanish = "es"

    var id: String { rawValue }

    /// 显示名称（用每种语言自身的写法）
    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        }
    }

    /// 在 UI 中显示的"语言"前缀
    var label: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        }
    }

    /// 从一段首选语言标签匹配界面语言。
    static func detect(from preferred: String) -> AppLanguage {
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
        if lower.hasPrefix("ko") {
            return .korean
        }
        if lower.hasPrefix("es") {
            return .spanish
        }
        return .english
    }

    /// 从系统 locale 检测最佳匹配
    static func detectFromSystem() -> AppLanguage {
        detect(from: Locale.preferredLanguages.first ?? "en")
    }
}

/// 界面语言是固定某一种，还是每次读取时跟随系统首选语言。
enum LanguagePreference: Equatable {
    /// 与具体语言代码都不同，存在 `app.language.choice` 里。
    static let followSystemToken = "system"

    /// `system` 会再次走 `AppLanguage.detect`。已存的语言代码保持不变，不受 preferred 影响。
    static func resolve(stored: String, preferred: String) -> AppLanguage {
        if stored == followSystemToken {
            return AppLanguage.detect(from: preferred)
        }
        if let fixed = AppLanguage(rawValue: stored) {
            return fixed
        }
        if stored.isEmpty {
            return AppLanguage.detect(from: preferred)
        }
        return .simplifiedChinese
    }
}

/// 本地化管理器（单例）
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// 存的是语言代码，或 `LanguagePreference.followSystemToken`。
    @Published private var preferenceStored: String

    private let storageKey = "app.language.choice"

    /// 跟随系统时每次读取都重新检测，所以系统语言变了会跟上。
    var language: AppLanguage {
        LanguagePreference.resolve(
            stored: preferenceStored,
            preferred: Locale.preferredLanguages.first ?? "en"
        )
    }

    var followsSystem: Bool {
        preferenceStored == LanguagePreference.followSystemToken
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? ""
        if stored.isEmpty {
            // 首次启动仍记下当时识别出的具体语言；用户之后可以改成跟随系统。
            let detected = AppLanguage.detectFromSystem()
            preferenceStored = detected.rawValue
            UserDefaults.standard.set(detected.rawValue, forKey: storageKey)
        } else if stored == LanguagePreference.followSystemToken || AppLanguage(rawValue: stored) != nil {
            preferenceStored = stored
        } else {
            preferenceStored = AppLanguage.simplifiedChinese.rawValue
            UserDefaults.standard.set(preferenceStored, forKey: storageKey)
        }
    }

    func setLanguage(_ new: AppLanguage) {
        preferenceStored = new.rawValue
        UserDefaults.standard.set(new.rawValue, forKey: storageKey)
    }

    func setFollowSystem() {
        preferenceStored = LanguagePreference.followSystemToken
        UserDefaults.standard.set(LanguagePreference.followSystemToken, forKey: storageKey)
    }
}
