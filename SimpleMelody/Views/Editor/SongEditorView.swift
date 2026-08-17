// Views/Editor/SongEditorView.swift
// 中间主编辑视图：歌曲元信息 + 段落编辑器列表
// v1.1: 多语言支持 + 本地化

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct SongEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var song: Song
    @Binding var showSectionPanel: Bool
    /// v1.7: 当前激活段落（从右栏预览共享过来）
    @Binding var activeSectionID: UUID?
    /// v1.7.9 Delta+: 是否允许下一次 activeSectionID 变化触发 TextEditor 聚焦
    /// true = 用户主动点击段落（需要聚焦）；false = 系统切歌（不聚焦）
    @Binding var focusBodyOnNextSectionChange: Bool

    @State private var showMetadata = true
    /// v1.7.7 Delta: 节拍器
    @StateObject private var metronome = MetronomeController()
    /// v1.7.8 Gamma+: 拖动时鼠标接近 ScrollView 顶部自动向上滚动
    @StateObject private var autoScroller = DragAutoScroller()

    /// v1.7.9 GT: 段落拖动开关（恢复 BugStable 双模式）
    /// 关闭（默认）：List + .swipeActions 左滑删除
    /// 开启：ScrollView + LazyVStack + .draggable 任意位置拖动
    /// 动画前提：SectionEditorView 已用原生 TextEditor（无 PassthroughScrollTextEditor），
    /// 故 List / ScrollView 两种容器下笔记与折叠展开动画均正常
    @AppStorage("sectionDragEnabled") private var sectionDragEnabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            songHeader
            Divider()
            sectionsScroll
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: song.title) { _, _ in song.updatedAt = Date() }
        .onReceive(NotificationCenter.default.publisher(for: .newSectionRequested)) { _ in
            addSection(typeName: "Verse")
        }
        // v1.7.9 Gamma+: 点编辑器空白区 → 让 window resignFirstResponder（关掉歌词编辑栏的光标）
        // 用 simultaneousGesture 而不是 onTapGesture：让子 view 的 tap 优先命中（避免误触）
        // 空白区域（背景、padding 等）才会触发 resign
        .simultaneousGesture(
            TapGesture().onEnded {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        )
    }

    // MARK: 头部元信息

    private var songHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField(L("歌曲标题"), text: $song.title, axis: .horizontal)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .textFieldStyle(.plain)

                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.primary)
                            .imageScale(.small)
                        TextField(L("艺术家"), text: $song.artist)
                            .textFieldStyle(.plain)
                    }
                    .font(.callout)
                }
                Spacer()
                Menu {
                    Button {
                        exportToText()
                    } label: {
                        Label(L("导出为文本文件（含全部信息）"), systemImage: "square.and.arrow.up")
                    }
                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(song.fullBody, forType: .string)
                    } label: {
                        Label(L("复制全文到剪贴板"), systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)
            }

            HStack(spacing: 14) {
                metadataChip(icon: "globe", label: languageSummaryLabel)
                metadataChip(icon: "metronome", label: song.bpm.map { "\($0) BPM" } ?? "— BPM")
                metadataChip(icon: "music.quarternote.3", label: song.musicalKey ?? "— Key")
                metadataChip(icon: "textformat.alt", label: "\(song.totalCharacters) \(L("字"))")
                // v1.7: 折叠时也显示节拍（按设计风格往后排）
                metadataChip(icon: "metronome.fill", label: song.beat.isEmpty ? "4/4" : song.beat)
                Spacer()
                Button {
                    // v1.7.9 Beta+: 元信息展开/收起 spring 动画（最丝滑手感）
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showMetadata.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showMetadata ? "chevron.up" : "chevron.down")
                            .imageScale(.small)
                        Text(showMetadata ? L("收起") : L("展开元信息"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.10))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
                .foregroundStyle(Color.accentColor)
                .help(showMetadata ? L("收起") : L("展开元信息（语言/BPM/调式/标签）"))
                .frame(minWidth: 80, minHeight: 28)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if showMetadata {
                metadataEditor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // v1.7.9 BugStable: if-else 都挂 transition（v1.7.8 Delta 二进制反汇编确认 transition 是 Optional 标记——必须两边都挂才能触发 transition pair 动画）
                Color.clear
                    .frame(height: 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func metadataChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(ThemeColor.mediumFill)
        )
    }

    private var languageSummaryLabel: String {
        let langs = song.languages
        if langs.isEmpty { return "—" }
        let names = langs.compactMap { SongLanguage.find(code: $0)?.localizedDisplayName }
        return names.joined(separator: " · ")
    }

    private var metadataEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 歌曲语言（多选）
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(L("歌词语言"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(song.languages.count)/\(SongLanguage.all.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .fixedSize()
                languageMultiSelect
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BPM").font(.caption).foregroundStyle(.primary)
                    TextField("—", value: Binding(
                        get: { song.bpm ?? 0 },
                        set: { song.bpm = $0 == 0 ? nil : $0 }
                    ), format: .number)
                    .frame(width: 80)
                    .fixedSize()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("调式")).font(.caption).foregroundStyle(.primary)
                    TextField("C Major", text: Binding(
                        get: { song.musicalKey ?? "" },
                        set: { song.musicalKey = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(width: 140)
                    .fixedSize()
                }

                // v1.6: 节拍下拉选择（不可手动输入）
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("节拍")).font(.caption).foregroundStyle(.primary)
                    Picker("", selection: Binding(
                        get: { BeatPreset.from(string: song.beat) },
                        set: { song.beat = $0.rawValue }
                    )) {
                        ForEach(BeatPreset.standard) { preset in
                            Text(preset.localizedName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 90)
                    .fixedSize()
                }

                // v1.7.7 Delta: 节拍器（声音 + 闪烁）
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("节拍器")).font(.caption).foregroundStyle(.primary)
                    MetronomeView(controller: metronome, bpm: song.bpm, beat: song.beat)
                        .frame(height: 24)
                }
                .onChange(of: song.bpm) { _, _ in
                    if metronome.isRunning { metronome.update(bpm: song.bpm, beat: song.beat) }
                }
                .onChange(of: song.beat) { _, _ in
                    if metronome.isRunning { metronome.update(bpm: song.bpm, beat: song.beat) }
                }
                .onDisappear { metronome.stop() }
            }
            .fixedSize()

            VStack(alignment: .leading, spacing: 4) {
                Text(L("标签（逗号分隔）"))
                    .font(.caption).foregroundStyle(.primary)
                TextField("ballad, sad, summer", text: Binding(
                    get: { song.tagsString },
                    set: { song.tagsString = $0 }
                ))
                .fixedSize()
            }
        }
        .padding(.top, 4)
    }

    // MARK: 多语言选择器（v1.4：chip 锁定 fixedSize 防错位）

    private var languageMultiSelect: some View {
        FlowLayout(spacing: 8) {
            ForEach(SongLanguage.all) { lang in
                let isOn = song.languages.contains(lang.code)
                LanguageToggleChip(
                    language: lang,
                    isOn: isOn,
                    onToggle: { toggleLanguage(lang.code) }
                )
                .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleLanguage(_ code: String) {
        var langs = song.languages
        if let idx = langs.firstIndex(of: code) {
            // 至少保留一个，不能全取消
            if langs.count > 1 {
                langs.remove(at: idx)
            }
        } else {
            langs.append(code)
        }
        song.languages = langs
        song.updatedAt = Date()
        try? context.save()
    }

    // MARK: 段落列表（v1.7.9 Beta：List + 条件性 .onMove / .swipeActions）
    // 段落拖动开关关闭时（默认）：用 List + .swipeActions 左滑删除，无拖动
    // 段落拖动开关开启时：用 List + .onMove 拖动（系统级 NSDraggingSource 与 NSTextView 不冲突）
    // 删除段落：右键菜单（SectionEditorView 的 contextMenu 已有）+ 左滑删除

    /// v1.7.8 Gamma+: 段落 frame 缓存（备用，目前不再使用，因为 List.onMove 系统级拖动不需手动判定段前/段后）
    @State private var sectionFrames: [UUID: CGRect] = [:]

    private var sectionsScroll: some View {
        // v1.7.9 GT3: 统一用 ScrollView+LazyVStack（不用 List）
        // List 的 NSTableView 阻断 transition + view-level .animation，导致笔记/折叠动画失效
        // ScrollView+LazyVStack 下 transition + .animation 正常工作，两种模式动画都正常
        // 区别在 ForEach 内 wrapper：OFF→SwipeDeleteSectionWrapper / ON→DraggableSectionWrapper
        ScrollViewReader { proxy in
            scrollableSectionsView(proxy: proxy)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: song.sections.map(\.id))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sectionDragEnabled)
    }

    /// v1.7.9 GT3: 统一容器 ScrollView + LazyVStack，wrapper 按开关切换
    @ViewBuilder
    private func scrollableSectionsView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(song.orderedSections) { section in
                    if sectionDragEnabled {
                        DraggableSectionWrapper(
                            section: section,
                            languages: song.languages,
                            song: song,
                            activeSectionID: $activeSectionID,
                            focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange,
                            onDrop: { target, ids, location in
                                handleSectionDrop(
                                    draggedIDs: ids,
                                    target: target,
                                    location: location
                                )
                            }
                        )
                        .id("\(section.id.uuidString)-drag")
                        .transition(.opacity)
                    } else {
                        SwipeDeleteSectionWrapper(
                            section: section,
                            languages: song.languages,
                            song: song,
                            activeSectionID: $activeSectionID,
                            focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange,
                            onDelete: { deleteSectionsByID(section.id) }
                        )
                        .id("\(section.id.uuidString)-swipe")
                        .transition(.opacity)
                    }
                }
                addSectionBar
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: activeSectionID) { _, newID in
            guard let id = newID else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                proxy.scrollTo("\(id.uuidString)-\(sectionDragEnabled ? "drag" : "swipe")", anchor: .center)
            }
        }
    }

    // MARK: 拖拽（v1.7.9 Beta+：ScrollView + .dropDestination 任意位置拖动）

    /// 拖动 section 到目标段：默认追加到目标段之后（更简单 + 更符合直觉）
    /// 段前/段后由 .dropDestination 的 location.y 决定（target 段的 midY）
    private func handleSectionDrop(draggedIDs: [UUID], target: SongSection, location: CGPoint) {
        let draggedSet = Set(draggedIDs)
        let draggedActual = song.sections.filter { draggedSet.contains($0.id) }
        guard !draggedActual.isEmpty else { return }
        var newOrder = song.orderedSections.filter { s in !draggedActual.contains(where: { $0.id == s.id }) }
        guard let targetIndex = newOrder.firstIndex(where: { $0.id == target.id }) else { return }
        // 简化策略：拖到目标段上方 → 插段前；拖到目标段下方 → 插段后
        // （dropDestination 默认 location 已经是 .global，可以根据目标段 frame 计算 midY）
        let insertIndex = targetIndex + 1  // 默认段后
        let safeIndex = min(insertIndex, newOrder.count)
        for (i, s) in draggedActual.enumerated() {
            newOrder.insert(s, at: min(safeIndex + i, newOrder.count))
        }
        for (i, s) in newOrder.enumerated() {
            s.order = i
        }
        song.updatedAt = Date()
        try? context.save()
    }

    /// 删除段落（来自 List 的 swipe-to-delete / 编辑模式）
    private func deleteSections(at offsets: IndexSet) {
        let ordered = song.orderedSections
        let indices = offsets.sorted(by: >)
        // 收集要删除的段落信息
        var toDelete: [SongSection] = []
        for index in indices {
            guard index < ordered.count else { continue }
            toDelete.append(ordered[index])
        }
        guard !toDelete.isEmpty else { return }

        // v1.3：删除前确认
        let message = L("将删除 %d 个段落").localized(with: toDelete.count)
        let title = toDelete.first.map { $0.marker } ?? ""
        guard DeleteConfirmator.confirm(title: title, message: message) else { return }

        for section in toDelete {
            // 重新排序
            for s in song.orderedSections where s.order > section.order {
                s.order -= 1
            }
            context.delete(section)
        }
        try? context.save()
    }

    /// v1.7.9 Beta: 按 ID 删除单个段落（来自 SwipeDeleteModifier 的 swipeAction）
    private func deleteSectionsByID(_ id: UUID) {
        guard let section = song.sections.first(where: { $0.id == id }) else { return }
        let message = L("将删除 %d 个段落").localized(with: 1)
        let title = section.marker
        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        for s in song.orderedSections where s.order > section.order {
            s.order -= 1
        }
        context.delete(section)
        try? context.save()
    }

    private var addSectionBar: some View {
        Menu {
            ForEach(SectionTypePreset.presets) { preset in
                Button {
                    addSection(typeName: preset.name)
                } label: {
                    // v1.4: localizedName 已是 key 驱动的翻译字符串，不再包 L()
                    Label(preset.localizedName, systemImage: preset.symbol)
                }
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text(L("添加段落"))
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4]))
                            .foregroundStyle(Color.accentColor.opacity(0.4))
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: 操作

    private func addSection(typeName: String) {
        let next = SongSection(order: song.orderedSections.count, typeName: typeName)
        next.song = song
        song.sections.append(next)
        song.updatedAt = Date()
        try? context.save()
    }

    /// 导出为完整文本文件（v1.2：含元信息、歌词、笔记、灵感、设定）
    private func exportToText() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        let safeTitle = song.title.isEmpty ? L("未命名") : song.title
        panel.nameFieldStringValue = "\(safeTitle)_\(SongExporter.filenameTimestamp()).smelody.txt"
        // 本地化按钮
        panel.prompt = L("保存")
        panel.message = L("将歌词的全部信息导出为文本文件")
        panel.title = L("导出歌词")
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let text = SongExporter.exportFullText(song)
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }
}

