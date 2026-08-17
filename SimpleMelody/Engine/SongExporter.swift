// Engine/SongExporter.swift
// 歌曲导出器 - 导出全部信息（歌词 + 灵感 + 设定 + 笔记）

import Foundation
import SwiftData

/// 歌曲导出器
enum SongExporter {
    /// 格式化时间戳（用于文件名）
    static func filenameTimestamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// 导出歌曲为完整文本格式（含元信息、歌词、笔记、灵感、设定）
    /// v1.6: 全部 key 改为英文，跨语言兼容；删除易混淆的导出时间字段
    static func exportFullText(_ song: Song, language: AppLanguage = .simplifiedChinese) -> String {
        var lines: [String] = []
        let separator = String(repeating: "=", count: 50)

        // 标题
        lines.append(separator)
        lines.append("  Simple Melody · " + L("歌词导出"))
        lines.append(separator)
        lines.append("")

        // 歌曲元信息（v1.6：统一英文 key）
        lines.append("【Song Info】")
        lines.append("Title: \(song.title.isEmpty ? L("未命名") : song.title)")
        if !song.artist.isEmpty {
            lines.append("Artist: \(song.artist)")
        }
        if !song.album.isEmpty {
            lines.append("Album: \(song.album)")
        }
        if let bpm = song.bpm {
            lines.append("BPM: \(bpm)")
        }
        if let key = song.musicalKey, !key.isEmpty {
            lines.append("Key: \(key)")
        }
        // v1.6: 节拍（位于调式之后）
        lines.append("Beat: \(song.beat.isEmpty ? "4/4" : song.beat)")
        // 语言用逗号分隔的 code（导入时直接识别）
        if !song.languages.isEmpty {
            lines.append("Languages: " + song.languages.joined(separator: ", "))
        }
        if !song.tags.isEmpty {
            lines.append("Tags: " + song.tags.joined(separator: ", "))
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current
        lines.append("Created: " + dateFormatter.string(from: song.createdAt))
        lines.append("Modified: " + dateFormatter.string(from: song.updatedAt))
        lines.append("")

        // 歌词正文
        lines.append("【Lyrics】")
        lines.append("")
        for section in song.orderedSections {
            lines.append(section.marker)
            if section.body.isEmpty {
                lines.append("  ")
            } else {
                lines.append(section.body)
            }
            // 段落笔记（如果有）
            if !section.notes.isEmpty {
                lines.append("")
                lines.append("  " + L("段落笔记") + ":")
                for noteLine in section.notes.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append("    " + noteLine)
                }
            }
            lines.append("")
        }

        // 灵感与设定
        let ideas = song.orderedIdeas
        if !ideas.isEmpty {
            lines.append(separator)
            lines.append("【Ideas & Settings】")
            lines.append("")

            // 按类型分组
            let grouped = Dictionary(grouping: ideas, by: { $0.ideaType })
            // 按 IdeaTypePreset.all 顺序输出
            for preset in IdeaTypePreset.all {
                guard let items = grouped[preset.name], !items.isEmpty else { continue }
                // v1.6: idea type 标题也用英文 name（导入时直接匹配）
                lines.append("◆ \(preset.name)")
                for idea in items {
                    let dateStr = formatShortDate(idea.createdAt)
                    lines.append("  • " + idea.content)
                    if !dateStr.isEmpty {
                        lines.append("    (\(dateStr))")
                    }
                }
                lines.append("")
            }
        }

        // 页脚（v1.6：移除「导出时间」字段避免污染导入；保留版本信息作为 # 注释）
        lines.append(separator)
        lines.append("# Simple Melody · Apple Silicon Native")
        lines.append(separator)

        return lines.joined(separator: "\n")
    }

    /// 短日期格式
    private static func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    /// 导出文件扩展名
    static let fileExtension = "smelody.txt"
}

// MARK: - 导入器

extension SongExporter {
    /// 备份结果
    struct BackupResult {
        var success: Int = 0
        var failed: [(song: Song, error: Error)] = []

        var totalProcessed: Int { success + failed.count }
    }

