// Models/SongFolder.swift
// v1.5: 曲目库文件夹分类 + 系统回收站

import Foundation
import SwiftData
import SwiftUI

/// 曲目库文件夹（含系统回收站）
@Model
final class SongFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 系统文件夹（回收站）标记：不可删除/重命名/移动
    var isSystem: Bool
    var createdAt: Date
    var sortOrder: Int
    /// 文件夹颜色 hex
    var colorHex: String

    /// 父文件夹（支持套娃文件夹）
    var parent: SongFolder?

    @Relationship(deleteRule: .nullify, inverse: \Song.folder)
    var songs: [Song] = []

    init(
        name: String,
        isSystem: Bool = false,
        parent: SongFolder? = nil,
        sortOrder: Int = 0,
        colorHex: String = "#8E8E93"
    ) {
        self.id = UUID()
        self.name = name
        self.isSystem = isSystem
        self.parent = parent
        self.sortOrder = sortOrder
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    /// 排序后的歌曲
    var orderedSongs: [Song] {
        songs.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 获取系统回收站
    static func fetchTrashFolder(context: ModelContext) -> SongFolder? {
        let descriptor = FetchDescriptor<SongFolder>(
            predicate: #Predicate { $0.isSystem == true }
        )
        return try? context.fetch(descriptor).first
    }

    /// 颜色
    var color: Color { Color(hex: colorHex) ?? .secondary }
}