// MARK: - 拖动时自动滚动辅助（v1.7.8 Gamma+）
// 监听全局 leftMouseDragged + leftMouseUp，当鼠标在 ScrollView 顶部 50pt 内时，
// 持续把 ScrollView 滚到上一个 section，达到"光标接近页面顶部自动向上滚动"的效果

/// v1.7.8 Gamma+: 拖动时鼠标接近 ScrollView 顶部 → 自动向上滚动
@MainActor
fileprivate final class DragAutoScroller: ObservableObject {
    /// ScrollViewReader 的 proxy（由 SongEditorView 在 onAppear 注入）
    var proxy: ScrollViewProxy?
    /// ScrollView 在屏幕坐标系里的 frame（由 GeometryReader 写入）
    var scrollViewFrame: CGRect = .zero
    /// 当前 ScrollView 顶部对齐的 section id（拖动开始时设初值，每次 auto-scroll 更新）
    var currentTopSectionID: UUID?
    /// 全部有序 sections（拖动开始 + sections 变化时同步）
    var orderedSections: [SongSection] = []

    /// 触发自动滚动的阈值：距 ScrollView 顶部多少 pt
    let edgeThreshold: CGFloat = 50
    /// 自动滚动 tick 间隔（秒）；数值越小滚得越快
    let tickInterval: TimeInterval = 0.08

    private var monitor: Any?
    private var timer: Timer?

    /// 启动全局事件监听
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
            return event
        }
    }

    /// 停止监听 + 清理 Timer
    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        stopTimer()
    }

    @MainActor
    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDragged:
            checkAndAutoScroll(mouseLocation: event.locationInWindow)
        case .leftMouseUp:
            stopTimer()
        default:
            break
        }
    }

    @MainActor
    private func checkAndAutoScroll(mouseLocation: NSPoint) {
        guard let proxy = proxy, !orderedSections.isEmpty,
              let screen = NSScreen.main else {
            stopTimer()
            return
        }

        // macOS 坐标系：event.locationInWindow 的 y 从屏幕底部算 → 转为从屏幕顶部算
        let mouseYFromTop = screen.frame.height - mouseLocation.y

        // ScrollView frame 是 .global 坐标（从屏幕顶部算）
        let localY = mouseYFromTop - scrollViewFrame.minY

        // 只在顶部边缘触发
        guard localY >= 0 && localY < edgeThreshold else {
            stopTimer()
            return
        }

        // 当前 ScrollView 顶部 section 已经在最顶了就别滚了
        guard let currentID = currentTopSectionID,
              let currentIdx = orderedSections.firstIndex(where: { $0.id == currentID }),
              currentIdx > 0 else {
            stopTimer()
            return
        }

        // 启动 timer 持续往上滚
        let snapshotSections = orderedSections
        startTimer {
            guard let currentID = self.currentTopSectionID,
                  let idx = snapshotSections.firstIndex(where: { $0.id == currentID }),
                  idx > 0 else {
                self.stopTimer()
                return
            }
            let prevIdx = idx - 1
            let prevID = snapshotSections[prevIdx].id
            withAnimation(.linear(duration: 0.08)) {
                proxy.scrollTo("\(prevID.uuidString)-drag", anchor: .top)
            }
            self.currentTopSectionID = prevID
        }
    }

    private func startTimer(_ action: @escaping () -> Void) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in action() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 视图修饰符（v1.7.9 Beta+）