    /// 一键备份所有歌曲到指定文件夹
    /// - Parameters:
    ///   - songs: 要备份的歌曲列表
    ///   - folderURL: 目标文件夹 URL
    /// - Returns: 备份结果（成功数和失败详情）
    static func backupAll(songs: [Song], to folderURL: URL) -> BackupResult {
        var result = BackupResult()

        // 创建时间戳子目录（避免同一天多次备份覆盖）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: Date())
        let backupFolder = folderURL.appendingPathComponent("SimpleMelody_Backup_\(timestamp)", isDirectory: true)

        // 创建文件夹
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        } catch {
            // 失败：所有歌曲都失败
            for song in songs {
                result.failed.append((song, error))
            }
            return result
        }

        // 逐首导出
        for song in songs {
            let safeTitle = song.title.isEmpty ? L("未命名") : song.title
            // 文件名清洗（去掉非法字符）
            let safeFileName = safeTitle
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "\n", with: " ")
            let fileURL = backupFolder.appendingPathComponent("\(safeFileName).smelody.txt")

            do {
                let text = exportFullText(song)
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                result.success += 1
            } catch {
                result.failed.append((song, error))
            }
        }

        return result
    }

    // MARK: v1.5: 文件夹级备份/导出（保留嵌套结构）

    /// 库备份快照（从 ModelContext 拷贝出来的纯数据，可跨线程使用）
    struct LibrarySnapshot {
        let rootFolders: [SongFolder]
        let rootSongs: [Song]
        let allFolders: [SongFolder]
        let allSongs: [Song]
    }

    /// 备份整个曲目库（保留文件夹层级）
    static func backupLibrary(
        rootFolders: [SongFolder],
        rootSongs: [Song],
        to folderURL: URL
    ) -> BackupResult {
        var result = BackupResult()
        let timestamp = filenameTimestamp()
        let backupFolder = folderURL.appendingPathComponent("SimpleMelody_Backup_\(timestamp)", isDirectory: true)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        } catch {
            for song in rootSongs {
                result.failed.append((song, error))
            }
            return result
        }

        // 备份根目录歌曲（不在任何文件夹里）
        for song in rootSongs {
            writeSongFile(song, to: backupFolder, result: &result)
        }

        // 备份所有文件夹
        for folder in rootFolders {
            let safeName = sanitizeFileName(folder.name)
            let subFolderURL = backupFolder.appendingPathComponent(safeName, isDirectory: true)
            do {
                try fileManager.createDirectory(at: subFolderURL, withIntermediateDirectories: true)
                writeFolderBackup(folder, to: subFolderURL, result: &result)
            } catch {
                if let first = folder.orderedSongs.first {
                    result.failed.append((first, error))
                }
            }
        }

        return result
    }

    /// 递归写文件夹内容
    private static func writeFolderBackup(
        _ folder: SongFolder,
        to baseURL: URL,
        result: inout BackupResult
    ) {
        let fileManager = FileManager.default
        for song in folder.orderedSongs {
            writeSongFile(song, to: baseURL, result: &result)
        }
        // 子文件夹（用 modelContext 查）
        let folderID = folder.id
        let childPredicate = #Predicate<SongFolder> { sub in
            sub.parent?.id == folderID
        }
        let children = (try? folder.modelContext?.fetch(
            FetchDescriptor<SongFolder>(predicate: childPredicate)
        )) ?? []
        for child in children {
            let childURL = baseURL.appendingPathComponent(sanitizeFileName(child.name), isDirectory: true)
            try? fileManager.createDirectory(at: childURL, withIntermediateDirectories: true)
            writeFolderBackup(child, to: childURL, result: &result)
        }
    }

    /// 写一首歌曲到文件
    private static func writeSongFile(_ song: Song, to baseURL: URL, result: inout BackupResult) {
        let safeTitle = song.title.isEmpty ? L("未命名") : song.title
        let safeFileName = sanitizeFileName(safeTitle)
        let fileURL = baseURL.appendingPathComponent("\(safeFileName).smelody.txt")
        do {
            let text = exportFullText(song)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            result.success += 1
        } catch {
            result.failed.append((song, error))
        }
    }

    /// 清洗文件名非法字符
    private static func sanitizeFileName(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// 导出文件夹（不含时间戳）
    static func exportFolder(_ folder: SongFolder, to baseURL: URL) -> BackupResult {
        var result = BackupResult()
        let safeName = folder.name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let exportRoot = baseURL.appendingPathComponent(safeName, isDirectory: true)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        } catch {
            result.failed.append((folder.orderedSongs.first ?? Song(title: folder.name), error))
            return result
        }
        return writeFolderRecursive(folder, to: exportRoot, result: &result)
    }

    /// 递归写入文件夹结构
    private static func writeFolderRecursive(
        _ folder: SongFolder,
        to baseURL: URL,
        result: inout BackupResult
    ) -> BackupResult {
        let fileManager = FileManager.default

        // 写入歌曲
        for song in folder.orderedSongs {
            let safeTitle = song.title.isEmpty ? L("未命名") : song.title
            let safeFileName = safeTitle
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "\n", with: " ")
            let fileURL = baseURL.appendingPathComponent("\(safeFileName).smelody.txt")
            do {
                let text = exportFullText(song)
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                result.success += 1
            } catch {
                result.failed.append((song, error))
            }
        }

        // 写入子文件夹
        let folderID = folder.id
        let childPredicate = #Predicate<SongFolder> { sub in
            sub.parent?.id == folderID
        }
        let children = (try? folder.modelContext?.fetch(
            FetchDescriptor<SongFolder>(predicate: childPredicate)
        )) ?? []

        for child in children {
            let safeChildName = child.name
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
            let childURL = baseURL.appendingPathComponent(safeChildName, isDirectory: true)
            do {
                try fileManager.createDirectory(at: childURL, withIntermediateDirectories: true)
                _ = writeFolderRecursive(child, to: childURL, result: &result)
            } catch {
                // 子文件夹创建失败跳过
            }
        }

        return result
    }
}

