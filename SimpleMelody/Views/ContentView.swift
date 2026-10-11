// 三栏根视图：左侧曲目 / 中间编辑 / 右侧（灵感 / 歌词预览）
// v1.7: 右栏两个互斥模块（灵感与设定 / 歌词预览），toolbar 双 toggle 切换

import SwiftUI
import SwiftData

/// v1.7.9 Gamma+: 切换歌词动画方向枚举（保留兼容）
/// v1.7.9 Delta+: 实际动画统一强制从右往左（不再根据索引算方向，避免快速切换下的反向 bug）
enum SongTransitionDirection: Equatable {
    case none
    case forward
    case backward
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var themeManager: ThemeManager

    @Query(sort: [SortDescriptor(\Song.updatedAt, order: .reverse)])
    private var songs: [Song]

    @State private var selectedSongIDs: Set<UUID> = []
    @State private var primarySongID: UUID?
    /// v1.7.9 Delta+: 曲目库排序 + 搜索（在 ContentView 持有，与 SongSidebarView 双向同步）
    @State private var sidebarSortMode: SongSortMode = .manual
    @State private var sidebarSearchText: String = ""
    /// v1.7.9 Delta+: 是否允许下一次 activeSectionID 变化触发 TextEditor 聚焦
    /// false = 切歌/系统行为（不聚焦）；true = 用户主动点击段落 / 双击歌词预览（聚焦）
    @State private var focusBodyOnNextSectionChange: Bool = false
    /// v1.7.5 Gamma: ⌘D 触发删除时需要的当前选中的 [Song]
    private var selectedSongs: [Song] {
        songs.filter { selectedSongIDs.contains($0.id) }
    }
    private var editingSongID: UUID? {
        // v1.7.8 Delta: 用 Set 加速 contains，避免歌曲多时列表切换卡顿
        let songIDSet = Set(songs.map(\.id))
        if let p = primarySongID, songIDSet.contains(p),
           selectedSongIDs.contains(p) {
            return p
        }
        return selectedSongIDs.first(where: songIDSet.contains)
    }

    /// 右栏模式（互斥：off / idea / preview / settings）
    @State private var rightPanelMode: RightPanelMode = .idea

