// 读音编辑器
// v1.4: 改回带文字按钮版本（修穿模错位）+ 注音 chip 列表限制高度防错位

import SwiftUI
import SwiftData
import AppKit
import QuartzCore

struct PronunciationEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var section: SongSection
    let language: String
    /// v1.7.2: 当前激活段落 id（与父 SectionEditorView 共享）
    /// 内部判断"我是否刚刚被设为激活" → 聚焦 TextEditor（仅指定段聚焦）
    @Binding var activeSectionID: UUID?
    /// v1.7.9 Delta+: 是否允许本次 activeSectionID 变化触发 TextEditor 聚焦
    /// true = 用户主动点段落 / 歌词预览双击 → 聚焦；false = 切歌 → 不聚焦
    /// 触发一次后会自动清零（设为 false）
    @Binding var focusBodyOnNextSectionChange: Bool

    @State private var showAddPopover: Bool = false
    @State private var showNeedKanjiAlert: Bool = false
    @State private var showClearMenu: Bool = false
    @State private var bodySelectedRange = NSRange(location: 0, length: 0)
    @State private var lastKanjiSelection = NSRange(location: 0, length: 0)
    @State private var pendingBodySelection: NSRange?

    // 添加读音表单
    @State private var newStart: Int = 0
    @State private var newLength: Int = 1
    @State private var newOriginal: String = ""
    @State private var newPhonetic: String = ""

    // 编辑读音表单
    @State private var editingAnnotation: PronunciationAnnotation?
    @State private var editPhonetic: String = ""
    @FocusState private var phoneticFieldFocused: Bool

    /// v1.7.1: 歌词正文 TextEditor 焦点状态
    @FocusState private var bodyFocused: Bool

    /// v1.7.9 GT3: PassthroughScrollTextEditor 的 isFocused @Binding 用
    @State private var bodyIsFocused: Bool = false
    /// 左键按住拖动始终可以重排这一段，不再看设置开关。

    /// v1.7.9 Test: 歌词 TextEditor 实际高度回传给父 view，让笔记栏底部对齐
    @Binding var lyricsEditorHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbar
            textEditorSection
        }
        .popover(isPresented: $showAddPopover) {
            addAnnotationPopover
        }
        .alert(L("请先选中要注音的汉字"), isPresented: $showNeedKanjiAlert) {
            Button(L("确定"), role: .cancel) {}
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
                    .appFont(12, weight: .medium)
                    .foregroundStyle(.primary)
            }
            .fixedSize()

            Spacer(minLength: 8)

            // 右侧：操作按钮组（带文字版，修复穿模）
            HStack(spacing: 6) {
                // 添加读音按钮（带文字）
                Button {
                    prepareAddNew()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.small)
                        Text(L("添加读音"))
                            .appFont(12, weight: .medium)
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
                .focusable(false)
                .help(L("为指定位置的文字添加读音"))

                // 删除注音按钮（红色，文字图标）
                Button {
                    deleteAllAnnotations()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.badge.minus")
                            .imageScale(.small)
                        Text(L("删除注音"))
                            .appFont(12, weight: .medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(minHeight: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.red.opacity(0.45), lineWidth: 1)
                    )
                    .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(L("删除本段落的全部注音"))
                .disabled(section.annotations.isEmpty)
                .opacity(section.annotations.isEmpty ? 0.4 : 1)
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
            minHeight: 120,
            rubyAnnotations: rubySpans,
            editingRubyRange: editingRubyRange,
            onRubyEdit: { span in
                if let anno = annotationMatching(span) {
                    editAnnotation(anno)
                }
            },
            onRubyDelete: { span in
                if let anno = annotationMatching(span) {
                    deleteAnnotation(anno)
                }
            },
            onSelectedRange: { range in
                bodySelectedRange = range
                if LyricsRubyMath.selectedKanjiRun(in: section.body, selection: range) != nil {
                    lastKanjiSelection = range
                }
            },
            onTextEdits: { edits, textBefore in
                remapAnnotations(edits: edits, textBefore: textBefore)
            },
            requestedSelection: $pendingBodySelection,
            yieldsSectionReorder: true,
            sectionReorderID: section.id
        )
        .popover(item: $editingAnnotation, arrowEdge: .top) { anno in
            editAnnotationSheet(anno)
        }
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

    private var editingRubyRange: NSRange? {
        if let anno = editingAnnotation {
            return NSRange(location: anno.rangeStart, length: anno.rangeLength)
        }
        if showAddPopover, newLength > 0 {
            return NSRange(location: newStart, length: newLength)
        }
        return nil
    }

    private var rubySpans: [LyricsRubySpan] {
        section.orderedAnnotations.map {
            LyricsRubySpan(
                rangeStart: $0.rangeStart,
                rangeLength: $0.rangeLength,
                original: $0.original,
                phonetic: $0.phonetic
            )
        }
    }

    private func annotationMatching(_ span: LyricsRubySpan) -> PronunciationAnnotation? {
        section.annotations.first {
            $0.rangeStart == span.rangeStart && $0.rangeLength == span.rangeLength
        }
    }

    // MARK: 添加读音弹窗

    private var addAnnotationPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("添加读音"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L("原文"))
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
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(phoneticLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                TextField(phoneticPlaceholder, text: $newPhonetic)
                    .textFieldStyle(.roundedBorder)
                    .focused($phoneticFieldFocused)
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
        .frame(width: 320)
        .onAppear {
            // onAppear 属于 SwiftUI 的更新事务，这里同步写 @FocusState 会报
            // "Modifying state during view update"；推迟一拍再聚焦
            DispatchQueue.main.async {
                phoneticFieldFocused = true
            }
        }
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
                    .focused($phoneticFieldFocused)
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
        .onAppear {
            // 同上：弹窗内容是在 SwiftUI 更新事务里挂上去的，onAppear 里同步写
            // @State / @FocusState 会触发 "Modifying state during view update"
            let phonetic = anno.phonetic
            DispatchQueue.main.async {
                editPhonetic = phonetic
                phoneticFieldFocused = true
            }
        }
    }

    // MARK: 操作

    private func prepareAddNew() {
        let seed = LyricsRubyMath.selectedKanjiRun(in: section.body, selection: bodySelectedRange)
            ?? LyricsRubyMath.selectedKanjiRun(in: section.body, selection: lastKanjiSelection)
        guard let run = seed, run.length > 0 else {
            showNeedKanjiAlert = true
            return
        }
        bodySelectedRange = run
        lastKanjiSelection = run
        pendingBodySelection = run
        if let existing = section.annotations.first(where: {
            $0.rangeStart == run.location && $0.rangeLength == run.length
        }) {
            editAnnotation(existing)
            return
        }
        newStart = run.location
        newLength = run.length
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

    /// 歌词被编辑后，把每一条注音的范围跟着挪，让假名始终压在自己的汉字上。
    /// 编辑在 shouldChangeText 里只是排队，这里（事务结束后的下一拍）按顺序重放：
    /// 编辑点之后的注音整体平移；编辑点落在注音里的按新文本重算，字变了就作废。
    /// 所有范围都会先夹在文本长度内，任何不一致都不会抛异常。
    private func remapAnnotations(edits: [(range: NSRange, replacement: String)], textBefore: String) {
        guard !section.annotations.isEmpty else { return }
        var text = textBefore as NSString
        var changed = false
        var dropped = Set<UUID>()
        for (edit, replacement) in edits {
            let location = max(0, min(edit.location, text.length))
            let length = max(0, min(edit.length, text.length - location))
            let safeEdit = NSRange(location: location, length: length)
            guard let after = text.replacingCharacters(in: safeEdit, with: replacement) as NSString? else { continue }
            for anno in Array(section.annotations) where !dropped.contains(anno.id) {
                switch LyricsRubyMath.remapAnnotation(
                    rangeStart: anno.rangeStart,
                    rangeLength: anno.rangeLength,
                    original: anno.original,
                    edit: safeEdit,
                    replacement: replacement,
                    updatedText: after
                ) {
                case let .keep(rangeStart, rangeLength):
                    if rangeStart != anno.rangeStart || rangeLength != anno.rangeLength {
                        anno.rangeStart = rangeStart
                        anno.rangeLength = rangeLength
                        changed = true
                    }
                case .drop:
                    context.delete(anno)
                    dropped.insert(anno.id)
                    changed = true
                }
            }
            text = after
        }
        if changed { try? context.save() }
    }

    private func deleteAllAnnotations() {
        let count = section.annotations.count
        guard count > 0 else { return }
        let message = L("将删除 %d 条注音").localized(with: count)
        guard DeleteConfirmator.confirm(title: L("删除注音"), message: message) else { return }
        for anno in Array(section.annotations) {
            context.delete(anno)
        }
        try? context.save()
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

/// 在正文上方绘制注音。系统文本框自己不会画这段注音属性。
final class LyricsRubyLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    var fontSize: CGFloat = 16

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        guard let storage = layoutManager.textStorage else { return false }
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        var hasRuby = false
        storage.enumerateAttribute(LyricsRubyMath.rubyAttributeName, in: charRange) { value, _, stop in
            if value != nil {
                hasRuby = true
                stop.pointee = true
            }
        }
        guard hasRuby else { return false }
        let extra = LyricsRubyMath.extraLineHeight(fontSize: fontSize)
        lineFragmentRect.pointee.size.height += extra
        lineFragmentUsedRect.pointee.size.height += extra
        baselineOffset.pointee += extra
        return true
    }

    /// 注音不得画出本行和文字视图的左右边。坐标与 drawGlyphs 的 origin 一致。
    fileprivate func rubyColumnLimits(lineRect: NSRect, originX: CGFloat) -> (minX: CGFloat, maxX: CGFloat) {
        let lineMin = originX + lineRect.minX
        let lineMax = originX + lineRect.maxX
        guard let view = firstTextView, view.bounds.width > 1 else {
            return (lineMin, lineMax)
        }
        return LyricsRubyMath.rubyColumnLimit(
            lineMinX: lineMin,
            lineMaxX: lineMax,
            viewMinX: view.bounds.minX,
            viewMaxX: view.bounds.maxX
        )
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        storage.enumerateAttribute(LyricsRubyMath.rubyAttributeName, in: charRange) { value, range, _ in
            guard value != nil,
                  let kana = LyricsRubyMath.rubyText(at: range.location, in: storage),
                  !kana.isEmpty else { return }
            let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var box = boundingRect(forGlyphRange: glyphRange, in: container)
            box.origin.x += origin.x
            box.origin.y += origin.y
            let lineRect = lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let rubyFont = NSFont.systemFont(ofSize: max(fontSize * LyricsRubyMath.rubySizeFactor, 8))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: rubyFont,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let rubySize = (kana as NSString).size(withAttributes: attrs)
            let limits = rubyColumnLimits(lineRect: lineRect, originX: origin.x)
            let x = LyricsRubyMath.rubyDrawX(
                baseMinX: box.minX,
                baseWidth: box.width,
                rubyWidth: rubySize.width,
                limitMinX: limits.minX,
                limitMaxX: limits.maxX
            )
            let y = origin.y + lineRect.minY + 1
            let room = limits.maxX - limits.minX
            if room > 0 {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: NSRect(
                    x: limits.minX,
                    y: origin.y + lineRect.minY,
                    width: room,
                    height: max(lineRect.height, rubySize.height + 2)
                )).addClip()
                (kana as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                (kana as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }
        }
    }
}

/// v1.7.9 Beta+: 自定义 NSTextView，重写 scrollWheel 把滚轮事件转发到外层 NSScrollView
final class PassthroughTextView: NSTextView {
    /// v1.7.9 Delta+: 编辑器最小高度（外部注入，替代硬编码 120）
    var minEditorHeight: CGFloat = 120
    var rubySpans: [LyricsRubySpan] = []
    var editingRubyRange: NSRange?
    var onRubyEdit: ((LyricsRubySpan) -> Void)?
    var onRubyDelete: ((LyricsRubySpan) -> Void)?
    var onSelectedRange: ((NSRange) -> Void)?
    /// 歌词编辑结束后统一回报（范围 + 替换文本），用于同步注音范围。
    /// 只在编辑事务之外被调用，见 shouldChangeText / flushPendingEdits。
    var onTextEdits: (([(range: NSRange, replacement: String)], String) -> Void)?
    /// 开关开启时，按下后移动就重排这一段，而不是在歌词里拖选。只点一下仍放光标。
    var yieldsSectionReorder = false
    var sectionReorderID: UUID?
    private var menuSpan: LyricsRubySpan?
    private var pointerTracking: NSTrackingArea?
    private var isSyncingCaret = false
    private var lastIndicatorFrame: NSRect = .null

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var isOpaque: Bool { false }

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
        // 选区变化可能正发生在 SwiftUI 更新 NSViewRepresentable 的过程中：
        // applyRuby 回写 selectedRanges、applyRequestedSelection 设定选区、换字后
        // AppKit 收拢选区，都会走到这里。此刻同步回调会改到 @State，触发
        // "Modifying state during view update"。所以推到下一个 runloop 再回报；
        // 这期间选区又动了就丢掉这一次，只回报最终值。
        let reported = selectedRange()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.selectedRange() == reported else { return }
            self.onSelectedRange?(reported)
        }
        shrinkSystemCaretToKanji(animated: !flag)
    }

    private var rubyExtraHeight: CGFloat {
        guard let layout = layoutManager as? LyricsRubyLayoutManager else { return 0 }
        return LyricsRubyMath.extraLineHeight(fontSize: layout.fontSize)
    }

    private var rubyBaseLineHeight: CGFloat {
        LyricsRubyMath.baseLineHeight(font: font ?? .systemFont(ofSize: 16))
    }

    private func lineHasRuby(_ charRange: NSRange) -> Bool {
        rubySpans.contains { NSIntersectionRange($0.nsRange, charRange).length > 0 }
    }

    private func invalidateCaret(at rect: NSRect) {
        guard !rect.isNull, !rect.isInfinite, rect.width > 0 || rect.height > 0 else { return }
        setNeedsDisplay(rect.insetBy(dx: -4, dy: -4))
    }

    private func kanjiCaretRect(from proposed: NSRect = .zero, at charIndex: Int? = nil) -> NSRect {
        let extra = rubyExtraHeight
        let base = rubyBaseLineHeight
        let origin = textContainerOrigin
        let size = (layoutManager as? LyricsRubyLayoutManager)?.fontSize ?? font?.pointSize ?? 16
        guard let layout = layoutManager as? LyricsRubyLayoutManager,
              let container = textContainer else {
            let fragment = proposed.isEmpty
                ? NSRect(x: origin.x + 5, y: origin.y, width: 1, height: base)
                : proposed
            return LyricsRubyMath.insertionRect(
                fragment: fragment,
                extraRubyHeight: extra,
                baseLineHeight: base,
                lineHasRuby: !rubySpans.isEmpty,
                fontSize: size
            )
        }
        let storageLen = textStorage?.length ?? 0
        let index = charIndex ?? selectedRange().location
        if layout.numberOfGlyphs == 0 || storageLen == 0 {
            let fragment = NSRect(
                x: origin.x + 5,
                y: origin.y,
                width: 1,
                height: rubySpans.isEmpty ? base : extra + base
            )
            return LyricsRubyMath.insertionRect(
                fragment: fragment,
                extraRubyHeight: extra,
                baseLineHeight: base,
                lineHasRuby: !rubySpans.isEmpty,
                fontSize: layout.fontSize
            )
        }
        let atEnd = index >= storageLen
        let afterNewline = index > 0 && index <= storageLen
            && ((textStorage?.string as NSString?)?.character(at: index - 1) ?? 0) == 10
        if afterNewline {
            // 回车另起一行后，光标应在「下一行的行首」，而不是上一行末尾。
            // 上一行末尾的字符是换行符，按常规路径会把换行符映射到上一行最后
            // 一个可见字形，光标就画到上一行末尾去了。
            if index >= storageLen {
                // 文本以换行结尾：光标落在 extra 空行的行首
                let extraRect = layout.extraLineFragmentRect
                if !extraRect.isNull, extraRect.height > 0 {
                    // extra 行矩形不含 lineFragmentPadding，补上它才能与
                    // AppKit 自己的光标 x 对齐（否则被裁剪掉，光标「消失」）
                    let padding = container.lineFragmentPadding
                    let fragment = NSRect(
                        x: extraRect.minX + padding + origin.x,
                        y: extraRect.minY + origin.y,
                        width: max(proposed.width, 1),
                        height: extraRect.height
                    )
                    return LyricsRubyMath.insertionRect(
                        fragment: fragment,
                        extraRubyHeight: extra,
                        baseLineHeight: base,
                        lineHasRuby: false,
                        fontSize: layout.fontSize
                    )
                }
            } else {
                // 换行后的下一行（可能非空）：用字符边界定位到那一行的行首
                let boundary = layout.glyphRange(
                    forCharacterRange: NSRange(location: index, length: 0),
                    actualCharacterRange: nil
                )
                if boundary.location < layout.numberOfGlyphs {
                    var lineRange = NSRange()
                    let lineRect = layout.lineFragmentRect(forGlyphAt: boundary.location, effectiveRange: &lineRange)
                    let charRange = layout.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
                    // 行矩形同样不含 lineFragmentPadding，行首 x 必须补上，
                    // 否则与 AppKit 光标错开 5pt，被裁剪到不可见
                    let padding = container.lineFragmentPadding
                    let fragment = NSRect(
                        x: lineRect.minX + padding + origin.x,
                        y: lineRect.minY + origin.y,
                        width: max(proposed.width, 1),
                        height: lineRect.height
                    )
                    return LyricsRubyMath.insertionRect(
                        fragment: fragment,
                        extraRubyHeight: extra,
                        baseLineHeight: base,
                        lineHasRuby: lineHasRuby(charRange),
                        fontSize: layout.fontSize
                    )
                }
            }
            // 边界信息拿不到时退回常规路径
        }
        let clamped = min(max(index, 0), storageLen - 1)
        let glyphIndex = layout.glyphIndexForCharacter(at: clamped)
        guard glyphIndex < layout.numberOfGlyphs else {
            let fragment = proposed.isEmpty
                ? NSRect(
                    x: origin.x + 5,
                    y: origin.y,
                    width: 1,
                    height: rubySpans.isEmpty ? base : extra + base
                )
                : proposed
            return LyricsRubyMath.insertionRect(
                fragment: fragment,
                extraRubyHeight: extra,
                baseLineHeight: base,
                lineHasRuby: !rubySpans.isEmpty,
                fontSize: layout.fontSize
            )
        }
        var lineRange = NSRange()
        let lineRect = layout.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
        let charRange = layout.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
        let hasRuby = lineHasRuby(charRange)
        let loc = layout.location(forGlyphAt: glyphIndex)
        var x = lineRect.minX + loc.x + origin.x
        if atEnd {
            let box = layout.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: container
            )
            x = box.maxX + origin.x
        }
        let fragment = NSRect(
            x: x,
            y: lineRect.minY + origin.y,
            width: max(proposed.width, 1),
            height: lineRect.height
        )
        return LyricsRubyMath.insertionRect(
            fragment: fragment,
            extraRubyHeight: extra,
            baseLineHeight: base,
            lineHasRuby: hasRuby,
            fontSize: layout.fontSize
        )
    }

    override var shouldDrawInsertionPoint: Bool {
        // 必须保留系统对第一响应者和关键窗口的判断。放弃焦点后若仍返回真，
        // 插入点指示器会活着回调放弃焦点，直到栈保护触发崩溃。
        let result = editingRubyRange == nil && super.shouldDrawInsertionPoint
        return result
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // 只留系统插入点，画在汉字带上。
        // 不要自绘一条（会叠在透明文字层上，变成第二条）。指示器已经存在时不要再调父类，
        // 父类那条细线会在改字号时残留。不要隐藏指示器，隐藏会递归进放弃焦点。
        // 系统还没建指示器时，在汉字框上调父类，系统光标才会出现。
        let placed = kanjiCaretRect(from: rect)
        if insertionIndicatorViews().isEmpty {
            super.drawInsertionPoint(in: placed, color: LyricsRubyMath.caretColor, turnedOn: flag)
        }
        shrinkSystemCaretToKanji(using: placed, animated: true)
    }

    override func updateInsertionPointStateAndRestartTimer(_ restartFlag: Bool) {
        if isSyncingCaret {
            // 重入时不要调父类：指示器会回到整段行高（注音加汉字）上，并且递归。
            return
        }
        isSyncingCaret = true
        super.updateInsertionPointStateAndRestartTimer(restartFlag)
        shrinkSystemCaretToKanji(animated: true)
        isSyncingCaret = false
    }

    /// 把系统光标放到汉字带上，颜色和粗细与搜索框一致。
    /// 不要再加第二个插入点指示器，也不要切换显示模式或隐藏，
    /// 那些会重新进入放弃焦点并把栈打爆。
    private func shrinkSystemCaretToKanji(using rect: NSRect? = nil, animated: Bool = true) {
        insertionPointColor = LyricsRubyMath.caretColor
        guard shouldDrawInsertionPoint else { return }
        let placed = rect ?? kanjiCaretRect()
        let slide = animated
            && !lastIndicatorFrame.isNull
            && LyricsRubyMath.shouldAnimateCaretMove(from: lastIndicatorFrame, to: placed)
        if !lastIndicatorFrame.isNull, lastIndicatorFrame != placed {
            invalidateCaret(at: lastIndicatorFrame)
        }
        invalidateCaret(at: placed)
        for view in insertionIndicatorViews() {
            placeIndicator(view, frameInTextView: placed, animated: slide)
        }
        lastIndicatorFrame = placed
    }

    private func placeIndicator(_ view: NSView, frameInTextView placed: NSRect, animated: Bool) {
        if let indicator = view as? NSTextInsertionIndicator {
            indicator.color = LyricsRubyMath.caretColor
        }
        let target: NSRect
        if view.superview === self {
            target = placed
        } else if let parent = view.superview {
            target = parent.convert(placed, from: self)
            if parent === superview, parent.subviews.last !== view {
                parent.addSubview(view, positioned: .above, relativeTo: self)
            }
        } else {
            target = placed
        }
        applyCaretFrame(view, target: target, animated: animated)
    }

    private func applyCaretFrame(_ view: NSView, target: NSRect, animated: Bool) {
        if view.frame == target { return }
        NSAnimationContext.runAnimationGroup { context in
            if animated {
                context.duration = LyricsRubyMath.caretMoveDuration
                context.timingFunction = CAMediaTimingFunction(name: .linear)
                context.allowsImplicitAnimation = true
                view.animator().frame = target
            } else {
                context.duration = 0
                view.frame = target
            }
        }
    }

    private func insertionIndicatorViews() -> [NSView] {
        var found: [NSView] = []
        let root: NSView = enclosingScrollView ?? superview ?? self
        var stack: [NSView] = [root]
        var index = 0
        while index < stack.count {
            let view = stack[index]
            index += 1
            for sub in view.subviews {
                if sub is NSTextInsertionIndicator {
                    if !found.contains(where: { $0 === sub }) {
                        found.append(sub)
                    }
                } else {
                    stack.append(sub)
                }
            }
        }
        return found
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTracking {
            removeTrackingArea(pointerTracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .cursorUpdate, .activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        pointerTracking = area
    }

    override func resetCursorRects() {
        discardCursorRects()
        // 编辑框内一律 I 形指针，只有可点按的注音给箭头
        addCursorRect(bounds, cursor: .iBeam)
        for span in rubySpans {
            guard let rect = rubyHitRect(for: span) else { continue }
            addCursorRect(rect, cursor: .arrow)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        applyPointer(at: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        applyPointer(at: event)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        applyPointer(at: event)
    }

    private func applyPointer(at event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if pointerKind(at: point) == .iBeam {
            NSCursor.iBeam.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func pointerKind(at point: NSPoint) -> LyricsRubyMath.PointerKind {
        LyricsRubyMath.pointerKind(overTappableRuby: tappableRubySpan(at: point) != nil)
    }

    /// 一条注音的可点按区域（视图坐标）。与绘制同一处起点，不越出栏的左右边。
    private func rubyHitRect(for span: LyricsRubySpan) -> NSRect? {
        guard let layout = layoutManager as? LyricsRubyLayoutManager,
              let container = textContainer,
              layout.numberOfGlyphs > 0 else { return nil }
        let glyphRange = layout.glyphRange(forCharacterRange: span.nsRange, actualCharacterRange: nil)
        guard glyphRange.length > 0, glyphRange.location != NSNotFound else { return nil }
        let box = layout.boundingRect(forGlyphRange: glyphRange, in: container)
        let lineRect = layout.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let rubyFont = NSFont.systemFont(ofSize: max(layout.fontSize * LyricsRubyMath.rubySizeFactor, 8))
        let rubyWidth = (span.phonetic as NSString).size(withAttributes: [.font: rubyFont]).width
        let origin = textContainerOrigin
        let viewMin = bounds.width > 1 ? bounds.minX - origin.x : lineRect.minX
        let viewMax = bounds.width > 1 ? bounds.maxX - origin.x : lineRect.maxX
        let limits = LyricsRubyMath.rubyColumnLimit(
            lineMinX: lineRect.minX,
            lineMaxX: lineRect.maxX,
            viewMinX: viewMin,
            viewMaxX: viewMax
        )
        return LyricsRubyMath.rubyHitRect(
            baseBox: box,
            rubyWidth: rubyWidth,
            lineMinY: lineRect.minY,
            extraRubyHeight: LyricsRubyMath.extraLineHeight(fontSize: layout.fontSize),
            limitMinX: limits.minX,
            limitMaxX: limits.maxX
        ).offsetBy(dx: origin.x, dy: origin.y)
    }

    /// 注音带里真正能点的那一块：点按进入编辑，右键出「编辑读音 / 删除」菜单
    private func tappableRubySpan(at point: NSPoint) -> LyricsRubySpan? {
        rubySpans.first { span in
            rubyHitRect(for: span)?.contains(point) ?? false
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let span = tappableRubySpan(at: convert(event.locationInWindow, from: nil)) {
            window?.makeFirstResponder(nil)
            onRubyEdit?(span)
            return
        }
        // 修饰键或连点仍交给文字系统选字。右键不进这里。
        let plainClick = event.clickCount == 1
            && event.modifierFlags.intersection([.shift, .command, .control, .option]).isEmpty
        guard yieldsSectionReorder, let sectionID = sectionReorderID, plainClick, let window else {
            super.mouseDown(with: event)
            return
        }
        let origin = event.locationInWindow
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        let button = SectionDragMath.sectionPointerButton(rightButton: false)
        while let next = window.nextEvent(matching: mask, until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            if next.type == .leftMouseUp {
                placeInsertionCaret(for: event)
                return
            }
            let p = next.locationInWindow
            let intent = SectionDragMath.sectionGestureIntent(
                button: button,
                translationX: p.x - origin.x,
                translationY: p.y - origin.y,
                ended: false
            )
            if intent == .reorder {
                beginSectionReorderDrag(id: sectionID, event: next)
                return
            }
        }
        placeInsertionCaret(for: event)
    }

    /// 没拖成重排时，仍把光标放到按下的字上。
    private func placeInsertionCaret(for event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let length = textStorage?.length ?? 0
        let clamped = min(max(index, 0), length)
        setSelectedRange(NSRange(location: clamped, length: 0))
    }

    /// 歌词缩影跟着光标。剪贴板只有段落类型，不附带纯文本编号。
    private func beginSectionReorderDrag(id: UUID, event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: SectionIDPasteboardWriter(id: id))
        let image = sectionReorderImage()
        let point = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(
            NSRect(x: point.x + 8, y: point.y + 8, width: image.size.width, height: image.size.height),
            contents: image
        )
        ReorderDragCenter.shared.beginSectionDrag(id: id)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        if let sectionReorderID, ReorderDragCenter.shared.isDraggingSection(sectionReorderID) {
            return context == .outsideApplication ? [] : [.copy, .move]
        }
        return super.draggingSession(session, sourceOperationMaskFor: context)
    }

    override func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        if let sectionReorderID, ReorderDragCenter.shared.isDraggingSection(sectionReorderID) {
            ReorderDragCenter.shared.updateSectionClaim(screenPoint: screenPoint)
            return
        }
        super.draggingSession(session, movedTo: screenPoint)
    }

    override func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if let sectionReorderID, ReorderDragCenter.shared.isDraggingSection(sectionReorderID) {
            ReorderDragCenter.shared.finishSectionDrag(screenPoint: screenPoint)
            return
        }
        super.draggingSession(session, endedAt: screenPoint, operation: operation)
    }

    /// 跟光标走的歌词缩影：正文，不是曲目行的图标加标题。空歌词也留一个空框。
    private func sectionReorderImage() -> NSImage {
        let limited = string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8)
            .joined(separator: "\n")
        let font = NSFont.systemFont(ofSize: 12)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let textWidth: CGFloat = 200
        let measured = (limited as NSString).boundingRect(
            with: NSSize(width: textWidth, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let size = NSSize(width: 220, height: max(72, ceil(measured.height) + 16))
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSColor.textBackgroundColor.setFill()
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        if !limited.isEmpty {
            (limited as NSString).draw(
                with: NSRect(x: 10, y: 8, width: textWidth, height: size.height - 16),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
        }
        image.unlockFocus()
        return image
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let span = tappableRubySpan(at: convert(event.locationInWindow, from: nil)) else {
            return super.menu(for: event)
        }
        menuSpan = span
        let menu = NSMenu()
        let edit = NSMenuItem(title: L("编辑读音"), action: #selector(editRubyFromMenu(_:)), keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)
        let del = NSMenuItem(title: L("删除"), action: #selector(deleteRubyFromMenu(_:)), keyEquivalent: "")
        del.target = self
        menu.addItem(del)
        return menu
    }

    @objc private func editRubyFromMenu(_ sender: Any?) {
        if let span = menuSpan { onRubyEdit?(span) }
    }

    @objc private func deleteRubyFromMenu(_ sender: Any?) {
        if let span = menuSpan { onRubyDelete?(span) }
    }

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
        relayoutForContent()
        // 普通输入/删除：当帧就把注音范围重算到位，避免下一帧才挪的错位闪烁
        flushPendingEdits()
    }

    /// 输入法组词更新不触发 didChangeText，这里补上同样的当帧重算
    override func setMarkedText(_ string: Any?, selectedRange: NSRange, replacementRange: NSRange) {
        // 父类签名是 Any!/Any，直接传 Any? 会触发「隐式从 Any? 转 Any」的
        // 编译告警；输入系统实际不会传 nil，空串兜底不改变行为。
        super.setMarkedText(string ?? "", selectedRange: selectedRange, replacementRange: replacementRange)
        flushPendingEdits()
    }

    /// 编辑事务里绝不能动模型：一旦触发界面更新，注音会重建富文本，
    /// 文字系统的标记范围就失效，下一次按键会因替换范围越界而卡死输入。
    /// 所以这里只记录，等事务结束后的下一拍再统一回报。
    private var pendingEdits: [(range: NSRange, replacement: String, textBefore: String)] = []
    private var flushScheduled = false

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // 拖放编号有时不走拖放回调，而在这里才变成要插入的字符串。
        if let replacementString, SectionDragMath.isSectionIDPayload(replacementString) {
            return false
        }
        let allowed = super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        if allowed {
            pendingEdits.append((affectedCharRange, replacementString ?? "", string))
            if !flushScheduled {
                flushScheduled = true
                DispatchQueue.main.async { [weak self] in self?.flushPendingEdits() }
            }
        }
        return allowed
    }

    private func flushPendingEdits() {
        flushScheduled = false
        guard !pendingEdits.isEmpty else { return }
        let edits = pendingEdits
        pendingEdits.removeAll()
        // 按序重放出最终文本；与文字视图当前内容不一致（整段换字/换段）就放弃。
        // 注意：不能拿 section.body 比——输入法标记文本期间绑定会滞后，
        // 重放文本比绑定新是正常现象，误判会导致注音永远不挪。
        var text = edits[0].textBefore as NSString
        for edit in edits {
            let loc = max(0, min(edit.range.location, text.length))
            let len = max(0, min(edit.range.length, text.length - loc))
            text = text.replacingCharacters(in: NSRange(location: loc, length: len), with: edit.replacement) as NSString
        }
        guard text as String == string else {
            return
        }
        onTextEdits?(edits.map { (range: $0.range, replacement: $0.replacement) }, edits[0].textBefore)
    }

    /// 只重算内容高度，不整页刷新。边框伸缩由外层 SwiftUI 的 frame 来做。
    func relayoutForContent() {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        window?.invalidateCursorRects(for: self)
        if !lastIndicatorFrame.isNull {
            invalidateCaret(at: lastIndicatorFrame)
        }
        shrinkSystemCaretToKanji(animated: false)
    }

    func fittedHeight(forWidth width: CGFloat) -> CGFloat {
        let inset = textContainerInset.width * 2
        textContainer?.containerSize = NSSize(
            width: max(width - inset, 1),
            height: CGFloat.greatestFiniteMagnitude
        )
        relayoutForContent()
        return intrinsicContentSize.height
    }

    // 进入、移动、准备放下、真正写下之前都问同一份判定。编号可能晚一点才变成字符串。
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if Self.shouldRejectSectionDrag(sender) { return [] }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if Self.shouldRejectSectionDrag(sender) { return [] }
        return super.draggingUpdated(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if Self.shouldRejectSectionDrag(sender) { return false }
        return super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if Self.shouldRejectSectionDrag(sender) { return false }
        return super.performDragOperation(sender)
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if Self.pasteboardCarriesSectionID(pboard, extraType: type) { return false }
        return super.readSelection(from: pboard, type: type)
    }

    static func shouldRejectSectionDrag(_ sender: NSDraggingInfo) -> Bool {
        pasteboardCarriesSectionID(sender.draggingPasteboard)
    }

    /// 只收集类型和字符串，收不收交给 SectionDragMath。
    static func pasteboardCarriesSectionID(
        _ pasteboard: NSPasteboard,
        extraType: NSPasteboard.PasteboardType? = nil
    ) -> Bool {
        var typeIDs = (pasteboard.types ?? []).map(\.rawValue)
        var strings: [String] = []
        let stringTypes: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("public.plain-text"),
            NSPasteboard.PasteboardType("NSStringPboardType"),
            NSPasteboard.PasteboardType(SectionDragMath.sectionIDTypeIdentifier)
        ]
        func absorb(type: NSPasteboard.PasteboardType, string: String?, data: Data?) {
            typeIDs.append(type.rawValue)
            if let string { strings.append(string) }
            if let data, let text = String(data: data, encoding: .utf8) {
                strings.append(text)
            }
        }
        if let extraType {
            absorb(
                type: extraType,
                string: pasteboard.string(forType: extraType),
                data: pasteboard.data(forType: extraType)
            )
        }
        let items = pasteboard.pasteboardItems ?? []
        if items.isEmpty {
            for type in stringTypes {
                absorb(
                    type: type,
                    string: pasteboard.string(forType: type),
                    data: pasteboard.data(forType: type)
                )
            }
        } else {
            for item in items {
                for type in item.types {
                    absorb(
                        type: type,
                        string: item.string(forType: type),
                        data: item.data(forType: type)
                    )
                }
                for type in stringTypes where !item.types.contains(type) {
                    absorb(
                        type: type,
                        string: item.string(forType: type),
                        data: item.data(forType: type)
                    )
                }
            }
        }
        return SectionDragMath.shouldRejectLyricsDrop(
            pasteboardStrings: strings,
            pasteboardTypeIDs: typeIDs
        )
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

/// 外层只动画边框高度（和段落展开/收起同一套 easeInOut 0.2），文字本身不跟着拉伸或闪。
struct PassthroughScrollTextEditor: View {
    @Environment(\.appFontScale) private var fontScale
    @Binding var text: String
    @Binding var isFocused: Bool
    var fontSize: CGFloat = 16
    var minHeight: CGFloat = 120
    var rubyAnnotations: [LyricsRubySpan] = []
    var editingRubyRange: NSRange? = nil
    var onRubyEdit: (LyricsRubySpan) -> Void = { _ in }
    var onRubyDelete: (LyricsRubySpan) -> Void = { _ in }
    var onSelectedRange: (NSRange) -> Void = { _ in }
    var onTextEdits: ([(range: NSRange, replacement: String)], String) -> Void = { _, _ in }
    var requestedSelection: Binding<NSRange?> = .constant(nil)
    var yieldsSectionReorder: Bool = false
    var sectionReorderID: UUID? = nil
    @State private var boxHeight: CGFloat = 120

    private var resolvedFontSize: CGFloat {
        AppFontMetrics.size(fontSize, scale: fontScale)
    }

    var body: some View {
        PassthroughScrollTextEditorNS(
            text: $text,
            isFocused: $isFocused,
            fontSize: resolvedFontSize,
            minHeight: minHeight,
            rubyAnnotations: rubyAnnotations,
            editingRubyRange: editingRubyRange,
            onRubyEdit: onRubyEdit,
            onRubyDelete: onRubyDelete,
            onSelectedRange: onSelectedRange,
            onTextEdits: onTextEdits,
            requestedSelection: requestedSelection,
            yieldsSectionReorder: yieldsSectionReorder,
            sectionReorderID: sectionReorderID,
            onFittedHeight: { h, animated in
                let target = max(minHeight, h)
                guard abs(target - boxHeight) > 1 else { return }
                if animated {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        boxHeight = target
                    }
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        boxHeight = target
                    }
                }
            }
        )
        .frame(height: max(boxHeight, minHeight), alignment: .top)
        .clipped()
        .onChange(of: minHeight) { _, newMin in
            if boxHeight < newMin {
                withAnimation(.easeInOut(duration: 0.2)) {
                    boxHeight = newMin
                }
            }
        }
        .onAppear {
            if boxHeight < minHeight { boxHeight = minHeight }
        }
    }
}

/// v1.7.9 Beta+: NSViewRepresentable 包装 NSTextView，禁用内部垂直滚动，让滚轮穿透
private struct PassthroughScrollTextEditorNS: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var fontSize: CGFloat = 16
    var minHeight: CGFloat = 120
    var rubyAnnotations: [LyricsRubySpan] = []
    var editingRubyRange: NSRange? = nil
    var onRubyEdit: (LyricsRubySpan) -> Void = { _ in }
    var onRubyDelete: (LyricsRubySpan) -> Void = { _ in }
    var onSelectedRange: (NSRange) -> Void = { _ in }
    var onTextEdits: ([(range: NSRange, replacement: String)], String) -> Void = { _, _ in }
    var requestedSelection: Binding<NSRange?> = .constant(nil)
    var yieldsSectionReorder: Bool = false
    var sectionReorderID: UUID? = nil
    var onFittedHeight: (CGFloat, Bool) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        // 用自定义 PassthroughScrollView（禁用垂直滚动）
        let scrollView = PassthroughScrollView()
        scrollView.minEditorHeight = minHeight  // v1.7.9 Delta+: 注入最小高度
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let storage = NSTextStorage()
        let layout = LyricsRubyLayoutManager()
        layout.fontSize = fontSize
        let container = NSTextContainer(size: NSSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 5
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)

        let textView = PassthroughTextView(frame: .zero, textContainer: container)
        textView.minEditorHeight = minHeight  // v1.7.9 Delta+: 注入最小高度
        textView.rubySpans = rubyAnnotations
        textView.editingRubyRange = editingRubyRange
        textView.onRubyEdit = onRubyEdit
        textView.onRubyDelete = onRubyDelete
        textView.onSelectedRange = onSelectedRange
        textView.onTextEdits = onTextEdits
        textView.yieldsSectionReorder = yieldsSectionReorder
        textView.sectionReorderID = sectionReorderID
        let resolvedFont = NSFont.systemFont(ofSize: fontSize)
        textView.font = resolvedFont
        textView.typingAttributes = [
            .font: resolvedFont,
            .foregroundColor: NSColor.labelColor,
        ]
        textView.textColor = .labelColor
        textView.insertionPointColor = LyricsRubyMath.caretColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.delegate = context.coordinator
        let extraTop = LyricsRubyMath.extraTopInset(fontSize: fontSize, hasRuby: !rubyAnnotations.isEmpty)
        textView.textContainerInset = NSSize(width: 8, height: 6 + extraTop)
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        // 用文字视图当前的字符串（组词期间比绑定新），属性重建才与文本同帧
        applyRuby(to: textView, lyrics: textView.string, font: resolvedFont, coordinator: context.coordinator)
        context.coordinator.textViewRef = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if let passthrough = textView as? PassthroughTextView {
            passthrough.minEditorHeight = minHeight
            passthrough.rubySpans = rubyAnnotations
            passthrough.editingRubyRange = editingRubyRange
            passthrough.onRubyEdit = onRubyEdit
            passthrough.onRubyDelete = onRubyDelete
            passthrough.onSelectedRange = onSelectedRange
            passthrough.onTextEdits = onTextEdits
            passthrough.yieldsSectionReorder = yieldsSectionReorder
            passthrough.sectionReorderID = sectionReorderID
        }
        if let passthroughScroll = scrollView as? PassthroughScrollView {
            passthroughScroll.minEditorHeight = minHeight
        }
        if let layout = textView.layoutManager as? LyricsRubyLayoutManager {
            layout.fontSize = fontSize
        }
        textView.minSize = NSSize(width: 0, height: minHeight)
        let resolvedFont = NSFont.systemFont(ofSize: fontSize)
        textView.font = resolvedFont
        textView.insertionPointColor = LyricsRubyMath.caretColor
        textView.typingAttributes = [
            .font: resolvedFont,
            .foregroundColor: NSColor.labelColor,
        ]
        let extraTop = LyricsRubyMath.extraTopInset(fontSize: fontSize, hasRuby: !rubyAnnotations.isEmpty)
        textView.textContainerInset = NSSize(width: 8, height: 6 + extraTop)
        let width = scrollView.bounds.width > 1 ? scrollView.bounds.width : (textView.bounds.width)
        let textChanged = textView.string != text
        // 输入法组词（标记文本）期间绑定不会跟着更新，此刻绝不能拿绑定覆盖
        // 文字视图：会毁掉标记文本并把光标重置到句子末尾。
        // 组词提交后 textDidChange 会更新绑定，下一次更新自然就一致了。
        if textChanged && !textView.hasMarkedText() {
            // 只换字，边框高度由外层 frame 动画，文字不做透明度/位移。
            textView.string = text
        }
        // 用文字视图当前的字符串（组词期间比绑定新），属性重建才与文本同帧
        applyRuby(to: textView, lyrics: textView.string, font: resolvedFont, coordinator: context.coordinator)
        applySelectionHighlight(to: textView)
        applyRequestedSelection(to: textView)
        if let passthrough = textView as? PassthroughTextView {
            let fitted = passthrough.fittedHeight(forWidth: max(width, 1))
            DispatchQueue.main.async {
                context.coordinator.reportHeight(fitted, animated: textChanged)
            }
        }
        if isFocused, textView.window?.firstResponder != textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func rubySignature(lyrics: String, fontSize: CGFloat) -> String {
        let parts = rubyAnnotations.map { "\($0.rangeStart):\($0.rangeLength):\($0.phonetic)" }.joined(separator: "|")
        let edit = editingRubyRange.map { "\($0.location):\($0.length)" } ?? ""
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? "d" : "l"
        return "\(lyrics)\u{1e}\(parts)\u{1e}\(fontSize)\u{1e}\(edit)\u{1e}\(dark)"
    }

    private func applyRuby(to textView: NSTextView, lyrics: String, font: NSFont, coordinator: Coordinator) {
        let signature = rubySignature(lyrics: lyrics, fontSize: font.pointSize)
        if coordinator.lastRubySignature == signature { return }
        guard let storage = textView.textStorage else { return }
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let attributed = LyricsRubyMath.attributedString(
            lyrics: lyrics,
            annotations: rubyAnnotations,
            font: font,
            textColor: .labelColor,
            editingRange: editingRubyRange,
            darkAppearance: dark
        )
        let selected = textView.selectedRanges
        if storage.string == attributed.string {
            storage.beginEditing()
            let full = NSRange(location: 0, length: storage.length)
            if full.length > 0 {
                // setAttributes 是整段替换属性，会把输入法的 NSMarkedClauseSegment
                // 抹掉（等于替用户提前提交组词）；先把标记摘出来，更新完再贴回去
                var marks: [(range: NSRange, value: Any)] = []
                storage.enumerateAttribute(.markedClauseSegment, in: full) { value, range, _ in
                    if let value { marks.append((range, value)) }
                }
                attributed.enumerateAttributes(in: full) { attrs, range, _ in
                    storage.setAttributes(attrs, range: range)
                }
                for mark in marks {
                    storage.addAttribute(.markedClauseSegment, value: mark.value, range: mark.range)
                }
            } else {
                storage.setAttributedString(attributed)
            }
            storage.endEditing()
        } else {
            storage.setAttributedString(attributed)
        }
        let maxLen = storage.length
        let clipped: [NSValue] = selected.compactMap { value in
            var range = value.rangeValue
            if range.location > maxLen { return nil }
            if NSMaxRange(range) > maxLen {
                range.length = maxLen - range.location
            }
            return NSValue(range: range)
        }
        if !clipped.isEmpty {
            textView.selectedRanges = clipped
        }
        coordinator.lastRubySignature = signature
    }

    private func applySelectionHighlight(to textView: NSTextView) {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if editingRubyRange != nil {
            let fill = LyricsRubyMath.editingHighlightColor(dark: dark)
            textView.selectedTextAttributes = [
                .backgroundColor: fill,
                .foregroundColor: NSColor.labelColor,
            ]
        } else {
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor.selectedTextBackgroundColor,
                .foregroundColor: NSColor.selectedTextColor,
            ]
        }
    }

    private func applyRequestedSelection(to textView: NSTextView) {
        guard let range = requestedSelection.wrappedValue else { return }
        let maxLen = (textView.string as NSString).length
        var clipped = range
        if clipped.location > maxLen {
            // 仍在 updateNSView 里，不能同步写 Binding，推迟一拍再清掉
            DispatchQueue.main.async {
                if requestedSelection.wrappedValue == range {
                    requestedSelection.wrappedValue = nil
                }
            }
            return
        }
        if NSMaxRange(clipped) > maxLen {
            clipped.length = max(0, maxLen - clipped.location)
        }
        textView.setSelectedRange(clipped)
        DispatchQueue.main.async {
            if requestedSelection.wrappedValue == range {
                requestedSelection.wrappedValue = nil
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        let width = proposal.width ?? nsView.bounds.width
        let height = proposal.height ?? minHeight
        if width > 1, let textView = nsView.documentView as? PassthroughTextView {
            textView.minEditorHeight = minHeight
            let fitted = textView.fittedHeight(forWidth: width)
            DispatchQueue.main.async {
                context.coordinator.reportHeight(fitted, animated: false)
            }
        }
        return CGSize(width: width, height: max(height, minHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onFittedHeight: onFittedHeight)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onFittedHeight: (CGFloat, Bool) -> Void
        weak var textViewRef: NSTextView?
        var lastRubySignature: String = ""
        private var lastReported: CGFloat = 0

        init(text: Binding<String>, onFittedHeight: @escaping (CGFloat, Bool) -> Void) {
            self.text = text
            self.onFittedHeight = onFittedHeight
        }

        func reportHeight(_ height: CGFloat, animated: Bool) {
            guard abs(height - lastReported) > 1 else { return }
            lastReported = height
            onFittedHeight(height, animated)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            if let passthrough = textView as? PassthroughTextView {
                let width = max(textView.bounds.width, 1)
                reportHeight(passthrough.fittedHeight(forWidth: width), animated: false)
            }
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
