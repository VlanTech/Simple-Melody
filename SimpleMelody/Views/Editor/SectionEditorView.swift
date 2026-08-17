// Views/Editor/SectionEditorView.swift
// 段落编辑器
// v1.4: 去掉重复的"自动注音"按钮（统一在 PronunciationEditorView 里）
// v1.4: 段落笔记放在注音列表旁边（横向并排）

import SwiftUI
import SwiftData
import AppKit

struct SectionEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var section: SongSection
    /// 歌曲支持的语言列表（用于注音等语言相关逻辑）
    let languages: [String]
    /// 直接传入 song，让子组件实时跟随 languages 变化
    let song: Song
    /// v1.7.2: 当前激活段落 id（与右栏预览 / List 滚动共享）
    /// 内部判断"我是否刚刚被设为激活" → 触发闪烁（仅指定段闪）
    @Binding var activeSectionID: UUID?
    /// v1.7.9 Delta+: 是否允许下一次 activeSectionID 变化触发 TextEditor 聚焦
    /// 用户主动点段落时设为 true，触发一次后清零；切歌时为 false
    @Binding var focusBodyOnNextSectionChange: Bool

    /// v1.7.9 BugStable: 歌词 TextEditor 实际高度（来自 PronunciationEditorView PreferenceKey）
    /// 用它动态计算笔记 TextEditor minHeight，使笔记栏底部对齐歌词 TextEditor 底部
    @State private var lyricsEditorHeight: CGFloat = 120

    /// v1.7.9 BugStable: matchedGeometryEffect 用 namespace 做伸缩过渡
    @Namespace private var animNamespace

    @State private var showNotes: Bool = false
    @State private var showTypePicker: Bool = false
    /// v1.7.1: 闪烁状态（跳转后临时高亮，800ms 后自动消失）
    @State private var isFlashing: Bool = false

    /// 是否包含日语（用于自动注音功能）
    var hasJapanese: Bool {
        languages.contains { $0.hasPrefix("ja") }
    }

    /// 主要语言（用于 UI 展示）
    var primaryLanguage: String {
        languages.first ?? "ja"
    }

    var preset: SectionTypePreset? { section.preset }

    var body: some View {
        // v1.7.9 Test: 恢复 v1.7.8 Delta 二进制反汇编确认的 body 设计
        //   - body level if-else 两侧挂 transition（`_ConditionalContent<sectionBody, Color.clear>`）
        //   - button action 内部用 withAnimation { state.toggle() } 触发动画（demangle `_yXEfU_` 后缀证明）
        //   - 不加 view-level .animation(_:value:)，靠 SwiftUI 14+ 隐式 transition + withAnimation 组合
        // v1.7.8 Delta 二进制反汇编：
        //   - body = `TupleView<(sectionHeader, (sectionBody)?)>`  = VStack<...> 内 if-else 切整个 sectionBody
        //   - sectionBody 内部 HStack 第二个 view 是 `(transition)?` = notesPanel if-else + Optional transition
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader
            if !section.isCollapsed {
                sectionBody
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: section.isCollapsed)
            } else {
                Color.clear
                    .frame(height: 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: section.isCollapsed)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)  // v1.7.3 Gamma: 删除系统色填充，保持透明
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isFlashing
                        ? ThemeColor.flashStroke
                        : (preset?.color ?? .secondary).opacity(0.35),
                    lineWidth: isFlashing ? 1.5 : 1
                )
        )
        .padding(5)  // 与外层系统色粗边框间隔 5pt（避免两层 border 接触）
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(
                    isFlashing
                        ? ThemeColor.flashStroke
                        : Color(NSColor.separatorColor).opacity(0.6),
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        // v1.7.9 Test: 段落拖动改用父 ScrollView + LazyVStack + .draggable（v1.7.8 Delta 风格）
        // 之前 v1.7.9 Beta+ 的 List + .onMove + 段落拖动开关删除——开关 + List 模式 + PassthroughScrollTextEditor 三方冲突
        .onTapGesture {
            // v1.7: 点段落任意位置激活
            if activeSectionID != section.id {
                // v1.7.9 Delta+: 用户主动点段落 → 允许下一次 activeSectionID 变化触发 TextEditor 聚焦
                focusBodyOnNextSectionChange = true
                activeSectionID = section.id
            }
        }
        // v1.7.2: 只有"我刚刚被设为激活"的那一段才闪烁（不再所有段落一起闪）
        .onChange(of: activeSectionID) { oldValue, newValue in
            let wasMine = (oldValue == section.id)
            let isNowMine = (newValue == section.id)
            if !wasMine && isNowMine {
                triggerFlash()
            }
        }
        .contextMenu {
            // v1.7.8 Delta: 上移至顶部 + 上移
            Button(L("上移至顶部"), systemImage: "arrow.up.to.line") { moveToTop() }
            Button(L("上移"), systemImage: "arrow.up") { moveUp() }
            // v1.7.8 Delta: 下移 + 下移至底部
            Button(L("下移"), systemImage: "arrow.down") { moveDown() }
            Button(L("下移至底部"), systemImage: "arrow.down.to.line") { moveToBottom() }
            Divider()
            Button(L("复制段落"), systemImage: "doc.on.doc") { duplicate() }
            Divider()
            // v1.7.9 Beta: 删除按钮改成红色更显眼（Label + tint + destructive role）
            Button(role: .destructive) {
                delete()
            } label: {
                Label(L("删除"), systemImage: "trash.fill")
            }
            .tint(.red)
        }
    }

    /// 触发闪烁动画（v1.7.3: 500ms 后自动消失）
    private func triggerFlash() {
        withAnimation(.easeOut(duration: 0.1)) {
            isFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.25)) {
                isFlashing = false
            }
        }
    }

    // MARK: 段落头（v1.4：去掉重复"自动注音"按钮）

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            // 类型图标 + 颜色圆点（固定 28×28）
            ZStack {
                Circle()
                    .fill((preset?.color ?? .primary).opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: preset?.symbol ?? "text.alignleft")
                    .foregroundStyle(preset?.color ?? .primary)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(width: 28, height: 28)

            // 段落类型按钮（点击选择类型）
            Button {
                showTypePicker.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(section.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(preset?.color ?? .primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(.primary)
                }
                .frame(minWidth: 60, alignment: .leading)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTypePicker) {
                SectionTypePicker(
                    currentType: section.typeName,
                    currentCustom: section.customName,
                    onPick: { name in
                        section.typeName = name
                        let p = SectionTypePreset.find(named: name)
                        if let p {
                            section.colorHex = p.colorHex
                            // v1.5: 切换段落类型时强制更新 marker（不再保留旧 customTag）
                            section.marker = p.defaultTag
                            section.customTag = ""  // 清掉旧 customTag
                        }
                        try? context.save()
                        showTypePicker = false
                    },
                    onCustom: { custom in
                        section.typeName = "Custom"
                        section.customName = custom
                        section.marker = "[\(custom)]"
                        section.customTag = ""
                        try? context.save()
                        showTypePicker = false
                    }
                )
                .frame(width: 320, height: 360)
            }

            // Tag 显示（v1.5：自动跟随段落类型变化，不可手动编辑）
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(section.marker)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeColor.mediumFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(ThemeColor.subtleStroke, lineWidth: 0.5)
            )
            .frame(width: 110)
            .help(L("Tag 跟随段落类型自动变化，可在选中后点击段落类型手动调整"))

            Spacer(minLength: 4)

            // 右侧操作按钮组（v1.4：去掉重复的"自动注音"按钮，统一在 PronunciationEditorView 里）
            HStack(spacing: 2) {
                // 拖动手柄（视觉提示）
                Image(systemName: "line.3.horizontal")
                    .imageScale(.small)
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .frame(width: 22, height: 28)
                    .help(L("长按段落任意位置可拖动重排"))

                // 段落笔记开关（带文字 + 图标）
                Button {
                    // v1.7.9 Test: 用 withAnimation 触发展开/收起动画（v1.7.8 Delta 风格）
                    // v1.7.8 Delta 二进制反汇编：sectionHeader 闭包末尾 `_yXEfU_` 后缀 = withAnimation 调用
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNotes.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showNotes ? "note.text" : "note.text")
                            .imageScale(.small)
                        Text(L("笔记"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(minHeight: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showNotes ? Color.accentColor.opacity(0.15) : ThemeColor.subtleFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(showNotes ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(showNotes ? Color.accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help(L("段落笔记"))
                .fixedSize()

                // 折叠
                Button {
                    // v1.7.9 Test: 用 withAnimation 触发展开/收起动画（v1.7.8 Delta 风格）
                    withAnimation(.easeInOut(duration: 0.2)) {
                        section.isCollapsed.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: section.isCollapsed ? "chevron.down" : "chevron.up")
                            .imageScale(.small)
                        Text(section.isCollapsed ? L("展开") : L("折叠"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(minHeight: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ThemeColor.softFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(ThemeColor.mediumStroke, lineWidth: 1)
                    )
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help(section.isCollapsed ? L("展开") : L("折叠"))
                .fixedSize()
            }
            .fixedSize()
        }
    }

    // MARK: 段落正文（v1.4：注音 + 笔记横向并排）

    private var sectionBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 注音 + 笔记横向并排（笔记可隐藏）
            HStack(alignment: .top, spacing: 10) {
                PronunciationEditorView(
                    section: section,
                    language: primaryLanguage,
                    song: song,
                    activeSectionID: $activeSectionID,
                    focusBodyOnNextSectionChange: $focusBodyOnNextSectionChange,
                    lyricsEditorHeight: $lyricsEditorHeight
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                // v1.7.9 GT3: if-else + 两边 transition + view-level .animation(value:)
                // view-level .animation 是 BugStable 动画秘诀，List 模式下也能触发布局动画
                if showNotes {
                    notesPanel
                        .frame(width: 220)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .animation(.easeInOut(duration: 0.2), value: showNotes)
                } else {
                    Color.clear
                        .frame(width: 0)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .animation(.easeInOut(duration: 0.2), value: showNotes)
                }
            }
        }
        .padding(.top, 4)
    }

    /// 段落笔记面板
    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .imageScale(.small)
                    .foregroundStyle(.primary)
                Text(L("段落笔记"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .fixedSize()

            // v1.7.9 GT3: 改回 PassthroughScrollTextEditor（NSViewRepresentable NSTextView）
            // 解决：点击空白区域聚焦 + 文字顶格 + 回车换行正常 + 高度随内容自适应
            // textContainerInset = (8, 6) 让文字从顶部 6pt 开始
            // 动态 minHeight 同步歌词栏底部：notesHeight = max(120, lyricsEditorHeight + 20)
            PassthroughScrollTextEditor(
                text: $section.notes,
                isFocused: .constant(false),
                fontSize: 13,
                minHeight: max(120, lyricsEditorHeight + 20)
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ThemeColor.subtleFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(ThemeColor.subtleStroke, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: 操作

    private func moveUp() {
        guard let song = section.song else { return }
        let ordered = song.orderedSections
        guard let idx = ordered.firstIndex(of: section), idx > 0 else { return }
        ordered[idx].order = idx - 1
        ordered[idx - 1].order = idx
        try? context.save()
    }

    private func moveDown() {
        guard let song = section.song else { return }
        let ordered = song.orderedSections
        guard let idx = ordered.firstIndex(of: section), idx < ordered.count - 1 else { return }
        ordered[idx].order = idx + 1
        ordered[idx + 1].order = idx
        try? context.save()
    }

    // v1.7.8 Delta: 上移至顶部
    private func moveToTop() {
        guard let song = section.song else { return }
        let ordered = song.orderedSections
        guard let idx = ordered.firstIndex(of: section), idx > 0 else { return }
        section.order = -1  // 临时设为最小，触发 SwiftData 排序刷新
        // 重新整理所有 order
        var newOrder = ordered.filter { $0.id != section.id }
        newOrder.insert(section, at: 0)
        for (i, s) in newOrder.enumerated() {
            s.order = i
        }
        try? context.save()
    }

    // v1.7.8 Delta: 下移至底部
    private func moveToBottom() {
        guard let song = section.song else { return }
        let ordered = song.orderedSections
        guard let idx = ordered.firstIndex(of: section), idx < ordered.count - 1 else { return }
        var newOrder = ordered.filter { $0.id != section.id }
        newOrder.append(section)
        for (i, s) in newOrder.enumerated() {
            s.order = i
        }
        try? context.save()
    }

    private func duplicate() {
        guard let song = section.song else { return }
        let copy = SongSection(
            order: section.order + 1,
            typeName: section.typeName,
            body: section.body,
            customName: section.customName,
            customTag: section.customTag,
            notes: section.notes
        )
        copy.song = song
        copy.marker = section.marker
        copy.colorHex = section.colorHex
        // 重新排序后面的段落
        for s in song.orderedSections where s.order > section.order {
            s.order += 1
        }
        song.sections.append(copy)
        try? context.save()
    }

    private func delete() {
        guard let song = section.song else { return }
        // 删除前确认
        let title = section.displayName
        let message = L("将删除段落") + "「\(section.marker)」"
        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        // 重新排序
        for s in song.orderedSections where s.order > section.order {
            s.order -= 1
        }
        context.delete(section)
        try? context.save()
    }

    private func autoGenerateFurigana() {
        // v1.4: 这里保留作为辅助方法（实际由 PronunciationEditorView 调用）
        guard hasJapanese else { return }
        let engine = JapaneseFuriganaEngine.shared
        let matches = engine.annotate(section.body)
        // 清除旧的自动注音（保留手动）
        for anno in section.annotations where anno.isAutoGenerated {
            context.delete(anno)
        }
        // 创建新自动注音
        for match in matches {
            let anno = PronunciationAnnotation(
                rangeStart: match.range.location,
                rangeLength: match.range.length,
                original: match.original,
                phonetic: match.kana,
                language: "ja",
                isAutoGenerated: true
            )
            anno.section = section
            section.annotations.append(anno)
        }
        try? context.save()
    }
}

// MARK: - 段落类型选择器（v1.4：跟随界面语言）

private struct SectionTypePicker: View {
    let currentType: String
    let currentCustom: String
    let onPick: (String) -> Void
    let onCustom: (String) -> Void

    @State private var customInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("段落类型"))
                .font(.headline)
                .padding(.bottom, 4)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], spacing: 6) {
                    ForEach(SectionTypePreset.presets) { preset in
                        Button {
                            onPick(preset.name)
                        } label: {
                            HStack(spacing: 8) {
Image(systemName: preset.symbol)
                                    .foregroundStyle(Color(hex: preset.colorHex) ?? .primary)
                                    // v1.4: 用 preset.localizedName（key 驱动，自动随界面语言切换）
                                    Text(preset.localizedName)
                                        .foregroundStyle(.primary)
                                Spacer()
                                if preset.name == currentType {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(preset.name == currentType
                                          ? (Color(hex: preset.colorHex)?.opacity(0.15) ?? Color.accentColor.opacity(0.15))
                                          : ThemeColor.subtleFill)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 240)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(L("自定义段落名"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack {
                    TextField(L("如 Spoken Word"), text: $customInput)
                        .textFieldStyle(.roundedBorder)
                    Button(L("应用")) {
                        guard !customInput.isEmpty else { return }
                        onCustom(customInput)
                    }
                    .disabled(customInput.isEmpty)
                }
            }
        }
        .padding(16)
    }
}