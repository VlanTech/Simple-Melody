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

    private enum Key {
        static let confirmDelete = "app.settings.confirmBeforeDelete"
    }

    private init() {
        // 默认开。如果 UserDefaults 里有就用 UserDefaults 的值。
        if UserDefaults.standard.object(forKey: Key.confirmDelete) == nil {
            self.confirmBeforeDelete = true
        } else {
            self.confirmBeforeDelete = UserDefaults.standard.bool(forKey: Key.confirmDelete)
        }
    }
}