    @State private var showSectionPanel: Bool = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// v1.7: 当前激活段落（编辑区 / 预览区共享）
    @State private var activeSectionID: UUID?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SongSidebarView(
                selectedSongIDs: $selectedSongIDs,
                sortMode: $sidebarSortMode,
                searchText: $sidebarSearchText
            )
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            // 右栏不走分栏宽度约束：那个值一变就跳。编辑区让出的宽度由这里插值。
            HStack(spacing: 0) {
                editorColumn
                rightColumn
            }
        }
        .navigationTitle("")
        .focusedValue(\.selectedSongID, editingSongID)
        // v1.7.8 Delta: 切歌时重置激活段落（去掉 .id(song.id) 后移到外层监听 editingSongID）
        .onChange(of: editingSongID) { oldID, newID in
            // v1.7.9 Delta+: 不再计算方向，统一从右往左；切换动画不再依赖索引
            if let id = newID, let song = songs.first(where: { $0.id == id }) {
                activeSectionID = song.orderedSections.first?.id
            } else {
                activeSectionID = nil
            }
            // v1.7.9 Delta+: 切歌属于"系统行为"，不自动聚焦 TextEditor（避免光标突然出现）
            focusBodyOnNextSectionChange = false
        }
        // v1.7.9 Beta+: 切歌时播放丝滑过渡动画（用 spring，0.3s 延迟修复保留 editingSongID Set 优化）
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: editingSongID)
        // v1.7.3 Delta: 主视图（侧栏 + 编辑区 + 详情）跟 ThemeManager 主题变化
        // 之前 SettingsView popover 内应用主题后主视图不会立即变色，要切歌 / 重新打开窗口才生效
        .preferredColorScheme(themeManager.preferredColorScheme)
        .toolbar { toolbarContent }
        .onReceive(NotificationCenter.default.publisher(for: .newSongRequested)) { _ in
            createNewSong()
        }
        // v1.7.5 Gamma: ⌘D 删除多选歌曲
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedSongsRequested)) { _ in
            handleDeleteSelected()
        }
        .onAppear {
            UpdateChecker.shared.checkOnLaunch()
        }
    }

    /// v1.7.5 Gamma: ⌘D 删除多选歌曲
    /// 逻辑与 SongSidebarView.moveToTrash 一致（不在回收站的歌曲移到回收站）
    private func handleDeleteSelected() {
        let songs = selectedSongs
        guard !songs.isEmpty else { return }
        let notInTrash = songs.filter { $0.folder?.isSystem != true }
        let toTrash = notInTrash.isEmpty ? [] : notInTrash

        guard !toTrash.isEmpty else { return }

        let title = toTrash.count == 1
            ? (toTrash[0].title.isEmpty ? L("未命名") : toTrash[0].title)
            : L("已选 %d 项").localized(with: toTrash.count)
        let message = toTrash.count == 1
            ? DeleteConfirmator.singleSongTrashMessage(
                sectionCount: toTrash[0].orderedSections.count,
                ideaCount: toTrash[0].orderedIdeas.count,
                translations: toTrash[0].orderedSections.map(\.translation)
            )
            : L("将 %d 首歌曲移到回收站？\n\n").localized(with: toTrash.count)
                + L("在回收站中再次删除才能永久删除")

        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        guard let trash = SongFolder.fetchTrashFolder(context: context) else { return }

        let idsToRemove = Set(toTrash.map { $0.id })
        for song in toTrash {
            song.folder = trash
        }
        try? context.save()
        TrashSound.play()
        selectedSongIDs.subtract(idsToRemove)
    }

    /// 中间歌词编辑区。最小宽度固定，不跟右栏一起被挤没。
    private var editorColumn: some View {
        ZStack {
            if let id = editingSongID, let song = songs.first(where: { $0.id == id }) {
                SongEditorView(
                    song: song,
                    showSectionPanel: $showSectionPanel,
                    activeSectionID: $activeSectionID,
                    focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange
                )
                .id(song.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
            } else {
                EmptySongView()
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 灵感、歌词预览、设置共用这一条。宽度按模式在 0、320、480 之间伸缩。
    private var rightColumn: some View {
        let width = RightColumnMetrics.layout(for: rightPanelMode).idealWidth
        return detailContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(width: width, alignment: .leading)
            .overlay(alignment: .leading) { Divider() }
            .clipped()
            .allowsHitTesting(rightPanelMode != .off)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: rightPanelMode)
    }

    /// 右栏内容。灵感、歌词预览、设置互斥。
    @ViewBuilder
    private var detailContent: some View {
        ZStack {
            switch rightPanelMode {
            case .off:
                Color.clear
                    .transition(.opacity)
            case .idea:
                if let id = editingSongID, let song = songs.first(where: { $0.id == id }) {
                    IdeaPanelView(song: song)
                        .id("idea")
                        .transition(rightPanelTransition(target: .idea))
                }
            case .preview:
                if let id = editingSongID, let song = songs.first(where: { $0.id == id }) {
                    LyricsPreviewView(
                        song: song,
                        activeSectionID: activeSectionID,
                        onSelectSection: { id in
                            // v1.7.2: 双击预览段落 → 跳转到编辑区对应位置
                            // v1.7.9 Delta+: 歌词预览双击 → 允许触发 TextEditor 聚焦（用户主动行为）
                            focusBodyOnNextSectionChange = true
                            activeSectionID = id
                        }
                    )
                    .id("preview")
                    .transition(rightPanelTransition(target: .preview))
                }
            case .settings:
                SettingsView()
                    .environmentObject(themeManager)
                    .id("settings")
                    .transition(rightPanelTransition(target: .settings))
            }
        }
    }

    /// 进入边来自 RightColumnMetrics。move + opacity，spring 仍是右栏已有的那一个。
    private func rightPanelTransition(target: RightPanelMode) -> AnyTransition {
        let layout = RightColumnMetrics.layout(for: target)
        guard layout.enterEdge != .none else { return .opacity }
        return .asymmetric(
            insertion: moveFade(layout.enterEdge),
            removal: moveFade(layout.leaveEdge)
        )
    }

    private func moveFade(_ edge: RightColumnEnterEdge) -> AnyTransition {
        let side: Edge
        switch edge {
        case .leading: side = .leading
        case .trailing: side = .trailing
        case .bottom: side = .bottom
        case .none: return .opacity
        }
        return .move(edge: side).combined(with: .opacity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // 灵感与设定
            Toggle(isOn: ideaToggleBinding) {
                Label(L("灵感分栏"), systemImage: "lightbulb")
            }
            .help(rightPanelMode == .idea ? L("关闭灵感与设定") : L("显示灵感与设定分栏"))

            // 歌词预览（v1.7）
            Toggle(isOn: previewToggleBinding) {
                Label(L("歌词预览"), systemImage: "text.viewfinder")
            }
            .help(rightPanelMode == .preview ? L("关闭歌词预览") : L("显示歌词预览"))

            Toggle(isOn: settingsToggleBinding) {
                Label(L("设置"), systemImage: "gearshape")
            }
            .help(L("设置"))
        }
    }

    /// 灵感开关：打开为灵感，关闭则收起右栏。
    private var ideaToggleBinding: Binding<Bool> {
        Binding(
            get: { rightPanelMode == .idea },
            set: { newValue in
                setRightPanel(newValue ? .idea : .off)
            }
        )
    }

    /// 设置开关：打开为设置，关闭则收起右栏。
    private var settingsToggleBinding: Binding<Bool> {
        Binding(
            get: { rightPanelMode == .settings },
            set: { newValue in
                setRightPanel(newValue ? .settings : .off)
            }
        )
    }

    /// 预览开关：打开为歌词预览，关闭则收起右栏。
    private var previewToggleBinding: Binding<Bool> {
        Binding(
            get: { rightPanelMode == .preview },
            set: { newValue in
                setRightPanel(newValue ? .preview : .off)
            }
        )
    }

    /// 同一条弹簧：宽度从 0、320、480 之间过去，内容的滑入也走这一次。
    private func setRightPanel(_ mode: RightPanelMode) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            rightPanelMode = mode
        }
    }

    private func createNewSong() {
        let new = Song(title: L("新歌曲"), sortOrder: songs.count)
        context.insert(new)
        let section = SongSection(order: 0, typeName: "Verse")
        section.song = new
        new.sections.append(section)
        try? context.save()
        selectedSongIDs = [new.id]
        primarySongID = new.id
        // 激活新歌的第一段
        activeSectionID = new.orderedSections.first?.id
    }
}

private struct EmptySongView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Song.updatedAt, order: .reverse)])
    private var songs: [Song]

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: "logo_monogram") ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .shadow(color: .accentColor.opacity(0.3), radius: 12)

            Text("Simple Melody")
                .appFont(28, weight: .semibold, design: .rounded)

            Text(L("选择左侧的歌曲开始创作，或新建一首新歌。"))
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                let new = Song(title: L("新歌曲"), sortOrder: songs.count)
                context.insert(new)
                let section = SongSection(order: 0, typeName: "Verse")
                section.song = new
                new.sections.append(section)
                try? context.save()
            } label: {
                Label(L("新建歌曲"), systemImage: "plus")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [Song.self, SongSection.self, PronunciationAnnotation.self, SongIdea.self], inMemory: true)
}