/// v1.7.9 Beta+: 拖动开关开启时 —— 段落包一层 .draggable + .dropDestination（任意位置按住即可拖）
/// 带蓝色横线 drop indicator + isDropTargeted 状态
struct DraggableSectionWrapper: View {
    let section: SongSection
    let languages: [String]
    let song: Song
    @Binding var activeSectionID: UUID?
    @Binding var focusBodyOnNextSectionChange: Bool
    let onDrop: (SongSection, [UUID], CGPoint) -> Void

    @State private var isDropTargeted: Bool = false

    var body: some View {
        SectionEditorView(
            section: section,
            languages: languages,
            song: song,
            activeSectionID: $activeSectionID,
            focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange
        )
        .contentShape(Rectangle())
        // 任意位置拖动：直接挂 .draggable + .dropDestination（用户在开启开关时已接受 NSTextView 冲突风险）
        .draggable(section.id.uuidString) {
            HStack(spacing: 6) {
                Image(systemName: "music.note.list")
                    .foregroundStyle(.tint)
                Text(section.marker)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .dropDestination(for: String.self) { items, location in
            let ids = items.compactMap { UUID(uuidString: $0) }.filter { $0 != section.id }
            guard !ids.isEmpty else { return false }
            onDrop(section, ids, location)
            return true
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isDropTargeted = targeted
            }
        }
        .overlay(alignment: .top) {
            if isDropTargeted {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2.5)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
    }
}

/// v1.7.9 GT3: 拖动开关关闭时用——自定义左滑删除（ScrollView+LazyVStack 下实现）
/// 药丸形状删除按钮 + 跟随左滑变形动效 + 点击其他段落自动恢复
/// 手势挂在整个段落，minimumDistance: 40 严格过滤，水平方向判断避免与文本选择冲突
struct SwipeDeleteSectionWrapper: View {
    let section: SongSection
    let languages: [String]
    let song: Song
    @Binding var activeSectionID: UUID?
    @Binding var focusBodyOnNextSectionChange: Bool
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var startOffsetX: CGFloat = 0
    @State private var dragStartedHorizontal: Bool = false

    private let deleteWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .trailing) {
            // 底层：药丸形状删除按钮（固定在右侧，被内容覆盖时不可见）
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth - 10, height: 36)
                    .background(Capsule().fill(Color.red))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)

