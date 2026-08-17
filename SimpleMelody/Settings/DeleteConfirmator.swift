// Settings/DeleteConfirmator.swift
// 删除确认弹窗（统一入口，可被 AppSettings.confirmBeforeDelete 关闭）

import SwiftUI
import AppKit

/// 删除确认器
enum DeleteConfirmator {
    /// 弹出删除确认窗口，根据 AppSettings.confirmBeforeDelete 决定是否弹窗
    /// - Parameters:
    ///   - title: 删除目标名称（歌曲标题 / 段落类型 / 灵感类型）
    ///   - message: 详细说明
    /// - Returns: true 表示确认删除
    @MainActor
    static func confirm(title: String, message: String) -> Bool {
        // 如果设置里关闭了确认，直接返回 true
        if !AppSettings.shared.confirmBeforeDelete {
            return true
        }

        let alert = NSAlert()
        alert.messageText = L("确认删除")
        alert.informativeText = "\(message)\n\n\(title)\n\n\(L("此操作暂不可恢复"))"
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("删除"))
        alert.addButton(withTitle: L("取消"))

        // 在 settings key 上绑定"不再提醒"
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L("不再提醒（可在设置中重新开启）")

        let response = alert.runModal()
        let suppressed = alert.suppressionButton?.state == .on

        if suppressed {
            AppSettings.shared.confirmBeforeDelete = false
        }

        return response == .alertFirstButtonReturn
    }
}
