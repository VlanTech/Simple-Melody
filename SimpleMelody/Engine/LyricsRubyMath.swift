// Engine/LyricsRubyMath.swift
// Lyrics + annotation ranges → NSAttributedString with CoreText ruby above the base run.
// Storage stays the plain lyrics string; ruby is display-only.

import AppKit
import CoreText
import Foundation

struct LyricsRubySpan: Equatable {
    var rangeStart: Int
    var rangeLength: Int
    var original: String
    var phonetic: String

    var nsRange: NSRange {
        NSRange(location: rangeStart, length: rangeLength)
    }
}

enum LyricsRubyMath {
    static let rubySizeFactor: CGFloat = 0.5

    static let rubyAttributeName = NSAttributedString.Key(rawValue: kCTRubyAnnotationAttributeName as String)

    static func extraLineHeight(fontSize: CGFloat) -> CGFloat {
        ceil(fontSize * rubySizeFactor) + 2
    }

    static func extraTopInset(fontSize: CGFloat, hasRuby: Bool) -> CGFloat {
        hasRuby ? extraLineHeight(fontSize: fontSize) : 0
    }

    static func baseLineHeight(font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender)
    }

    /// Same bar as the song-search `TextField`: AppKit default thickness, not a custom fat fill.
    static let systemCaretWidth: CGFloat = 2

    /// Same color as the song-search field (accent / system insertion), not body text.
    static var caretColor: NSColor { .textInsertionPointColor }

    /// Linear slide when the insertion point jumps to another glyph.
    static let caretMoveDuration: TimeInterval = 0.1

    static let caretMoveThreshold: CGFloat = 0.5

    static func caretWidth(fontSize: CGFloat) -> CGFloat {
        _ = fontSize
        return systemCaretWidth
    }

    static func shouldAnimateCaretMove(from: CGRect, to: CGRect) -> Bool {
        guard from.width > 0, from.height > 0, to.width > 0, to.height > 0 else { return false }
        return abs(from.minX - to.minX) > caretMoveThreshold
            || abs(from.minY - to.minY) > caretMoveThreshold
    }

    /// Insertion point sits on the base glyphs, not the ruby band above them.
    /// A full fragment (base + extra) is pinned to the kanji at the bottom.
    /// A font-height caret on a ruby line is shifted down by the ruby extra —
    /// AppKit often places that shorter caret at the top of the fragment, on the kana.
    static func caretRect(
        from rect: CGRect,
        extraRubyHeight: CGFloat,
        baseLineHeight: CGFloat,
        lineHasRuby: Bool = false
    ) -> CGRect {
        guard lineHasRuby, extraRubyHeight > 0, baseLineHeight > 0 else { return rect }
        if rect.height + 0.5 >= baseLineHeight + extraRubyHeight {
            let height = min(baseLineHeight, rect.height)
            return CGRect(
                x: rect.origin.x,
                y: rect.maxY - height,
                width: rect.width,
                height: height
            )
        }
        return CGRect(
            x: rect.origin.x,
            y: rect.origin.y + extraRubyHeight,
            width: rect.width,
            height: min(rect.height, baseLineHeight)
        )
    }

    /// System insertion box: kanji-band geometry, search-field thickness.
    static func insertionRect(
        fragment: CGRect,
        extraRubyHeight: CGFloat,
        baseLineHeight: CGFloat,
        lineHasRuby: Bool,
        fontSize: CGFloat
    ) -> CGRect {
        _ = fontSize
        var rect = caretRect(
            from: fragment,
            extraRubyHeight: extraRubyHeight,
            baseLineHeight: baseLineHeight,
            lineHasRuby: lineHasRuby
        )
        if rect.width <= 1.5 {
            rect.size.width = systemCaretWidth
        }
        return rect
    }

    enum PointerKind: Equatable {
        case iBeam
        case arrow
    }

    /// 一条注音在歌词被编辑后的去向
    enum AnnotationShift: Equatable {
        /// 范围平移或重算后仍然对得上原文
        case keep(rangeStart: Int, rangeLength: Int)
        /// 编辑落在注音内部且原文已经变了（读音作废）
        case drop
    }

    /// 歌词改动后重新对齐一条注音，让假名始终压在自己的汉字上：
    /// - 改动点在注音之后：范围不动
    /// - 改动点在注音之前：整体平移 delta
    /// - 改动点落在注音内部：按新文本重算范围，原文还对得上就保留，对不上就作废
    ///   （例如把「東京」改成「東坂」，旧的 とうきょう 就该丢）
    /// 注意：edit 是「编辑前文本」里的有效范围（调用方负责按编辑前文本夹住），
    /// updatedText 是编辑后的文本；删除大段时 edit 的长度会超过 updatedText，
    /// 所以这里绝不能用 updatedText 去夹 edit。
    static func remapAnnotation(
        rangeStart: Int,
        rangeLength: Int,
        original: String,
        edit: NSRange,
        replacement: String,
        updatedText: NSString
    ) -> AnnotationShift {
        let end = rangeStart + rangeLength
        let editEnd = edit.location + edit.length
        let delta = (replacement as NSString).length - edit.length

        if end <= edit.location {
            return .keep(rangeStart: rangeStart, rangeLength: rangeLength)
        }
        if rangeStart >= editEnd {
            return .keep(rangeStart: max(0, rangeStart + delta), rangeLength: rangeLength)
        }

        let lower = min(rangeStart, edit.location)
        let upper = max(end, editEnd) + delta
        let clampedLower = max(0, min(lower, updatedText.length))
        let clampedLength = max(0, min(upper - lower, updatedText.length - clampedLower))
        guard clampedLength > 0 else { return .drop }
        let candidate = NSRange(location: clampedLower, length: clampedLength)
        guard updatedText.substring(with: candidate) == original else { return .drop }
        return .keep(rangeStart: clampedLower, rangeLength: clampedLength)
    }

    /// The lyrics box is an I-beam everywhere; the arrow shows only over a
    /// reading the user can click (the kana drawn above an annotated kanji).
    static func pointerKind(overTappableRuby: Bool) -> PointerKind {
        overTappableRuby ? .arrow : .iBeam
    }

    /// Clickable area of one drawn reading, in text-container coordinates:
    /// the ruby band at the top of the line fragment, widened when the reading
    /// overhangs its kanji. The caller adds `textContainerOrigin`.
    static func rubyHitRect(
        baseBox: CGRect,
        rubyWidth: CGFloat,
        lineMinY: CGFloat,
        extraRubyHeight: CGFloat
    ) -> CGRect {
        let (minX, maxX) = rubyHitXRange(
            baseMinX: baseBox.minX,
            baseWidth: baseBox.width,
            rubyWidth: rubyWidth
        )
        return CGRect(
            x: minX,
            y: lineMinY,
            width: max(0, maxX - minX),
            height: max(0, extraRubyHeight)
        )
    }

    /// Drawn ruby is centered on the base box and may be wider (overhang).
    static func rubyHitXRange(baseMinX: CGFloat, baseWidth: CGFloat, rubyWidth: CGFloat) -> (minX: CGFloat, maxX: CGFloat) {
        let width = max(baseWidth, rubyWidth)
        let x = baseMinX + (baseWidth - width) / 2
        return (x, x + width)
    }

    static func editingHighlightColor(dark: Bool) -> NSColor {
        if dark {
            return NSColor(srgbRed: 0.30, green: 0.30, blue: 0.34, alpha: 1)
        }
        // Pale enough to read the kanji in light mode; darker gray was wrapping the run.
        return NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1)
    }

    /// Selection may mix kana and kanji. Keep the ideograph run and expand it
    /// to the full consecutive kanji (当然です + 然で → 当然).
    static func selectedKanjiRun(in lyrics: String, selection: NSRange) -> NSRange? {
        let ns = lyrics as NSString
        let length = ns.length
        guard length > 0 else { return nil }
        let loc = max(0, min(selection.location, length))
        var selLen = max(0, selection.length)
        if loc + selLen > length { selLen = length - loc }

        var seed: Int?
        if selLen == 0 {
            if isIdeograph(ns, at: loc) {
                seed = loc
            } else if loc > 0, isIdeograph(ns, at: loc - 1) {
                seed = loc - 1
            }
        } else {
            for index in loc..<(loc + selLen) where isIdeograph(ns, at: index) {
                seed = index
                break
            }
        }
        guard let startSeed = seed else { return nil }
        var start = startSeed
        var end = startSeed + 1
        while start > 0, isIdeograph(ns, at: start - 1) { start -= 1 }
        while end < length, isIdeograph(ns, at: end) { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    static func attributedString(
        lyrics: String,
        annotations: [LyricsRubySpan],
        font: NSFont = .systemFont(ofSize: 16),
        textColor: NSColor = .labelColor,
        editingRange: NSRange? = nil,
        darkAppearance: Bool = false
    ) -> NSAttributedString {
        let usable = annotations.filter {
            !$0.phonetic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.rangeLength > 0
        }
        let storage = NSMutableAttributedString(string: lyrics, attributes: [
            .font: font,
            .foregroundColor: textColor,
        ])
        let length = (lyrics as NSString).length
        for span in usable {
            let range = span.nsRange
            guard range.location >= 0, NSMaxRange(range) <= length else { continue }
            let phonetic = span.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
            storage.addAttribute(rubyAttributeName, value: makeRuby(phonetic), range: range)
        }
        let kerns = kernAdjustments(lyrics: lyrics, annotations: usable, font: font)
        for (index, extra) in kerns where extra > 0 && index >= 0 && index < length {
            storage.addAttribute(.kern, value: extra, range: NSRange(location: index, length: 1))
        }
        if let editingRange,
           editingRange.location >= 0,
           editingRange.length > 0,
           NSMaxRange(editingRange) <= length {
            storage.addAttribute(
                .backgroundColor,
                value: editingHighlightColor(dark: darkAppearance),
                range: editingRange
            )
        }
        return storage
    }

    static func makeRuby(_ phonetic: String) -> CTRubyAnnotation {
        let attrs: [CFString: Any] = [
            kCTRubyAnnotationSizeFactorAttributeName: rubySizeFactor,
        ]
        return CTRubyAnnotationCreateWithAttributes(
            .auto,
            .auto,
            .before,
            phonetic as CFString,
            attrs as CFDictionary
        )
    }

    static func rubyText(at index: Int, in attributed: NSAttributedString) -> String? {
        guard index >= 0, index < attributed.length else { return nil }
        return rubyText(in: attributed.attributes(at: index, effectiveRange: nil))
    }

    static func rubyText(in attributes: [NSAttributedString.Key: Any]) -> String? {
        guard let value = attributes[rubyAttributeName] else { return nil }
        let ruby = value as! CTRubyAnnotation
        let text = CTRubyAnnotationGetTextForPosition(ruby, .before) as String?
        if let text, !text.isEmpty { return text }
        return nil
    }

    static func rubySizeFactor(in attributes: [NSAttributedString.Key: Any]) -> CGFloat? {
        guard let value = attributes[rubyAttributeName] else { return nil }
        return CTRubyAnnotationGetSizeFactor(value as! CTRubyAnnotation)
    }

    static func containsRuby(_ attributed: NSAttributedString) -> Bool {
        guard attributed.length > 0 else { return false }
        var found = false
        attributed.enumerateAttribute(rubyAttributeName, in: NSRange(location: 0, length: attributed.length)) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    static func kern(at index: Int, in attributed: NSAttributedString) -> CGFloat {
        guard index >= 0, index < attributed.length else { return 0 }
        return (attributed.attribute(.kern, at: index, effectiveRange: nil) as? CGFloat) ?? 0
    }

    static func usedHeight(_ attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        var fit = CFRange(location: 0, length: 0)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            setter,
            CFRange(location: 0, length: attributed.length),
            nil,
            CGSize(width: max(width, 1), height: CGFloat.greatestFiniteMagnitude),
            &fit
        )
        return size.height
    }

    /// JLREQ 3.3.8 / simple-ruby: long ruby may overhang unannotated kana; it must not
    /// overhang neighboring ideographs. Consecutive kanji already sharing one span are
    /// group ruby. When two ruby groups would meet over intervening kana (負けず劣らず),
    /// add buffer in that kana. Empty neighboring space does not expand the base.
    static func kernAdjustments(
        lyrics: String,
        annotations: [LyricsRubySpan],
        font: NSFont
    ) -> [Int: CGFloat] {
        // 范围越界的注音直接跳过：歌词刚变、范围还没来得及重对齐的瞬间，
        // 渲染层绝不能拿过期范围去 substring（会抛 NSRangeException 卡死输入）。
        let length = (lyrics as NSString).length
        let usable = annotations
            .filter { span in
                span.rangeLength > 0
                    && !span.phonetic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && span.rangeStart >= 0
                    && span.rangeStart + span.rangeLength <= length
            }
            .sorted { $0.rangeStart < $1.rangeStart }
        guard !usable.isEmpty else { return [:] }
        let ns = lyrics as NSString
        let rubyFont = NSFont.systemFont(ofSize: max(font.pointSize * rubySizeFactor, 8))
        let rubyEm = measure("あ", font: rubyFont)
        let ranges = usable.map(\.nsRange)
        var kern: [Int: CGFloat] = [:]

        func halfOverflow(_ span: LyricsRubySpan) -> CGFloat {
            let base = measure(ns.substring(with: span.nsRange), font: font)
            let ruby = measure(span.phonetic.trimmingCharacters(in: .whitespacesAndNewlines), font: rubyFont)
            return max(0, ruby - base) / 2
        }

        func overflow(_ span: LyricsRubySpan) -> CGFloat {
            let base = measure(ns.substring(with: span.nsRange), font: font)
            let ruby = measure(span.phonetic.trimmingCharacters(in: .whitespacesAndNewlines), font: rubyFont)
            return max(0, ruby - base)
        }

        for index in 0..<usable.count {
            let current = usable[index]
            let end = NSMaxRange(current.nsRange)
            guard index + 1 < usable.count else { continue }
            let next = usable[index + 1]
            let gapStart = end
            let gapEnd = next.rangeStart
            guard gapEnd > gapStart, gapEnd <= length else { continue }
            let gap = NSRange(location: gapStart, length: gapEnd - gapStart)
            if gapHasBarrier(ns, range: gap, covered: ranges) { continue }
            let gapWidth = measure(ns.substring(with: gap), font: font)
            let meet = halfOverflow(current) + halfOverflow(next)
            if meet >= gapWidth {
                addKern(max(meet - gapWidth, 0) + rubyEm, in: gap, into: &kern)
            }
        }

        for span in usable {
            let extra = overflow(span)
            guard extra > 0 else { continue }
            let left = neighborAllowance(
                ns,
                from: span.rangeStart,
                goingLeft: true,
                covered: ranges
            )
            let right = neighborAllowance(
                ns,
                from: NSMaxRange(span.nsRange),
                goingLeft: false,
                covered: ranges
            )
            let leftover = extra - left - right
            if leftover > 0.5 {
                expandBase(span.nsRange, extra: leftover, length: length, into: &kern)
            }
        }
        return kern.filter { $0.value > 0.05 }
    }

    private static func measure(_ string: String, font: NSFont) -> CGFloat {
        guard !string.isEmpty else { return 0 }
        return (string as NSString).size(withAttributes: [.font: font]).width
    }

    private static func isIdeograph(_ ns: NSString, at index: Int) -> Bool {
        guard index >= 0, index < ns.length else { return false }
        let value = UnicodeScalar(ns.character(at: index))?.value ?? 0
        return (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value)
    }

    private static func isNewline(_ ns: NSString, at index: Int) -> Bool {
        guard index >= 0, index < ns.length else { return false }
        let c = ns.character(at: index)
        return c == 10 || c == 13
    }

    private static func isCovered(_ index: Int, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSLocationInRange(index, $0) }
    }

    private static func gapHasBarrier(_ ns: NSString, range: NSRange, covered: [NSRange]) -> Bool {
        for i in 0..<range.length {
            let index = range.location + i
            if isNewline(ns, at: index) || isIdeograph(ns, at: index) || isCovered(index, covered) {
                return true
            }
        }
        return false
    }

    /// Edge, newline, or unannotated kana/other text: unlimited — ruby may overhang
    /// into that empty band. Ideograph or another ruby base: none, so the kanji spacing grows.
    private static func neighborAllowance(
        _ ns: NSString,
        from start: Int,
        goingLeft: Bool,
        covered: [NSRange]
    ) -> CGFloat {
        let length = ns.length
        if goingLeft {
            if start <= 0 { return .greatestFiniteMagnitude }
            let index = start - 1
            if isNewline(ns, at: index) { return .greatestFiniteMagnitude }
            if isIdeograph(ns, at: index) || isCovered(index, covered) { return 0 }
            return .greatestFiniteMagnitude
        }
        if start >= length { return .greatestFiniteMagnitude }
        if isNewline(ns, at: start) { return .greatestFiniteMagnitude }
        if isIdeograph(ns, at: start) || isCovered(start, covered) { return 0 }
        return .greatestFiniteMagnitude
    }

    private static func addKern(_ amount: CGFloat, in range: NSRange, into kern: inout [Int: CGFloat]) {
        guard amount > 0, range.length > 0 else { return }
        let each = amount / CGFloat(range.length)
        for offset in 0..<range.length {
            kern[range.location + offset, default: 0] += each
        }
    }

    /// JIS X 4051 2:1:1 — 1 unit before, 2 between base characters, 1 after.
    private static func expandBase(_ range: NSRange, extra: CGFloat, length: Int, into kern: inout [Int: CGFloat]) {
        guard extra > 0, range.length > 0 else { return }
        let n = range.length
        let unit = extra / CGFloat(2 * n)
        if range.location > 0 {
            kern[range.location - 1, default: 0] += unit
        }
        if n > 1 {
            for offset in 0..<(n - 1) {
                kern[range.location + offset, default: 0] += 2 * unit
            }
        }
        let last = range.location + n - 1
        if last < length {
            kern[last, default: 0] += unit
        }
    }
}
