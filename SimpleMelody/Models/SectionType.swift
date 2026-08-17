// Models/SectionType.swift
// 段落类型预设
// v1.4: localizedName 改为调用 L(nameKey) 实现 4 语言切换

import Foundation
import SwiftUI

/// 段落类型预设定义
struct SectionTypePreset: Hashable, Codable, Identifiable {
    var id: String { name }
    let name: String           // 段落英文名 "Verse"
    let nameKey: String        // 翻译表 key
    let defaultTag: String     // 默认标签 "[Verse 1]"
    let symbol: String         // SF Symbol 名称
    let colorHex: String       // 段落颜色

    init(name: String, nameKey: String, defaultTag: String, symbol: String, colorHex: String) {
        self.name = name
        self.nameKey = nameKey
        self.defaultTag = defaultTag
        self.symbol = symbol
        self.colorHex = colorHex
    }

    static let presets: [SectionTypePreset] = [
        SectionTypePreset(name: "Intro",       nameKey: "section.type.Intro",       defaultTag: "[Intro]",        symbol: "play.circle",           colorHex: "#8E8E93"),
        SectionTypePreset(name: "Verse",       nameKey: "section.type.Verse",       defaultTag: "[Verse]",        symbol: "text.alignleft",        colorHex: "#5B9BD5"),
        SectionTypePreset(name: "Pre-Chorus",  nameKey: "section.type.Pre-Chorus",  defaultTag: "[Pre-Chorus]",   symbol: "arrow.up.right",        colorHex: "#7B68EE"),
        SectionTypePreset(name: "Chorus",      nameKey: "section.type.Chorus",      defaultTag: "[Chorus]",       symbol: "music.mic",             colorHex: "#FF6B6B"),
        SectionTypePreset(name: "Post-Chorus", nameKey: "section.type.Post-Chorus", defaultTag: "[Post-Chorus]",  symbol: "arrow.down.right",      colorHex: "#FF8E72"),
        SectionTypePreset(name: "Bridge",      nameKey: "section.type.Bridge",      defaultTag: "[Bridge]",       symbol: "arrow.triangle.branch", colorHex: "#50C878"),
        SectionTypePreset(name: "Hook",        nameKey: "section.type.Hook",        defaultTag: "[Hook]",         symbol: "hook",                  colorHex: "#FFA500"),
        SectionTypePreset(name: "Refrain",     nameKey: "section.type.Refrain",     defaultTag: "[Refrain]",      symbol: "repeat",                colorHex: "#4A90E2"),
        SectionTypePreset(name: "Interlude",   nameKey: "section.type.Interlude",   defaultTag: "[Interlude]",    symbol: "pause.circle",          colorHex: "#A0A0A0"),
        SectionTypePreset(name: "Solo",        nameKey: "section.type.Solo",        defaultTag: "[Solo]",         symbol: "music.note.list",       colorHex: "#DA70D6"),
        SectionTypePreset(name: "Outro",       nameKey: "section.type.Outro",       defaultTag: "[Outro]",        symbol: "stop.circle",           colorHex: "#8E8E93"),
        SectionTypePreset(name: "Coda",        nameKey: "section.type.Coda",        defaultTag: "[Coda]",         symbol: "flag.checkered",        colorHex: "#A0A0A0"),
        SectionTypePreset(name: "Custom",      nameKey: "section.type.Custom",      defaultTag: "[Custom]",       symbol: "tag",                   colorHex: "#9B59B6"),
    ]

    static func find(named name: String) -> SectionTypePreset? {
        presets.first { $0.name == name }
    }

    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    /// v1.4: 跟随界面语言动态翻译（兼容旧代码引用 .localizedName）
    var localizedName: String { L(nameKey) }

    /// 加上序号的标签，例如 "Verse 1" / "Chorus 2"
    func numberedTag(_ index: Int? = nil) -> String {
        if let idx = index, idx > 1 {
            return "[\(name) \(idx)]"
        }
        return defaultTag
    }
}

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let int = UInt32(hex, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// 根据当前颜色模式返回适合的前景色
    func adaptiveForeground() -> Color {
        // 简单亮度判断
        let uiColor = NSColor(self)
        var brightness: CGFloat = 0
        uiColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        return brightness > 0.6 ? .black : .white
    }
}

#if canImport(AppKit)
import AppKit
#endif