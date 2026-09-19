// Settings/AppSettings.swift
// 应用偏好设置（用 UserDefaults 持久化）

import Foundation
import Combine

/// 应用偏好设置（ObservableObject 便于 SwiftUI 绑定）
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// 删除歌曲/段落/灵感前的确认弹窗（默认开）
    @Published var confirmBeforeDelete: Bool {
        didSet {
            UserDefaults.standard.set(confirmBeforeDelete, forKey: Key.confirmDelete)
        }
    }

    /// 启动时静默检查 GitHub 版本（默认开；新版本才弹窗）
    @Published var autoCheckUpdates: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckUpdates, forKey: Key.autoCheckUpdates)
        }
    }

    /// 歌词预览段落下方小字：笔记（默认）或译文
    @Published var previewCaptionSource: PreviewCaptionSource {
        didSet {
            UserDefaults.standard.set(previewCaptionSource.rawValue, forKey: Key.previewCaption)
        }
    }

    private enum Key {
        static let confirmDelete = "app.settings.confirmBeforeDelete"
        static let autoCheckUpdates = "app.settings.autoCheckUpdates"
        static let previewCaption = "app.settings.previewCaptionSource"
    }

    private init() {
        // 默认开。如果 UserDefaults 里有就用 UserDefaults 的值。
        if UserDefaults.standard.object(forKey: Key.confirmDelete) == nil {
            self.confirmBeforeDelete = true
        } else {
            self.confirmBeforeDelete = UserDefaults.standard.bool(forKey: Key.confirmDelete)
        }
        if UserDefaults.standard.object(forKey: Key.autoCheckUpdates) == nil {
            self.autoCheckUpdates = true
        } else {
            self.autoCheckUpdates = UserDefaults.standard.bool(forKey: Key.autoCheckUpdates)
        }
        if let raw = UserDefaults.standard.string(forKey: Key.previewCaption),
           let source = PreviewCaptionSource(rawValue: raw) {
            self.previewCaptionSource = source
        } else {
            self.previewCaptionSource = .notes
        }
    }
}