/// 歌曲导入器
enum SongImporter {
    /// 解析错误
    enum ImportError: LocalizedError {
        case invalidFormat(String)
        case missingMetadata
        case readFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat(let reason): return L("文件格式无效：\(reason)")
            case .missingMetadata: return L("缺少歌曲元信息")
            case .readFailed(let reason): return L("读取失败：\(reason)")
            }
        }
    }

    /// 从文本导入歌曲
    /// v1.6: 全部用英文 key 判定（兼容跨语言），节拍加入；段落笔记从歌词行末识别
    static func importFromText(_ text: String, into context: ModelContext) throws -> Song {
        let lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            throw ImportError.invalidFormat("empty file")
        }

        var title: String = ""
        var artist: String = ""
        var album: String = ""
        var bpm: Int? = nil
        var musicalKey: String? = nil
        var beat: String = "4/4"  // v1.6: 默认 4/4
        var languages: [String] = []
        var tags: [String] = []
        var sections: [(marker: String, body: String, notes: String)] = []
        var ideas: [(type: String, content: String)] = []

        // 状态机
        enum ParseSection {
            case header      // 歌曲元信息
            case lyrics      // 歌词
            case ideas       // 灵感与设定
            case unknown
        }
        var currentSection: ParseSection = .unknown
        var currentIdeaType: String = "Inspiration"
        var currentSectionMarker: String? = nil
        var currentSectionBody: [String] = []
        var currentSectionNotes: [String] = []
        var inNotesBlock = false

        func flushSection() {
            if let marker = currentSectionMarker {
                sections.append((
                    marker: marker,
                    body: currentSectionBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: currentSectionNotes.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
            currentSectionMarker = nil
            currentSectionBody = []
            currentSectionNotes = []
            inNotesBlock = false
        }

        for rawLine in lines {
            let line = rawLine
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // 跳过空行（不影响状态）
            if trimmedLine.isEmpty { continue }

            // 跳过注释行（v1.6 新增：# 开头的行不进解析）
            if trimmedLine.hasPrefix("#") { continue }

            // 段头识别（v1.6：用英文段头）
            if line.hasPrefix("【") && line.hasSuffix("】") {
                flushSection()
                let header = String(line.dropFirst().dropLast()).lowercased()
                if header == "song info" {
                    currentSection = .header
                } else if header == "lyrics" {
                    currentSection = .lyrics
                } else if header == "ideas & settings" || header == "ideas" {
                    currentSection = .ideas
                } else {
                    currentSection = .unknown
                }
                continue
            }

            // 分隔线（===）
            if line.hasPrefix("===") { continue }

            switch currentSection {
            case .header:
                // v1.6: 用英文 key 判定（不再用中文 key 兼容，避免误识别）
                if let colonIdx = line.firstIndex(of: ":") {
                    let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                    let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "title":
                        title = value
                    case "artist":
                        artist = value
                    case "album":
                        album = value
                    case "bpm":
                        bpm = Int(value)
                    case "key":
                        musicalKey = value.isEmpty ? nil : value
                    case "beat":
                        // v1.6: 节拍（标准预设或自定义字符串）
                        beat = value.isEmpty ? "4/4" : value
                    case "languages":
                        // v1.6: 直接识别 code 列表（逗号分隔），如 "zh, en, ja"
                        for part in value.components(separatedBy: CharacterSet(charactersIn: ",·;")) {
                            let trimmed = part.trimmingCharacters(in: .whitespaces)
                            if trimmed.isEmpty { continue }
                            // 直接匹配 code（兼容旧版中文显示名）
                            if let lang = SongLanguage.find(code: trimmed) {
                                languages.append(lang.code)
                            } else if let lang = SongLanguage.all.first(where: { $0.localizedDisplayName == trimmed }) {
                                languages.append(lang.code)
                            } else if let lang = SongLanguage.all.first(where: { $0.englishName.lowercased() == trimmed.lowercased() }) {
                                languages.append(lang.code)
                            }
                        }
                    case "tags":
                        tags = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    default:
                        // 跳过未知 key（不污染任何字段，包括"导出时间"之类的中文 key）
                        break
                    }
                }
            case .lyrics:
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // 段落标签 [Verse 1] 或包含中括号
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    flushSection()
                    currentSectionMarker = trimmed
                    inNotesBlock = false
                } else if trimmed.contains(L("段落笔记")) || trimmed.lowercased().hasPrefix("notes:") {
                    inNotesBlock = true
                } else if inNotesBlock {
                    // 笔记内容（缩进）
                    if !trimmed.isEmpty {
                        let unindented = trimmed.hasPrefix("    ") ? String(trimmed.dropFirst(4)) : trimmed
                        currentSectionNotes.append(unindented)
                    }
                } else if !trimmed.isEmpty {
                    currentSectionBody.append(line)
                }
            case .ideas:
                // v1.6: 灵感类型标题 "◆ Inspiration"（用 preset.name 英文 key）
                if line.hasPrefix("◆") {
                    let typeName = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    if let preset = IdeaTypePreset.all.first(where: {
                        $0.name == typeName || $0.localizedName == typeName
                    }) {
                        currentIdeaType = preset.name
                    } else {
                        currentIdeaType = "Inspiration"  // fallback
                    }
                    continue
                }
                // 项目 "  • content"
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("•") {
                    let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        ideas.append((type: currentIdeaType, content: content))
                    }
                }
            case .unknown:
                continue
            }
        }
        // 收尾
        flushSection()

        // 至少要有标题
        if title.isEmpty {
            // 尝试从第一行或文件名推断
            if let firstRealLine = lines.first(where: { !$0.isEmpty && !$0.hasPrefix("=") }) {
                title = firstRealLine.trimmingCharacters(in: CharacterSet(charactersIn: " *="))
            }
            if title.isEmpty {
                throw ImportError.missingMetadata
            }
        }

        // 默认语言
        if languages.isEmpty {
            languages = ["ja"]
        }

        // 创建 Song
        let song = Song(
            title: title,
            artist: artist,
            album: album,
            languages: languages,
            bpm: bpm,
            musicalKey: musicalKey,
            beat: beat,  // v1.6: 节拍
            tags: tags
        )
        context.insert(song)

        // 创建 Sections
        for (idx, sec) in sections.enumerated() {
            let typeName = inferSectionTypeName(from: sec.marker)
            let section = SongSection(
                order: idx,
                typeName: typeName,
                body: sec.body,
                customTag: sec.marker,
                notes: sec.notes
            )
            section.song = song
            song.sections.append(section)
        }

        // 创建 Ideas
        for (idx, idea) in ideas.enumerated() {
            let songIdea = SongIdea(order: idx, content: idea.content, ideaType: idea.type)
            songIdea.song = song
            song.ideas.append(songIdea)
        }

        try context.save()
        return song
    }

    /// 从 [Verse]、[Chorus] 等 tag 推断段落类型
    private static func inferSectionTypeName(from marker: String) -> String {
        // marker 格式: [Verse 1] / [Verse] / [副歌] 等
        let inner = marker
            .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .components(separatedBy: .whitespaces).first ?? ""

        // 先尝试英文
        let englishName = inner.components(separatedBy: CharacterSet(charactersIn: "-")).first ?? inner
        if SectionTypePreset.find(named: englishName) != nil {
            return englishName
        }

        // 再通过本地化名匹配（当前语言 + 英文 key 兼容）
        for preset in SectionTypePreset.presets {
            if preset.localizedName == inner || preset.name == inner {
                return preset.name
            }
        }

        // 默认 Verse
        return "Verse"
    }

    // MARK: v1.5: 递归导入文件夹（含套娃结构）

    /// 从文件夹递归导入所有 .smelody.txt 文件，按目录结构创建文件夹
    /// - Returns: 导入的歌曲总数
    static func importFolder(at folderURL: URL, into context: ModelContext) throws -> Int {
        let fileManager = FileManager.default
        let folderName = folderURL.lastPathComponent
        let trash = SongFolder.fetchTrashFolder(context: context)
        // 创建顶层文件夹
        let topFolder = SongFolder(name: folderName)
        context.insert(topFolder)

        return try importFolderRecursive(
            folderURL: folderURL,
            parent: topFolder,
            context: context,
            trash: trash,
            count: 0
        )
    }

    // MARK: v1.5.2: 平面导入（只扫顶层，归到同名文件夹）

    /// 仅扫描顶层目录中的 .smelody.txt 文件，全部归到一个跟源文件夹同名的 SongFolder
    /// （不递归套娃子目录，套娃里的歌曲不进）
    /// - Returns: 导入的歌曲总数
    static func importFolderFlat(at folderURL: URL, into context: ModelContext) throws -> Int {
        let fileManager = FileManager.default
        let folderName = folderURL.lastPathComponent

        // 创建（同名）顶层文件夹
        let topFolder = SongFolder(name: folderName)
        context.insert(topFolder)

        let items = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var count = 0
        for item in items {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }
            // 只处理顶层文件（跳过套娃子目录）
            if isDir.boolValue { continue }
            // 只处理 .smelody.txt 文件
            guard item.pathExtension == "txt" && item.lastPathComponent.hasSuffix(".smelody.txt") else { continue }

            do {
                let text = try String(contentsOf: item, encoding: .utf8)
                let song = try importFromText(text, into: context)
                song.folder = topFolder
                count += 1
            } catch {
                continue
            }
        }

        try context.save()
        return count
    }

    /// 递归扫描目录
    private static func importFolderRecursive(
        folderURL: URL,
        parent: SongFolder?,
        context: ModelContext,
        trash: SongFolder?,
        count: Int
    ) throws -> Int {
        var total = count
        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in items {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // 子文件夹：递归
                let childName = item.lastPathComponent
                let childFolder = SongFolder(name: childName, parent: parent)
                context.insert(childFolder)
                total = try importFolderRecursive(
                    folderURL: item,
                    parent: childFolder,
                    context: context,
                    trash: trash,
                    count: total
                )
            } else if item.pathExtension == "txt" && item.lastPathComponent.hasSuffix(".smelody.txt") {
                // .smelody.txt 文件：导入为歌曲
                do {
                    let text = try String(contentsOf: item, encoding: .utf8)
                    let song = try importFromText(text, into: context)
                    song.folder = parent
                    // 不导入到回收站
                    _ = trash
                    total += 1
                } catch {
                    // 单个文件导入失败，跳过继续
                    continue
                }
            }
        }

        try context.save()
        return total
    }
}
