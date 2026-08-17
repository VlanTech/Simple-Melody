// Engine/TrashSound.swift
// v1.7.4 Beta: 删除操作播放系统 trash 音效
//
// macOS 没有公开的 trash 系统音效 API（系统直接合成 trash 声音，不导出公共 sound 文件）。
// 用最接近的 Frog 系统声音作为近似 —— Frog.aiff 是一个短促的 drop 音，类似东西落下的感觉。
// 如果 Frog 不可用，fallback 到 beep()。

import AppKit

enum TrashSound {
    /// 播放 trash 音效（删除歌曲 / 删除文件夹 / 移到废纸篓时调用）
    static func play() {
        // macOS 系统声音文件位于 /System/Library/Sounds/
        // Frog = 低沉 pop 音（最接近 trash 的"东西落下"感）
        if let s = NSSound(named: "Frog") {
            s.play()
        } else if let s = NSSound(named: "Pop") {
            s.play()
        } else {
            NSSound.beep()
        }
    }
}