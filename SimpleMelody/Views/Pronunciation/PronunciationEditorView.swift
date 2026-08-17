// Views/Pronunciation/PronunciationEditorView.swift
// 读音编辑器
// v1.4: 改回带文字按钮版本（修穿模错位）+ 注音 chip 列表限制高度防错位

import SwiftUI
import SwiftData
import AppKit

struct PronunciationEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var section: SongSection
    let language: String
    /// 直接拿 song，让 hasJapanese 跟随 song.languages 实时变化
    let song: Song
    /// v1.7.2: 当前激活段落 id（与父 SectionEditorView 共享）
    /// 内部判断"我是否刚刚被设为激活" → 聚焦 TextEditor（仅指定段聚焦）
    @Binding var activeSectionID: UUID?
    /// v1.7.9 Delta+: 是否允许本次 activeSectionID 变化触发 TextEditor 聚焦
    /// true = 用户主动点段落 / 歌词预览双击 → 聚焦；false = 切歌 → 不聚焦
    /// 触发一次后会自动清零（设为 false）
    @Binding var focusBodyOnNextSectionChange: Bool

    @State private var showAddPopover: Bool = false
    @State private var showClearMenu: Bool = false

    // 添加读音表单
    @State private var newStart: Int = 0
    @State private var newLength: Int = 1
    @State private var newOriginal: String = ""
    @State private var newPhonetic: String = ""

    // 编辑读音表单
    @State private var editingAnnotation: PronunciationAnnotation?
    @State private var editPhonetic: String = ""

    /// v1.7.1: 歌词正文 TextEditor 焦点状态
    @FocusState private var bodyFocused: Bool

    /// v1.7.9 GT3: PassthroughScrollTextEditor 的 isFocused @Binding 用
    @State private var bodyIsFocused: Bool = false

    /// v1.7.9 Test: 歌词 TextEditor 实际高度回传给父 view，让笔记栏底部对齐
    @Binding var lyricsEditorHeight: CGFloat

    /// 只要 song.languages 包含日语就启用自动注音；与其他语言多选互不干扰
    private var hasJapanese: Bool {
        song.languages.contains { $0.hasPrefix("ja") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbar
            textEditorSection
            annotationChipsSection
        }
        .popover(isPresented: $showAddPopover) {
            addAnnotationPopover
        }
        .sheet(item: $editingAnnotation) { anno in
            editAnnotationSheet(anno)
        }
        // v1.7.9 BugStable: 把 TextEditor 实际高度回传给父 view，让笔记栏底部对齐歌词 TextEditor 底部
        .onPreferenceChange(LyricsEditorHeightKey.self) { h in
            if abs(h - lyricsEditorHeight) > 0.5 {
                lyricsEditorHeight = h
            }
        }
    }

    // MARK: 工具栏（v1.4：带文字按钮，修复穿模错位）

    private var toolbar: some View {
        HStack(spacing: 8) {
            // 左侧：标题（带图标）
            HStack(spacing: 5) {
                Image(systemName: "text.alignleft")
                    .imageScale(.small)
                    .foregroundStyle(.primary)
                Text(L("正文"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .fixedSize()

            Spacer(minLength: 8)

            // 右侧：操作按钮组（带文字版，修复穿模）
            HStack(spacing: 6) {
                // 自动注音按钮（带文字）
                Button {
                    autoFurigana()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "character.book.closed")
                            .imageScale(.small)
                        Text(L("自动注音"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(minHeight: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(hasJapanese ? Color.accentColor.opacity(0.15) : ThemeColor.subtleFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(hasJapanese ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(hasJapanese ? Color.accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help(hasJapanese ? L("对日语汉字自动生成假名注音") : L("请先在歌曲语言中加入日语"))
                .disabled(!hasJapanese)

                // 添加读音按钮（带文字）
                Button {
                    prepareAddNew()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.small)
                        Text(L("添加读音"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(minHeight: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(L("为指定位置的文字添加读音"))

                // 清除菜单（带文字）
                Menu {
                    Button(role: .destructive) {
                        clearAutoAnnotations()
                    } label: {
                        Label(L("清除所有自动注音"), systemImage: "trash.fill")
                    }
                    .tint(.red)  // v1.7.9 Beta+: 显式红色（macOS role: .destructive 不一定自动上色）
                    .disabled(!section.annotations.contains(where: { $0.isAutoGenerated }))

                    Button(role: .destructive) {
                        clearManualAnnotations()
                    } label: {
                        Label(L("清除所有手动注音"), systemImage: "trash.fill")
                    }
                    .tint(.red)
                    .disabled(!section.annotations.contains(where: { !$0.isAutoGenerated }))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.small)
                        Text(L("更多"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
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
                .menuStyle(.borderlessButton)
                .help(L("清除注音选项"))
                .fixedSize()
            }
            .fixedSize()
        }
        .frame(minHeight: 32)
    }

    // MARK: 文本编辑器（v1.4：移除缩进内边距修错位）

    private var textEditorSection: some View {
        // v1.7.9 GT3: 改回 PassthroughScrollTextEditor（NSViewRepresentable NSTextView）
        // 解决：点击空白区域聚焦 + 文字顶格 + 回车换行正常 + 高度随内容自适应
        PassthroughScrollTextEditor(
            text: $section.body,
            isFocused: $bodyIsFocused,
            fontSize: 16,
            minHeight: 120
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ThemeColor.subtleStroke, lineWidth: 1)
                )
        )
            // v1.7.9 Test: 把 TextEditor 实际高度通过 PreferenceKey 传给父 view，让笔记栏底部对齐
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: LyricsEditorHeightKey.self, value: proxy.size.height)
                }
            )
            // v1.7.1: 双击预览跳转时激活计数器 +1 → 触发 TextEditor 获得焦点
            .focused($bodyFocused)
            // v1.7.2 + v1.7.9 Delta+: 只有"我刚刚被设为激活"的那一段才聚焦；只有用户主动行为（点击段落/歌词预览双击）才聚焦
            // 切歌属于系统行为，不会触发 focusBodyOnNextSectionChange=true → 不聚焦光标
            .onChange(of: activeSectionID) { oldValue, newValue in
                if oldValue != section.id && newValue == section.id && focusBodyOnNextSectionChange {
                    bodyFocused = true
                    focusBodyOnNextSectionChange = false  // 用完即清零（防止下次系统切歌误聚焦）
                }
            }
    }

    // MARK: 注音 chip 列表（v1.4：固定行数 + 不嵌套 ScrollView，修复穿模）

    @ViewBuilder
    private var annotationChipsSection: some View {
        if !section.annotations.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "highlighter")
                        .imageScale(.small)
                        .foregroundStyle(.primary)
                    Text(L("注音列表"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(section.annotations.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .fixedSize()

                // v1.4: 改成普通 wrap（不用 FlowLayout，避免和 ScrollView 嵌套导致错位）
                chipListContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
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

    /// chip 列表：用 FlowLayout wrap + 固定最大高度（超过则显示 ScrollView）
    private var chipListContent: some View {
        let annotations = section.orderedAnnotations
        return Group {
            if annotations.count <= 6 {
                // 少量注音：直接 wrap，不需要滚动
                FlowLayout(spacing: 5) {
                    ForEach(annotations) { anno in
                        AnnotationChip(
                            annotation: anno,
                            onTap: { editAnnotation(anno) },
                            onDelete: { deleteAnnotation(anno) }
                        )
                    }
                }
            } else {
                // 大量注音：加 ScrollView 限高
                ScrollView(.vertical, showsIndicators: true) {
                    FlowLayout(spacing: 5) {
                        ForEach(annotations) { anno in
                            AnnotationChip(
                                annotation: anno,
                                onTap: { editAnnotation(anno) },
                                onDelete: { deleteAnnotation(anno) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 96)  // 限制高度，超出滚动
            }
        }
    }

    // MARK: 添加读音弹窗

    private var addAnnotationPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("添加读音"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L("在正文中的位置"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Stepper(value: $newStart, in: 0...max(0, section.body.count - 1)) {
                        Text(L("起始: %d").localized(with: newStart))
                            .font(.callout.monospacedDigit())
                    }
                    .labelsHidden()
                    Text(L("起始: %d").localized(with: newStart))
                        .font(.callout.monospacedDigit())
                        .frame(width: 90, alignment: .leading)
                    Stepper(value: $newLength, in: 1...max(1, section.body.count - newStart)) {
                        Text(L("长度: %d").localized(with: newLength))
                            .font(.callout.monospacedDigit())
                    }
                    .labelsHidden()
                    Text(L("长度: %d").localized(with: newLength))
                        .font(.callout.monospacedDigit())
                        .frame(width: 90, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("原文预览"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(newOriginal.isEmpty ? "—" : newOriginal)
                    .font(.callout)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ThemeColor.softFill)
                    )
                    .onChange(of: newStart) { _, _ in updateOriginal() }
                    .onChange(of: newLength) { _, _ in updateOriginal() }
                    .onChange(of: section.body) { _, _ in updateOriginal() }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(phoneticLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                TextField(phoneticPlaceholder, text: $newPhonetic)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(L("取消")) { showAddPopover = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L("保存")) {
                    saveNewAnnotation()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPhonetic.isEmpty || newOriginal.isEmpty || newLength <= 0)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var phoneticLabel: String {
        switch language {
        case "ja": return L("假名读音")
        case "zh", "zh-Hans", "zh-Hant": return L("拼音")
        default: return L("Phonetic")
        }
    }

    private var phoneticPlaceholder: String {
        switch language {
        case "ja": return "せかい"
        case "zh", "zh-Hans", "zh-Hant": return "rú shì jiè"
        default: return "phonetic"
        }
    }

    // MARK: 编辑读音 Sheet

    private func editAnnotationSheet(_ anno: PronunciationAnnotation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("编辑读音"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L("原文"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(anno.original)
                    .font(.callout)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ThemeColor.softFill)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(phoneticLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                TextField(phoneticPlaceholder, text: $editPhonetic)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(L("取消")) { editingAnnotation = nil }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(role: .destructive) {
                    deleteAnnotation(anno)
                    editingAnnotation = nil
                } label: {
                    Label(L("删除"), systemImage: "trash.fill")
                }
                .tint(.red)
                Button(L("保存")) {
                    anno.phonetic = editPhonetic
                    anno.isAutoGenerated = false
                    try? context.save()
                    editingAnnotation = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editPhonetic.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { editPhonetic = anno.phonetic }
    }

    // MARK: 操作

    private func prepareAddNew() {
        newStart = 0
        newLength = min(1, max(0, section.body.count))
        newPhonetic = ""
        updateOriginal()
        showAddPopover = true
    }

    private func updateOriginal() {
        let nsBody = section.body as NSString
        let safeStart = max(0, min(newStart, max(0, nsBody.length - 1)))
        let safeLength = max(0, min(newLength, max(0, nsBody.length - safeStart)))
        if safeLength == 0 {
            newOriginal = ""
        } else {
            newOriginal = nsBody.substring(with: NSRange(location: safeStart, length: safeLength))
        }
    }

    private func saveNewAnnotation() {
        guard !newPhonetic.isEmpty, !newOriginal.isEmpty else { return }
        // 检查该位置是否已有注音
        if let existing = section.annotations.first(where: { $0.rangeStart == newStart && $0.rangeLength == newLength }) {
            existing.phonetic = newPhonetic
            existing.isAutoGenerated = false
        } else {
            let anno = PronunciationAnnotation(
                rangeStart: newStart,
                rangeLength: newLength,
                original: newOriginal,
                phonetic: newPhonetic,
                language: languageCodeForPhonetic,
                isAutoGenerated: false
            )
            anno.section = section
            section.annotations.append(anno)
        }
        try? context.save()
        showAddPopover = false
    }

    private var languageCodeForPhonetic: String {
        switch language {
        case "ja": return "ja"
        case "zh", "zh-Hans": return "zh-pinyin"
        case "zh-Hant": return "zh-bopomofo"
        default: return "ipa"
        }
    }

    private func editAnnotation(_ anno: PronunciationAnnotation) {
        editingAnnotation = anno
        editPhonetic = anno.phonetic
    }

    private func deleteAnnotation(_ anno: PronunciationAnnotation) {
        let title = anno.original
        let message = L("将删除注音") + "「\(anno.phonetic) → \(anno.original)」"
        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        context.delete(anno)
        try? context.save()
    }

    private func autoFurigana() {
        guard hasJapanese else { return }
        // 如果已有自动注音，先确认（避免误删）
        let existingAuto = section.annotations.filter { $0.isAutoGenerated }
        if !existingAuto.isEmpty {
            let message = L("将覆盖 %d 条现有的自动注音").localized(with: existingAuto.count)
            guard DeleteConfirmator.confirm(title: L("重新生成自动注音"), message: message) else { return }
        }
        let engine = JapaneseFuriganaEngine.shared
        let matches = engine.annotate(section.body)
        // 清除旧的自动注音
        for anno in existingAuto {
            context.delete(anno)
        }
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

    private func clearAutoAnnotations() {
        let count = section.annotations.filter { $0.isAutoGenerated }.count
        guard count > 0 else { return }
        let message = L("将清除 %d 条自动注音").localized(with: count)
        guard DeleteConfirmator.confirm(title: L("清除所有自动注音"), message: message) else { return }
        for anno in section.annotations where anno.isAutoGenerated {
            context.delete(anno)
        }
        try? context.save()
    }

    private func clearManualAnnotations() {
        let count = section.annotations.filter { !$0.isAutoGenerated }.count
        guard count > 0 else { return }
        let message = L("将清除 %d 条手动注音").localized(with: count)
        guard DeleteConfirmator.confirm(title: L("清除所有手动注音"), message: message) else { return }
        for anno in section.annotations where !anno.isAutoGenerated {
            context.delete(anno)
        }
        try? context.save()
    }
}

// MARK: - 注音 Chip（v1.4：固定最小尺寸，避免错位）

private struct AnnotationChip: View {
    let annotation: PronunciationAnnotation
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(annotation.original)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(annotation.phonetic)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(annotation.isAutoGenerated ? Color.accentColor : .orange)
                if annotation.isAutoGenerated {
                    Text("A")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .fixedSize()
            .background(
                Capsule()
                    .fill(annotation.isAutoGenerated
                          ? Color.accentColor.opacity(0.10)
                          : Color.orange.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .strokeBorder(annotation.isAutoGenerated
                                  ? Color.accentColor.opacity(0.3)
                                  : Color.orange.opacity(0.3),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(L("编辑"), systemImage: "pencil", action: onTap)
            Button(role: .destructive, action: onDelete) {
                Label(L("删除"), systemImage: "trash.fill")
            }
            .tint(.red)
        }
    }
}
// MARK: - v1.7.9 Beta+: 滚轮穿透 TextEditor（光标在歌词编辑栏时滚轮穿透到外层 ScrollView）

/// v1.7.9 Beta+: 自定义 NSScrollView，子类化重写 scrollWheel 不消费滚轮事件，让外层 ScrollView 处理
final class PassthroughScrollView: NSScrollView {
    /// v1.7.9 Delta+: 编辑器最小高度（外部注入，替代硬编码 120）
    var minEditorHeight: CGFloat = 120

    override func scrollWheel(with event: NSEvent) {
        // v1.7.9 Beta+ 修复: 沿视图树向上找外层 NSScrollView，转发滚轮让外层真的滚动
        forwardScrollWheelToOuterScrollView(event: event, from: self)
    }

    // v1.7.9 Delta+: 跟随 documentView 的 intrinsicContentSize，让 SwiftUI 撑开高度
    override var intrinsicContentSize: NSSize {
        guard let docView = documentView else {
            return NSSize(width: NSView.noIntrinsicMetric, height: minEditorHeight)
        }
        return NSSize(width: NSView.noIntrinsicMetric, height: max(docView.intrinsicContentSize.height, minEditorHeight))
    }
}

/// v1.7.9 Beta+: 自定义 NSTextView，重写 scrollWheel 把滚轮事件转发到外层 NSScrollView
final class PassthroughTextView: NSTextView {
    /// v1.7.9 Delta+: 编辑器最小高度（外部注入，替代硬编码 120）
    var minEditorHeight: CGFloat = 120

    override func scrollWheel(with event: NSEvent) {
        // v1.7.9 Beta+ 修复: 不调 super（NSTextView 默认不消费滚轮，但 enclosingScrollView 会消费）
        // 沿视图树向上找外层 NSScrollView，转发滚轮让外层真的滚动
        forwardScrollWheelToOuterScrollView(event: event, from: self)
    }

    // v1.7.9 Delta+: 高度自适应——按内容撑开（最小值由外部 minEditorHeight 决定）
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: minEditorHeight)
        }
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        let total = usedHeight + textContainerInset.height * 2 + 8  // 8 = 上下 padding 4
        return NSSize(width: NSView.noIntrinsicMetric, height: max(total, minEditorHeight))
    }

    override func didChangeText() {
        super.didChangeText()
        // 文本变化触发 intrinsicContentSize 重算 → SwiftUI 重布局 → 高度自动撑开
        invalidateIntrinsicContentSize()
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }
}

/// v1.7.9 Beta+: 沿视图树向上找第一个不是当前 ScrollView 的 NSScrollView，转发滚轮事件
private func forwardScrollWheelToOuterScrollView(event: NSEvent, from view: NSView) {
    // 从 view 的 enclosingScrollView 之上开始找（跳过自己这层 NSScrollView）
    let startView: NSView? = (view is NSScrollView) ? view.superview : (view.enclosingScrollView?.superview ?? view.superview)
    var current: NSView? = startView
    while let v = current {
        if let sv = v as? NSScrollView {
            // 找到外层 NSScrollView → 让它自己处理滚轮
            sv.scrollWheel(with: event)
            return
        }
        current = v.superview
    }
    // 找不到外层 NSScrollView → 不做任何事
}

/// v1.7.9 Beta+: NSViewRepresentable 包装 NSTextView，禁用内部垂直滚动，让滚轮穿透
struct PassthroughScrollTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var fontSize: CGFloat = 16
    var minHeight: CGFloat = 120

    func makeNSView(context: Context) -> NSScrollView {
        // 用自定义 PassthroughScrollView（禁用垂直滚动）
        let scrollView = PassthroughScrollView()
        scrollView.minEditorHeight = minHeight  // v1.7.9 Delta+: 注入最小高度
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // 用自定义 PassthroughTextView
        let textView = PassthroughTextView(frame: .zero)
        textView.minEditorHeight = minHeight  // v1.7.9 Delta+: 注入最小高度
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text
        context.coordinator.textViewRef = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        // v1.7.9 Beta+: 焦点控制（@Binding 变化时 SwiftUI 调用 updateNSView）
        if isFocused, textView.window?.firstResponder != textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textViewRef: NSTextView?

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

// MARK: - v1.7.9 BugStable: 歌词 TextEditor 实际高度 PreferenceKey
/// 父 view 通过 onPreferenceChange 拿到 lyrics TextEditor 渲染高度，动态计算笔记栏 minHeight 使其底部对齐
struct LyricsEditorHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 120
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