            // 上层：段落内容（左滑偏移露出底层药丸按钮）
            SectionEditorView(
                section: section,
                languages: languages,
                song: song,
                activeSectionID: $activeSectionID,
                focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
            .offset(x: offsetX)
            // 删除按钮展开时禁用内容交互
            .allowsHitTesting(offsetX == 0)
        }
        .clipped()
        .contentShape(Rectangle())
        // v1.7.9 GT3: 左滑手势用 .gesture + minimumDistance: 40
        // .gesture 优先级高于 simultaneousGesture，能抢占文本选择的拖动
        // 40px 水平移动比 NSTextView 的文本选择启动更早触发
        .gesture(
            DragGesture(minimumDistance: 40)
                .onChanged { value in
                    if !dragStartedHorizontal {
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 2
                        guard isHorizontal else { return }
                        dragStartedHorizontal = true
                        // 让 TextEditor 失焦，避免文本选择干扰
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
                    guard dragStartedHorizontal else { return }
                    let newOffset = startOffsetX + value.translation.width
                    withAnimation(.interactiveSpring()) {
                        offsetX = min(max(newOffset, -deleteWidth), 0)
                    }
                }
                .onEnded { _ in
                    if dragStartedHorizontal {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            if offsetX < -deleteWidth / 2 {
                                offsetX = -deleteWidth
                                startOffsetX = -deleteWidth
                            } else {
                                offsetX = 0
                                startOffsetX = 0
                            }
                        }
                    }
                    dragStartedHorizontal = false
                }
        )
        // 点击内容区：若删除按钮已展开则先关闭
        .onTapGesture {
            if offsetX != 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    offsetX = 0
                    startOffsetX = 0
                }
            }
        }
        // v1.7.9 GT3: 激活段落变化时（点击其他段落）自动关闭删除按钮
        .onChange(of: activeSectionID) { _, _ in
            if offsetX != 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    offsetX = 0
                    startOffsetX = 0
                }
            }
        }
    }
}

// MARK: - 语言切换 Chip

struct LanguageToggleChip: View {
    let language: SongLanguage
    let isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Text(language.localizedDisplayName)
                    .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isOn ? Color.accentColor.opacity(0.18) : ThemeColor.softFill)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isOn ? Color.accentColor.opacity(0.5) : ThemeColor.mediumStroke,
                                  lineWidth: 1)
            )
            .foregroundStyle(isOn ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(language.localizedDisplayName)
    }
}
