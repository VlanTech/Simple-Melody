// Views/Sidebar/SongSidebarView.swift
// 左侧曲目列表
// v1.5.2: 多选（Set<UUID>）+ 批量操作菜单 + 文件夹歌曲完整右键 + 批量导入

import SwiftUI
import SwiftData

struct SongSidebarView: View {
    @Environment(\.modelContext) private var context
    @Binding var selectedSongIDs: Set<UUID>
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
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text(L("曲目库"))
                    .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button {
                    selectedSongIDs.removeAll()
                } label: {
                    Text(L("取消选择"))
                        .font(.system(size: 11))
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
            ForEach(filtered(rootSongs)) { song in
                SongRow(song: song, onDrop: { ids in
                    self.handleSongDrop(draggedIDs: ids, before: song)
                })
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
                    onDropInFolder: { target, ids in
                        self.handleSongDropInFolder(draggedIDs: ids, before: target, folder: folder)
                    },
                    onMoveUp: { song in self.moveSongUp(song) },
                    onMoveDown: { song in self.moveSongDown(song) },
                    onMoveToFolder: { songs, target in self.moveSongsToFolder(songs, folder: target) },
                    allFolders: rootFolders,
                    onFolderMoveUp: { self.moveFolderUp(folder) },
                    onFolderMoveDown: { self.moveFolderDown(folder) }
                )
            }

            // 系统回收站（固定最底）
            if let trash = trashFolder {
                TrashSection(
                    folder: trash,
                    selectedSongIDs: $selectedSongIDs,
                    currentSelection: selectedSongs
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
                .font(.system(size: 32))
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
                notes: s.notes
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
            ? (L("将歌曲移到回收站")
                + "\n" + L("包含") + " \(list[0].orderedSections.count) " + L("个段落")
                + " · \(list[0].orderedIdeas.count) " + L("条灵感与设定")
                + "\n\n" + L("在回收站中再次删除才能永久删除"))
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

    /// 拖动到根目录某 Song 上：移到根 + 排到该 Song 之前
    private func handleSongDrop(draggedIDs: [UUID], before target: Song) {
        let dragged = draggedIDs.compactMap { findSong($0) }
        guard !dragged.isEmpty else { return }
        for song in dragged {
            song.folder = nil
        }
        // sortOrder 是 Int，用 (target.sortOrder - 1) 到 target.sortOrder 之间的整数插入
        let count = dragged.count
        let baseOrder = max(0, target.sortOrder - count)
        for (i, s) in dragged.enumerated() {
            s.sortOrder = baseOrder + i
        }
        try? context.save()
        normalizeSortOrder(in: nil)
    }

    /// 拖动到某 folder 内 Song 上：移到该 folder + 排到该 Song 之前
    private func handleSongDropInFolder(draggedIDs: [UUID], before target: Song, folder: SongFolder) {
        let dragged = draggedIDs.compactMap { findSong($0) }
        guard !dragged.isEmpty else { return }
        for song in dragged {
            song.folder = folder
        }
        let count = dragged.count
        let baseOrder = max(0, target.sortOrder - count)
        for (i, s) in dragged.enumerated() {
            s.sortOrder = baseOrder + i
        }
        try? context.save()
        normalizeSortOrder(in: folder)
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
    /// v1.7.8 Beta: 拖到 folder 内某 Song 上时回调（参数：目标 song + 被拖入 song ID 列表）
    let onDropInFolder: (Song, [UUID]) -> Void
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

    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.orderedSongs) { song in
                SongRow(song: song, onDrop: { ids in
                    onDropInFolder(song, ids)
                })
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
                        .font(.system(size: 12, weight: .semibold))
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
                notes: s.notes
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

    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.orderedSongs) { song in
                // v1.7.8 Beta: 回收站里的歌曲不支持拖入（onDrop 不传，等于空回调）
                SongRow(song: song, onDrop: { _ in })
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
                                TrashSound.play()  // v1.7.4 Beta
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
                                TrashSound.play()  // v1.7.4 Beta
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
                        .font(.system(size: 12, weight: .semibold))
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
    /// v1.7.8 Beta: 接收到拖入时的回调，参数是被拖动的 song ID 列表
    let onDrop: ([UUID]) -> Void

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
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title.isEmpty ? L("未命名") : song.title)
                    .font(.system(size: 13, weight: .medium))
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
        // v1.7.8 Beta: 拖拽支持
        .draggable(song.id.uuidString) {
            // drag preview（拖动时显示的浮动视图）
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .foregroundStyle(.tint)
                Text(song.title.isEmpty ? L("未命名") : song.title)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        // 接收：把拖入的 song 移到本 song 所在 folder + 排在本 song 之前
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap { UUID(uuidString: $0) }.filter { $0 != song.id }
            guard !ids.isEmpty else { return false }
            onDrop(ids)
            return true
        }
    }
}