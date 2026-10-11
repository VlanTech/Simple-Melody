// 左侧曲目列表
// v1.5.2: 多选（Set<UUID>）+ 批量操作菜单 + 文件夹歌曲完整右键 + 批量导入

import SwiftUI
import SwiftData
import AppKit

struct SongSidebarView: View {
    /// 根目录歌曲共用这一栏。文件夹用自己的 id，避免和根目录串成同一条缝。
    private static let rootReorderGroup = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Environment(\.modelContext) private var context
    @Binding var selectedSongIDs: Set<UUID>
    @StateObject private var reorderLine = SongReorderLineState()
    /// v1.7.9 Delta+: 排序 + 搜索状态由 ContentView 持有（保证切歌方向判定和 UI 显示顺序一致）
    @Binding var sortMode: SongSortMode
    @Binding var searchText: String

    @Query(sort: [SortDescriptor(\Song.sortOrder, order: .forward), SortDescriptor(\Song.updatedAt, order: .reverse)])
    private var songs: [Song]

    @Query(sort: [SortDescriptor(\SongFolder.sortOrder, order: .forward)])
    private var folders: [SongFolder]

    /// 根层级文件夹（不含回收站，回收站单独放最底）
    private var rootFolders: [SongFolder] {
        folders.filter { !$0.isSystem && $0.parent == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var trashFolder: SongFolder? {
        folders.first { $0.isSystem }
    }

    /// 根目录歌曲（不在任何文件夹里）
    private var rootSongs: [Song] {
        songs.filter { $0.folder == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 按 ID 找歌曲
    private func findSong(_ id: UUID) -> Song? {
        songs.first { $0.id == id }
    }

    /// 当前多选对应的歌曲列表（按 sortOrder 排序）
    private var selectedSongs: [Song] {
        selectedSongIDs.compactMap { findSong($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func filtered(_ list: [Song]) -> [Song] {
        guard !searchText.isEmpty else { return list }
        return list.filter { song in
            song.title.localizedCaseInsensitiveContains(searchText) ||
            song.artist.localizedCaseInsensitiveContains(searchText) ||
            song.tagsString.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sortedSongs: [Song] {
        switch sortMode {
        case .manual:
            return songs.sorted { $0.sortOrder < $1.sortOrder }
        case .recent:
            return songs.sorted { $0.updatedAt > $1.updatedAt }
        case .title:
            return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            selectionToolbar
            Divider()
            songList
            Divider()
            footer
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .appFont(14, weight: .medium)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text(L("曲目库"))
                    .appFont(14, weight: .semibold)
                Text("\(songs.count) \(L("首"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Picker(L("排序方式"), selection: $sortMode) {
                    Label(L("手动排序"), systemImage: "hand.draw").tag(SongSortMode.manual)
                    Label(L("最近修改"), systemImage: "clock").tag(SongSortMode.recent)
                    Label(L("标题"), systemImage: "textformat").tag(SongSortMode.title)
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .imageScale(.small)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: 搜索栏

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("搜索曲目"), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: 选中工具栏（v1.7.4 Gamma: 只在多选时显示，单选不弹出"已选 1 项"）

    @ViewBuilder
    private var selectionToolbar: some View {
        if selectedSongIDs.count > 1 {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                Text(selectionCountText)
                    .appFont(12, weight: .medium)
                Spacer()
                Button {
                    selectedSongIDs.removeAll()
                } label: {
                    Text(L("取消选择"))
                        .appFont(11)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.08))
        }
    }

    private var selectionCountText: String {
        if selectedSongIDs.count == 1 {
            return L("已选 1 项")
        } else {
            return L("已选 %d 项").localized(with: selectedSongIDs.count)
        }
    }

    // MARK: 列表（v1.5.2：文件夹 + 根目录 + 回收站 + 多选）

    private var songList: some View {
        List(selection: $selectedSongIDs) {
            // 根目录歌曲
            let visibleRootSongs = filtered(rootSongs)
            ForEach(Array(visibleRootSongs.enumerated()), id: \.element.id) { index, song in
                SongRow(
                    song: song,
                    reorderLine: reorderLine,
                    groupID: Self.rootReorderGroup,
                    isGroupTop: index == 0,
                    isGroupBottom: index == visibleRootSongs.count - 1,
                    onDrop: { ids, dropY, midY in
                        self.handleSongDrop(draggedIDs: ids, target: song, dropY: dropY, targetMidY: midY)
                    }
                )
                    .tag(song.id)
                    .contextMenu {
                        songContextMenu(for: song, allSelectedSongs: selectedSongs)
                    }
            }

            // 文件夹
            ForEach(rootFolders) { folder in
                FolderSection(
                    folder: folder,
                    selectedSongIDs: $selectedSongIDs,
                    currentSelection: selectedSongs,
                    onDropToFolder: { ids in
                        self.handleSongDropToFolderEnd(draggedIDs: ids, folder: folder)
                    },
                    onDropInFolder: { target, ids, dropY, midY in
                        self.handleSongDropInFolder(
                            draggedIDs: ids,
                            target: target,
                            folder: folder,
                            dropY: dropY,
                            targetMidY: midY
                        )
                    },
                    onMoveUp: { song in self.moveSongUp(song) },
                    onMoveDown: { song in self.moveSongDown(song) },
                    onMoveToFolder: { songs, target in self.moveSongsToFolder(songs, folder: target) },
                    allFolders: rootFolders,
                    onFolderMoveUp: { self.moveFolderUp(folder) },
                    onFolderMoveDown: { self.moveFolderDown(folder) },
                    reorderLine: reorderLine
                )
            }

            // 系统回收站（固定最底）
            if let trash = trashFolder {
                TrashSection(
                    folder: trash,
                    selectedSongIDs: $selectedSongIDs,
                    currentSelection: selectedSongs,
                    reorderLine: reorderLine
                )
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if sortedSongs.isEmpty && folders.isEmpty {
                emptyState
            }
        }
    }

    // MARK: 歌曲右键菜单（v1.5.2：支持多选批量）

    @ViewBuilder
    private func songContextMenu(for song: Song, allSelectedSongs: [Song]) -> some View {
        // 如果右键的这首歌在 selection 里，且 selection 数量 > 1，显示批量菜单
        let isMultiSelection = allSelectedSongs.count > 1 && allSelectedSongs.contains(where: { $0.id == song.id })

        if isMultiSelection {
            multiSelectionContextMenu(songs: allSelectedSongs)
        } else {
            singleSongContextMenu(for: song)
        }
    }

    @ViewBuilder
    private func singleSongContextMenu(for song: Song) -> some View {
        let isInTrash = song.folder?.isSystem == true

        if isInTrash {
            Button(L("恢复"), systemImage: "arrow.uturn.backward.circle") {
                restoreFromTrash([song])
            }
            Divider()
            Button(L("永久删除"), systemImage: "trash.slash.fill", role: .destructive) {
                permanentlyDelete([song])
            }
            .tint(.red)
        } else {
            // v1.7.9 GT4: 列表内上移/下移（不跨文件夹）
            Button(L("上移"), systemImage: "arrow.up") { moveSongUp(song) }
            Button(L("下移"), systemImage: "arrow.down") { moveSongDown(song) }
            Divider()
            Button(L("新建段落"), systemImage: "plus.rectangle.on.rectangle") {
                addSection(to: song)
            }
            Button(L("复制"), systemImage: "doc.on.doc") {
                duplicate(song)
            }

            // 归并到文件夹
            if !rootFolders.isEmpty {
                Menu(L("归并到文件夹")) {
                    ForEach(rootFolders) { folder in
                        Button {
                            moveSongsToFolder([song], folder: folder)
                        } label: {
                            Label(folder.name, systemImage: "folder")
                        }
                    }
                }
            }

            Divider()
            Button(L("移到回收站"), systemImage: "trash.fill", role: .destructive) {
                moveToTrash([song])
            }
            .tint(.red)
        }
    }

    @ViewBuilder
    private func multiSelectionContextMenu(songs: [Song]) -> some View {
        let inTrashCount = songs.filter { $0.folder?.isSystem == true }.count
        let notInTrashCount = songs.count - inTrashCount

        if inTrashCount == songs.count {
            // 全部都在回收站
            Button(L("恢复"), systemImage: "arrow.uturn.backward.circle") {
                restoreFromTrash(songs)
            }
            Divider()
            Button(L("永久删除"), systemImage: "trash.slash.fill", role: .destructive) {
                permanentlyDelete(songs)
            }
            .tint(.red)
        } else if notInTrashCount == songs.count {
            // 全部都不在回收站
            Button(L("批量导出"), systemImage: "square.and.arrow.up") {
                exportSongs(songs)
            }
            Divider()

            // 合并到新文件夹
            Button(L("合并到新文件夹"), systemImage: "folder.badge.plus") {
                mergeToNewFolder(songs: songs)
            }

            // 合并到现有文件夹
            if !rootFolders.isEmpty {
                Menu(L("合并到文件夹")) {
                    ForEach(rootFolders) { folder in
                        Button {
                            moveSongsToFolder(songs, folder: folder)
                        } label: {
                            Label(folder.name, systemImage: "folder")
                        }
                    }
                }
            }

            Divider()
            Button(L("批量移到回收站"), systemImage: "trash.fill", role: .destructive) {
                moveToTrash(songs)
            }
            .tint(.red)
        } else {
            // 混合（部分在回收站）：显示简化菜单
            Button(L("批量移到回收站"), systemImage: "trash.fill", role: .destructive) {
                moveToTrash(songs)
            }
            .tint(.red)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .appFont(32)
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? L("还没有歌曲") : L("没有匹配的歌曲"))
                .font(.callout)
                .foregroundStyle(.secondary)
            if searchText.isEmpty {
                Button(L("新建第一首")) { addSong() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding()
    }

    // MARK: 底部

    private var footer: some View {
        HStack(spacing: 6) {
            Button {
                addSong()
            } label: {
                Label(L("新建歌曲"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .help(L("新建歌曲"))

            Divider()
                .frame(height: 18)

            Button {
                addFolder()
            } label: {
                Label(L("新建文件夹"), systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .help(L("新建文件夹"))

            Divider()
                .frame(height: 18)

            // 导入歌曲：支持单文件或多文件批量
            Button {
                importSongs()
            } label: {
                Label(L("导入歌曲"), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .help(L("导入 .smelody.txt 文件（可多选）"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: 操作 - 单首歌曲

    private func addSong() {
        let new = Song(title: "\(L("新歌曲")) \(songs.count + 1)", sortOrder: songs.count)
        context.insert(new)
        let section = SongSection(order: 0, typeName: "Verse")
        section.song = new
        new.sections.append(section)
        try? context.save()
        selectedSongIDs = [new.id]
    }

    private func addSection(to song: Song) {
        let next = SongSection(order: song.orderedSections.count, typeName: "Verse")
        next.song = song
        song.sections.append(next)
        song.updatedAt = Date()
        try? context.save()
    }

    /// 导入歌曲（v1.5.2：支持多选文件）
    private func importSongs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = L("导入")
        panel.message = L("选择要导入的 .smelody.txt 文件（可多选）")
        panel.title = L("导入歌曲")

        panel.begin { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            var importedCount = 0
            var firstImported: Song?
            for url in panel.urls {
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let song = try SongImporter.importFromText(text, into: context)
                    importedCount += 1
                    if firstImported == nil { firstImported = song }
                } catch {
                    continue
                }
            }
            try? context.save()
            if let first = firstImported {
                selectedSongIDs = [first.id]
            }
            let alert = NSAlert()
            alert.messageText = L("导入成功")
            alert.informativeText = L("导入成功 (%d 首歌曲)").localized(with: importedCount)
            alert.alertStyle = .informational
            alert.addButton(withTitle: L("确定"))
            alert.runModal()
        }
    }

    /// 批量导入文件夹（v1.5.2：只扫顶层，不递归套娃，归到同名文件夹）
    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = L("导入")
        panel.message = L("导入文件夹（不递归套娃，归到同名文件夹）")
        panel.title = L("批量导入文件夹")

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let count = try SongImporter.importFolderFlat(at: url, into: context)
                let alert = NSAlert()
                alert.messageText = L("导入成功")
                alert.informativeText = L("导入成功 (%d 首歌曲)").localized(with: count)
                alert.alertStyle = .informational
                alert.addButton(withTitle: L("确定"))
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = L("导入失败")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: L("确定"))
                alert.runModal()
            }
        }
    }

    private func duplicate(_ song: Song) {
        let copy = Song(
            title: song.title + " " + L("副本"),
            artist: song.artist,
            album: song.album,
            languages: song.languages,
            bpm: song.bpm,
            musicalKey: song.musicalKey,
            tags: song.tags,
            sortOrder: songs.count
        )
        context.insert(copy)
        for s in song.orderedSections {
            let newSection = SongSection(
                order: s.order,
                typeName: s.typeName,
                body: s.body,
                customName: s.customName,
                customTag: s.customTag,
                notes: s.notes,
                translation: s.translation
            )
            newSection.song = copy
            copy.sections.append(newSection)
        }
        try? context.save()
    }

    /// v1.5: 删除歌曲 = 移到回收站（v1.5.2：支持批量）
    private func moveToTrash(_ list: [Song]) {
        guard !list.isEmpty else { return }
        let title = list.count == 1
            ? (list[0].title.isEmpty ? L("未命名") : list[0].title)
            : L("已选 %d 项").localized(with: list.count)
        let message = list.count == 1
            ? DeleteConfirmator.singleSongTrashMessage(
                sectionCount: list[0].orderedSections.count,
                ideaCount: list[0].orderedIdeas.count,
                translations: list[0].orderedSections.map(\.translation)
            )
            : L("将 %d 首歌曲移到回收站？\n\n").localized(with: list.count)
                + L("在回收站中再次删除才能永久删除")

        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        guard let trash = SongFolder.fetchTrashFolder(context: context) else { return }

        let idsToRemove = Set(list.map { $0.id })
        for song in list {
            song.folder = trash
        }
        try? context.save()
        // v1.7.4 Beta: 播放 trash 音效
        TrashSound.play()
        // 如果当前选中包含这些，从 selection 移除
        selectedSongIDs.subtract(idsToRemove)
    }

    private func restoreFromTrash(_ list: [Song]) {
        for song in list {
            song.folder = nil
        }
        try? context.save()
    }

    private func permanentlyDelete(_ list: [Song]) {
        let title = list.count == 1
            ? (list[0].title.isEmpty ? L("未命名") : list[0].title)
            : L("已选 %d 项").localized(with: list.count)
        let message = L("将歌曲永久删除？此操作不可恢复！")

        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        let idsToRemove = Set(list.map { $0.id })
        for song in list {
            context.delete(song)
        }
        try? context.save()
        // v1.7.4 Beta: 播放 trash 音效
        TrashSound.play()
        selectedSongIDs.subtract(idsToRemove)
    }

    /// 把歌曲移到指定文件夹
    private func moveSongsToFolder(_ list: [Song], folder: SongFolder) {
        for song in list {
            song.folder = folder
        }
        try? context.save()
    }

    /// 批量合并到新文件夹
    private func mergeToNewFolder(songs: [Song]) {
        let alert = NSAlert()
        alert.messageText = L("合并到新文件夹")
        alert.informativeText = L("输入文件夹名")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("确定"))
        alert.addButton(withTitle: L("取消"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = L("新文件夹")
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let folder = SongFolder(name: name, sortOrder: folders.count)
        context.insert(folder)
        for song in songs {
            song.folder = folder
        }
        try? context.save()
        selectedSongIDs.removeAll()
    }

    /// 批量导出
    private func exportSongs(_ list: [Song]) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = L("选择这里")
        panel.message = L("选择保存批量导出的目录")
        panel.title = L("批量导出")

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let tempFolder = SongFolder(name: "批量导出_\(filenameTimestamp())")
            for song in list {
                song.folder = tempFolder
            }
            try? context.save()
            let result = SongExporter.exportFolder(tempFolder, to: url)
            for song in list {
                song.folder = nil
            }
            context.delete(tempFolder)
            try? context.save()

            let alert = NSAlert()
            alert.messageText = result.failed.isEmpty ? L("导出完成") : L("导出部分失败")
            alert.informativeText = L("成功 %d 首，失败 %d 首").localized(with: result.success, result.failed.count)
            alert.alertStyle = result.failed.isEmpty ? .informational : .warning
            alert.addButton(withTitle: L("确定"))
            alert.runModal()
        }
    }

    private func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private func addFolder() {
        let alert = NSAlert()
        alert.messageText = L("新建文件夹")
        alert.informativeText = L("输入文件夹名")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("确定"))
        alert.addButton(withTitle: L("取消"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = L("新文件夹")
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let folder = SongFolder(name: name, sortOrder: folders.count)
        context.insert(folder)
        try? context.save()
    }

    private func moveToRoot(_ list: [Song]) {
        for song in list {
            song.folder = nil
        }
        try? context.save()
    }

    // MARK: 拖拽排序（v1.7.8 Beta）

    /// 拖到根目录某首歌上：移到根目录，并按落点插进这一整组。
    private func handleSongDrop(draggedIDs: [UUID], target: Song, dropY: CGFloat, targetMidY: CGFloat) {
        applySongReorder(draggedIDs: draggedIDs, target: target, folder: nil, dropY: dropY, targetMidY: targetMidY)
    }

    /// 拖到文件夹里某首歌上：移进该文件夹，并按落点插进这一整组。
    private func handleSongDropInFolder(
        draggedIDs: [UUID],
        target: Song,
        folder: SongFolder,
        dropY: CGFloat,
        targetMidY: CGFloat
    ) {
        applySongReorder(draggedIDs: draggedIDs, target: target, folder: folder, dropY: dropY, targetMidY: targetMidY)
    }

    /// 用目标所在的整组歌曲重排，搜索没显示出来的也留在原相对位置。只改这一组的序号。
    private func applySongReorder(
        draggedIDs: [UUID],
        target: Song,
        folder: SongFolder?,
        dropY: CGFloat,
        targetMidY: CGFloat
    ) {
        let dragged = draggedIDs.compactMap { findSong($0) }
        guard !dragged.isEmpty else { return }
        let siblings = siblingSongs(in: folder)
        let siblingIDs = Set(siblings.map(\.id))
        let incoming = dragged
            .filter { !siblingIDs.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
        var orderedIDs = siblings.map(\.id)
        for song in incoming where !orderedIDs.contains(song.id) {
            orderedIDs.append(song.id)
        }
        let moved = SectionDragMath.reorderedSiblingIDs(
            orderedIDs: orderedIDs,
            draggedIDs: dragged.map(\.id),
            targetID: target.id,
            dropY: dropY,
            targetMidY: targetMidY
        )
        if moved == orderedIDs && incoming.isEmpty { return }
        var byID: [UUID: Song] = [:]
        for song in siblings { byID[song.id] = song }
        for song in dragged { byID[song.id] = song }
        let movedIDs = Set(moved)
        for song in dragged where movedIDs.contains(song.id) {
            song.folder = folder
        }
        for (index, id) in moved.enumerated() {
            byID[id]?.sortOrder = index
        }
        try? context.save()
    }

    /// 根目录或某个文件夹里的全部歌曲，不看搜索框。
    private func siblingSongs(in folder: SongFolder?) -> [Song] {
        if let folder {
            return folder.orderedSongs.sorted { $0.sortOrder < $1.sortOrder }
        }
        return songs.filter { $0.folder == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 拖动到 folder 末尾（label）：加入该 folder + 排到末尾
    private func handleSongDropToFolderEnd(draggedIDs: [UUID], folder: SongFolder) {
        let dragged = draggedIDs.compactMap { findSong($0) }
        guard !dragged.isEmpty else { return }
        let existing = folder.orderedSongs.sorted { $0.sortOrder < $1.sortOrder }
        for song in dragged {
            song.folder = folder
        }
        // 排到末尾
        let startIndex = existing.count
        for (i, s) in dragged.enumerated() {
            s.sortOrder = startIndex + i
        }
        try? context.save()
        normalizeSortOrder(in: folder)
    }

    /// 把某 folder 内（或根目录）的 sortOrder 重新整理为 0, 1, 2, ...
    private func normalizeSortOrder(in folder: SongFolder?) {
        let siblings: [Song]
        if let f = folder {
            siblings = f.orderedSongs.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            // 拆开 complex expression（type-check 友好）
            let rootList: [Song] = songs.filter { $0.folder == nil }
            siblings = rootList.sorted { $0.sortOrder < $1.sortOrder }
        }
        for (i, s) in siblings.enumerated() {
            s.sortOrder = i
        }
        try? context.save()
    }

    // v1.7.9 GT4: 列表内上移/下移（不跨文件夹，仅交换同列表内 sortOrder）
    private func moveSongUp(_ song: Song) {
        let siblings: [Song]
        if let f = song.folder {
            siblings = f.orderedSongs.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            siblings = songs.filter { $0.folder == nil }.sorted { $0.sortOrder < $1.sortOrder }
        }
        guard let idx = siblings.firstIndex(where: { $0.id == song.id }), idx > 0 else { return }
        let prev = siblings[idx - 1]
        let tmp = song.sortOrder
        song.sortOrder = prev.sortOrder
        prev.sortOrder = tmp
        try? context.save()
    }

    private func moveSongDown(_ song: Song) {
        let siblings: [Song]
        if let f = song.folder {
            siblings = f.orderedSongs.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            siblings = songs.filter { $0.folder == nil }.sorted { $0.sortOrder < $1.sortOrder }
        }
        guard let idx = siblings.firstIndex(where: { $0.id == song.id }), idx < siblings.count - 1 else { return }
        let next = siblings[idx + 1]
        let tmp = song.sortOrder
        song.sortOrder = next.sortOrder
        next.sortOrder = tmp
        try? context.save()
    }

    // v1.7.9 GT5: 文件夹列表内上移/下移（仅在文件夹间交换 sortOrder）
    // 注意：List 渲染顺序是「根目录歌曲 ForEach」在前、「文件夹 ForEach」在后，
    // 所以文件夹 sortOrder 变化不会让文件夹越过根目录歌曲
    private func moveFolderUp(_ folder: SongFolder) {
        let siblings = rootFolders
        guard let idx = siblings.firstIndex(where: { $0.id == folder.id }), idx > 0 else { return }
        let prev = siblings[idx - 1]
        let tmp = folder.sortOrder
        folder.sortOrder = prev.sortOrder
        prev.sortOrder = tmp
        try? context.save()
    }

    private func moveFolderDown(_ folder: SongFolder) {
        let siblings = rootFolders
        guard let idx = siblings.firstIndex(where: { $0.id == folder.id }), idx < siblings.count - 1 else { return }
        let next = siblings[idx + 1]
        let tmp = folder.sortOrder
        folder.sortOrder = next.sortOrder
        next.sortOrder = tmp
        try? context.save()
    }

}

// MARK: - 文件夹分组视图（v1.5.2：完整歌曲右键菜单）

private struct FolderSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var folder: SongFolder
    @Binding var selectedSongIDs: Set<UUID>
    let currentSelection: [Song]
    /// v1.7.8 Beta: 拖到 folder label 时回调（参数：被拖入的 song ID 列表）
    let onDropToFolder: ([UUID]) -> Void
    /// 拖到文件夹内某首歌上：目标、被拖歌曲、落点纵坐标、行中线
    let onDropInFolder: (Song, [UUID], CGFloat, CGFloat) -> Void
    /// v1.7.9 GT4: 上移/下移回调（列表内排序，不跨文件夹）
    let onMoveUp: (Song) -> Void
    let onMoveDown: (Song) -> Void
    /// v1.7.9 GT4: 移到其他文件夹回调（参数：歌曲列表 + 目标文件夹）
    let onMoveToFolder: ([Song], SongFolder) -> Void
    /// v1.7.9 GT4: 所有根文件夹（用于"移到其他文件夹"子菜单，排除当前文件夹）
    let allFolders: [SongFolder]
    /// v1.7.9 GT5: 文件夹自身的上移/下移回调（文件夹间排序，不越过根目录歌曲）
    let onFolderMoveUp: () -> Void
    let onFolderMoveDown: () -> Void
    let reorderLine: SongReorderLineState

    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            let visibleSongs = folder.orderedSongs
            ForEach(Array(visibleSongs.enumerated()), id: \.element.id) { index, song in
                SongRow(
                    song: song,
                    reorderLine: reorderLine,
                    groupID: folder.id,
                    isGroupTop: index == 0,
                    isGroupBottom: index == visibleSongs.count - 1,
                    onDrop: { ids, dropY, midY in
                        onDropInFolder(song, ids, dropY, midY)
                    }
                )
                    .tag(song.id)
                    .contextMenu {
                        songContextMenu(for: song)
                    }
            }
        } label: {
            // v1.7.9 Delta+: 用 Button 拦截单击 → 不会冒泡到外层 List(selection:)，避免 folder 被"误选中"
            // 之前用 .onTapGesture(count: 2) 时，单击事件冒泡到 List，SwiftUI 会把 folder row 当作 selection 目标
            // → 用户感觉"低概率单击选中了 folder"。改成 Button 后单击就 toggle 展开，selection 不会触发
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color(hex: folder.colorHex) ?? .accentColor)
                    Text(folder.name)
                        .appFont(12, weight: .semibold)
                        .lineLimit(1)
                    Spacer()
                    Text("\(folder.orderedSongs.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // v1.7.8 Beta: 拖到 folder label 加入 folder（排到末尾）
            .dropDestination(for: String.self) { items, _ in
                let ids = items.compactMap { UUID(uuidString: $0) }
                guard !ids.isEmpty else { return false }
                onDropToFolder(ids)
                return true
            }
            // v1.7.4 Gamma: 文件夹右键菜单移到 label 内部 HStack 后，
            // 之前放在 DisclosureGroup 整体外会拦截 children 的右键事件
            // → 导致 FolderSection 内的歌曲右键不出菜单
            .contextMenu {
                // v1.7.9 GT5: 文件夹列表内上移/下移（不越过根目录歌曲）
                Button(L("上移"), systemImage: "arrow.up") { onFolderMoveUp() }
                Button(L("下移"), systemImage: "arrow.down") { onFolderMoveDown() }
                Divider()
                Button(L("重命名"), systemImage: "pencil") {
                    renameFolder(folder)
                }
                Button(L("解散文件夹"), systemImage: "tray.and.arrow.up") {
                    disbandFolder(folder)
                }
                Divider()
                Button(L("导出文件夹"), systemImage: "square.and.arrow.up") {
                    exportFolder(folder)
                }
                Divider()
                Button(L("删除文件夹"), systemImage: "trash.fill", role: .destructive) {
                    deleteFolder(folder)
                }
                .tint(.red)
            }
        }
        .help(L("单击展开/折叠文件夹"))
    }

    /// v1.5.2: 文件夹内歌曲完整右键菜单
    @ViewBuilder
    private func songContextMenu(for song: Song) -> some View {
        let isMultiSelection = currentSelection.count > 1 && currentSelection.contains(where: { $0.id == song.id })

        if isMultiSelection {
            // 多选菜单
            Button(L("批量导出"), systemImage: "square.and.arrow.up") {
                exportBatch(currentSelection)
            }
            Divider()
            // v1.7.9 GT4: 批量移到其他文件夹
            let otherFolders = allFolders.filter { $0.id != folder.id }
            if !otherFolders.isEmpty {
                Menu(L("批量移到其他文件夹")) {
                    ForEach(otherFolders) { f in
                        Button {
                            onMoveToFolder(currentSelection, f)
                        } label: {
                            Label(f.name, systemImage: "folder")
                        }
                    }
                }
            }
            Button(L("批量移到根目录"), systemImage: "arrow.up.forward") {
                for s in currentSelection { s.folder = nil }
                try? context.save()
            }
            Divider()
            Button(L("批量移到回收站"), systemImage: "trash.fill", role: .destructive) {
                moveToTrashBatch(currentSelection)
            }
            .tint(.red)
        } else {
            // 单选菜单
            // v1.7.9 GT4: 列表内上移/下移（不跨文件夹）
            Button(L("上移"), systemImage: "arrow.up") { onMoveUp(song) }
            Button(L("下移"), systemImage: "arrow.down") { onMoveDown(song) }
            Divider()
            Button(L("新建段落"), systemImage: "plus.rectangle.on.rectangle") {
                let next = SongSection(order: song.orderedSections.count, typeName: "Verse")
                next.song = song
                song.sections.append(next)
                song.updatedAt = Date()
                try? context.save()
            }
            Button(L("复制"), systemImage: "doc.on.doc") {
                duplicate(song)
            }
            Divider()
            // v1.7.9 GT4: 移到其他文件夹（排除当前文件夹）
            let otherFolders = allFolders.filter { $0.id != folder.id }
            if !otherFolders.isEmpty {
                Menu(L("移到其他文件夹")) {
                    ForEach(otherFolders) { f in
                        Button {
                            onMoveToFolder([song], f)
                        } label: {
                            Label(f.name, systemImage: "folder")
                        }
                    }
                }
            }
            Button(L("移到根目录"), systemImage: "arrow.up.forward") {
                song.folder = nil
                try? context.save()
            }
            Divider()
            Button(L("移到回收站"), systemImage: "trash.fill", role: .destructive) {
                guard let trash = SongFolder.fetchTrashFolder(context: context) else { return }
                song.folder = trash
                try? context.save()
            }
            .tint(.red)
        }
    }

    private func renameFolder(_ folder: SongFolder) {
        let alert = NSAlert()
        alert.messageText = L("重命名")
        alert.informativeText = L("输入新文件夹名")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("确定"))
        alert.addButton(withTitle: L("取消"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = folder.name
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else { return }
            folder.name = newName
            try? context.save()
        }
    }

    private func disbandFolder(_ folder: SongFolder) {
        let message = L("将解散文件夹") + "「\(folder.name)」\n"
            + L("所有歌曲将移到根目录，文件夹本身会被删除。")

        guard DeleteConfirmator.confirm(title: L("解散文件夹"), message: message) else { return }
        for song in folder.orderedSongs {
            song.folder = nil
        }
        context.delete(folder)
        try? context.save()
    }

    /// v1.6: 删除文件夹（先移到回收站，回收站里再删才永久删除）
    private func deleteFolder(_ folder: SongFolder) {
        let songCount = folder.orderedSongs.count
        let message = L("将永久删除文件夹及其中所有歌曲？此操作不可恢复！")
        guard DeleteConfirmator.confirm(title: L("删除文件夹"), message: message) else { return }

        // 把所有歌曲移到回收站（用户可在回收站二次删除）
        guard let trash = SongFolder.fetchTrashFolder(context: context) else { return }
        for song in folder.orderedSongs {
            song.folder = trash
        }
        // 删除文件夹本身
        context.delete(folder)
        try? context.save()
        // v1.7.4 Beta: 播放 trash 音效
        TrashSound.play()
        _ = songCount  // 显式忽略（用于语义清晰）
    }

    private func exportFolder(_ folder: SongFolder) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = L("选择这里")
        panel.message = L("选择保存导出文件夹的目录")
        panel.title = L("导出文件夹")

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let result = SongExporter.exportFolder(folder, to: url)
            let alert = NSAlert()
            alert.messageText = result.failed.isEmpty ? L("导出完成") : L("导出部分失败")
            alert.informativeText = "成功 \(result.success) 首"
            alert.alertStyle = result.failed.isEmpty ? .informational : .warning
            alert.addButton(withTitle: L("确定"))
            alert.runModal()
        }
    }

    private func duplicate(_ song: Song) {
        let copy = Song(
            title: song.title + " " + L("副本"),
            artist: song.artist,
            album: song.album,
            languages: song.languages,
            bpm: song.bpm,
            musicalKey: song.musicalKey,
            tags: song.tags,
            sortOrder: song.folder?.songs.count ?? 0
        )
        context.insert(copy)
        copy.folder = song.folder
        for s in song.orderedSections {
            let newSection = SongSection(
                order: s.order,
                typeName: s.typeName,
                body: s.body,
                customName: s.customName,
                customTag: s.customTag,
                notes: s.notes,
                translation: s.translation
            )
            newSection.song = copy
            copy.sections.append(newSection)
        }
        try? context.save()
    }

    private func exportBatch(_ list: [Song]) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = L("选择这里")
        panel.title = L("批量导出")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let tempFolder = SongFolder(name: "批量导出_\(filenameTimestamp())")
            for s in list { s.folder = tempFolder }
            try? context.save()
            let result = SongExporter.exportFolder(tempFolder, to: url)
            for s in list { s.folder = list.first?.folder }
            context.delete(tempFolder)
            try? context.save()
            let alert = NSAlert()
            alert.messageText = result.failed.isEmpty ? L("导出完成") : L("导出部分失败")
            alert.informativeText = L("成功 %d 首，失败 %d 首").localized(with: result.success, result.failed.count)
            alert.alertStyle = result.failed.isEmpty ? .informational : .warning
            alert.addButton(withTitle: L("确定"))
            alert.runModal()
        }
    }


    private func moveToTrashBatch(_ list: [Song]) {
        let title = L("已选 %d 项").localized(with: list.count)
        let message = L("将 %d 首歌曲移到回收站？\n\n").localized(with: list.count)
            + L("在回收站中再次删除才能永久删除")
        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        guard let trash = SongFolder.fetchTrashFolder(context: context) else { return }
        for song in list {
            song.folder = trash
        }
        try? context.save()
        let ids = Set(list.map { $0.id })
        selectedSongIDs.subtract(ids)
    }

    private func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}

// MARK: - 回收站分组视图

private struct TrashSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var folder: SongFolder
    @Binding var selectedSongIDs: Set<UUID>
    let currentSelection: [Song]
    let reorderLine: SongReorderLineState

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.orderedSongs) { song in
                // v1.7.8 Beta: 回收站里的歌曲不支持拖入（onDrop 不传，等于空回调）
                SongRow(song: song, reorderLine: reorderLine, acceptsReorder: false, onDrop: { _, _, _ in })
                    .tag(song.id)
                    .contextMenu {
                        let isMultiSelection = currentSelection.count > 1 && currentSelection.contains(where: { $0.id == song.id })
                        if isMultiSelection {
                            Button(L("批量恢复"), systemImage: "arrow.uturn.backward.circle") {
                                for s in currentSelection { s.folder = nil }
                                try? context.save()
                            }
                            Divider()
                            Button(L("批量永久删除"), systemImage: "trash.slash.fill", role: .destructive) {
                                let title = L("已选 %d 项").localized(with: currentSelection.count)
                                let message = L("将歌曲永久删除？此操作不可恢复！")
                                guard DeleteConfirmator.confirm(title: title, message: message) else { return }
                                for s in currentSelection { context.delete(s) }
                                try? context.save()
                                TrashSound.play()
                                selectedSongIDs.removeAll()
                            }
                            .tint(.red)
                        } else {
                            Button(L("恢复"), systemImage: "arrow.uturn.backward.circle") {
                                song.folder = nil
                                try? context.save()
                            }
                            Divider()
                            Button(L("永久删除"), systemImage: "trash.slash.fill", role: .destructive) {
                                let message = L("将歌曲永久删除？此操作不可恢复！")
                                guard DeleteConfirmator.confirm(title: song.title, message: message) else { return }
                                context.delete(song)
                                try? context.save()
                                TrashSound.play()
                                selectedSongIDs.removeAll()
                            }
                            .tint(.red)
                        }
                    }
            }
        } label: {
            // v1.7.9 Delta+: 同 FolderSection，用 Button 拦截单击避免被外层 List selection 误选
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(Color(hex: folder.colorHex) ?? .red)
                    Text(L("回收站"))
                        .appFont(12, weight: .semibold)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("\(folder.orderedSongs.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .help(L("单击展开/折叠回收站"))
    }
}

enum SongSortMode: Hashable {
    case manual, recent, title
}

private struct SongRow: View {
    let song: Song
    @ObservedObject var reorderLine: SongReorderLineState
    /// 根目录或某个文件夹。同一栏的缝才合并成一条线。
    var groupID: UUID = UUID()
    var isGroupTop: Bool = false
    var isGroupBottom: Bool = false
    /// 回收站不接受重排，也不画落点横线。
    var acceptsReorder: Bool = true
    /// 被拖歌曲、落点纵坐标、分界。顶头和垫底分界更宽，其余在中线。
    let onDrop: ([UUID], CGFloat, CGFloat) -> Void

    @State private var rowHeight: CGFloat = 1

    private var showsLine: Bool {
        let sides = SectionDragMath.reorderLineSides(for: ReorderDragCenter.shared.subject)
        return acceptsReorder && sides.songLibrary && reorderLine.claim?.rowID == song.id
    }

    private var lineOnTop: Bool {
        reorderLine.claim?.insertsBefore == true
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: [.accentColor.opacity(0.8), .accentColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                Image(systemName: "music.note")
                    .foregroundStyle(.white)
                    .appFont(14, weight: .semibold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title.isEmpty ? L("未命名") : song.title)
                    .appFont(13, weight: .medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .lineLimit(1)
                    }
                    Text("·")
                    Text("\(song.orderedSections.count) \(L("段"))")
                    if let bpm = song.bpm {
                        Text("·")
                        Text("\(bpm) BPM")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rowHeight = max(geo.size.height, 1) }
                    .onChange(of: geo.size.height) { _, height in
                        rowHeight = max(height, 1)
                    }
            }
        )
        .background {
            if acceptsReorder {
                SongReorderEdgeTracker(
                    rowID: song.id,
                    groupID: groupID,
                    isGroupTop: isGroupTop,
                    isGroupBottom: isGroupBottom,
                    lineState: reorderLine
                )
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: lineOnTop ? .top : .bottom) {
            if showsLine {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2.5)
                    .padding(.horizontal, 4)
                    .allowsHitTesting(false)
            }
        }
        .draggable(song.id.uuidString) {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .foregroundStyle(.tint)
                Text(song.title.isEmpty ? L("未命名") : song.title)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .dropDestination(for: String.self) { items, location in
            let dropY = location.y
            let split = SectionDragMath.reorderSplitY(
                rowHeight: max(rowHeight, 1),
                isGroupTop: isGroupTop,
                isGroupBottom: isGroupBottom
            )
            let ids = items.compactMap { UUID(uuidString: $0) }
            guard !ids.isEmpty else { return false }
            guard acceptsReorder else { return true }
            onDrop(ids, dropY, split)
            return true
        }
        .onDisappear {
            reorderLine.unregister(rowID: song.id)
        }
    }
}

/// 同一栏里相邻两首只画一条缝。拖动时同时看所有歌曲行，不能只看当前悬停的那一行。
private final class SongReorderLineState: ObservableObject {
    struct Claim: Equatable {
        var rowID: UUID
        var insertsBefore: Bool
    }

    private final class RowAnchor {
        weak var view: NSView?
        var groupID: UUID
        var isGroupTop: Bool
        var isGroupBottom: Bool
        init(view: NSView, groupID: UUID, isGroupTop: Bool, isGroupBottom: Bool) {
            self.view = view
            self.groupID = groupID
            self.isGroupTop = isGroupTop
            self.isGroupBottom = isGroupBottom
        }
    }

    @Published private(set) var claim: Claim?
    private var anchors: [UUID: RowAnchor] = [:]
    private var rows: [UUID: SectionDragMath.SongReorderLineSpan] = [:]
    private var pointerY: CGFloat?
    private var monitor: Any?
    private var timer: Timer?
    /// 按下时指针是否在某一行的屏幕矩形里（含左右）。只记这一下，拖出侧栏后仍算拖歌曲。
    private var dragBeganInSongRow = false
    /// 按下时拖放剪贴板的代数。没变过的内容是上一次留下的，不能当成这次在拖歌曲。
    private var dragPasteboardChangeCount = 0

    func register(rowID: UUID, view: NSView, groupID: UUID, isGroupTop: Bool, isGroupBottom: Bool) {
        if let anchor = anchors[rowID] {
            anchor.view = view
            anchor.groupID = groupID
            anchor.isGroupTop = isGroupTop
            anchor.isGroupBottom = isGroupBottom
        } else {
            anchors[rowID] = RowAnchor(
                view: view,
                groupID: groupID,
                isGroupTop: isGroupTop,
                isGroupBottom: isGroupBottom
            )
        }
        ensureMonitor()
    }

    func unregister(rowID: UUID) {
        anchors.removeValue(forKey: rowID)
        rows.removeValue(forKey: rowID)
        guard pointerY != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.publish()
        }
    }

    private func ensureMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            switch event.type {
            case .leftMouseDown:
                self.noteMouseDown()
            case .leftMouseUp:
                self.noteMouseUp()
            default:
                self.noteMouseDragged()
            }
            return event
        }
    }

    private func noteMouseDown() {
        dragBeganInSongRow = pointerInsideSongRow(NSEvent.mouseLocation)
        dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
    }

    private func noteMouseUp() {
        if ReorderDragCenter.shared.subject == .song {
            ReorderDragCenter.shared.setSubject(.none)
        }
        endDrag()
        dragBeganInSongRow = false
    }

    /// 任意一次按下拖动都不画曲目库横条。只有判定结果是歌曲时才采样。
    private func noteMouseDragged() {
        let subject = currentDragSubject()
        let sides = SectionDragMath.reorderLineSides(for: subject)
        guard sides.songLibrary else {
            if ReorderDragCenter.shared.subject == .song {
                ReorderDragCenter.shared.setSubject(.none)
            }
            if timer != nil || claim != nil || pointerY != nil {
                endDrag()
            }
            return
        }
        ReorderDragCenter.shared.setSubject(.song)
        startDragging()
    }

    private func currentDragSubject() -> SectionDragMath.ReorderDragSubject {
        let pasteboard = NSPasteboard(name: .drag)
        let fresh = pasteboard.changeCount != dragPasteboardChangeCount
        let types = (pasteboard.types ?? []).map(\.rawValue)
        var strings: [String] = []
        if let text = pasteboard.string(forType: .string) {
            strings.append(text)
        }
        let utf8 = NSPasteboard.PasteboardType("public.utf8-plain-text")
        if let text = pasteboard.string(forType: utf8), !strings.contains(text) {
            strings.append(text)
        }
        return SectionDragMath.reorderDragSubject(
            pointerBeganInsideSongRow: dragBeganInSongRow,
            pasteboardTypeIDs: types,
            pasteboardStrings: strings,
            pasteboardChangeIsFresh: fresh
        )
    }

    /// 整行矩形，含左右。宽或高不像歌曲行的视图不当成歌曲行，避免整窗误判。
    private func pointerInsideSongRow(_ screenPoint: NSPoint) -> Bool {
        for anchor in anchors.values {
            guard let view = anchor.view, let window = view.window else { continue }
            let onScreen = window.convertToScreen(view.convert(view.bounds, to: nil))
            guard onScreen.width > 1, onScreen.width < 500,
                  onScreen.height > 1, onScreen.height < 600 else { continue }
            if onScreen.contains(screenPoint) { return true }
        }
        return false
    }

    private func startDragging() {
        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.sample()
            }
            let tracking = RunLoop.Mode(rawValue: "NSEventTrackingRunLoopMode")
            RunLoop.main.add(timer, forMode: .common)
            RunLoop.main.add(timer, forMode: tracking)
            self.timer = timer
        }
        sample()
    }

    private func endDrag() {
        timer?.invalidate()
        timer = nil
        pointerY = nil
        publish()
    }

    /// 屏幕坐标原点在左下，这里改成从上往下，好和相邻行比哪一条缝更近。
    private func sample() {
        let down = NSEvent.pressedMouseButtons & (1 << 0) != 0
        guard down else {
            endDrag()
            return
        }
        var spans: [UUID: SectionDragMath.SongReorderLineSpan] = [:]
        for (id, anchor) in anchors {
            guard let view = anchor.view, let window = view.window else { continue }
            let onScreen = window.convertToScreen(view.convert(view.bounds, to: nil))
            guard onScreen.height > 0 else { continue }
            spans[id] = SectionDragMath.SongReorderLineSpan(
                id: id,
                minY: -onScreen.maxY,
                height: onScreen.height,
                groupID: anchor.groupID,
                isGroupTop: anchor.isGroupTop,
                isGroupBottom: anchor.isGroupBottom
            )
        }
        rows = spans
        pointerY = -NSEvent.mouseLocation.y
        publish()
    }

    private func publish() {
        let sides = SectionDragMath.reorderLineSides(for: ReorderDragCenter.shared.subject)
        let next: Claim?
        if sides.songLibrary, let pointerY {
            let winner = SectionDragMath.exclusiveReorderClaim(
                pointerY: pointerY,
                rows: Array(rows.values)
            )
            next = winner.map { Claim(rowID: $0.id, insertsBefore: $0.insertsBefore) }
        } else {
            next = nil
        }
        if claim != next {
            claim = next
        }
    }

    deinit {
        timer?.invalidate()
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// 拖动还没松手时登记这一行的位置。落点由全部歌曲行一起算，不能只看悬停的那一行。
private struct SongReorderEdgeTracker: NSViewRepresentable {
    var rowID: UUID
    var groupID: UUID
    var isGroupTop: Bool
    var isGroupBottom: Bool
    var lineState: SongReorderLineState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.sync(view, from: self)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.sync(nsView, from: self)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.lineState?.unregister(rowID: coordinator.rowID)
    }

    final class Coordinator {
        var rowID = UUID()
        var lineState: SongReorderLineState?

        func sync(_ view: NSView, from tracker: SongReorderEdgeTracker) {
            rowID = tracker.rowID
            lineState = tracker.lineState
            tracker.lineState.register(
                rowID: tracker.rowID,
                view: view,
                groupID: tracker.groupID,
                isGroupTop: tracker.isGroupTop,
                isGroupBottom: tracker.isGroupBottom
            )
        }
    }
}