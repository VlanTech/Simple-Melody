// Views/Pronunciation/SelectableTextEditor.swift
// 可选中 + 注音高亮的文本编辑器（基于 NSTextView）

import SwiftUI
import AppKit

struct SelectableTextEditor: NSViewRepresentable {
    @Binding var text: String
    let annotations: [PronunciationAnnotation]
    let onSelectionChange: (NSRange) -> Void
    let onAnnotationTap: (PronunciationAnnotation) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 16)
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.string = text
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        }

        context.coordinator.textView = textView
        context.coordinator.applyAnnotations(to: textView, annotations: annotations)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // 仅当外部修改时才更新文本（避免光标跳到开头）
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        context.coordinator.applyAnnotations(to: textView, annotations: annotations)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextEditor
        weak var textView: NSTextView?
        /// 当前文本上的注音信息（id -> Annotation），用于点击事件查找
        private var currentAnnotations: [PronunciationAnnotation] = []

        init(_ parent: SelectableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            if parent.text != newText {
                parent.text = newText
                applyAnnotations(to: textView, annotations: parent.annotations)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let ranges = textView.selectedRanges.compactMap { $0 as? NSValue }.map { $0.rangeValue }
            let range = ranges.first ?? NSRange(location: 0, length: 0)
            parent.onSelectionChange(range)
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            // 注音点击：通过 charIndex 找匹配的 annotation
            if let anno = currentAnnotations.first(where: {
                $0.rangeStart <= charIndex && charIndex < $0.rangeStart + $0.rangeLength
            }) {
                parent.onAnnotationTap(anno)
                return true
            }
            return false
        }

        /// 应用注音样式
        func applyAnnotations(to textView: NSTextView, annotations: [PronunciationAnnotation]) {
            currentAnnotations = annotations
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            let body = textView.string as NSString

            storage.beginEditing()
            // 重置默认样式
            storage.setAttributes([
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.clear,
                .underlineStyle: NSUnderlineStyle(),
                .underlineColor: NSColor.clear,
                .link: NSNull(),
            ], range: fullRange)

            // 应用每个注音
            for anno in annotations {
                let r = NSRange(location: anno.rangeStart, length: anno.rangeLength)
                guard r.location + r.length <= body.length else { continue }
                let bgColor: NSColor
                let fgColor: NSColor
                if anno.isAutoGenerated {
                    bgColor = NSColor.controlAccentColor.withAlphaComponent(0.18)
                    fgColor = NSColor.controlAccentColor
                } else {
                    bgColor = NSColor.systemOrange.withAlphaComponent(0.25)
                    fgColor = NSColor.systemOrange
                }
                storage.addAttribute(.backgroundColor, value: bgColor, range: r)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: r)
                storage.addAttribute(.underlineColor, value: fgColor, range: r)
                storage.addAttribute(.foregroundColor, value: fgColor, range: r)
                // 通过 link 属性触发点击回调（用 NSCheckingStyle 来获得下划线但无导航）
                storage.addAttribute(.link, value: URL(string: "sm-anno://\(anno.id.uuidString)") ?? URL(string: "sm-anno://")!, range: r)
                storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: r)
            }
            storage.endEditing()
        }
    }
}
