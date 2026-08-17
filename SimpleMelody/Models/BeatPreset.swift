// Models/BeatPreset.swift
// v1.6: 节拍预设（用于下拉选择）

import Foundation

/// 节拍预设（常用拍号）
enum BeatPreset: String, CaseIterable, Identifiable, Codable {
    case twoFour = "2/4"
    case threeFour = "3/4"
    case fourFour = "4/4"
    case sixEight = "6/8"
    case sevenEight = "7/8"
    case nineEight = "9/8"
    case twelveEight = "12/8"
    case custom = "custom"

    var id: String { rawValue }

    /// 所有非自定义选项
    static var standard: [BeatPreset] {
        Self.allCases.filter { $0 != .custom }
    }

    /// 本地化显示名（跟随界面语言）
    var localizedName: String {
        switch self {
        case .twoFour: return "2/4"
        case .threeFour: return "3/4"
        case .fourFour: return "4/4"
        case .sixEight: return "6/8"
        case .sevenEight: return "7/8"
        case .nineEight: return "9/8"
        case .twelveEight: return "12/8"
        case .custom: return L("自定义")
        }
    }

    /// 从字符串匹配（导入时识别）
    static func from(string: String) -> BeatPreset {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if let preset = BeatPreset(rawValue: trimmed) {
            return preset
        }
        // 宽松匹配：去掉空格、忽略大小写
        let normalized = trimmed.replacingOccurrences(of: " ", with: "")
        return BeatPreset.allCases.first { $0.rawValue == normalized } ?? .fourFour
    }

    /// 标准预设字符串列表（用于导入端枚举）
    static var standardRawValues: [String] {
        standard.map { $0.rawValue }
    }
}