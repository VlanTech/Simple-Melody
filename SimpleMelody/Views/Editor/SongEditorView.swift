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

    /// 各段落笔记/译文侧栏。Command 点击时整首歌共用这一份状态。
    @State private var sectionPanels: [UUID: SectionSidePanel] = [:]
    @State private var imagineRequest: ImagineRequest?
    @State private var imagineBusy = false
    @State private var imagineMessage: String?
    @State private var imagineTask: Task<Void, Never>?
    @StateObject private var imagineCancel = ImagineCancelMonitor()
    @AppStorage("export.includeLyrics") private var exportLyrics = true
    @AppStorage("export.includeTranslation") private var exportTranslation = true
    @AppStorage("export.includeRuby") private var exportRuby = true
    @AppStorage("export.includeNotes") private var exportNotes = true
    @AppStorage("export.includeIdeas") private var exportIdeas = true
    @State private var showExportDialog = false

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
        .sheet(item: $imagineRequest) { request in
            ImagineDialog(wholeSong: request.sectionID == nil) { action, language, prompt, keepFormat in
                let sectionID = request.sectionID
                imagineRequest = nil
                performImagine(
                    action: action,
                    targetLanguage: language,
                    prompt: prompt,
                    sectionID: sectionID,
                    keepCurrentFormat: keepFormat
                )
            } onCancel: {
                imagineRequest = nil
            }
        }
        .sheet(isPresented: $showExportDialog) {
            ExportDialog(
                includeLyrics: $exportLyrics,
                includeTranslation: $exportTranslation,
                includeRuby: $exportRuby,
                includeNotes: $exportNotes,
                includeIdeas: $exportIdeas
            ) { options in
                showExportDialog = false
                DispatchQueue.main.async {
                    exportToText(options: options)
                }
            } onCopyAll: {
                showExportDialog = false
                copyFullBodyToPasteboard()
            } onCancel: {
                showExportDialog = false
            }
        }
        .overlay {
            if imagineBusy {
                VStack(spacing: 8) {
                    ProgressView(L("正在请模型处理"))
                    Text(L("按 Command-Esc 取消"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .background {
                    Button(action: cancelImagine) {}
                        .keyboardShortcut(.escape, modifiers: .command)
                        .labelsHidden()
                        .frame(width: 0, height: 0)
                }
            }
        }
        .onChange(of: imagineBusy) { _, busy in
            if busy {
                imagineCancel.start { cancelImagine() }
            } else {
                imagineCancel.stop()
            }
        }
        .onDisappear {
            imagineCancel.stop()
        }
        .alert(L("Imagine"), isPresented: Binding(
            get: { imagineMessage != nil },
            set: { if !$0 { imagineMessage = nil } }
        )) {
            Button(L("确定"), role: .cancel) { imagineMessage = nil }
        } message: {
            Text(imagineMessage ?? "")
        }
    }

    // MARK: 头部元信息

    private var songHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField(L("歌曲标题"), text: $song.title, axis: .horizontal)
                        .appFont(24, weight: .bold, design: .rounded)
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
                // 页操作区：导出/复制，并预留以后再加页面按钮的宽度
                HStack(spacing: 8) {
                    Button {
                        imagineRequest = ImagineRequest(sectionID: nil)
                    } label: {
                        Image(systemName: "sparkles")
                            .appFont(14, weight: .semibold)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                    .help(L("Imagine"))
                    .accessibilityLabel(L("Imagine"))
                    Button {
                        showExportDialog = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .appFont(14, weight: .semibold)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                    .help(L("导出"))
                    .accessibilityLabel(L("导出"))
                }
                .frame(minWidth: 64, minHeight: 32, alignment: .trailing)
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
                            .appFont(11, weight: .medium)
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

    // 段落列表用滚动视图而不是列表：列表的表格视图会挡住折叠和笔记动画。

    private var sectionsScroll: some View {
        ScrollViewReader { proxy in
            scrollableSectionsView(proxy: proxy)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: song.sections.map(\.id))
    }

    /// 左键拖动重排，右键拖动滑出 Imagine 和删除。两件事同时在，不再看设置开关。
    @ViewBuilder
    private func scrollableSectionsView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(song.orderedSections) { section in
                    SwipeDeleteSectionWrapper(
                        section: section,
                        languages: song.languages,
                        song: song,
                        sidePanel: panelBinding(for: section.id),
                        onHeaderControl: { applyHeaderControl($0, sectionID: section.id) },
                        activeSectionID: $activeSectionID,
                        focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange,
                        onDelete: { deleteSectionsByID(section.id) },
                        onImagine: { imagineRequest = ImagineRequest(sectionID: section.id) },
                        onDrop: { target, ids, location, height in
                            handleSectionDrop(
                                draggedIDs: ids,
                                target: target,
                                location: location,
                                targetHeight: height
                            )
                        }
                    )
                    .id(section.id)
                    .transition(.opacity)
                }
                addSectionBar
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(NSColor.textBackgroundColor))
        .background(
            ScrollFrameReporter { frame, anchor in
                autoScroller.scrollViewFrame = frame
                autoScroller.scrollAnchorView = anchor
            }
        )
        .onAppear {
            autoScroller.proxy = proxy
            autoScroller.orderedSections = song.orderedSections
            autoScroller.currentTopSectionID = activeSectionID ?? song.orderedSections.last?.id
            autoScroller.start()
            installSectionDropHandler()
        }
        .onDisappear {
            autoScroller.stop()
            ReorderDragCenter.shared.onSectionDrop = nil
        }
        .onChange(of: song.sections.map(\.id)) { _, _ in
            autoScroller.orderedSections = song.orderedSections
        }
        .onChange(of: activeSectionID) { _, newID in
            if let id = newID {
                autoScroller.currentTopSectionID = id
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    // MARK: 拖拽（v1.7.9 Beta+：ScrollView + .dropDestination 任意位置拖动）

    private func panelBinding(for id: UUID) -> Binding<SectionSidePanel> {
        Binding(
            get: { sectionPanels[id] ?? .none },
            set: { sectionPanels[id] = $0 }
        )
    }

    /// Command 按住时对整首歌应用同一开/合；否则只改当前段。
    private func applyHeaderControl(_ control: SectionHeaderControl, sectionID: UUID) {
        let ordered = song.orderedSections
        guard let index = ordered.firstIndex(where: { $0.id == sectionID }) else { return }
        let commandHeld = NSEvent.modifierFlags.contains(.command)
        let before = ordered.map {
            SectionPanelState(panel: sectionPanels[$0.id] ?? .none, collapsed: $0.isCollapsed)
        }
        let after = SectionBatchAction.apply(
            states: before,
            clickedIndex: index,
            control: control,
            commandHeld: commandHeld
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            for (offset, section) in ordered.enumerated() {
                sectionPanels[section.id] = after[offset].panel
                if section.isCollapsed != after[offset].collapsed {
                    section.isCollapsed = after[offset].collapsed
                }
            }
        }
    }

    /// 歌词栏拖动松手时走同一份插入。SwiftUI 若已经放下，这里不会再写一遍。
    private func installSectionDropHandler() {
        ReorderDragCenter.shared.onSectionDrop = { draggedID, targetID, dropY, height in
            guard let target = song.orderedSections.first(where: { $0.id == targetID }) else { return }
            handleSectionDrop(
                draggedIDs: [draggedID],
                target: target,
                location: CGPoint(x: 0, y: dropY),
                targetHeight: height
            )
        }
    }

    /// 拖到目标段上半 → 插到该段之前；下半 → 插到该段之后。空拖 / 拖到自身为 no-op。
    private func handleSectionDrop(
        draggedIDs: [UUID],
        target: SongSection,
        location: CGPoint,
        targetHeight: CGFloat
    ) {
        guard ReorderDragCenter.shared.claimDrop(draggedIDs: draggedIDs) else { return }
        let ordered = song.orderedSections
        guard let newIDs = SectionDragMath.reorderedIDs(
            orderedIDs: ordered.map(\.id),
            draggedIDs: draggedIDs,
            targetID: target.id,
            dropY: location.y,
            targetMidY: targetHeight / 2
        ) else { return }
        let byID = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })
        for (i, id) in newIDs.enumerated() {
            byID[id]?.order = i
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
                    .appFont(14, weight: .medium)
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

    private func copyFullBodyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(song.fullBody, forType: .string)
    }

    /// 导出为文本文件。默认含全部信息；对话框按勾选写回，仍可再导入。
    private func exportToText(options: SongExportOptions = .all) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        let safeTitle = song.title.isEmpty ? L("未命名") : song.title
        panel.nameFieldStringValue = "\(safeTitle)_\(SongExporter.filenameTimestamp()).smelody.txt"
        panel.prompt = L("保存")
        panel.message = options == .all
            ? L("将歌词的全部信息导出为文本文件")
            : L("导出选中内容")
        panel.title = L("导出歌词")
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let text = SongExporter.exportFullText(song, options: options)
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

/// v1.7.8 Gamma+ / v1.7.10 Extra: 拖动时鼠标接近 ScrollView 顶部 → 自动向上滚动。
/// Extra：start()/stop() 会调用；NSEvent monitor 同步处理（不 Task 跳出 tracking loop）；
/// 进入顶部边缘立即滚一格；timer 加到 RunLoop.common + eventTracking。
fileprivate final class DragAutoScroller: ObservableObject {
    var proxy: ScrollViewProxy?
    /// ScrollView 在 window 坐标系里的 frame（由 ScrollFrameReporter 写入，origin 左下）
    var scrollViewFrame: CGRect = .zero
    /// 用于沿 superview 找到外层 NSScrollView
    weak var scrollAnchorView: NSView?
    var currentTopSectionID: UUID?
    var orderedSections: [SongSection] = []

    let edgeThreshold: CGFloat = SectionDragMath.defaultTopEdgeThreshold
    let tickInterval: TimeInterval = 0.08
    let scrollDelta: CGFloat = SectionDragMath.defaultScrollDelta

    private var monitor: Any?
    private var timer: Timer?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            // 必须留在这一层调用：拖放走的是事件跟踪运行循环。
            self?.handleEvent(event)
            return event
        }
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        stopTimer()
    }

    private func handleEvent(_ event: NSEvent) {
        let kind: SectionDragMath.DragEventKind
        switch event.type {
        case .leftMouseDragged: kind = .leftMouseDragged
        case .leftMouseUp: kind = .leftMouseUp
        default: kind = .other
        }
        let inTopEdge = kind == .leftMouseDragged && SectionDragMath.isInTopAutoScrollEdge(
            mouseInWindow: event.locationInWindow,
            scrollViewInWindow: scrollViewFrame,
            threshold: edgeThreshold
        )
        switch SectionDragMath.commandForDragEvent(kind: kind, inTopEdge: inTopEdge) {
        case .scrollNowAndEnsureTimer:
            scrollUpOneTick()
            startTimer { [weak self] in
                self?.scrollUpOneTick()
            }
        case .stopTimer:
            stopTimer()
        case .ignore:
            break
        }
    }

    private func scrollUpOneTick() {
        if let scrollView = enclosingEditorScrollView() {
            let clip = scrollView.contentView
            let documentHeight = scrollView.documentView?.frame.height ?? clip.bounds.height
            let nextY = SectionDragMath.nextScrollOriginY(
                currentY: clip.bounds.origin.y,
                isFlipped: clip.isFlipped,
                delta: scrollDelta,
                documentHeight: documentHeight,
                clipHeight: clip.bounds.height
            )
            var origin = clip.bounds.origin
            origin.y = nextY
            clip.scroll(to: origin)
            scrollView.reflectScrolledClipView(clip)
            return
        }
        guard let proxy = proxy else { return }
        guard let currentID = currentTopSectionID,
              let currentIdx = orderedSections.firstIndex(where: { $0.id == currentID }),
              let prevIdx = SectionDragMath.previousSectionIndex(currentIndex: currentIdx) else {
            return
        }
        let prevID = orderedSections[prevIdx].id
        withAnimation(.linear(duration: 0.08)) {
            proxy.scrollTo(prevID, anchor: .top)
        }
        currentTopSectionID = prevID
    }

    private func enclosingEditorScrollView() -> NSScrollView? {
        var current: NSView? = scrollAnchorView
        while let view = current {
            if let scrollView = view as? NSScrollView, !(scrollView is PassthroughScrollView) {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }

    private func startTimer(_ action: @escaping () -> Void) {
        guard timer == nil else { return }
        timer = SectionDragMath.scheduleAutoScrollTimer(interval: tickInterval, action: action)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

/// 报告视图在窗口坐标里的框架，原点在左下。
fileprivate struct ScrollFrameReporter: NSViewRepresentable {
    var onFrameChange: (CGRect, NSView) -> Void

    func makeNSView(context: Context) -> ScrollFrameView {
        let view = ScrollFrameView()
        view.onFrameChange = onFrameChange
        return view
    }

    func updateNSView(_ nsView: ScrollFrameView, context: Context) {
        nsView.onFrameChange = onFrameChange
        nsView.report()
    }
}

fileprivate final class ScrollFrameView: NSView {
    var onFrameChange: ((CGRect, NSView) -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        report()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        report()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        report()
    }

    func report() {
        onFrameChange?(convert(bounds, to: nil), self)
    }
}

/// 段落拖动和曲目库拖动共用这一份：谁在拖，横条就归谁。
final class ReorderDragCenter: ObservableObject {
    static let shared = ReorderDragCenter()

    struct SectionClaim: Equatable {
        var rowID: UUID
        var insertsBefore: Bool
    }

    @Published private(set) var subject: SectionDragMath.ReorderDragSubject = .none
    @Published private(set) var sectionClaim: SectionClaim?
    private var dropApplied = false
    /// 松手后短时间内仍是这一段，避免 SwiftUI 和这里各写一遍。
    private var finishedSectionID: UUID?
    /// 歌词栏拖动松手、且 SwiftUI 没有先放下时，用这一份写回顺序。
    var onSectionDrop: ((UUID, UUID, CGFloat, CGFloat) -> Void)?

    private final class SectionRow {
        weak var view: NSView?
        init(view: NSView) { self.view = view }
    }

    private var sectionRows: [UUID: SectionRow] = [:]
    private var draggingSectionID: UUID?

    func setSubject(_ next: SectionDragMath.ReorderDragSubject) {
        if next != .section, sectionClaim != nil {
            sectionClaim = nil
        }
        if subject != next {
            subject = next
        }
    }

    /// 同一次歌词栏拖动只写下第一份结果。不是这次拖的段落则照常写下。
    func claimDrop(draggedIDs: [UUID]) -> Bool {
        let tracked = draggingSectionID ?? finishedSectionID
        guard let tracked, draggedIDs.contains(tracked) else { return true }
        if dropApplied { return false }
        dropApplied = true
        return true
    }

    func registerSectionRow(id: UUID, view: NSView) {
        if let row = sectionRows[id] {
            row.view = view
        } else {
            sectionRows[id] = SectionRow(view: view)
        }
    }

    func unregisterSectionRow(id: UUID) {
        sectionRows.removeValue(forKey: id)
        if sectionClaim?.rowID == id {
            sectionClaim = nil
        }
    }

    func beginSectionDrag(id: UUID) {
        dropApplied = false
        finishedSectionID = nil
        draggingSectionID = id
        setSubject(.section)
    }

    func isDraggingSection(_ id: UUID) -> Bool {
        draggingSectionID == id
    }

    func updateSectionClaim(screenPoint: NSPoint) {
        guard draggingSectionID != nil else { return }
        guard SectionDragMath.reorderLineSides(for: .section).sectionList else {
            if sectionClaim != nil { sectionClaim = nil }
            return
        }
        guard let hit = sectionHit(at: screenPoint) else {
            if sectionClaim != nil { sectionClaim = nil }
            return
        }
        let before = SectionDragMath.insertsBefore(dropY: hit.localY, targetMidY: hit.height / 2)
        let next = SectionClaim(rowID: hit.id, insertsBefore: before)
        if sectionClaim != next {
            sectionClaim = next
        }
    }

    func finishSectionDrag(screenPoint: NSPoint) {
        let dragged = draggingSectionID
        let applied = dropApplied
        let hit = sectionHit(at: screenPoint)
        draggingSectionID = nil
        finishedSectionID = dragged
        if sectionClaim != nil { sectionClaim = nil }
        if subject == .section {
            setSubject(.none)
        }
        if !applied, let dragged, let hit {
            onSectionDrop?(dragged, hit.id, hit.localY, hit.height)
        }
        let token = dragged
        DispatchQueue.main.async { [weak self] in
            guard let self, self.finishedSectionID == token, self.draggingSectionID == nil else { return }
            self.finishedSectionID = nil
            self.dropApplied = false
        }
    }

    private struct SectionHit {
        var id: UUID
        var localY: CGFloat
        var height: CGFloat
    }

    /// 只认横坐标落在段落列表里的行。缝隙归更近的那一段，仍用这一段的上下半。
    private func sectionHit(at screenPoint: NSPoint) -> SectionHit? {
        let slack: CGFloat = 12
        var best: (hit: SectionHit, distance: CGFloat, top: CGFloat)?
        for (id, row) in sectionRows {
            guard let view = row.view, let window = view.window else { continue }
            let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
            guard rect.width > 1, rect.height > 1 else { continue }
            guard screenPoint.x >= rect.minX, screenPoint.x <= rect.maxX else { continue }
            let localY = rect.maxY - screenPoint.y
            let distance: CGFloat
            if localY < 0 {
                distance = -localY
            } else if localY > rect.height {
                distance = localY - rect.height
            } else {
                distance = 0
            }
            guard distance <= slack else { continue }
            if let current = best {
                let closer = distance < current.distance - 0.5
                let tieUpper = abs(distance - current.distance) <= 0.5 && rect.maxY > current.top
                if !closer && !tieUpper { continue }
            }
            best = (
                SectionHit(id: id, localY: localY, height: rect.height),
                distance,
                rect.maxY
            )
        }
        return best?.hit
    }
}

/// 段落拖放只走专用类型，不附带纯文本编号。纯文本编号会被歌词栏当成正文。
struct SectionIDPayload: Codable, Transferable, Hashable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: SectionDragMath.sectionIDTypeIdentifier))
    }
}

/// 歌词栏发起的拖动只写段落类型。不附带纯文本编号，避免被当成歌词。
final class SectionIDPasteboardWriter: NSObject, NSPasteboardWriting {
    let id: UUID

    init(id: UUID) {
        self.id = id
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [NSPasteboard.PasteboardType(SectionDragMath.sectionIDTypeIdentifier)]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        guard type.rawValue == SectionDragMath.sectionIDTypeIdentifier else { return nil }
        return try? JSONEncoder().encode(SectionIDPayload(id: id))
    }
}

/// 跟光标走的歌词栏缩影。只显示这段歌词正文，不是曲目行那种图标加标题。
private struct SectionLyricsDragPreview: View {
    let lyrics: String

    var body: some View {
        Text(lyrics)
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .lineLimit(8)
            .multilineTextAlignment(.leading)
            .frame(width: 220, alignment: .topLeading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 72, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .allowsHitTesting(false)
    }
}

// MARK: - 视图修饰符（v1.7.9 Beta+）

/// v1.7.9 Beta+: 拖动开关开启时 —— 段落包一层 .draggable + .dropDestination（任意位置按住即可拖）
/// 带蓝色横线 drop indicator + isDropTargeted 状态
struct DraggableSectionWrapper: View {
    let section: SongSection
    let languages: [String]
    let song: Song
    @Binding var sidePanel: SectionSidePanel
    let onHeaderControl: (SectionHeaderControl) -> Void
    @Binding var activeSectionID: UUID?
    @Binding var focusBodyOnNextSectionChange: Bool
    let onDrop: (SongSection, [UUID], CGPoint, CGFloat) -> Void

    @State private var isDropTargeted: Bool = false
    @State private var sectionHeight: CGFloat = 1
    @State private var insertBefore: Bool = true
    @ObservedObject private var reorderDrag = ReorderDragCenter.shared

    private var sectionLineBefore: Bool {
        if reorderDrag.sectionClaim?.rowID == section.id {
            return reorderDrag.sectionClaim?.insertsBefore ?? true
        }
        return insertBefore
    }

    /// 只有当前拖的是段落、并且落点就在这一段上时才画。拖歌曲时不画。
    private var showsSectionLine: Bool {
        let sessionHit = reorderDrag.sectionClaim?.rowID == section.id
        guard sessionHit || isDropTargeted else { return false }
        let subject: SectionDragMath.ReorderDragSubject = reorderDrag.subject == .song ? .song : .section
        return SectionDragMath.reorderLineSides(for: subject).sectionList
    }

    var body: some View {
        SectionEditorView(
            section: section,
            languages: languages,
            activeSectionID: $activeSectionID,
            focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange,
            sidePanel: $sidePanel,
            onHeaderControl: onHeaderControl
        )
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { sectionHeight = max(geo.size.height, 1) }
                    .onChange(of: geo.size.height) { _, height in
                        sectionHeight = max(height, 1)
                    }
            }
        )
        .background {
            SectionReorderRowTracker(rowID: section.id)
                .allowsHitTesting(false)
        }
        .draggable(SectionIDPayload(id: section.id)) {
            SectionLyricsDragPreview(lyrics: section.body)
        }
        .dropDestination(for: SectionIDPayload.self) { items, location in
            let ids = items.map(\.id).filter { $0 != section.id }
            guard !ids.isEmpty else { return false }
            insertBefore = SectionDragMath.insertsBefore(dropY: location.y, targetMidY: sectionHeight / 2)
            onDrop(section, ids, location, sectionHeight)
            return true
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isDropTargeted = targeted
            }
        }
        .overlay(alignment: sectionLineBefore ? .top : .bottom) {
            if showsSectionLine {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2.5)
                    .padding(.horizontal, 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}

/// 拖动时登记这一段在屏幕上的位置。落点横条和松手都用它，不靠猜。
private struct SectionReorderRowTracker: NSViewRepresentable {
    var rowID: UUID

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.sync(view, rowID: rowID)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.sync(nsView, rowID: rowID)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.lineCenter?.unregisterSectionRow(id: coordinator.rowID)
    }

    final class Coordinator {
        var rowID = UUID()
        var lineCenter: ReorderDragCenter?

        func sync(_ view: NSView, rowID: UUID) {
            self.rowID = rowID
            let center = ReorderDragCenter.shared
            lineCenter = center
            center.registerSectionRow(id: rowID, view: view)
        }
    }
}

private struct ImagineRequest: Identifiable {
    let id = UUID()
    var sectionID: UUID?
}

extension SongEditorView {
    fileprivate func imagineDocument() -> ImagineDocument {
        ImagineDocument(
            title: song.title,
            artist: song.artist,
            languages: song.languages.joined(separator: ","),
            bpm: song.bpm,
            musicalKey: song.musicalKey,
            beat: song.beat,
            ideas: song.orderedIdeas.map(\.content).joined(separator: "\n"),
            ideaItems: song.orderedIdeas.map {
                ImagineIdea(id: $0.id.uuidString, ideaType: $0.ideaType, content: $0.content)
            },
            sections: song.orderedSections.map { section in
                ImagineSection(
                    id: section.id.uuidString,
                    marker: section.marker,
                    body: section.body,
                    translation: section.translation,
                    notes: section.notes,
                    annotations: section.orderedAnnotations.map {
                        ImagineRuby(
                            rangeStart: $0.rangeStart,
                            rangeLength: $0.rangeLength,
                            original: $0.original,
                            phonetic: $0.phonetic
                        )
                    }
                )
            }
        )
    }

    fileprivate func writeImagine(_ document: ImagineDocument, replaceAnnotations: Bool = false) {
        let languages = document.languages
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !languages.isEmpty {
            song.languages = languages
        }
        let title = document.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            song.title = title
        }
        song.bpm = document.bpm
        song.musicalKey = document.musicalKey
        song.beat = document.beat
        var kept: [SongSection] = []
        var seen = Set<UUID>()
        for snap in document.sections {
            if let uuid = UUID(uuidString: snap.id),
               let existing = song.sections.first(where: { $0.id == uuid }) {
                existing.body = snap.body
                existing.translation = snap.translation
                existing.notes = snap.notes
                if replaceAnnotations {
                    replaceSectionAnnotations(existing, with: snap.annotations)
                }
                kept.append(existing)
                seen.insert(existing.id)
            } else {
                let typeName = ImagineWorkflow.sectionTypeName(fromMarker: snap.marker)
                let tag = snap.marker.trimmingCharacters(in: .whitespacesAndNewlines)
                let created = SongSection(
                    order: kept.count,
                    typeName: typeName,
                    body: snap.body,
                    customTag: tag,
                    notes: snap.notes,
                    translation: snap.translation
                )
                applyImagineMarker(created, marker: snap.marker)
                created.song = song
                song.sections.append(created)
                if replaceAnnotations {
                    replaceSectionAnnotations(created, with: snap.annotations)
                }
                kept.append(created)
                seen.insert(created.id)
            }
        }
        for leftover in song.sections where !seen.contains(leftover.id) {
            context.delete(leftover)
        }
        for (index, section) in kept.enumerated() {
            section.order = index
        }
        if !document.ideaItems.isEmpty {
            var keptIdeas: [SongIdea] = []
            var seenIdeas = Set<UUID>()
            for (index, snap) in document.ideaItems.enumerated() {
                let type = IdeaTypePreset.find(named: snap.ideaType)?.name ?? "Inspiration"
                if let uuid = UUID(uuidString: snap.id),
                   let existing = song.ideas.first(where: { $0.id == uuid }) {
                    existing.content = snap.content
                    existing.ideaType = type
                    existing.order = index
                    keptIdeas.append(existing)
                    seenIdeas.insert(existing.id)
                } else {
                    let created = SongIdea(order: index, content: snap.content, ideaType: type)
                    created.song = song
                    song.ideas.append(created)
                    keptIdeas.append(created)
                    seenIdeas.insert(created.id)
                }
            }
            for leftover in song.ideas where !seenIdeas.contains(leftover.id) {
                context.delete(leftover)
            }
        }
        song.updatedAt = Date()
        try? context.save()
    }

    fileprivate func applyImagineMarker(_ section: SongSection, marker: String) {
        let trimmed = marker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let typeName = ImagineWorkflow.sectionTypeName(fromMarker: trimmed)
        section.typeName = typeName
        section.customTag = trimmed
        section.marker = trimmed
        if typeName == "Custom" {
            let inner = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            if section.customName.isEmpty, !inner.isEmpty {
                section.customName = inner
            }
        }
        if let preset = SectionTypePreset.find(named: typeName) {
            section.colorHex = preset.colorHex
        }
    }

    fileprivate func replaceSectionAnnotations(_ section: SongSection, with items: [ImagineRuby]) {
        for anno in section.annotations {
            context.delete(anno)
        }
        for item in items {
            let anno = PronunciationAnnotation(
                rangeStart: item.rangeStart,
                rangeLength: item.rangeLength,
                original: item.original,
                phonetic: item.phonetic,
                language: "ja",
                isAutoGenerated: true
            )
            anno.section = section
            section.annotations.append(anno)
        }
    }

    fileprivate func performImagine(
        action: ImagineAction,
        targetLanguage: String,
        prompt: String,
        sectionID: UUID?,
        keepCurrentFormat: Bool
    ) {
        let saved = LLMAPIKeyStore().current()
        let document = imagineDocument()
        let scope: ImagineScope = sectionID.map { .section($0.uuidString) } ?? .song
        guard let composed = ImagineWorkflow.compose(
            action: action,
            scope: scope,
            document: document,
            targetLanguage: targetLanguage,
            userPrompt: prompt,
            keepCurrentFormat: keepCurrentFormat
        ) else {
            if action == .translate {
                imagineMessage = L("没有歌词的段落不会翻译，笔记也不会被当成歌词")
            } else if action == .furigana {
                imagineMessage = L("没有歌词的段落不会注音")
            } else {
                imagineMessage = L("回复格式无法识别，没有改动歌词")
            }
            return
        }
        guard let request = ImagineAPI.chatRequest(connection: saved, system: composed.system, user: composed.user) else {
            imagineMessage = L("请先填写供应商网址和 API Key")
            return
        }
        imagineTask?.cancel()
        imagineBusy = true
        imagineTask = Task {
            let result = await ImagineAPI.send(request)
            await MainActor.run {
                imagineBusy = false
                imagineTask = nil
                if Task.isCancelled { return }
                switch result {
                case .success(let text):
                    let outcome = ImagineWorkflow.applyResult(
                        reply: text,
                        action: action,
                        scope: scope,
                        document: document,
                        keepCurrentFormat: keepCurrentFormat
                    )
                    if outcome.overreach {
                        imagineTask?.cancel()
                        imagineMessage = L("段落Imagine不能改整首歌或其他段落")
                    } else if outcome.document == document {
                        imagineMessage = L("回复格式无法识别，没有改动歌词")
                    } else {
                        writeImagine(outcome.document, replaceAnnotations: action != .translate)
                    }
                case .failure(.cancelled):
                    break
                case .failure:
                    imagineMessage = L("连接失败")
                }
            }
        }
    }

    fileprivate func cancelImagine() {
        imagineTask?.cancel()
        imagineBusy = false
        imagineTask = nil
    }
}

private struct ImagineDialog: View {
    let wholeSong: Bool
    let onRun: (ImagineAction, String, String, Bool) -> Void
    let onCancel: () -> Void

    @State private var action: ImagineAction = .translate
    @State private var targetLanguage = ImagineDialog.initialLanguage()
    @State private var prompt = ""
    @State private var keepCurrentFormat = true
    @State private var showCreateWarning = false

    private var languageChoices: [String] {
        var names = SongLanguage.all.map(\.name)
        if !targetLanguage.isEmpty, !names.contains(targetLanguage) {
            names.insert(targetLanguage, at: 0)
        }
        return names
    }

    private static func initialLanguage() -> String {
        let last = ImagineLanguageMemory.last()
        if !last.isEmpty { return last }
        return SongLanguage.all.first?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(wholeSong ? L("Imagine") : L("段落Imagine"))
                .font(.title3.weight(.semibold))
            if action == .create && wholeSong {
                Text(L("也可填写歌曲语言、速度、调式和节拍"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !wholeSong {
                Text(L("只修改这一段"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker(L("Imagine"), selection: $action) {
                Text(L("翻译")).tag(ImagineAction.translate)
                Text(L("创意")).tag(ImagineAction.create)
                Text(L("注音")).tag(ImagineAction.furigana)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if action == .create && wholeSong {
                Toggle(L("依照当前格式"), isOn: $keepCurrentFormat)
            }

            if action == .translate {
                Picker(L("目标语言"), selection: $targetLanguage) {
                    ForEach(languageChoices, id: \.self) { name in
                        Text(L(name)).tag(name)
                    }
                }
                .pickerStyle(.menu)
            }

            Text(L("提示词可留空"))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(L("提示词可留空"), text: $prompt, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(L("取消"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L("开始")) {
                    if action == .create || action == .furigana {
                        showCreateWarning = true
                    } else {
                        startImagine()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(action == .translate && targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: AppFontMetrics.dialogWidth)
        .alert(changeWarningTitle, isPresented: $showCreateWarning) {
            Button(L("取消"), role: .cancel) {}
            Button(L("继续")) { startImagine() }
        } message: {
            Text(changeWarningMessage)
        }
    }

    private var changeWarningTitle: String {
        action == .furigana ? L("注音可能无法撤销或改错") : L("创意可能无法撤销或改错")
    }

    private var changeWarningMessage: String {
        action == .furigana
            ? L("注音会改动读音，可能无法撤销或出现错误。确定要继续吗？")
            : L("创意会改动歌词，可能无法撤销或出现错误。确定要继续吗？")
    }

    private func startImagine() {
        if action == .translate {
            ImagineLanguageMemory.remember(targetLanguage)
        }
        onRun(action, targetLanguage, prompt, keepCurrentFormat)
    }
}

private struct ExportDialog: View {
    enum Kind: String, CaseIterable, Identifiable, Hashable {
        case allFile
        case selectedFile
        case copyAll
        var id: String { rawValue }
    }

    @Binding var includeLyrics: Bool
    @Binding var includeTranslation: Bool
    @Binding var includeRuby: Bool
    @Binding var includeNotes: Bool
    @Binding var includeIdeas: Bool
    let onExportFile: (SongExportOptions) -> Void
    let onCopyAll: () -> Void
    let onCancel: () -> Void

    @State private var kind: Kind = .allFile

    private var selectedOptions: SongExportOptions {
        SongExportOptions(
            lyrics: includeLyrics,
            translation: includeTranslation,
            ruby: includeRuby,
            notes: includeNotes,
            ideas: includeIdeas
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("导出"))
                .font(.title3.weight(.semibold))

            Picker(L("导出"), selection: $kind) {
                Text(L("导出为文本文件（含全部信息）")).tag(Kind.allFile)
                Text(L("按内容导出")).tag(Kind.selectedFile)
                Text(L("复制全文到剪贴板")).tag(Kind.copyAll)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if kind == .selectedFile {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("歌词正文"), isOn: $includeLyrics)
                    Toggle(L("翻译"), isOn: $includeTranslation)
                    Toggle(L("注音"), isOn: $includeRuby)
                    Toggle(L("段落笔记"), isOn: $includeNotes)
                    Toggle(L("灵感与设定"), isOn: $includeIdeas)
                    if !selectedOptions.includesAnything {
                        Text(L("至少勾选一项再导出"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button(L("取消"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(kind == .copyAll ? L("复制") : L("导出")) {
                    switch kind {
                    case .allFile:
                        onExportFile(.all)
                    case .selectedFile:
                        onExportFile(selectedOptions)
                    case .copyAll:
                        onCopyAll()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(kind == .selectedFile && !selectedOptions.includesAnything)
            }
        }
        .padding(20)
        .frame(width: AppFontMetrics.dialogWidth)
    }
}

final class ImagineCancelMonitor: ObservableObject {
    private var token: Any?

    func start(_ onCancel: @escaping () -> Void) {
        stop()
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // 键码 53 是 Esc。
            if flags.contains(.command), event.keyCode == 53 {
                onCancel()
                return nil
            }
            return event
        }
    }

    func stop() {
        if let token {
            NSEvent.removeMonitor(token)
            self.token = nil
        }
    }
}

/// 右键按住再拖，把段落滑开，露出左边的 Imagine 和右边的删除。
/// 左键拖动不走这里，交给里面的重排。只点右键、不拖，仍是段落菜单。
struct SwipeDeleteSectionWrapper: View {
    let section: SongSection
    let languages: [String]
    let song: Song
    @Binding var sidePanel: SectionSidePanel
    let onHeaderControl: (SectionHeaderControl) -> Void
    @Binding var activeSectionID: UUID?
    @Binding var focusBodyOnNextSectionChange: Bool
    let onDelete: () -> Void
    let onImagine: () -> Void
    let onDrop: (SongSection, [UUID], CGPoint, CGFloat) -> Void

    @State private var offsetX: CGFloat = 0
    @State private var startOffsetX: CGFloat = 0

    private let actionWidth: CGFloat = 80

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Button {
                    closeSwipe()
                    onImagine()
                } label: {
                    Image(systemName: "sparkles")
                        .appFont(16)
                        .foregroundStyle(.white)
                        .frame(width: actionWidth - 10, height: 36)
                        .background(Capsule().fill(Color.blue))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 5)
                .accessibilityLabel(L("段落Imagine"))
                Spacer(minLength: 0)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .appFont(16)
                        .foregroundStyle(.white)
                        .frame(width: actionWidth - 10, height: 36)
                        .background(Capsule().fill(Color.red))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5)
            }

            // 上层：段落内容。左键拖动重排；右键拖动才把这一层推开。
            DraggableSectionWrapper(
                section: section,
                languages: languages,
                song: song,
                sidePanel: $sidePanel,
                onHeaderControl: onHeaderControl,
                activeSectionID: $activeSectionID,
                focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange,
                onDrop: onDrop
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
            .offset(x: offsetX)
            // 按钮展开时禁用内容交互，才能点到 Imagine 和删除
            .allowsHitTesting(offsetX == 0)
        }
        .clipped()
        .contentShape(Rectangle())
        .background {
            SectionRightDragCatcher(
                onTranslation: { dx in
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    let newOffset = startOffsetX + dx
                    withAnimation(.interactiveSpring()) {
                        offsetX = min(max(newOffset, -actionWidth), actionWidth)
                    }
                },
                onFinish: { intent in
                    guard intent == .revealImagine || intent == .revealDelete else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        if offsetX > actionWidth / 2 {
                            offsetX = actionWidth
                            startOffsetX = actionWidth
                        } else if offsetX < -actionWidth / 2 {
                            offsetX = -actionWidth
                            startOffsetX = -actionWidth
                        } else {
                            offsetX = 0
                            startOffsetX = 0
                        }
                    }
                }
            )
            .allowsHitTesting(false)
        }
        // 点击内容区：若按钮已展开则先关闭
        .onTapGesture {
            if offsetX != 0 {
                closeSwipe()
            }
        }
        // v1.7.9 GT3: 激活段落变化时（点击其他段落）自动关闭删除按钮
        .onChange(of: activeSectionID) { _, _ in
            if offsetX != 0 {
                closeSwipe()
            }
        }
    }

    private func closeSwipe() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            offsetX = 0
            startOffsetX = 0
        }
    }
}

/// 右键拖动，或触控板双指拖动（按下或不按下）时滑开段落。不挡左键，竖直滑动仍滚动页面。
private struct SectionRightDragCatcher: NSViewRepresentable {
    var onTranslation: (CGFloat) -> Void
    var onFinish: (SectionDragMath.SectionGestureIntent) -> Void

    func makeNSView(context: Context) -> SectionRightDragCatcherView {
        let view = SectionRightDragCatcherView()
        view.onTranslation = onTranslation
        view.onFinish = onFinish
        return view
    }

    func updateNSView(_ nsView: SectionRightDragCatcherView, context: Context) {
        nsView.onTranslation = onTranslation
        nsView.onFinish = onFinish
    }

    static func dismantleNSView(_ nsView: SectionRightDragCatcherView, coordinator: ()) {
        nsView.teardown()
    }
}

private final class SectionRightDragCatcherView: NSView {
    var onTranslation: ((CGFloat) -> Void)?
    var onFinish: ((SectionDragMath.SectionGestureIntent) -> Void)?
    /// 重放右键给段落菜单时，其他段落不要再把这次点击吃掉。
    private static var passingReplay = false

    private var monitor: Any?
    private var tracking = false
    private var revealed = false
    private var origin = NSPoint.zero
    private var downEvent: NSEvent?
    /// 不按下的双指滑动。只有认领的那一段吃掉水平滑动。
    private var scrollTracking = false
    private var scrollHeld = false
    private var scrollX: CGFloat = 0
    private var scrollY: CGFloat = 0
    private static var scrollOwner: ObjectIdentifier?
    /// 水平滑动松手后，系统还会送惯性滚动。认领过的那段要继续吃掉，避免页面跟着跳。
    private static var momentumSwallow: ObjectIdentifier?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        install()
    }

    override func removeFromSuperview() {
        teardown()
        super.removeFromSuperview()
    }

    func teardown() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        tracking = false
        if Self.scrollOwner == ObjectIdentifier(self) {
            Self.scrollOwner = nil
        }
        if Self.momentumSwallow == ObjectIdentifier(self) {
            Self.momentumSwallow = nil
        }
        scrollTracking = false
        scrollHeld = false
    }

    private func install() {
        teardown()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.rightMouseDown, .rightMouseDragged, .rightMouseUp, .scrollWheel]
        ) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if Self.passingReplay { return event }
        guard let window, event.window === window, !isHiddenOrHasHiddenAncestor else { return event }
        if event.type == .scrollWheel {
            return handleScroll(event)
        }
        let button = SectionDragMath.sectionPointerButton(rightButton: true)
        switch event.type {
        case .rightMouseDown:
            let local = convert(event.locationInWindow, from: nil)
            guard bounds.width > 1, bounds.height > 1, bounds.contains(local) else { return event }
            tracking = true
            revealed = false
            origin = event.locationInWindow
            downEvent = event
            return nil
        case .rightMouseDragged:
            guard tracking else { return event }
            let dx = event.locationInWindow.x - origin.x
            let dy = event.locationInWindow.y - origin.y
            let intent = SectionDragMath.sectionGestureIntent(
                button: button,
                translationX: dx,
                translationY: dy,
                ended: false,
                alreadyRevealing: revealed
            )
            if intent == .revealImagine || intent == .revealDelete {
                revealed = true
                onTranslation?(dx)
            }
            return nil
        case .rightMouseUp:
            guard tracking else { return event }
            tracking = false
            let dx = event.locationInWindow.x - origin.x
            let dy = event.locationInWindow.y - origin.y
            let intent = SectionDragMath.sectionGestureIntent(
                button: button,
                translationX: dx,
                translationY: dy,
                ended: true,
                alreadyRevealing: revealed
            )
            let down = downEvent
            downEvent = nil
            revealed = false
            if intent == .contextMenu, let down {
                replayContextClick(down)
            } else {
                onFinish?(intent)
            }
            return nil
        default:
            return event
        }
    }

    /// 不按下的双指滑动。水平的滑出按钮；竖直的留给页面滚动。
    private func handleScroll(_ event: NSEvent) -> NSEvent? {
        if tracking { return event }
        let id = ObjectIdentifier(self)
        let momentum = event.phase == [] && event.momentumPhase != []
        if momentum {
            guard Self.momentumSwallow == id else { return event }
            if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                Self.momentumSwallow = nil
            }
            return nil
        }
        guard event.hasPreciseScrollingDeltas, event.phase != [] else { return event }
        let ending = event.phase.contains(.ended) || event.phase.contains(.cancelled)
        if event.phase.contains(.began) {
            Self.momentumSwallow = nil
            let local = convert(event.locationInWindow, from: nil)
            let inside = bounds.width > 1 && bounds.height > 1 && bounds.contains(local)
            if inside {
                if let owner = Self.scrollOwner, owner != id { return event }
                Self.scrollOwner = id
                scrollTracking = true
                scrollHeld = false
                revealed = false
                scrollX = 0
                scrollY = 0
            }
            if !ending {
                return event
            }
            guard scrollTracking, Self.scrollOwner == id else { return event }
        }
        if ending {
            guard scrollTracking, Self.scrollOwner == id else { return event }
            let held = scrollHeld
            let result = applyScroll(event, ended: true)
            scrollTracking = false
            scrollHeld = false
            revealed = false
            Self.scrollOwner = nil
            if result == nil || held {
                Self.momentumSwallow = id
                return nil
            }
            return event
        }
        guard scrollTracking, Self.scrollOwner == id else { return event }
        return applyScroll(event, ended: false)
    }

    private func applyScroll(_ event: NSEvent, ended: Bool) -> NSEvent? {
        let delta = SectionDragMath.trackpadFingerDelta(
            scrollingDeltaX: event.scrollingDeltaX,
            scrollingDeltaY: event.scrollingDeltaY,
            naturalScrolling: event.isDirectionInvertedFromDevice
        )
        scrollX += delta.x
        scrollY += delta.y
        let claim = SectionDragMath.trackpadSectionScroll(
            fingerX: scrollX,
            fingerY: scrollY,
            ended: ended,
            alreadyRevealing: revealed
        )
        switch claim {
        case .pass:
            return event
        case .hold:
            scrollHeld = true
            return nil
        case .reveal(let intent):
            scrollHeld = true
            revealed = true
            onTranslation?(scrollX)
            if ended {
                onFinish?(intent)
            }
            return nil
        }
    }

    /// 没拖成滑动时，把按下再交给系统，段落菜单照旧弹出。
    private func replayContextClick(_ down: NSEvent) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        Self.passingReplay = true
        down.window?.sendEvent(down)
        Self.passingReplay = false
        install()
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
                    .appFont(12, weight: isOn ? .semibold : .regular)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .appFont(12)
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
