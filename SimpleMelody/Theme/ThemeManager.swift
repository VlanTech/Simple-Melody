// Theme/ThemeManager.swift
// 主题管理（跟随系统 / 强制浅色 / 强制深色）

import SwiftUI
import Combine
import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light  = "浅色"
    case dark   = "深色"

    var id: String { rawValue }
}

final class ThemeManager: ObservableObject {
    @AppStorage("app.theme.choice") private var storedChoice: String = AppTheme.system.rawValue
    @Published var theme: AppTheme = .system

    init() {
        self.theme = AppTheme(rawValue: storedChoice) ?? .system
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    func setTheme(_ new: AppTheme) {
        theme = new
        storedChoice = new.rawValue
        // v1.7.4 Delta: 直接修改 NSApp.appearance，立刻生效（不依赖 SwiftUI .preferredColorScheme 的重新渲染）
        // 之前纯靠 .preferredColorScheme 在 macOS 上某些 view hierarchy 下需要点击两次才变色
        DispatchQueue.main.async {
            switch new {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
}

// MARK: - v1.7.3: 主题感知色板
// 解决 Bug 1（浅色模式文字图标透明）+ Bug 2（跟随系统切换异常）
// 设计原则：用 `Color.primary.opacity(X)` 而不是 `Color.secondary.opacity(X)`。
//   - 浅色模式：primary = 黑，背景 = 白 → 黑色 6% 是清晰可见的浅灰
//   - 深色模式：primary = 白，背景 = 黑 → 白色 6% 是清晰可见的浅灰
//   - Color.secondary 在两种模式下都是浅灰，再叠 opacity 在浅色背景上会失明
enum ThemeColor {
    /// 最淡的背景填充（按钮 / panel 内层）— 浅色 6% / 深色 6%
    static var subtleFill: Color { Color.primary.opacity(0.06) }
    /// 较淡的背景填充（折叠按钮 / 工具胶囊）— 8%
    static var softFill: Color { Color.primary.opacity(0.08) }
    /// 中等背景填充（tag chip）— 10%
    static var mediumFill: Color { Color.primary.opacity(0.10) }
    /// 淡边框（panel border）— 12%
    static var subtleStroke: Color { Color.primary.opacity(0.12) }
    /// 中等边框（按钮 border）— 15%
    static var mediumStroke: Color { Color.primary.opacity(0.15) }
    /// 闪烁时填充（跳转目标段落高亮）— 18%
    static var flashFill: Color { Color.primary.opacity(0.10) }
    /// 闪烁时边框 — 35%
    static var flashStroke: Color { Color.primary.opacity(0.35) }
}
