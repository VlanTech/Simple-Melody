// SimpleMelodyTests/SectionDragMathTests.swift
// Compiles against the shipped Engine/SectionDragMath.swift (not a reimplementation).
//
//   swiftc -o section-drag-tests \
//     SimpleMelody/Engine/SectionDragMath.swift \
//     SimpleMelodyTests/SectionDragMathTests.swift
//   ./section-drag-tests

import Foundation
import CoreGraphics
import AppKit
import CoreText

@main
enum SectionDragMathTests {
    static func main() {
        var failed = 0
        var passed = 0

        func expect(_ condition: Bool, _ message: String) {
            if condition {
                passed += 1
                print("PASS  \(message)")
            } else {
                failed += 1
                print("FAIL  \(message)")
            }
        }

        func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
            expect(actual == expected, "\(message)  actual=\(actual) expected=\(expected)")
        }

        // Shared IDs for reorder cases
        let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let c = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!
        let d = UUID(uuidString: "00000000-0000-0000-0000-00000000000D")!
        let e = UUID(uuidString: "00000000-0000-0000-0000-00000000000E")!
        let ordered = [a, b, c, d, e]
        let mid: CGFloat = 40

        // MARK: insert before / after (the v1.7.10 Extra contract)

        expect(SectionDragMath.insertsBefore(dropY: 10, targetMidY: mid), "drop above midpoint inserts before")
        expect(!SectionDragMath.insertsBefore(dropY: 50, targetMidY: mid), "drop below midpoint inserts after")
        expect(!SectionDragMath.insertsBefore(dropY: mid, targetMidY: mid), "drop on midpoint inserts after")

        expectEqual(
            SectionDragMath.insertIndex(targetIndex: 1, dropY: 10, targetMidY: mid, filteredCount: 4),
            1,
            "above midpoint → insert at targetIndex (before)"
        )
        expectEqual(
            SectionDragMath.insertIndex(targetIndex: 1, dropY: 50, targetMidY: mid, filteredCount: 4),
            2,
            "below midpoint → insert at targetIndex+1 (after)"
        )
        expectEqual(
            SectionDragMath.insertIndex(targetIndex: 0, dropY: 0, targetMidY: mid, filteredCount: 4),
            0,
            "before first section → index 0"
        )
        expectEqual(
            SectionDragMath.insertIndex(targetIndex: 3, dropY: 80, targetMidY: mid, filteredCount: 4),
            4,
            "after last filtered section → count"
        )
        expect(
            SectionDragMath.insertIndex(targetIndex: -1, dropY: 10, targetMidY: mid, filteredCount: 4) == nil,
            "negative targetIndex is nil"
        )
        expect(
            SectionDragMath.insertIndex(targetIndex: 4, dropY: 10, targetMidY: mid, filteredCount: 4) == nil,
            "targetIndex == count is nil"
        )

        // MARK: reorderedIDs — above midpoint → before (old code always used targetIndex+1)

        expectEqual(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [c], targetID: b,
                dropY: 10, targetMidY: mid
            ),
            [a, c, b, d, e],
            "drag C onto B above midpoint → A C B D E"
        )
        expectEqual(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [c], targetID: b,
                dropY: 50, targetMidY: mid
            ),
            [a, b, c, d, e],
            "drag C onto B below midpoint → A B C D E"
        )
        expectEqual(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [c], targetID: d,
                dropY: 10, targetMidY: mid
            ),
            [a, b, c, d, e],
            "drag C onto D above midpoint → stays A B C D E"
        )
        expectEqual(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [c], targetID: d,
                dropY: 50, targetMidY: mid
            ),
            [a, b, d, c, e],
            "drag C onto D below midpoint → A B D C E"
        )
        expectEqual(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [a], targetID: e,
                dropY: 50, targetMidY: mid
            ),
            [b, c, d, e, a],
            "drag A onto E below midpoint → B C D E A"
        )
        expectEqual(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [e], targetID: a,
                dropY: 5, targetMidY: mid
            ),
            [e, a, b, c, d],
            "drag E onto A above midpoint → E A B C D"
        )

        // MARK: empty / self-drop no-ops

        expect(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [], targetID: b,
                dropY: 10, targetMidY: mid
            ) == nil,
            "empty draggedIDs is a no-op"
        )
        expect(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [b], targetID: b,
                dropY: 10, targetMidY: mid
            ) == nil,
            "self-drop is a no-op"
        )
        expect(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [b, b], targetID: b,
                dropY: 50, targetMidY: mid
            ) == nil,
            "self-drop with duplicate target id is a no-op"
        )
        let missing = UUID(uuidString: "00000000-0000-0000-0000-0000000000FF")!
        expect(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [c], targetID: missing,
                dropY: 10, targetMidY: mid
            ) == nil,
            "missing target is a no-op"
        )

        // Multi-drag preserves original relative order
        expectEqual(
            SectionDragMath.reorderedIDs(
                orderedIDs: ordered, draggedIDs: [a, c], targetID: d,
                dropY: 50, targetMidY: mid
            ),
            [b, d, a, c, e],
            "multi-drag A+C onto D after → B D A C E"
        )

        // MARK: auto-scroll edge (window coords, origin bottom-left)

        let scroll = CGRect(x: 100, y: 200, width: 300, height: 400) // maxY = 600
        expect(
            SectionDragMath.isInTopAutoScrollEdge(
                mouseInWindow: CGPoint(x: 250, y: 590),
                scrollViewInWindow: scroll,
                threshold: 50
            ),
            "mouse 10pt from top, inside x → auto-scroll"
        )
        expect(
            SectionDragMath.isInTopAutoScrollEdge(
                mouseInWindow: CGPoint(x: 250, y: 600),
                scrollViewInWindow: scroll,
                threshold: 50
            ),
            "mouse exactly on top edge → auto-scroll"
        )
        expect(
            !SectionDragMath.isInTopAutoScrollEdge(
                mouseInWindow: CGPoint(x: 250, y: 550),
                scrollViewInWindow: scroll,
                threshold: 50
            ),
            "mouse 50pt from top is outside the half-open threshold"
        )
        expect(
            !SectionDragMath.isInTopAutoScrollEdge(
                mouseInWindow: CGPoint(x: 250, y: 300),
                scrollViewInWindow: scroll,
                threshold: 50
            ),
            "mouse in the middle of the scroll view → no auto-scroll"
        )
        expect(
            !SectionDragMath.isInTopAutoScrollEdge(
                mouseInWindow: CGPoint(x: 50, y: 590),
                scrollViewInWindow: scroll,
                threshold: 50
            ),
            "mouse left of scroll view → no auto-scroll"
        )
        expect(
            !SectionDragMath.isInTopAutoScrollEdge(
                mouseInWindow: CGPoint(x: 250, y: 150),
                scrollViewInWindow: scroll,
                threshold: 50
            ),
            "mouse below scroll view → no auto-scroll"
        )
        expect(
            !SectionDragMath.isInTopAutoScrollEdge(
                mouseInWindow: CGPoint(x: 250, y: 590),
                scrollViewInWindow: .zero,
                threshold: 50
            ),
            "zero scroll frame → no auto-scroll"
        )

        expectEqual(
            SectionDragMath.nextScrollOriginY(
                currentY: 80, isFlipped: true, delta: 32,
                documentHeight: 1000, clipHeight: 400
            ),
            48,
            "flipped clip view scrolls up by decreasing y"
        )
        expectEqual(
            SectionDragMath.nextScrollOriginY(
                currentY: 10, isFlipped: true, delta: 32,
                documentHeight: 1000, clipHeight: 400
            ),
            0,
            "flipped clip view clamps at 0"
        )
        expectEqual(
            SectionDragMath.nextScrollOriginY(
                currentY: 100, isFlipped: false, delta: 32,
                documentHeight: 1000, clipHeight: 400
            ),
            132,
            "unflipped clip view scrolls up by increasing y"
        )
        expectEqual(
            SectionDragMath.nextScrollOriginY(
                currentY: 580, isFlipped: false, delta: 32,
                documentHeight: 1000, clipHeight: 400
            ),
            600,
            "unflipped clip view clamps at documentHeight-clipHeight"
        )

        expectEqual(SectionDragMath.previousSectionIndex(currentIndex: 3), 2, "previous index from 3")
        expect(SectionDragMath.previousSectionIndex(currentIndex: 0) == nil, "previous index at 0 is nil")
        expect(SectionDragMath.previousSectionIndex(currentIndex: -1) == nil, "previous index negative is nil")

        // MARK: auto-scroll command table (scroll on the dragged event, not timer-only)

        expectEqual(
            SectionDragMath.commandForDragEvent(kind: .leftMouseDragged, inTopEdge: true),
            .scrollNowAndEnsureTimer,
            "dragged in top edge → scroll immediately and keep timer"
        )
        expectEqual(
            SectionDragMath.commandForDragEvent(kind: .leftMouseDragged, inTopEdge: false),
            .stopTimer,
            "dragged outside top edge → stop timer"
        )
        expectEqual(
            SectionDragMath.commandForDragEvent(kind: .leftMouseUp, inTopEdge: true),
            .stopTimer,
            "mouse up stops auto-scroll even if still in the top edge"
        )
        expectEqual(
            SectionDragMath.commandForDragEvent(kind: .leftMouseUp, inTopEdge: false),
            .stopTimer,
            "mouse up stops auto-scroll"
        )
        expectEqual(
            SectionDragMath.commandForDragEvent(kind: .other, inTopEdge: true),
            .ignore,
            "non-drag events are ignored"
        )

        let modes = SectionDragMath.autoScrollTimerRunLoopModes
        expect(modes.contains(.common), "auto-scroll timer is added for RunLoop.common")
        expect(
            modes.contains(SectionDragMath.eventTrackingRunLoopMode),
            "auto-scroll timer is added for NSEventTrackingRunLoopMode"
        )
        expectEqual(
            SectionDragMath.eventTrackingRunLoopMode.rawValue,
            "NSEventTrackingRunLoopMode",
            "event-tracking mode is the AppKit dragging run-loop mode"
        )

        // Drive the shipped scheduler: a default-mode-only Timer.scheduledTimer would
        // NOT fire here. This must use scheduleAutoScrollTimer.
        var trackingFires = 0
        let trackingTimer = SectionDragMath.scheduleAutoScrollTimer(
            interval: 0.02,
            on: .current
        ) {
            trackingFires += 1
        }
        let trackingMode = CFRunLoopMode(SectionDragMath.eventTrackingRunLoopMode.rawValue as CFString)
        let trackingDeadline = CFAbsoluteTimeGetCurrent() + 0.8
        while trackingFires == 0 && CFAbsoluteTimeGetCurrent() < trackingDeadline {
            _ = CFRunLoopRunInMode(trackingMode, 0.05, true)
        }
        trackingTimer.invalidate()
        expect(trackingFires >= 1, "shipped auto-scroll timer fires in NSEventTrackingRunLoopMode (fires=\(trackingFires))")

        // `.common` is a mode *set*; run in `.default` to prove common-registration works.
        var defaultFires = 0
        let defaultTimer = SectionDragMath.scheduleAutoScrollTimer(
            interval: 0.02,
            on: .current
        ) {
            defaultFires += 1
        }
        let defaultMode = CFRunLoopMode(RunLoop.Mode.default.rawValue as CFString)
        let defaultDeadline = CFAbsoluteTimeGetCurrent() + 0.8
        while defaultFires == 0 && CFAbsoluteTimeGetCurrent() < defaultDeadline {
            _ = CFRunLoopRunInMode(defaultMode, 0.05, true)
        }
        defaultTimer.invalidate()
        expect(defaultFires >= 1, "shipped auto-scroll timer (added to .common) fires in default mode (fires=\(defaultFires))")

        // MARK: lyrics drop rejection

        let uuid = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        expect(SectionDragMath.isSectionIDPayload(uuid), "UUID string is a section-id payload")
        expect(SectionDragMath.isSectionIDPayload("  \(uuid)  "), "padded UUID string is a section-id payload")
        expect(!SectionDragMath.isSectionIDPayload("verse lyrics"), "plain lyrics are not a section-id")
        expect(!SectionDragMath.isSectionIDPayload(""), "empty string is not a section-id")
        expect(!SectionDragMath.shouldAcceptLyricsStringDrop(uuid), "lyrics editor rejects UUID string drop")
        expect(SectionDragMath.shouldAcceptLyricsStringDrop("hello"), "lyrics editor accepts real text drop")
        expect(
            SectionDragMath.shouldRejectLyricsDrop(
                pasteboardStrings: [uuid],
                pasteboardTypeIDs: ["public.utf8-plain-text"]
            ),
            "reject when pasteboard string is a section UUID"
        )
        expect(
            SectionDragMath.shouldRejectLyricsDrop(
                pasteboardStrings: ["hello"],
                pasteboardTypeIDs: [SectionDragMath.sectionIDTypeIdentifier]
            ),
            "reject custom section-id UTType even if a string is also present"
        )
        expect(
            !SectionDragMath.shouldRejectLyricsDrop(
                pasteboardStrings: ["hello chorus"],
                pasteboardTypeIDs: ["public.utf8-plain-text"]
            ),
            "accept ordinary text drops"
        )
        expectEqual(
            SectionDragMath.sectionIDTypeIdentifier,
            "com.simplemelody.section-id",
            "shipped UTType identifier is the dedicated section-id type"
        )

        // MARK: exclusive 译文 / 笔记 panel

        expectEqual(
            SectionSidePanel.toggling(.none, targeting: .translation),
            .translation,
            "closed → 译文 opens"
        )
        expectEqual(
            SectionSidePanel.toggling(.translation, targeting: .translation),
            .none,
            "open 译文 tapped again → collapse"
        )
        expectEqual(
            SectionSidePanel.toggling(.notes, targeting: .translation),
            .translation,
            "笔记 → 译文 switches (cannot both be open)"
        )
        expectEqual(
            SectionSidePanel.toggling(.translation, targeting: .notes),
            .notes,
            "译文 → 笔记 switches"
        )
        expectEqual(
            SectionSidePanel.toggling(.notes, targeting: .notes),
            .none,
            "open 笔记 tapped again → collapse"
        )

        // MARK: shipped export/import codec (notes + translation)

        expect(
            SectionLyricCodec.indentedBlock(label: "Translation", content: "").isEmpty,
            "empty translation omitted from export"
        )
        expect(
            SectionLyricCodec.indentedBlock(label: "Translation", content: "  \n").isEmpty,
            "whitespace-only translation omitted from export"
        )

        let notesOnly = SectionLyricCodec.encode(
            marker: "[Verse]",
            body: "sung line",
            translation: "",
            notes: "a note",
            notesLabel: "段落笔记"
        )
        let notesOnlyText = notesOnly.joined(separator: "\n")
        expect(!notesOnlyText.contains("Translation"), "notes-only encode has no Translation block")
        expect(notesOnlyText.contains("段落笔记"), "notes-only encode has notes block")
        let notesOnlyParsed = SectionLyricCodec.parseLyrics(notesOnly)
        expectEqual(notesOnlyParsed.count, 1, "notes-only parse count")
        expectEqual(notesOnlyParsed.first?.body ?? "", "sung line", "notes-only body")
        expectEqual(notesOnlyParsed.first?.notes ?? "", "a note", "notes-only notes")
        expectEqual(notesOnlyParsed.first?.translation ?? "", "", "notes-only translation empty")

        let transOnly = SectionLyricCodec.encode(
            marker: "[Chorus]",
            body: "we walk",
            translation: "我们走",
            notes: "",
            notesLabel: "段落笔记"
        )
        let transOnlyText = transOnly.joined(separator: "\n")
        expect(transOnlyText.contains("  Translation:"), "translation-only encode has Translation block")
        expect(!transOnlyText.contains("段落笔记"), "translation-only encode omits empty notes")
        let transOnlyParsed = SectionLyricCodec.parseLyrics(transOnly)
        expectEqual(transOnlyParsed.first?.body ?? "", "we walk", "translation-only body")
        expectEqual(transOnlyParsed.first?.translation ?? "", "我们走", "translation-only translation")
        expectEqual(transOnlyParsed.first?.notes ?? "", "", "translation-only notes empty")

        let both = SectionLyricCodec.encode(
            marker: "[Bridge]",
            body: "line A\nline B",
            translation: "行甲\n行乙",
            notes: "mood: warm",
            notesLabel: "段落笔记"
        )
        let bothParsed = SectionLyricCodec.parseLyrics(both)
        expectEqual(bothParsed.first?.marker ?? "", "[Bridge]", "both marker")
        expectEqual(bothParsed.first?.body ?? "", "line A\nline B", "both body")
        expectEqual(bothParsed.first?.translation ?? "", "行甲\n行乙", "both translation")
        expectEqual(bothParsed.first?.notes ?? "", "mood: warm", "both notes")

        let mixedLines = """
        [Verse]
        hello chorus
          Translation:
            你好副歌
          段落笔记:
            keep this as notes
        """.components(separatedBy: "\n")
        let mixed = SectionLyricCodec.parseLyrics(mixedLines)
        expectEqual(mixed.first?.body ?? "", "hello chorus", "import does not put translation into body")
        expectEqual(mixed.first?.translation ?? "", "你好副歌", "import translation")
        expectEqual(mixed.first?.notes ?? "", "keep this as notes", "import notes")
        expect(!(mixed.first?.body ?? "").contains("你好"), "body must not contain translation text")
        expect(!(mixed.first?.body ?? "").contains("keep this"), "body must not contain notes text")

        let zhMarker = SectionLyricCodec.parseLyrics("""
        [Outro]
        fade
          译文:
            渐弱
        """.components(separatedBy: "\n"))
        expectEqual(zhMarker.first?.translation ?? "", "渐弱", "译文: alias is a translation marker")
        expectEqual(zhMarker.first?.body ?? "", "fade", "译文: not mixed into body")

        let enNotes = SectionLyricCodec.parseLyrics("""
        [Intro]
        hum
          Notes:
            piano
        """.components(separatedBy: "\n"))
        expectEqual(enNotes.first?.notes ?? "", "piano", "Notes: alias is a notes marker")
        expectEqual(enNotes.first?.body ?? "", "hum", "Notes: not mixed into body")

        expectEqual(SectionLyricCodec.rubyExportLabel, "Ruby", "ruby export label is Ruby")
        let rubyPairsText = SectionLyricCodec.rubyExportText([("東京", "とうきょう"), ("負", "ま")])
        expectEqual(rubyPairsText, "東京｜とうきょう\n負｜ま", "ruby export text is 汉字｜读音 lines")
        expect(SectionLyricCodec.rubyExportText([("  ", "あ")]).isEmpty, "empty original is omitted from ruby export")
        let encodedRuby = SectionLyricCodec.encode(
            marker: "[Verse]",
            body: "東京は負けず劣らず",
            translation: "东京也不服输",
            notes: "gikun ok",
            notesLabel: "段落笔记",
            ruby: "東京｜とうきょう\n負｜ま\n劣｜おと"
        )
        let encodedRubyText = encodedRuby.joined(separator: "\n")
        expect(encodedRubyText.contains("  Ruby:"), "encode writes a Ruby block")
        expect(encodedRubyText.contains("    東京｜とうきょう"), "encode writes 汉字｜读音 under Ruby")
        expect(encodedRubyText.contains("  Translation:"), "ruby file still has Translation")
        let parsedRuby = SectionLyricCodec.parseLyrics(encodedRuby)
        expectEqual(parsedRuby.first?.body ?? "", "東京は負けず劣らず", "ruby block is not mixed into lyrics")
        expectEqual(parsedRuby.first?.ruby ?? "", "東京｜とうきょう\n負｜ま\n劣｜おと", "parse keeps the ruby field")
        expectEqual(parsedRuby.first?.translation ?? "", "东京也不服输", "ruby file keeps translation")
        expectEqual(parsedRuby.first?.notes ?? "", "gikun ok", "ruby file keeps notes")
        expect(!(parsedRuby.first?.body ?? "").contains("とうきょう"), "body must not contain readings")
        let zhRuby = SectionLyricCodec.parseLyrics("""
        [Chorus]
        東京
          注音:
            東京｜とうきょう
        """.components(separatedBy: "\n"))
        expectEqual(zhRuby.first?.ruby ?? "", "東京｜とうきょう", "注音: alias is a ruby marker")
        expectEqual(zhRuby.first?.body ?? "", "東京", "注音: not mixed into body")
        let furiAlias = SectionLyricCodec.parseLyrics("""
        [Verse]
        人
          Furigana:
            人|ひと
        """.components(separatedBy: "\n"))
        expectEqual(furiAlias.first?.ruby ?? "", "人|ひと", "Furigana: alias is a ruby marker")
        let oldFile = SectionLyricCodec.parseLyrics("""
        [Verse]
        hello chorus
          Translation:
            你好副歌
          段落笔记:
            keep this as notes
        """.components(separatedBy: "\n"))
        expectEqual(oldFile.first?.ruby ?? "", "", "old files without Ruby still import")
        expectEqual(oldFile.first?.body ?? "", "hello chorus", "old files keep lyrics")
        let lyricsOnly = SectionLyricCodec.encode(
            marker: "[Verse]",
            body: "sung line",
            translation: "译文",
            notes: "a note",
            notesLabel: "段落笔记",
            ruby: "字｜よ",
            options: SongExportOptions(lyrics: true, translation: false, ruby: false, notes: false, ideas: false)
        ).joined(separator: "\n")
        expect(lyricsOnly.contains("sung line"), "lyrics-only export keeps the body")
        expect(!lyricsOnly.contains("Translation"), "lyrics-only export omits translation")
        expect(!lyricsOnly.contains("Ruby"), "lyrics-only export omits ruby")
        expect(!lyricsOnly.contains("段落笔记"), "lyrics-only export omits notes")
        let rubyOnly = SongExportOptions(lyrics: false, translation: false, ruby: true, notes: false, ideas: false)
        expect(rubyOnly.writesLyricBody, "exporting ruby also writes the lyric body so it can import")
        expect(rubyOnly.includesLyricsSection, "ruby-only still writes the Lyrics section")
        let none = SongExportOptions(lyrics: false, translation: false, ruby: false, notes: false, ideas: false)
        expect(!none.includesAnything, "no boxes checked is empty")
        expect(SongExportOptions.all.includesAnything, "default export includes everything")
        let placedFromFile = ImagineWorkflow.placeRuby(
            lyrics: "東京は負けず劣らず",
            pairs: ImagineWorkflow.rubyPairs(from: parsedRuby.first?.ruby ?? "")
        )
        expectEqual(placedFromFile.count, 3, "file ruby places onto the lyrics")
        expectEqual(placedFromFile[0].phonetic, "とうきょう", "file ruby 東京 reading round-trips")
        let selectedTranslation = SectionLyricCodec.encode(
            marker: "[Verse]",
            body: "sung line",
            translation: "东京也不服输",
            notes: "a note",
            notesLabel: "段落笔记",
            ruby: "字｜よ",
            options: SongExportOptions(lyrics: false, translation: true, ruby: false, notes: false, ideas: false)
        ).joined(separator: "\n")
        expect(!selectedTranslation.contains("sung line"), "checked-translation export omits the lyric body")
        expect(selectedTranslation.contains("Translation"), "checked-translation export keeps translation")
        expect(!selectedTranslation.contains("Ruby"), "checked-translation export omits ruby")
        let selectedTranslationParsed = SectionLyricCodec.parseLyrics(selectedTranslation.components(separatedBy: "\n"))
        expectEqual(selectedTranslationParsed.first?.body ?? "", "", "checked-translation import has empty lyrics")
        expectEqual(selectedTranslationParsed.first?.translation ?? "", "东京也不服输", "checked-translation import keeps translation")
        let selectedNotes = SectionLyricCodec.encode(
            marker: "[Chorus]",
            body: "sung line",
            translation: "译文",
            notes: "keep this as notes",
            notesLabel: "段落笔记",
            ruby: "字｜よ",
            options: SongExportOptions(lyrics: false, translation: false, ruby: false, notes: true, ideas: false)
        )
        let selectedNotesParsed = SectionLyricCodec.parseLyrics(selectedNotes)
        expectEqual(selectedNotesParsed.first?.notes ?? "", "keep this as notes", "checked-notes export round-trips notes")
        expectEqual(selectedNotesParsed.first?.body ?? "", "", "checked-notes export omits the lyric body")
        expectEqual(selectedNotesParsed.first?.ruby ?? "", "", "checked-notes export omits ruby")

        // MARK: v1.8.0 version compare + GitHub payload (injected)

        expectEqual(AppReleaseMath.displayVersion, "v1.8.3", "display version is v1.8.3")
        expectEqual(AppReleaseMath.marketingVersion, "1.8.3", "marketing version is 1.8.3")
        expectEqual(AppReleaseMath.compare(local: "v1.8.0", remote: "v1.7.10"), 1, "1.8.0 is newer than GitHub 1.7.10")
        expectEqual(AppReleaseMath.compare(local: "v1.7.9", remote: "v1.7.10"), -1, "1.7.9 is older than 1.7.10")
        expectEqual(AppReleaseMath.compare(local: "v1.7.10 Extra", remote: "v1.7.10"), 0, "letter suffix does not change numeric compare")
        expectEqual(
            AppReleaseMath.decision(local: "v1.8.0", remoteTag: "v1.7.10"),
            .upToDate,
            "launch with local 1.8.0 vs GitHub 1.7.10 → no popup"
        )
        expectEqual(
            AppReleaseMath.decision(local: "v1.7.9", remoteTag: "v1.7.10"),
            .updateAvailable,
            "older local vs newer remote → update dialog"
        )
        expectEqual(
            AppReleaseMath.decision(local: "v1.7.10 Extra", remoteTag: "v1.7.10"),
            .upToDate,
            "equal numeric tags → no popup"
        )
        expectEqual(
            AppReleaseMath.decision(local: "v1.8.0", remoteTag: nil),
            .invalid,
            "missing remote tag → invalid (silent on launch)"
        )
        let ghJSON = """
        {"tag_name":"v1.7.10","body":"## Notes\\n- item","html_url":"https://github.com/VlanTech/Simple-Melody/releases/tag/v1.7.10"}
        """.data(using: .utf8)!
        let parsed = AppReleaseMath.parseGitHubRelease(jsonData: ghJSON)
        expectEqual(parsed?.tagName ?? "", "v1.7.10", "parse GitHub tag_name")
        expect((parsed?.body ?? "").contains("Notes"), "parse GitHub body")
        expectEqual(
            parsed?.htmlURL ?? "",
            "https://github.com/VlanTech/Simple-Melody/releases/tag/v1.7.10",
            "parse GitHub html_url"
        )
        expect(AppReleaseMath.parseGitHubRelease(jsonData: Data("{}".utf8)) == nil, "JSON without tag_name is nil")
        let req = AppReleaseMath.makeLatestRequest()
        expect(req.url?.absoluteString == AppReleaseMath.githubLatestURL, "request hits releases/latest")
        expect(req.value(forHTTPHeaderField: "User-Agent")?.contains("SimpleMelody") == true, "GitHub User-Agent set")

        // MARK: changelog letter-suffix fold

        expectEqual(ChangelogFold.numericStem("v1.7.10 Extra"), "v1.7.10", "Extra folds to numeric stem")
        expectEqual(ChangelogFold.numericStem("v1.7.9 GT5"), "v1.7.9", "GT5 folds to numeric stem")
        expectEqual(ChangelogFold.numericStem("v1.7.9 BugStable"), "v1.7.9", "BugStable folds to numeric stem")
        expectEqual(ChangelogFold.numericStem("v1.7.9 Test"), "v1.7.9", "Test folds to numeric stem")
        expectEqual(ChangelogFold.numericStem("v1.7 Beta"), "v1.7", "Beta after minor folds to v1.7")
        expectEqual(ChangelogFold.numericStem("v1.7.1"), "v1.7.1", "plain numeric stays")
        expectEqual(ChangelogFold.numericStem("v1.8.0"), "v1.8.0", "v1.8.0 stem unchanged")

        let folded = ChangelogFold.fold([
            ChangelogRow(version: "v1.8.0", date: "2026-09-19", isLatest: true, bodyMarkdown: "eight", bodyMarkdownZHT: "八", bodyMarkdownEN: "eight-en", bodyMarkdownJA: "八日"),
            ChangelogRow(version: "v1.7.10 Extra", date: "2026-09-17", isLatest: false, bodyMarkdown: "extra-body", bodyMarkdownZHT: "e-zht", bodyMarkdownEN: "e-en", bodyMarkdownJA: "e-ja"),
            ChangelogRow(version: "v1.7.10", date: "2026-06-26", isLatest: false, bodyMarkdown: "minecraft", bodyMarkdownZHT: "m-zht", bodyMarkdownEN: "m-en", bodyMarkdownJA: "m-ja"),
            ChangelogRow(version: "v1.7.9 GT5", date: "2026-06-25", isLatest: false, bodyMarkdown: "gt5", bodyMarkdownZHT: "", bodyMarkdownEN: "", bodyMarkdownJA: ""),
            ChangelogRow(version: "v1.7.9 Test", date: "2026-06-24", isLatest: false, bodyMarkdown: "test", bodyMarkdownZHT: "", bodyMarkdownEN: "", bodyMarkdownJA: ""),
            ChangelogRow(version: "v1.7 Beta", date: "2026-01-01", isLatest: false, bodyMarkdown: "beta", bodyMarkdownZHT: "", bodyMarkdownEN: "", bodyMarkdownJA: ""),
        ])
        expectEqual(folded.map(\.version), ["v1.8.0", "v1.7.10", "v1.7.9", "v1.7"], "stems only, letter tags gone")
        expect(folded[0].isLatest, "v1.8.0 remains the only latest")
        expect(!folded.dropFirst().contains(where: \.isLatest), "folded older stems are not latest")
        expect(!(folded.map(\.version).joined()).contains("Extra"), "no Extra heading")
        expect(!(folded.map(\.version).joined()).contains("GT"), "no GT heading")
        expect(!(folded.map(\.version).joined()).contains("Beta"), "no Beta heading")
        expectEqual(folded.first { $0.version == "v1.7.10" }?.date ?? "", "2026-06-26", "folded v1.7.10 keeps the numeric stem date")
        expect((folded.first { $0.version == "v1.7.10" }?.bodyMarkdown ?? "").contains("extra-body"), "1.7.10 keeps Extra body")
        expect((folded.first { $0.version == "v1.7.10" }?.bodyMarkdown ?? "").contains("minecraft"), "1.7.10 keeps memorial body")
        expect((folded.first { $0.version == "v1.7.9" }?.bodyMarkdown ?? "").contains("gt5"), "1.7.9 concatenates GT5")
        expect((folded.first { $0.version == "v1.7.9" }?.bodyMarkdown ?? "").contains("test"), "1.7.9 concatenates Test")

        // MARK: preview caption + delete 译文 count

        expectEqual(
            LyricsPreviewCaption.text(notes: "a note", translation: "trans", source: .notes),
            "a note",
            "caption source notes → notes"
        )
        expect(
            LyricsPreviewCaption.text(notes: "  ", translation: "trans", source: .notes) == nil,
            "empty chosen notes stays hidden even if translation exists"
        )
        expectEqual(
            LyricsPreviewCaption.text(notes: "a note", translation: "trans", source: .translation),
            "trans",
            "caption source translation → translation"
        )
        expect(
            LyricsPreviewCaption.text(notes: "a note", translation: "", source: .translation) == nil,
            "empty chosen translation stays hidden"
        )
        let paired = LyricsPreviewCaption.translationRows(
            body: "line1\nline2\nline3",
            translation: "t1\nt2\nt3"
        )
        expectEqual(paired.map(\.lyric), ["line1", "line2", "line3"], "translation rows keep lyric lines")
        expectEqual(paired.map(\.translation), ["t1", "t2", "t3"], "each lyric line has the translation line below it")
        let gapped = LyricsPreviewCaption.translationRows(body: "a\nb\nc", translation: "A\n\nC")
        expectEqual(gapped.map(\.translation), ["A", nil, "C"], "a blank translation line does not shift later lines")
        let extra = LyricsPreviewCaption.translationRows(body: "a\nb", translation: "A\nB\nC")
        expectEqual(extra.map(\.lyric), ["a", "b", ""], "extra translation lines are kept")
        expectEqual(extra.map(\.translation), ["A", "B", "C"], "extra translation stays on its own row")
        expect(
            LyricsPreviewCaption.translationRows(body: "  ", translation: " \n ").isEmpty,
            "blank lyrics and blank translation produce no rows"
        )
        expectEqual(
            SongDeleteSummary.translationCount(["hello", "", "  ", "world"]),
            2,
            "non-empty translations counted"
        )
        let trashLine = SongDeleteSummary.formatCountsLine(
            sectionCount: 3,
            ideaCount: 2,
            translationCount: 1,
            includeLabel: "包含",
            sectionsLabel: "个段落",
            ideasLabel: "条灵感与设定",
            translationsLabel: "条译文"
        )
        expect(trashLine.contains("3"), "delete line has section count")
        expect(trashLine.contains("2"), "delete line has idea count")
        expect(trashLine.contains("1"), "delete line has translation count")
        expect(trashLine.contains("条译文"), "delete line includes 译文 label")

        // MARK: Command whole-song notes / translation / collapse
        let batchStates: [SectionPanelState] = [
            SectionPanelState(panel: .none, collapsed: false),
            SectionPanelState(panel: .notes, collapsed: false),
            SectionPanelState(panel: .translation, collapsed: true),
            SectionPanelState(panel: .none, collapsed: true),
        ]
        let openNotes = SectionBatchAction.apply(states: batchStates, clickedIndex: 0, control: .notes, commandHeld: true)
        expectEqual(openNotes.map(\.panel), [SectionSidePanel.notes, .notes, .notes, .notes], "Command+笔记 on a closed section opens notes everywhere")
        expectEqual(openNotes[1], batchStates[1], "section already on notes is unchanged")
        expectEqual(openNotes[2].collapsed, true, "opening notes does not touch collapse")
        let closeNotes = SectionBatchAction.apply(states: openNotes, clickedIndex: 1, control: .notes, commandHeld: true)
        let closedPanels: [SectionSidePanel] = [.none, .none, .none, .none]
        expectEqual(closeNotes.map(\.panel), closedPanels, "Command+笔记 on an open section closes notes everywhere")
        let withTranslation = [
            SectionPanelState(panel: .notes, collapsed: false),
            SectionPanelState(panel: .translation, collapsed: false),
            SectionPanelState(panel: .none, collapsed: false),
        ]
        let closed = SectionBatchAction.apply(states: withTranslation, clickedIndex: 0, control: .notes, commandHeld: true)
        expectEqual(closed[1].panel, .translation, "sections showing 译文 stay when notes are closed")
        expectEqual(closed[2].panel, .none, "already-closed notes stay closed")
        expectEqual(closed[0].panel, .none, "open notes become closed")
        let openTrans = SectionBatchAction.apply(states: batchStates, clickedIndex: 0, control: .translation, commandHeld: true)
        let openedTranslation: [SectionSidePanel] = [.translation, .translation, .translation, .translation]
        expectEqual(openTrans.map(\.panel), openedTranslation, "Command+译文 opens translation everywhere")
        expectEqual(openTrans[2], batchStates[2], "section already on translation is unchanged")
        let closeTrans = SectionBatchAction.apply(states: openTrans, clickedIndex: 2, control: .translation, commandHeld: true)
        expect(closeTrans.allSatisfy { $0.panel != .translation }, "Command+译文 on an open section closes translation")
        expectEqual(closeTrans[1].panel, .none, "notes section changes to none only because it was not already closed-without-translation wait")
        // closing translation: notes sections are not translation, so they stay notes
        let notesAndTrans = [
            SectionPanelState(panel: .translation, collapsed: false),
            SectionPanelState(panel: .notes, collapsed: false),
        ]
        let transClosed = SectionBatchAction.apply(states: notesAndTrans, clickedIndex: 0, control: .translation, commandHeld: true)
        expectEqual(transClosed[0].panel, .none, "clicked translation closes")
        expectEqual(transClosed[1].panel, .notes, "notes section unchanged when closing translation")
        let folds = SectionBatchAction.apply(states: batchStates, clickedIndex: 0, control: .collapse, commandHeld: true)
        let allCollapsed = [true, true, true, true]
        expectEqual(folds.map(\.collapsed), allCollapsed, "Command+折叠 on an expanded section collapses all")
        expectEqual(folds[2], SectionPanelState(panel: .translation, collapsed: true), "already collapsed section keeps its panel")
        expectEqual(folds[3], batchStates[3], "already collapsed section is unchanged")
        let unfolds = SectionBatchAction.apply(states: folds, clickedIndex: 2, control: .collapse, commandHeld: true)
        let allExpanded = [false, false, false, false]
        expectEqual(unfolds.map(\.collapsed), allExpanded, "Command+折叠 on a collapsed section expands all")
        let single = SectionBatchAction.apply(states: batchStates, clickedIndex: 0, control: .notes, commandHeld: false)
        expectEqual(single[0].panel, .notes, "plain click opens only the clicked section")
        expectEqual(single[1], batchStates[1], "plain click leaves other sections")
        expectEqual(single[2], batchStates[2], "plain click leaves other sections 2")
        expectEqual(single[3], batchStates[3], "plain click leaves other sections 3")
        let exclusivity = SectionBatchAction.apply(
            states: [SectionPanelState(panel: .notes, collapsed: false)],
            clickedIndex: 0,
            control: .translation,
            commandHeld: false
        )
        expectEqual(exclusivity[0].panel, .translation, "opening translation on one section clears notes")

        // MARK: changelog display is not Markdown
        let rendered = ChangelogDisplayText.fromMarkdown("""
        ## 新增
        - first **bold** item
        ## 修复
        - uses `code` and more
        """)
        expect(rendered.contains("【新增】"), "heading ## becomes 【】")
        expect(!rendered.contains("## "), "no leftover markdown heading")
        expect(rendered.contains("• first bold item"), "list dash becomes bullet; ** stripped")
        expect(!rendered.contains("- first"), "markdown dash list is not shown raw")
        expect(rendered.contains("• uses code and more"), "backticks stripped")
        expect(!rendered.contains("`code`"), "inline code fences not shown")
        let alreadyPlain = ChangelogDisplayText.fromMarkdown("【新增】\n• already converted")
        expect(alreadyPlain.contains("【新增】"), "plain 【】 passthrough")
        expect(alreadyPlain.contains("• already converted"), "plain bullet passthrough")

        // MARK: UI languages
        expectEqual(AppLanguage.detect(from: "ko"), .korean, "ko → 韩语")
        expectEqual(AppLanguage.detect(from: "ko-KR"), .korean, "ko-KR → 韩语")
        expectEqual(AppLanguage.detect(from: "es"), .spanish, "es → 西班牙语")
        expectEqual(AppLanguage.detect(from: "es-ES"), .spanish, "es-ES → 西班牙语")
        expectEqual(AppLanguage.detect(from: "zh-Hans"), .simplifiedChinese, "zh-Hans unchanged")
        expectEqual(AppLanguage.detect(from: "zh-CN"), .simplifiedChinese, "zh-CN unchanged")
        expectEqual(AppLanguage.detect(from: "zh-Hant"), .traditionalChinese, "zh-Hant unchanged")
        expectEqual(AppLanguage.detect(from: "zh-TW"), .traditionalChinese, "zh-TW unchanged")
        expectEqual(AppLanguage.detect(from: "ja"), .japanese, "ja unchanged")
        expectEqual(AppLanguage.detect(from: "ja-JP"), .japanese, "ja-JP unchanged")
        expectEqual(AppLanguage.detect(from: "en"), .english, "en unchanged")
        expectEqual(AppLanguage.detect(from: "en-US"), .english, "en-US unchanged")
        expectEqual(AppLanguage.korean.displayName, "한국어", "picker name 한국어")
        expectEqual(AppLanguage.spanish.displayName, "Español", "picker name Español")

        let system = LanguagePreference.followSystemToken
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "ko"), .korean, "follow system ko → 韩语")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "ko-KR"), .korean, "follow system ko-KR → 韩语")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "es"), .spanish, "follow system es → 西班牙语")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "es-ES"), .spanish, "follow system es-ES → 西班牙语")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "zh-Hans"), .simplifiedChinese, "follow system zh-Hans unchanged")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "zh-Hant"), .traditionalChinese, "follow system zh-Hant unchanged")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "zh-TW"), .traditionalChinese, "follow system zh-TW unchanged")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "ja"), .japanese, "follow system ja unchanged")
        expectEqual(LanguagePreference.resolve(stored: system, preferred: "en"), .english, "follow system en unchanged")
        expectEqual(LanguagePreference.resolve(stored: "ja", preferred: "ko-KR"), .japanese, "fixed language ignores the preferred tag")
        expectEqual(LanguagePreference.resolve(stored: "zh-Hans", preferred: "es-ES"), .simplifiedChinese, "stored zh-Hans stays 简体")
        expectEqual(LanguagePreference.resolve(stored: "zh-Hant", preferred: "en"), .traditionalChinese, "stored zh-Hant stays 繁体")
        expectEqual(LanguagePreference.resolve(stored: "ko", preferred: "en-US"), .korean, "stored ko stays 韩语")
        expectEqual(LanguagePreference.resolve(stored: "es", preferred: "ja-JP"), .spanish, "stored es stays 西班牙语")
        let tables = LocalizationManager.translationTable
        let langs: [AppLanguage] = [.simplifiedChinese, .traditionalChinese, .english, .japanese, .korean, .spanish]
        let keySets = langs.map { Set(tables[$0]?.keys.map { $0 } ?? []) }
        expect(keySets.allSatisfy { $0 == keySets[0] }, "six language tables share one key set")
        var empty = 0
        var koCopies = 0
        var esCopies = 0
        for key in keySets[0] {
            for lang in langs {
                let value = tables[lang]?[key] ?? ""
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { empty += 1 }
            }
            let zh = tables[.simplifiedChinese]?[key] ?? ""
            let ko = tables[.korean]?[key] ?? ""
            let es = tables[.spanish]?[key] ?? ""
            func asciiOnly(_ s: String) -> Bool { s.unicodeScalars.allSatisfy { $0.value < 128 } }
            if ko == zh && !asciiOnly(ko) { koCopies += 1 }
            if es == zh && !asciiOnly(es) { esCopies += 1 }
        }
        expectEqual(empty, 0, "every localization value is non-empty")
        expectEqual(koCopies, 0, "Korean is not a copy of 简体 except ASCII tokens")
        expectEqual(esCopies, 0, "Spanish is not a copy of 简体 except ASCII tokens")
        let followLabels: [(AppLanguage, String)] = [
            (.simplifiedChinese, "跟随系统"),
            (.traditionalChinese, "跟隨系統"),
            (.english, "Follow System"),
            (.japanese, "システムに合わせる"),
            (.korean, "시스템을 따름"),
            (.spanish, "Seguir el sistema"),
        ]
        for (lang, label) in followLabels {
            expectEqual(tables[lang]?["跟随系统"] ?? "", label, "\(lang.rawValue) 跟随系统 label")
        }
        let fontSizeLabels: [(AppLanguage, String, String, String)] = [
            (.simplifiedChinese, "字体大小", "较小", "较大"),
            (.traditionalChinese, "字體大小", "較小", "較大"),
            (.english, "Font size", "Smaller", "Larger"),
            (.japanese, "フォントサイズ", "小さく", "大きく"),
            (.korean, "글자 크기", "작게", "크게"),
            (.spanish, "Tamaño de letra", "Más pequeño", "Más grande"),
        ]
        for (lang, size, smaller, larger) in fontSizeLabels {
            expectEqual(tables[lang]?["字体大小"] ?? "", size, "\(lang.rawValue) 字体大小 label")
            expectEqual(tables[lang]?["较小"] ?? "", smaller, "\(lang.rawValue) 较小 label")
            expectEqual(tables[lang]?["较大"] ?? "", larger, "\(lang.rawValue) 较大 label")
        }
        let sectionImagineNames: [(AppLanguage, String)] = [
            (.simplifiedChinese, "段落Imagine"),
            (.traditionalChinese, "段落Imagine"),
            (.english, "Section Imagine"),
            (.japanese, "段落 Imagine"),
            (.korean, "단락 Imagine"),
            (.spanish, "Imagine de sección"),
        ]
        for (lang, expected) in sectionImagineNames {
            expectEqual(tables[lang]?["段落Imagine"] ?? "", expected, "\(lang.rawValue) 段落Imagine name")
        }
        for lang in langs {
            expect(!(tables[lang]?["注音可能无法撤销或改错"] ?? "").isEmpty, "\(lang.rawValue) has furigana warning title")
            expect(!(tables[lang]?["注音会改动读音，可能无法撤销或出现错误。确定要继续吗？"] ?? "").isEmpty, "\(lang.rawValue) has furigana warning body")
            expect(!(tables[lang]?["没有歌词的段落不会注音"] ?? "").isEmpty, "\(lang.rawValue) has empty-lyrics furigana message")
            expect(!(tables[lang]?["请先选中要注音的汉字"] ?? "").isEmpty, "\(lang.rawValue) has select-kanji-first alert")
        }
        expectEqual(tables[.english]?["注音"] ?? "", "Furigana", "English 注音 label")
        expectEqual(tables[.japanese]?["注音"] ?? "", "ふりがな", "Japanese 注音 label")
        let exportByContent: [(AppLanguage, String, String, String)] = [
            (.simplifiedChinese, "按内容导出", "导出选中内容", "歌词正文"),
            (.traditionalChinese, "按內容匯出", "匯出選中內容", "歌詞正文"),
            (.english, "Export by content", "Export selected content", "Lyrics"),
            (.japanese, "内容を選んでエクスポート", "選択した内容をエクスポート", "歌詞本文"),
            (.korean, "내용 골라 내보내기", "선택한 내용 내보내기", "가사 본문"),
            (.spanish, "Exportar por contenido", "Exportar lo seleccionado", "Letra"),
        ]
        for (lang, byContent, selected, body) in exportByContent {
            expectEqual(tables[lang]?["按内容导出"] ?? "", byContent, "\(lang.rawValue) 按内容导出")
            expectEqual(tables[lang]?["导出选中内容"] ?? "", selected, "\(lang.rawValue) 导出选中内容")
            expectEqual(tables[lang]?["歌词正文"] ?? "", body, "\(lang.rawValue) 歌词正文")
        }
        let largeModelHint = "建议选用参数量更大的模型，以便翻译、注音和创作更准确"
        for lang in langs {
            let hint = tables[lang]?[largeModelHint] ?? ""
            expect(!hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(lang.rawValue) large-parameter model hint")
        }

        let retiredHints = [
            "Skill 需要移交给拥有 Agent 能力的智能体",
            "Skill 需要移交給擁有 Agent 能力的智能體",
            "Skills must be handed off to an Agent-capable AI",
            "Skill は Agent 能力を持つ AI に引き渡す必要があります",
            "Skill은 에이전트 능력이 있는 AI에게 넘겨야 합니다",
            "La habilidad debe pasarse a una IA con capacidad de agente",
        ]
        let hintKey = "Skill需要移交给有文件处理能力的LLM"
        for lang in langs {
            let bag = Set((tables[lang] ?? [:]).keys).union(tables[lang]?.values.map { $0 } ?? [])
            for retired in retiredHints {
                expect(!bag.contains(retired), "\(lang.rawValue) no longer has the Agent-capable hint")
            }
            expect(tables[lang]?[hintKey] != nil, "\(lang.rawValue) has the file-capable LLM hint key")
        }
        expectEqual(tables[.simplifiedChinese]?[hintKey] ?? "", hintKey, "simplified hint is the new sentence")
        let hintTranslations: [(AppLanguage, String)] = [
            (.traditionalChinese, "Skill需要移交給有檔案處理能力的LLM"),
            (.english, "The Skill must be handed to an LLM that can handle files"),
            (.japanese, "Skill はファイルを扱える LLM に引き渡す必要があります"),
            (.korean, "Skill은 파일을 처리할 수 있는 LLM에게 넘겨야 합니다"),
            (.spanish, "La habilidad debe pasarse a un LLM que sí pueda manejar archivos"),
        ]
        for (lang, expected) in hintTranslations {
            let value = tables[lang]?[hintKey] ?? ""
            expectEqual(value, expected, "\(lang.rawValue) hint translates the file-capable LLM sentence")
            expect(value != hintKey, "\(lang.rawValue) hint is not a copy of 简体")
            expect(!value.isEmpty, "\(lang.rawValue) hint is non-empty")
        }
        expect(
            tables[.simplifiedChinese]?["把 .smelody.txt 歌词文件发给 AI Agent"] != nil,
            "other Agent wording on the skill page stays"
        )

        // MARK: v1.8.3 lyrics ruby + identity
        let lyrics = "東京は"
        let tokyo = LyricsRubySpan(rangeStart: 0, rangeLength: 2, original: "東京", phonetic: "とうきょう")
        let rubyFont = NSFont.systemFont(ofSize: 16)
        let withRuby = LyricsRubyMath.attributedString(lyrics: lyrics, annotations: [tokyo], font: rubyFont)
        let withoutRuby = LyricsRubyMath.attributedString(lyrics: lyrics, annotations: [], font: rubyFont)
        expectEqual(withRuby.string, lyrics, "storage string stays 東京は")
        expectEqual(withoutRuby.string, lyrics, "unannotated storage string stays 東京は")
        expectEqual(LyricsRubyMath.rubyText(at: 0, in: withRuby) ?? "", "とうきょう", "東京 has ruby とうきょう")
        expectEqual(LyricsRubyMath.rubyText(at: 1, in: withRuby) ?? "", "とうきょう", "京 shares the 東京 ruby run")
        expect(LyricsRubyMath.rubyText(at: 2, in: withRuby) == nil, "は has no ruby")
        var tokyoRange = NSRange(location: 0, length: 0)
        let tokyoAttrs = withRuby.attributes(at: 0, effectiveRange: &tokyoRange)
        expectEqual(tokyoRange, NSRange(location: 0, length: 2), "ruby run covers 東京")
        let factor = LyricsRubyMath.rubySizeFactor(in: tokyoAttrs) ?? 1
        expect(factor < 1, "ruby size factor is smaller than the base glyphs")
        expectEqual(factor, LyricsRubyMath.rubySizeFactor, "ruby size factor is the shipped 0.5")
        let afterText = (tokyoAttrs[LyricsRubyMath.rubyAttributeName] as! CTRubyAnnotation)
        expect(CTRubyAnnotationGetTextForPosition(afterText, .after) == nil || (CTRubyAnnotationGetTextForPosition(afterText, .after) as String?)?.isEmpty == true, "ruby position is before (above), not after")
        expect(LyricsRubyMath.rubyText(at: 0, in: withoutRuby) == nil, "no annotations yields no ruby")
        expect(!LyricsRubyMath.containsRuby(withoutRuby), "empty annotation list has no ruby attributes")
        let rubyHeight = LyricsRubyMath.usedHeight(withRuby, width: 240)
        let plainHeight = LyricsRubyMath.usedHeight(withoutRuby, width: 240)
        expect(rubyHeight > plainHeight, "framesetter height with ruby is greater than without")

        let extraRuby = LyricsRubyMath.extraLineHeight(fontSize: 16)
        expect(extraRuby > 0, "ruby band has height")
        let baseCaret = LyricsRubyMath.baseLineHeight(font: rubyFont)
        expect(baseCaret > 0, "kanji line height is positive")
        let tallCaret = CGRect(x: 4, y: 0, width: 1, height: extraRuby + baseCaret)
        let trimmedCaret = LyricsRubyMath.caretRect(
            from: tallCaret,
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: true
        )
        expectEqual(trimmedCaret.height, baseCaret, "caret height covers the kanji, not the ruby")
        expectEqual(trimmedCaret.origin.y, extraRuby, "caret starts below the ruby band")
        let doubleExtraCaret = CGRect(x: 4, y: 0, width: 1, height: extraRuby * 2 + baseCaret)
        let pinnedCaret = LyricsRubyMath.caretRect(
            from: doubleExtraCaret,
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: true
        )
        expectEqual(pinnedCaret.height, baseCaret, "double-extra fragment still pins the caret to the kanji")
        expectEqual(pinnedCaret.origin.y, extraRuby * 2, "pinned caret sits on the kanji at the bottom of the fragment")
        let shortOnRuby = LyricsRubyMath.caretRect(
            from: CGRect(x: 4, y: 0, width: 1, height: baseCaret),
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: true
        )
        expectEqual(shortOnRuby.origin.y, extraRuby, "font-height caret on a ruby line moves down onto the kanji")
        expectEqual(shortOnRuby.height, baseCaret, "shifted caret keeps the kanji height")
        let plainCaret = LyricsRubyMath.caretRect(
            from: CGRect(x: 4, y: 0, width: 1, height: 20),
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: false
        )
        expectEqual(plainCaret.height, CGFloat(20), "caret on a line without ruby stays the base height")
        expectEqual(plainCaret.origin.y, CGFloat(0), "caret on a line without ruby is not shifted")
        expectEqual(LyricsRubyMath.systemCaretWidth, CGFloat(2), "search-field caret is the system 2pt bar")
        expectEqual(LyricsRubyMath.caretWidth(fontSize: 13), LyricsRubyMath.systemCaretWidth, "small type keeps the system caret width")
        expectEqual(LyricsRubyMath.caretWidth(fontSize: 16), LyricsRubyMath.systemCaretWidth, "default 16pt caret matches the song-search field")
        expectEqual(LyricsRubyMath.caretWidth(fontSize: 22), LyricsRubyMath.systemCaretWidth, "larger type still uses the system caret width")
        expectEqual(LyricsRubyMath.caretColor, NSColor.textInsertionPointColor, "caret uses the system insertion color, not body text")
        expectEqual(LyricsRubyMath.caretMoveDuration, TimeInterval(0.1), "caret move duration is a short linear slide")
        expect(
            LyricsRubyMath.shouldAnimateCaretMove(
                from: CGRect(x: 4, y: 10, width: 2, height: 16),
                to: CGRect(x: 20, y: 10, width: 2, height: 16)
            ),
            "moving to another glyph animates"
        )
        expect(
            !LyricsRubyMath.shouldAnimateCaretMove(
                from: CGRect(x: 4, y: 10, width: 2, height: 16),
                to: CGRect(x: 4.2, y: 10, width: 2, height: 16)
            ),
            "sub-pixel jitter does not animate"
        )
        expect(
            !LyricsRubyMath.shouldAnimateCaretMove(from: .null, to: CGRect(x: 4, y: 10, width: 2, height: 16)),
            "first placement does not animate"
        )
        let inserted = LyricsRubyMath.insertionRect(
            fragment: tallCaret,
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: true,
            fontSize: 16
        )
        expectEqual(inserted.height, baseCaret, "insertion height covers the kanji, not the ruby")
        expectEqual(inserted.origin.y, extraRuby, "insertion starts below the ruby band")
        expectEqual(inserted.origin.x, tallCaret.origin.x, "insertion keeps the glyph x")
        expectEqual(inserted.width, LyricsRubyMath.systemCaretWidth, "placeholder width becomes the system caret width")
        let proposedInserted = LyricsRubyMath.insertionRect(
            fragment: CGRect(x: 4, y: 0, width: 2, height: extraRuby + baseCaret),
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: true,
            fontSize: 16
        )
        expectEqual(proposedInserted.width, CGFloat(2), "AppKit's 2pt insertion width is kept")
        let shortInserted = LyricsRubyMath.insertionRect(
            fragment: CGRect(x: 4, y: 0, width: 1, height: baseCaret),
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: true,
            fontSize: 16
        )
        expectEqual(shortInserted.origin.y, extraRuby, "font-height insertion on a ruby line moves down onto the kanji")
        expectEqual(shortInserted.height, baseCaret, "shifted insertion keeps the kanji height")
        let plainInserted = LyricsRubyMath.insertionRect(
            fragment: CGRect(x: 4, y: 0, width: 1, height: 20),
            extraRubyHeight: extraRuby,
            baseLineHeight: baseCaret,
            lineHasRuby: false,
            fontSize: 22
        )
        expectEqual(plainInserted.height, CGFloat(20), "plain-line insertion stays the base height")
        expectEqual(plainInserted.origin.y, CGFloat(0), "plain-line insertion is not shifted")
        expectEqual(plainInserted.width, LyricsRubyMath.systemCaretWidth, "plain-line insertion uses the system caret width")
        // 指针：编辑框内一律 I 形，只有可点按的注音那一块给箭头
        expectEqual(LyricsRubyMath.pointerKind(overTappableRuby: true), .arrow, "the pointer is an arrow over a reading that can be clicked")
        expectEqual(LyricsRubyMath.pointerKind(overTappableRuby: false), .iBeam, "everywhere else in the lyrics box stays an I-beam")
        let tapRect = LyricsRubyMath.rubyHitRect(
            baseBox: CGRect(x: 10, y: 0, width: 32, height: 20),
            rubyWidth: 14,
            lineMinY: 4,
            extraRubyHeight: extraRuby
        )
        expectEqual(tapRect, CGRect(x: 10, y: 4, width: 32, height: extraRuby), "a reading shorter than its kanji keeps the kanji width")
        expect(tapRect.contains(CGPoint(x: 26, y: 4 + extraRuby / 2)), "the middle of the ruby band is clickable")
        expect(!tapRect.contains(CGPoint(x: 26, y: 4 + extraRuby + 1)), "the kanji just under the band is not clickable")
        expect(!tapRect.contains(CGPoint(x: 60, y: 4 + extraRuby / 2)), "the empty space beside the reading is not clickable")
        let wideTapRect = LyricsRubyMath.rubyHitRect(
            baseBox: CGRect(x: 10, y: 0, width: 32, height: 20),
            rubyWidth: 48,
            lineMinY: 4,
            extraRubyHeight: extraRuby
        )
        expect(wideTapRect.width > tapRect.width, "a reading wider than its kanji widens the clickable box")
        expectEqual(wideTapRect.midX, tapRect.midX, "the widened box stays centered on the kanji")
        let hit = LyricsRubyMath.rubyHitXRange(baseMinX: 10, baseWidth: 16, rubyWidth: 40)
        expect(hit.maxX - hit.minX >= 40, "ruby hit box covers a reading wider than the kanji")

        // MARK: 歌词改动后注音跟着挪（假名必须压在自己的汉字上）
        let before = "君と東京の街" as NSString   // 東京 在 [2,2)
        let insertedHead = "あ君と東京の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 0, length: 0), replacement: "あ", updatedText: insertedHead
            ),
            .keep(rangeStart: 3, rangeLength: 2),
            "在注音前面插入：注音整体右移"
        )
        let deletedHead = "と東京の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 0, length: 1), replacement: "", updatedText: deletedHead
            ),
            .keep(rangeStart: 1, rangeLength: 2),
            "在注音前面删除：注音整体左移"
        )
        let appended = "君と東京の街を歩いた" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 6, length: 0), replacement: "を歩いた", updatedText: appended
            ),
            .keep(rangeStart: 2, rangeLength: 2),
            "在注音后面改动：注音范围不动"
        )
        let replacedInside = "君と東坂の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 3, length: 1), replacement: "坂", updatedText: replacedInside
            ),
            .drop,
            "注音里的字被改掉：读音作废"
        )
        let retypedSame = "君と東京の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 2, length: 2), replacement: "東京", updatedText: retypedSame
            ),
            .keep(rangeStart: 2, rangeLength: 2),
            "原位重打同样的字：保留读音"
        )
        let deletedTail = "君と東の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 3, length: 1), replacement: "", updatedText: deletedTail
            ),
            .drop,
            "注音里删掉一个字：读音作废"
        )
        let widened = "君と東京都の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 4, length: 0), replacement: "都", updatedText: widened
            ),
            .keep(rangeStart: 2, rangeLength: 2),
            "紧跟注音后面插入：注音范围不受影响"
        )
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 999, length: 1), replacement: "x", updatedText: before
            ),
            .keep(rangeStart: 2, rangeLength: 2),
            "越界的编辑位置不影响它前面的注音"
        )
        let staleSpan = LyricsRubySpan(rangeStart: 999, rangeLength: 2, original: "東京", phonetic: "とうきょう")
        let staleRendered = LyricsRubyMath.attributedString(
            lyrics: "君と東京の街", annotations: [staleSpan], font: .systemFont(ofSize: 16)
        )
        expect(!LyricsRubyMath.containsRuby(staleRendered), "过期的注音范围被渲染层跳过，不抛异常")
        expectEqual(
            LyricsRubyMath.kernAdjustments(lyrics: "君と東京の街", annotations: [staleSpan], font: .systemFont(ofSize: 16)),
            [:],
            "kernAdjustments 跳过越界注音"
        )
        let stepOneText = "あ君と東京の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 2, rangeLength: 2, original: "東京",
                edit: NSRange(location: 0, length: 0), replacement: "あ", updatedText: stepOneText
            ),
            .keep(rangeStart: 3, rangeLength: 2),
            "两步重放·第一步：句首插入后右移"
        )
        let stepTwoText = "あと東京の街" as NSString
        expectEqual(
            LyricsRubyMath.remapAnnotation(
                rangeStart: 3, rangeLength: 2, original: "東京",
                edit: NSRange(location: 1, length: 1), replacement: "", updatedText: stepTwoText
            ),
            .keep(rangeStart: 2, rangeLength: 2),
            "两步重放·第二步：删掉插入的字后左移回来"
        )
        let lightFill = LyricsRubyMath.editingHighlightColor(dark: false)
        let darkFill = LyricsRubyMath.editingHighlightColor(dark: true)
        expect(lightFill != darkFill, "editing highlight differs in light and dark mode")
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
        lightFill.usingColorSpace(.sRGB)?.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        darkFill.usingColorSpace(.sRGB)?.getRed(&dr, green: &dg, blue: &db, alpha: &da)
        expect(lr + lg + lb > dr + dg + db, "light-mode highlight is lighter than dark-mode")
        expect((lr + lg + lb) / 3 > 0.93, "light-mode highlight stays pale enough to read")
        let phrase = "当然です"
        let mixedSel = NSRange(location: 1, length: 2)
        expectEqual((phrase as NSString).substring(with: mixedSel), "然で", "fixture selects 然で inside 当然です")
        let expanded = LyricsRubyMath.selectedKanjiRun(in: phrase, selection: mixedSel)
        expect(expanded?.location == 0 && expanded?.length == 2, "然で expands to the full 当然 run")
        expectEqual((phrase as NSString).substring(with: expanded ?? NSRange()), "当然", "expanded run is 当然")
        let caretRun = LyricsRubyMath.selectedKanjiRun(in: phrase, selection: NSRange(location: 1, length: 0))
        expect(caretRun?.location == 0 && caretRun?.length == 2, "caret on 然 still expands to 当然")
        expect(LyricsRubyMath.selectedKanjiRun(in: phrase, selection: NSRange(location: 2, length: 2)) == nil, "です with no kanji does not start a reading")
        expect(LyricsRubyMath.selectedKanjiRun(in: "", selection: NSRange(location: 0, length: 0)) == nil, "empty lyrics have no kanji run")
        let highlighted = LyricsRubyMath.attributedString(
            lyrics: lyrics,
            annotations: [tokyo],
            font: rubyFont,
            editingRange: NSRange(location: 0, length: 2),
            darkAppearance: false
        )
        expect(highlighted.attribute(.backgroundColor, at: 0, effectiveRange: nil) != nil, "editing wraps 東京 in a background")
        expect(highlighted.attribute(.backgroundColor, at: 2, effectiveRange: nil) == nil, "は is not wrapped while 東京 is edited")

        let blocked = LyricsRubyMath.kernAdjustments(
            lyrics: "人字人",
            annotations: [LyricsRubySpan(rangeStart: 1, rangeLength: 1, original: "字", phonetic: "あいうえおかきくけこ")],
            font: rubyFont
        )
        expect(blocked.values.reduce(0, +) > 0, "long ruby between ideographs expands the kanji")
        let openKana = LyricsRubyMath.kernAdjustments(
            lyrics: "の字の",
            annotations: [LyricsRubySpan(rangeStart: 1, rangeLength: 1, original: "字", phonetic: "あいうえおかきくけこ")],
            font: rubyFont
        )
        expect(openKana.values.reduce(0, +) == 0, "long ruby beside unannotated kana does not expand the kanji")
        let tokyoKern = LyricsRubyMath.kernAdjustments(lyrics: lyrics, annotations: [tokyo], font: rubyFont)
        expect(tokyoKern.values.reduce(0, +) == 0, "とうきょう over 東京は hangs into は, no extra kanji spacing")
        let splitKern = LyricsRubyMath.kernAdjustments(
            lyrics: "負けず劣らず",
            annotations: [
                LyricsRubySpan(rangeStart: 0, rangeLength: 1, original: "負", phonetic: "ああああああああ"),
                LyricsRubySpan(rangeStart: 3, rangeLength: 1, original: "劣", phonetic: "ああああああああ"),
            ],
            font: rubyFont
        )
        expect((splitKern[1] ?? 0) + (splitKern[2] ?? 0) > 0, "けず keeps a buffer when the two readings would meet")
        let groupKern = LyricsRubyMath.kernAdjustments(
            lyrics: "人東京人",
            annotations: [LyricsRubySpan(rangeStart: 1, rangeLength: 2, original: "東京", phonetic: "あいうえおかきくけこ")],
            font: rubyFont
        )
        expect((groupKern[1] ?? 0) > 0, "group ruby longer than consecutive kanji adds space between the kanji")
        let withKern = LyricsRubyMath.attributedString(
            lyrics: "人字人",
            annotations: [LyricsRubySpan(rangeStart: 1, rangeLength: 1, original: "字", phonetic: "あいうえおかきくけこ")],
            font: rubyFont
        )
        expect(LyricsRubyMath.kern(at: 0, in: withKern) + LyricsRubyMath.kern(at: 1, in: withKern) > 0, "attributed string applies the extra kern")

        expectEqual(AppReleaseMath.displayVersion, "v1.8.3", "shipped display version")
        expectEqual(AppReleaseMath.marketingVersion, "1.8.3", "shipped marketing version")
        let shown = ChangelogContent.displayedEntries
        let latest = shown.filter(\.isLatest)
        expectEqual(latest.map(\.version), ["v1.8.3"], "only latest changelog row is v1.8.3")
        expect(!shown.contains(where: { $0.version == "v1.8.2" && $0.isLatest }), "v1.8.2 is not latest")
        expect(!shown.contains(where: { $0.version == "v1.8.1" && $0.isLatest }), "v1.8.1 is not latest")
        expectEqual(shown.first { $0.version == "v1.7.10" }?.date ?? "", "2026-06-26", "displayed v1.7.10 date is June 26")
        expect(!shown.contains(where: { $0.version.contains("Extra") }), "Extra heading is folded into v1.7.10")
        let bodies = [
            latest[0].bodyMarkdown,
            latest[0].bodyMarkdownZHT ?? "",
            latest[0].bodyMarkdownEN ?? "",
            latest[0].bodyMarkdownJA ?? "",
            latest[0].bodyMarkdownKO ?? "",
            latest[0].bodyMarkdownES ?? "",
        ]
        expectEqual(bodies.filter { !$0.isEmpty }.count, 6, "v1.8.3 has six language bodies")
        // 简体正文是手写范本，其他语言照它翻译
        let rubyNotes = [
            ["Imagine", "Imagine", "Imagine", "Imagine", "Imagine", "Imagine"],
            ["注音", "注音", "furigana", "ふりがな", "후리가나", "furigana"],
            ["日语", "日語", "Japanese", "日本語", "일본어", "japonés"],
            ["歌词", "歌詞", "Lyric", "歌詞", "가사", "letra"],
            ["光标", "游標", "cursor", "カーソル", "커서", "cursor"],
            ["导出", "匯出", "export", "書き出", "내보낼", "exportar"],
            ["创意", "創意", "Creative", "創作", "창작", "Creativo"],
            ["弃用", "棄用", "retired", "廃止", "폐지", "retirado"],
        ]
        for (index, body) in bodies.enumerated() {
            for phrases in rubyNotes {
                expect(body.contains(phrases[index]), "v1.8.3 body \(index) mentions \(phrases[index])")
            }
        }
        let v182 = shown.first { $0.version == "v1.8.2" }
        let v182Bodies = [
            v182?.bodyMarkdown ?? "",
            v182?.bodyMarkdownZHT ?? "",
            v182?.bodyMarkdownEN ?? "",
            v182?.bodyMarkdownJA ?? "",
            v182?.bodyMarkdownKO ?? "",
            v182?.bodyMarkdownES ?? "",
        ]
        let imagineNotes = [
            ["Imagine", "Imagine", "Imagine", "Imagine", "Imagine", "Imagine"],
            ["右上方", "右上方", "top right", "右上", "오른쪽 위", "arriba a la derecha"],
            ["右滑", "右滑", "swiping", "滑らせ", "밀면", "deslizar"],
            ["LLM", "LLM", "LLM", "LLM", "LLM", "LLM"],
            ["歌词", "歌詞", "lyrics", "歌詞", "가사", "letra"],
            ["字体大小", "字體大小", "Font size", "フォントサイズ", "글자 크기", "tamaño de letra"],
            ["设置", "設定", "Settings", "設定", "설정", "Ajustes"],
            ["修复", "修復", "Fixed", "修正", "수정", "Corrección"],
        ]
        for (index, body) in v182Bodies.enumerated() {
            for phrases in imagineNotes {
                expect(body.contains(phrases[index]), "v1.8.2 body \(index) mentions \(phrases[index])")
            }
        }
        let previous = shown.first { $0.version == "v1.8.1" }
        let previousBodies = [
            previous?.bodyMarkdown ?? "",
            previous?.bodyMarkdownZHT ?? "",
            previous?.bodyMarkdownEN ?? "",
            previous?.bodyMarkdownJA ?? "",
            previous?.bodyMarkdownKO ?? "",
            previous?.bodyMarkdownES ?? "",
        ]
        for body in bodies {
            let shownBody = ChangelogDisplayText.fromMarkdown(body)
            expect(shownBody.contains("【"), "changelog uses 【】")
            expect(shownBody.contains("•"), "changelog uses •")
            expect(!shownBody.contains("##"), "no markdown heading")
            expect(!shownBody.contains("**"), "no markdown bold")
            expect(!shownBody.contains("`"), "no backticks")
        }
        let joined = previousBodies.joined(separator: "\n")
        expect(joined.contains("Command") || joined.contains("整首歌"), "mentions whole-song Command")
        expect(joined.contains("韩语") || joined.contains("한국어") || joined.contains("coreano") || joined.contains("韓国語"), "mentions Korean")
        expect(joined.contains("西班牙语") || joined.contains("español") || joined.contains("Español") || joined.contains("スペイン語"), "mentions Spanish")
        expect(joined.contains("导出") || joined.contains("export") || joined.contains("書き出し") || joined.contains("내보내기") || joined.contains("exportar"), "mentions export button")
        let commandNotes = [
            ["Command", "Command", "Command", "Command", "Command", "Command"],
            ["全文段落", "全文段落", "every section", "曲全体", "곡 전체", "todas las secciones"],
            ["韩语", "韓語", "Korean", "韓国語", "한국어", "coreano"],
            ["西班牙语", "西班牙語", "Spanish", "スペイン語", "스페인어", "español"],
            ["导出按钮", "匯出按鈕", "export button", "書き出しボタン", "내보내기 버튼", "botón de exportar"],
            ["设置页", "設定頁", "settings page", "設定ページ", "설정 페이지", "página de ajustes"],
            ["API Key", "API Key", "API Key", "API Key", "API Key", "API Key"],
        ]
        for (index, body) in previousBodies.enumerated() {
            for phrases in commandNotes {
                expect(body.contains(phrases[index]), "v1.8.1 body \(index) mentions \(phrases[index])")
            }
            expect(!body.contains("##"), "v1.8.1 source body \(index) has no markdown heading")
            expect(!body.contains("**"), "v1.8.1 source body \(index) has no markdown bold")
            expect(!body.contains("`"), "v1.8.1 source body \(index) has no backticks")
        }
        // 带标版本（GT5 / Beta / Gamma / Extra …）已按数字版本合并，日志分段合并、取最新日期
        expect(
            ChangelogContent.entries.allSatisfy { ChangelogFold.numericStem($0.version) == $0.version },
            "no letter-tagged versions are left in the source data"
        )
        let tagged = [
            "Extra", "Beta", "Gamma", "Delta", "GT", "GT2", "GT3", "GT4", "GT5",
            "Test", "BugStable", "Alpha", "RC",
        ]
        for entry in ChangelogContent.entries {
            for token in tagged {
                expect(!entry.version.contains(token), "\(entry.version) heading carries no \(token) tag")
            }
        }
        let v179 = ChangelogContent.entries.first { $0.version == "v1.7.9" }
        expectEqual(v179?.date, "2026-06-25", "merged v1.7.9 takes the latest date of its builds")
        expectEqual(ChangelogContent.entries.first { $0.version == "v1.7.10" }?.date, "2026-06-26", "merged v1.7.10 takes the latest date of its builds")
        let v179Bodies = [
            v179?.bodyMarkdown ?? "",
            v179?.markdown(for: .english) ?? "",
            v179?.markdown(for: .korean) ?? "",
        ]
        for (index, body) in v179Bodies.enumerated() {
            let headings = body.components(separatedBy: "【").count - 1
            expectEqual(headings, 3, "merged v1.7.9 body \(index) has one heading per section, not one per build")
            expectEqual(body.filter { $0 == "•" }.count, 22, "merged v1.7.9 body \(index) keeps all 22 bullets")
        }
        // 手写的简体范本同样覆盖更早的条目
        let templateRows: [(String, [[String]])] = [
            ("v1.8.0", [
                ["下载", "下載", "Download", "ダウンロード", "다운로드", "descarga"],
                ["歌词预览", "歌詞預覽", "lyrics preview", "歌詞プレビュー", "가사 미리보기", "vista previa"],
                ["笔记", "筆記", "notes", "メモ", "메모", "notas"],
                ["译文", "譯文", "translation", "訳文", "번역", "traducción"],
            ]),
            ("v1.7.10", [
                ["译文", "譯文", "translation", "訳文", "번역", "traducción"],
                ["笔记", "筆記", "notes", "メモ", "메모", "notas"],
                ["歌词文件", "歌詞檔", "lyric file", "歌詞ファイル", "가사 파일", "archivo de letra"],
                ["拖动段落", "拖動段落", "sections are dragged", "セクションのドラッグ", "섹션을 끄는", "arrastrar secciones"],
                ["纪念", "紀念", "In memory", "記念", "기념", "En memoria"],
                ["十二周年", "十二週年", "twelfth anniversary", "十二周年", "12주년", "duodécimo aniversario"],
            ]),
        ]
        for (version, phrasesList) in templateRows {
            guard let row = ChangelogContent.entries.first(where: { $0.version == version }) else {
                expect(false, "\(version) entry exists")
                continue
            }
            let rowBodies = [
                row.bodyMarkdown,
                row.markdown(for: .traditionalChinese),
                row.markdown(for: .english),
                row.markdown(for: .japanese),
                row.markdown(for: .korean),
                row.markdown(for: .spanish),
            ]
            for (index, body) in rowBodies.enumerated() {
                for phrases in phrasesList {
                    expect(body.contains(phrases[index]), "\(version) body \(index) mentions \(phrases[index])")
                }
            }
        }
        let forbidden = ["##", "**", "`", "swipeActions", "List(selection:)"]
        for row in shown {
            let rowBodies = [
                row.bodyMarkdown,
                row.markdown(for: .traditionalChinese),
                row.markdown(for: .english),
                row.markdown(for: .japanese),
                row.markdown(for: .korean),
                row.markdown(for: .spanish),
            ]
            for body in rowBodies {
                let shownBody = ChangelogDisplayText.fromMarkdown(body)
                expect(shownBody.contains("【") && shownBody.contains("•"), "\(row.version) changelog is plain 【】 and •")
                for token in forbidden {
                    expect(!shownBody.contains(token), "\(row.version) changelog hides \(token)")
                }
            }
        }

        let suiteName = "SimpleMelodyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let keyStore = LLMAPIKeyStore(defaults: defaults)
        expectEqual(keyStore.current(), .empty, "api connection store starts empty")
        let typed = LLMConnection(
            baseURL: "https://provider.example/v1",
            modelName: "model-\(UUID().uuidString)",
            apiKey: "key-\(UUID().uuidString)"
        )
        keyStore.save(typed)
        expectEqual(keyStore.current(), typed, "saved provider URL, model name, and api key read back from the same store")
        keyStore.clear()
        expectEqual(keyStore.current(), .empty, "cleared api connection is empty")
        defaults.removePersistentDomain(forName: suiteName)

        // MARK: Imagine scope, prompt, reply, and chat request
        let imagineDoc = ImagineDocument(
            title: "夜航",
            artist: "A",
            languages: "ja",
            bpm: 90,
            musicalKey: "C",
            beat: "4/4",
            ideas: "雨夜",
            sections: [
                ImagineSection(id: "s1", marker: "[Verse]", body: "alpha line", translation: "", notes: ""),
                ImagineSection(id: "s2", marker: "[Chorus]", body: "beta line", translation: "old chorus", notes: "keep"),
            ]
        )
        let sectionTranslate = ImagineWorkflow.compose(
            action: .translate,
            scope: .section("s1"),
            document: imagineDoc,
            targetLanguage: "英语",
            userPrompt: ""
        )!
        expect(sectionTranslate.system.contains("信达雅"), "translation reference asks for 信达雅")
        expect(sectionTranslate.system.contains("用户提示词优先于信达雅"), "translation reference ranks the user prompt above 信达雅")
        expect(sectionTranslate.system.contains("不要自行加戏"), "translation reference names the rule the prompt outranks")
        expect(sectionTranslate.system.contains("Notes 不是歌词"), "translation reference forbids treating notes as lyrics")
        expect(sectionTranslate.system.contains("Ruby / 注音不是歌词"), "translation reference does not treat ruby as lyrics")
        expect(!sectionTranslate.system.contains("格律"), "translation reference is not the creative one")
        expect(sectionTranslate.user.contains("alpha line"), "section request includes that section")
        expect(!sectionTranslate.user.contains("beta line"), "section request does not include another section")
        expect(!sectionTranslate.user.contains("用户提示词:"), "empty user prompt is omitted")
        expect(!sectionTranslate.user.contains("请自由发挥"), "empty user prompt is not replaced")
        expect(sectionTranslate.user.contains("目标语言: 英语"), "translation carries the target language")
        let sectionCreate = ImagineWorkflow.compose(
            action: .create,
            scope: .section("s1"),
            document: imagineDoc,
            targetLanguage: "",
            userPrompt: "更口语一点"
        )!
        expect(sectionCreate.system.contains("格律"), "creative reference mentions meter")
        expect(sectionCreate.system.contains("用户提示词优先"), "creative reference ranks the user prompt first")
        expect(!sectionCreate.system.contains("信达雅"), "creative reference is not the translation one")
        expect(sectionCreate.user.contains("更口语一点"), "user prompt is included when present")
        expect(sectionCreate.user.contains("Title: 夜航"), "section creative includes the song title")
        expect(sectionCreate.user.contains("Language: ja"), "section creative includes the song language")
        expect(sectionCreate.user.contains("BPM: 90"), "section creative includes BPM")
        expect(sectionCreate.user.contains("Key: C"), "section creative includes 调式")
        expect(sectionCreate.user.contains("Beat: 4/4"), "section creative includes 节拍")
        expect(sectionCreate.user.contains("雨夜"), "section creative includes ideas")
        expect(sectionCreate.user.contains("beta line"), "section creative sends other sections for 文风")
        expect(sectionCreate.user.contains("只输出这一个 Section: s1"), "section creative asks to return only the target")
        expect(sectionCreate.user.contains("Target section: s1"), "section creative marks the target")
        expect(sectionCreate.system.contains("文风参考"), "creative reference says 段落任务 sends the whole song for 文风")
        let whole = ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: imagineDoc,
            targetLanguage: "",
            userPrompt: ""
        )!
        expect(whole.user.contains("beta line") && whole.user.contains("alpha line"), "whole-song request includes every section")
        expect(whole.user.contains("BPM: 90"), "whole-song request carries BPM")
        expect(whole.user.contains("Key: C"), "whole-song request carries 调式")
        expect(whole.user.contains("Beat: 4/4"), "whole-song request carries 节拍")
        expect(whole.user.contains("Language: ja"), "whole-song request carries language")
        expect(!whole.user.contains("用户提示词:"), "whole-song empty prompt is omitted")
        expect(ImagineWorkflow.compose(action: .translate, scope: .section("missing"), document: imagineDoc, targetLanguage: "英语", userPrompt: "") == nil, "missing section is not sent")

        let translated = ImagineWorkflow.apply(
            reply: "Section: s1\nTranslation:\n一行译文\nSection: s2\nLyrics:\n不应写入",
            action: .translate,
            scope: .section("s1"),
            document: imagineDoc
        )
        expectEqual(translated.sections[0].translation, "一行译文", "translation writes the matching section")
        expectEqual(translated.sections[1].body, "beta line", "section translation does not rewrite another section")
        expectEqual(translated.bpm, 90, "section translation leaves BPM unchanged")
        let ignoredMeta = ImagineWorkflow.apply(
            reply: "BPM: 200\nKey: Am\nLanguage: en\nBeat: 7/8\nSection: s1\nTranslation:\n只要译文",
            action: .translate,
            scope: .section("s1"),
            document: imagineDoc
        )
        expectEqual(ignoredMeta.bpm, 90, "section reply does not change BPM")
        expectEqual(ignoredMeta.musicalKey, "C", "section reply does not change 调式")
        expectEqual(ignoredMeta.beat, "4/4", "section reply does not change 节拍")
        expectEqual(ignoredMeta.languages, "ja", "section reply does not change language")
        let mismatched = ImagineWorkflow.apply(
            reply: "当然可以，这是一段没有字段的回复",
            action: .translate,
            scope: .section("s1"),
            document: imagineDoc
        )
        expectEqual(mismatched, imagineDoc, "mismatched reply writes nothing")
        let created = ImagineWorkflow.apply(
            reply: "Language: en\nBPM: 128\nKey: Am\nBeat: 6/8\nSection: s1\nLyrics:\nnew alpha\nNotes:\nsoft",
            action: .create,
            scope: .song,
            document: imagineDoc,
            allowSongBasics: true
        )
        expectEqual(created.languages, "en", "whole-song creative can set language")
        expectEqual(created.bpm, 128, "whole-song creative can set BPM")
        expectEqual(created.musicalKey, "Am", "whole-song creative can set 调式")
        expectEqual(created.beat, "6/8", "whole-song creative can set 节拍")
        expectEqual(created.sections[0].body, "new alpha", "creative writes lyrics")
        expectEqual(created.sections[0].notes, "soft", "creative writes notes")
        expectEqual(created.sections[1].body, "beta line", "unmentioned section stays")
        let presentBasics = ImagineWorkflow.apply(
            reply: "Language: en\nBPM: 128\nKey: Am\nBeat: 6/8\nSection: s1\nLyrics:\nnew alpha",
            action: .create,
            scope: .song,
            document: imagineDoc
        )
        expectEqual(presentBasics.languages, "en", "present language field is written")
        expectEqual(presentBasics.bpm, 128, "present BPM field is written")
        expectEqual(presentBasics.musicalKey, "Am", "present 调式 field is written")
        expectEqual(presentBasics.beat, "6/8", "present 节拍 field is written")
        let omittedBasics = ImagineWorkflow.apply(
            reply: "Section: s1\nLyrics:\nnew alpha",
            action: .create,
            scope: .song,
            document: imagineDoc
        )
        expectEqual(omittedBasics.languages, "ja", "omitted language field is left unchanged")
        expectEqual(omittedBasics.bpm, 90, "omitted BPM field is left unchanged")
        expectEqual(omittedBasics.musicalKey, "C", "omitted 调式 field is left unchanged")
        expectEqual(omittedBasics.beat, "4/4", "omitted 节拍 field is left unchanged")
        expectEqual(omittedBasics.sections[0].body, "new alpha", "lyrics still write when song basics are omitted")
        let titled = ImagineWorkflow.apply(
            reply: "Title: 新夜航\nSection: s1\nLyrics:\nnew alpha",
            action: .create,
            scope: .song,
            document: imagineDoc
        )
        expectEqual(titled.title, "新夜航", "Title field writes the song title")
        expectEqual(titled.sections[0].body, "new alpha", "lyrics still write with Title")
        let zhTitle = ImagineWorkflow.apply(
            reply: "歌名: 港口\nSection: s1\nLyrics:\nnew alpha",
            action: .create,
            scope: .song,
            document: imagineDoc
        )
        expectEqual(zhTitle.title, "港口", "歌名 alias writes Title")
        var blankSong = imagineDoc
        blankSong.title = ""
        blankSong.bpm = nil
        blankSong.musicalKey = nil
        blankSong.sections = [
            ImagineSection(id: "s1", marker: "[Verse]", body: "", translation: "", notes: ""),
        ]
        let blankCompose = ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: blankSong,
            targetLanguage: "",
            userPrompt: "你自己想歌名"
        )!
        expect(blankCompose.user.contains("从空白歌曲创建"), "blank song asks the model to fill basics")
        expect(blankCompose.user.contains("歌名必须写在 Title"), "blank song tells the model to put 歌名 in Title")
        expect(blankCompose.user.contains("必须输出 Title、Language、BPM、Key、Beat"), "blank song requires Title and song basics")
        expect(ImagineWorkflow.reference(for: .create).contains("Title:"), "creative format includes Title")
        expect(ImagineWorkflow.reference(for: .create).contains("禁止把歌名写进 Idea"), "creative reference keeps 歌名 out of Idea")
        var missingBPM = imagineDoc
        missingBPM.bpm = nil
        let missingCompose = ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: missingBPM,
            targetLanguage: "",
            userPrompt: ""
        )!
        expect(missingCompose.user.contains("当前空白必须补上并遵循格式: BPM"), "filled song still fills blank BPM")
        expect(missingCompose.user.contains("没有修改必要"), "unchanged filled fields may be omitted")
        expect(ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: imagineDoc,
            targetLanguage: "",
            userPrompt: ""
        )!.user.contains("默认输出 Idea 块"), "whole-song creative asks for ideas by default")
        expect(ImagineWorkflow.reference(for: .create).contains("Idea:"), "creative format includes Idea blocks")
        var withIdeas = imagineDoc
        withIdeas.ideaItems = [
            ImagineIdea(id: "i1", ideaType: "Inspiration", content: "雨夜"),
        ]
        let ideaReply = ImagineWorkflow.apply(
            reply: """
            Section: s1
            Lyrics:
            new alpha
            Idea: 1
            Type: Setting
            Content:
            雨中的港口
            """,
            action: .create,
            scope: .song,
            document: withIdeas,
            keepCurrentFormat: true
        )
        expectEqual(ideaReply.ideaItems.count, 1, "ideas keep slot count when format is kept")
        expectEqual(ideaReply.ideaItems[0].content, "雨中的港口", "Idea Content writes 灵感设定")
        expectEqual(ideaReply.ideaItems[0].ideaType, "Setting", "Idea Type is kept")
        expectEqual(ideaReply.ideaItems[0].id, "i1", "existing idea id is kept")
        let ideaOverreach = ImagineWorkflow.applyResult(
            reply: """
            Section: s1
            Lyrics:
            hack
            Idea: 1
            Type: Inspiration
            Content:
            should not write
            """,
            action: .create,
            scope: .section("s1"),
            document: imagineDoc
        )
        expect(ideaOverreach.overreach, "段落Imagine writing 灵感设定 is overreach")
        expectEqual(ideaOverreach.document.ideaItems, [], "段落Imagine does not write ideas")
        var noted = imagineDoc
        noted.sections[0].notes = "原来的笔记"
        let notesDump = ImagineWorkflow.apply(
            reply: "Section: s1\nNotes:\n一行译文",
            action: .translate,
            scope: .section("s1"),
            document: noted
        )
        expectEqual(notesDump.sections[0].translation, "一行译文", "mislabeled Notes still land in translation")
        expectEqual(notesDump.sections[0].notes, "原来的笔记", "translation does not overwrite notes")
        let bothFields = ImagineWorkflow.apply(
            reply: "Section: s1\nTranslation:\n正经译文\nNotes:\n正经译文",
            action: .translate,
            scope: .section("s1"),
            document: noted
        )
        expectEqual(bothFields.sections[0].translation, "正经译文", "Translation field wins")
        expectEqual(bothFields.sections[0].notes, "原来的笔记", "duplicate Notes on translate are ignored")
        let zhLabel = ImagineWorkflow.apply(
            reply: "段落: s1\n译文:\n中文标签译文",
            action: .translate,
            scope: .section("s1"),
            document: imagineDoc
        )
        expectEqual(zhLabel.sections[0].translation, "中文标签译文", "Chinese Translation label is recognized")
        expectEqual(zhLabel.sections[0].notes, "", "Chinese translation does not land in notes")
        let splitReply = "Section: 1\nLyrics:\none verse\nSection: 2\nLyrics:\ntwo chorus"
        let splitDoc = ImagineDocument(
            title: "夜航",
            artist: "A",
            languages: "ja",
            bpm: 90,
            musicalKey: "C",
            beat: "4/4",
            ideas: "",
            sections: [
                ImagineSection(id: "s1", marker: "[Verse]", body: "", translation: "", notes: ""),
                ImagineSection(id: "s2", marker: "[Chorus]", body: "", translation: "", notes: ""),
            ]
        )
        let split = ImagineWorkflow.apply(
            reply: splitReply,
            action: .create,
            scope: .song,
            document: splitDoc,
            keepCurrentFormat: true
        )
        expectEqual(split.sections.count, 2, "依照当前格式 keeps the section count")
        expectEqual(split.sections[0].body, "one verse", "labeled sections fill lyric boxes in order")
        expectEqual(split.sections[1].body, "two chorus", "second labeled section does not dump into the first")
        expectEqual(split.sections[0].id, "s1", "依照当前格式 keeps reserved slot ids")
        var mixedFormat = imagineDoc
        mixedFormat.sections[0].body = ""
        mixedFormat.sections[0].notes = ""
        mixedFormat.sections[0].translation = ""
        mixedFormat.sections[1].body = "keep me"
        let offCompose = ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: mixedFormat,
            targetLanguage: "",
            userPrompt: "",
            keepCurrentFormat: false
        )!
        expect(!offCompose.user.contains("keep me"), "依照当前格式 off does not send current lyrics as the template")
        expect(!offCompose.user.contains("alpha line"), "依照当前格式 off does not send other current lyrics")
        expect(offCompose.user.contains("BPM: 90"), "依照当前格式 off still sends song basics")
        let offPlaced = ImagineWorkflow.apply(
            reply: "Section: 1\nLyrics:\nnew front",
            action: .create,
            scope: .song,
            document: mixedFormat,
            keepCurrentFormat: false
        )
        expectEqual(offPlaced.sections.count, 2, "filled sections stay after AI slots")
        expectEqual(offPlaced.sections[0].body, "new front", "blank slots are replaced by the reply")
        expectEqual(offPlaced.sections[1].body, "keep me", "filled sections move to the end")
        expectEqual(offPlaced.sections[1].id, "s2", "moved filled section keeps its id")
        let overreach = ImagineWorkflow.applyResult(
            reply: "BPM: 200\nSection: s1\nLyrics:\nhack\nSection: s2\nLyrics:\nno",
            action: .create,
            scope: .section("s1"),
            document: imagineDoc
        )
        expect(overreach.overreach, "段落Imagine overreach is flagged")
        expectEqual(overreach.document, imagineDoc, "段落Imagine overreach does not write")
        let overreachMeta = ImagineWorkflow.applyResult(
            reply: "Language: en\nSection: s1\nLyrics:\nhack",
            action: .create,
            scope: .section("s1"),
            document: imagineDoc
        )
        expect(overreachMeta.overreach, "段落Imagine song-level work is overreach")
        expectEqual(overreachMeta.document.sections[0].body, "alpha line", "段落Imagine song-level work does not write lyrics")
        let titleOverreach = ImagineWorkflow.applyResult(
            reply: "Title: 不该写\nSection: s1\nLyrics:\nhack",
            action: .create,
            scope: .section("s1"),
            document: imagineDoc
        )
        expect(titleOverreach.overreach, "段落Imagine Title is overreach")
        expectEqual(titleOverreach.document.title, "夜航", "段落Imagine Title does not write")
        expectEqual(titleOverreach.document.sections[0].body, "alpha line", "段落Imagine Title overreach does not write lyrics")
        let dump = ImagineWorkflow.applyResult(
            reply: "Section: s1\nLyrics:\nalpha line\nbeta line",
            action: .create,
            scope: .section("s1"),
            document: imagineDoc
        )
        expect(dump.overreach, "dumping another section's lyrics is overreach")
        expectEqual(dump.document.sections[0].body, "alpha line", "dump does not write the target section")
        let sectionOnly = ImagineWorkflow.applyResult(
            reply: "Section: s1\nLyrics:\nnew alpha",
            action: .create,
            scope: .section("s1"),
            document: imagineDoc
        )
        expect(!sectionOnly.overreach, "returning only the target section is not overreach")
        expectEqual(sectionOnly.document.sections[0].body, "new alpha", "target section still writes")
        expectEqual(sectionOnly.document.sections[1].body, "beta line", "other section stays")
        let verseID = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let chorusID = "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"
        let uuidDoc = ImagineDocument(
            title: "夜航",
            artist: "A",
            languages: "ja",
            bpm: 90,
            musicalKey: "C",
            beat: "4/4",
            ideas: "雨夜",
            sections: [
                ImagineSection(id: verseID, marker: "[Verse]", body: "alpha line", translation: "", notes: ""),
                ImagineSection(id: chorusID, marker: "[Chorus]", body: "beta line", translation: "old chorus", notes: "keep"),
            ]
        )
        let echoed = ImagineWorkflow.apply(
            reply: "Section: \(verseID.lowercased())\nTranslation:\n一行译文",
            action: .translate,
            scope: .section(verseID),
            document: uuidDoc
        )
        expectEqual(echoed.sections[0].translation, "一行译文", "lowercase UUID echo still writes the translation")
        expectEqual(echoed.sections[1].body, "beta line", "lowercase echo does not touch another section")
        expectEqual(echoed.bpm, 90, "lowercase section echo leaves BPM unchanged")
        let echoedLyrics = ImagineWorkflow.apply(
            reply: "Section: \(verseID.lowercased())\nLyrics:\nnew alpha",
            action: .create,
            scope: .section(verseID),
            document: uuidDoc
        )
        expectEqual(echoedLyrics.sections[0].body, "new alpha", "lowercase UUID echo still writes lyrics")
        expectEqual(echoedLyrics.sections[1].translation, "old chorus", "lowercase lyric echo leaves the other section")
        var blankLyricsDoc = imagineDoc
        blankLyricsDoc.sections[1].body = "   "
        blankLyricsDoc.sections[1].notes = "只在笔记里"
        let skipped = ImagineWorkflow.compose(
            action: .translate,
            scope: .section("s2"),
            document: blankLyricsDoc,
            targetLanguage: "英语",
            userPrompt: ""
        )
        expect(skipped == nil, "empty lyrics with notes are not sent for translation")
        let wholeSkipNotes = ImagineWorkflow.compose(
            action: .translate,
            scope: .song,
            document: blankLyricsDoc,
            targetLanguage: "英语",
            userPrompt: ""
        )!
        expect(wholeSkipNotes.user.contains("alpha line"), "whole-song translation still sends sections that have lyrics")
        expect(!wholeSkipNotes.user.contains("只在笔记里"), "whole-song translation does not send notes from an empty section")
        let untouched = ImagineWorkflow.apply(
            reply: "Section: s2\nTranslation:\n不该出现的译文",
            action: .translate,
            scope: .song,
            document: blankLyricsDoc
        )
        expectEqual(untouched.sections[1].translation, "old chorus", "empty lyrics are not given a translation")
        expectEqual(untouched.sections[1].notes, "只在笔记里", "notes stay notes")

        // MARK: Imagine furigana
        expectEqual(ImagineWorkflow.phoneticOnly("し/よん"), "し", "candidate readings keep only the first kana")
        expectEqual(ImagineWorkflow.hiraganaOnly("し/よん"), "し", "hiraganaOnly forwards to phoneticOnly")
        expectEqual(ImagineWorkflow.phoneticOnly("トウキョウ"), "トウキョウ", "katakana is kept for gikun")
        expectEqual(ImagineWorkflow.phoneticOnly("デジャヴ"), "デジャヴ", "vu katakana is kept")
        expectEqual(ImagineWorkflow.phoneticOnly("ゴールデンウィーク"), "ゴールデンウィーク", "long-vowel katakana is kept")
        expectEqual(ImagineWorkflow.phoneticOnly("とうkyo"), "とう", "latin is stripped")
        expectEqual(ImagineWorkflow.phoneticOnly("とうきょう"), "とうきょう", "plain hiragana is kept")
        var furiganaDoc = imagineDoc
        furiganaDoc.sections[0].body = "東京は負けず劣らず"
        furiganaDoc.sections[0].notes = "即視感按デジャヴ来读"
        furiganaDoc.sections[1].body = "人"
        let sectionFuri = ImagineWorkflow.compose(
            action: .furigana,
            scope: .section("s1"),
            document: furiganaDoc,
            targetLanguage: "",
            userPrompt: ""
        )!
        expect(sectionFuri.system.contains("平假名"), "furigana reference requires hiragana by default")
        expect(sectionFuri.system.contains("义训"), "furigana reference allows gikun")
        expect(sectionFuri.system.contains("熟字训"), "furigana reference allows jukujikun")
        expect(sectionFuri.system.contains("デジャヴ"), "furigana reference names 即視感 as katakana")
        expect(sectionFuri.system.contains("禁止候选"), "furigana reference forbids candidates")
        expect(sectionFuri.system.contains("｜"), "furigana reference uses ｜ pairs")
        expect(!sectionFuri.system.contains("信达雅"), "furigana reference is not the translation one")
        expect(sectionFuri.user.contains("東京は負けず劣らず"), "section furigana sends that section")
        expect(sectionFuri.user.contains("即視感按デジャヴ来读"), "section furigana sends that section's notes")
        expect(sectionFuri.user.contains("雨夜"), "section furigana sends ideas as context")
        expect(!sectionFuri.user.contains("Section: s2"), "section furigana does not send the other section")
        expect(!sectionFuri.user.contains("beta line"), "section furigana does not send the other section lyrics")
        expect(!sectionFuri.user.contains("keep"), "section furigana does not send the other section's notes")
        let wholeFuri = ImagineWorkflow.compose(
            action: .furigana,
            scope: .song,
            document: furiganaDoc,
            targetLanguage: "",
            userPrompt: "用词的常见读音"
        )!
        expect(wholeFuri.user.contains("東京は負けず劣らず") && wholeFuri.user.contains("人"), "whole-song furigana sends every lyrics section")
        expect(wholeFuri.user.contains("即視感按デジャヴ来读") && wholeFuri.user.contains("keep"), "whole-song furigana sends notes")
        expect(wholeFuri.user.contains("雨夜"), "whole-song furigana sends ideas")
        expect(wholeFuri.user.contains("用词的常见读音"), "furigana user prompt is included")
        expect(ImagineWorkflow.compose(action: .furigana, scope: .section("s2"), document: blankLyricsDoc, targetLanguage: "", userPrompt: "") == nil, "empty lyrics are not sent for furigana")
        let placedFuri = ImagineWorkflow.apply(
            reply: """
            Section: s1
            Ruby:
            東京｜とうきょう
            負｜ま
            劣｜おと
            Section: s2
            Ruby:
            人｜ひと
            """,
            action: .furigana,
            scope: .section("s1"),
            document: furiganaDoc
        )
        expectEqual(placedFuri.sections[0].annotations.count, 3, "section furigana writes three readings")
        expectEqual(placedFuri.sections[0].annotations[0].original, "東京", "first reading is 東京")
        expectEqual(placedFuri.sections[0].annotations[0].phonetic, "とうきょう", "東京 reading is hiragana")
        expectEqual(placedFuri.sections[0].annotations[0].rangeStart, 0, "東京 starts at 0")
        expectEqual(placedFuri.sections[0].annotations[0].rangeLength, 2, "東京 length is 2")
        expectEqual(placedFuri.sections[0].annotations[1].original, "負", "second reading is 負")
        expectEqual(placedFuri.sections[0].annotations[1].rangeStart, 3, "負 follows 東京は")
        expectEqual(placedFuri.sections[0].annotations[2].original, "劣", "third reading is 劣")
        expectEqual(placedFuri.sections[0].body, "東京は負けず劣らず", "furigana does not rewrite lyrics")
        expectEqual(placedFuri.sections[1].annotations.count, 0, "section furigana does not write the other section")
        let candidateFuri = ImagineWorkflow.apply(
            reply: "Section: s2\nRuby:\n人｜ひと/にん\n四｜し/よん",
            action: .furigana,
            scope: .section("s2"),
            document: furiganaDoc
        )
        expectEqual(candidateFuri.sections[1].annotations.first?.phonetic ?? "", "ひと", "candidate slash keeps the first hiragana")
        let skippedLatin = ImagineWorkflow.apply(
            reply: "Section: s1\nRuby:\n東京｜Tokyo",
            action: .furigana,
            scope: .section("s1"),
            document: furiganaDoc
        )
        expectEqual(skippedLatin.sections[0].annotations.count, 0, "latin-only readings are not written")
        var gikunDoc = furiganaDoc
        gikunDoc.sections[0].body = "即視感と黃金週"
        let gikunFuri = ImagineWorkflow.apply(
            reply: "Section: s1\nRuby:\n即視感｜デジャヴ\n黃金週｜ゴールデンウィーク",
            action: .furigana,
            scope: .section("s1"),
            document: gikunDoc
        )
        expectEqual(gikunFuri.sections[0].annotations.count, 2, "gikun katakana readings are written")
        expectEqual(gikunFuri.sections[0].annotations[0].phonetic, "デジャヴ", "即視感 reading is デジャヴ")
        expectEqual(gikunFuri.sections[0].annotations[1].phonetic, "ゴールデンウィーク", "黃金週 reading is ゴールデンウィーク")
        let okuri = ImagineWorkflow.placeRuby(
            lyrics: "負けず劣らず",
            pairs: [("負", "まけず"), ("劣", "おとらず")]
        )
        expectEqual(okuri.count, 2, "okurigana pairs are placed")
        expectEqual(okuri[0].phonetic, "ま", "負 does not repeat けず")
        expectEqual(okuri[0].original, "負", "負けず shrinks to 負")
        expectEqual(okuri[1].phonetic, "おと", "劣 does not repeat らず")
        let duplicate = ImagineWorkflow.placeRuby(
            lyrics: "即視感デジャヴ",
            pairs: [("即視感", "デジャヴ")]
        )
        expectEqual(duplicate.count, 0, "a reading that already sits beside the kanji is dropped")
        let shrunk = ImagineWorkflow.placeRuby(
            lyrics: "負けず劣らず",
            pairs: [("負けず", "まけず")]
        )
        expectEqual(shrunk.count, 1, "負けず as original still places")
        expectEqual(shrunk[0].original, "負", "leading kana is not part of the ruby base")
        expectEqual(shrunk[0].phonetic, "ま", "reading drops the okurigana copied from the lyrics")
        let songFuri = ImagineWorkflow.apply(
            reply: "Section: s1\nRuby:\n東京｜とうきょう\nSection: s2\nRuby:\n人｜ひと",
            action: .furigana,
            scope: .song,
            document: furiganaDoc
        )
        expectEqual(songFuri.sections[0].annotations.first?.phonetic ?? "", "とうきょう", "whole-song furigana writes s1")
        expectEqual(songFuri.sections[1].annotations.first?.phonetic ?? "", "ひと", "whole-song furigana writes s2")
        expect(wholeFuri.user.contains("不要只做第一段"), "whole-song furigana tells the model not to stop at the first section")
        expect(wholeFuri.user.contains("Index: 1") && wholeFuri.user.contains("Index: 2"), "whole-song furigana numbers every lyrics section")
        expect(sectionFuri.system.contains("不得漏段"), "furigana reference forbids skipping later sections")
        expect(offCompose.user.contains("不要写成 [custom]"), "create without current format forbids [custom] markers")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: ""), "Verse", "blank marker is the default verse")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: "[Chorus]"), "Chorus", "[Chorus] is Chorus")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: "[Chorus 2]"), "Chorus", "[Chorus 2] stays Chorus")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: "[Bridge]"), "Bridge", "[Bridge] is Bridge")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: "主歌"), "Verse", "主歌 maps to Verse")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: "副歌"), "Chorus", "副歌 maps to Chorus")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: "[custom]"), "Custom", "[custom] stays Custom only when named that")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: "[Rap]"), "Custom", "unknown tags are Custom")
        var numberedFuriDoc = uuidDoc
        numberedFuriDoc.sections[0].body = "東京は空"
        numberedFuriDoc.sections[1].body = "人"
        let numberedFuri = ImagineWorkflow.apply(
            reply: """
            Section: 1
            Ruby:
            東京｜とうきょう
            Section: 2
            Ruby:
            人｜ひと
            """,
            action: .furigana,
            scope: .song,
            document: numberedFuriDoc
        )
        expectEqual(numberedFuri.sections[0].annotations.first?.phonetic ?? "", "とうきょう", "Section: 1 furigana writes the first UUID section")
        expectEqual(numberedFuri.sections[1].annotations.first?.phonetic ?? "", "ひと", "Section: 2 furigana writes the second UUID section")
        let markerPlaced = ImagineWorkflow.apply(
            reply: """
            Section: 1
            Marker: [Chorus]
            Lyrics:
            new front
            Section: 2
            Marker: [Bridge]
            Lyrics:
            new back
            """,
            action: .create,
            scope: .song,
            document: mixedFormat,
            keepCurrentFormat: false
        )
        expectEqual(markerPlaced.sections[0].marker, "[Chorus]", "create copies Chorus Marker onto a new slot")
        expectEqual(markerPlaced.sections[1].marker, "[Bridge]", "create copies Bridge Marker onto the next slot")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: markerPlaced.sections[0].marker), "Chorus", "Chorus Marker is not Custom")
        expectEqual(ImagineWorkflow.sectionTypeName(fromMarker: markerPlaced.sections[1].marker), "Bridge", "Bridge Marker is not Custom")
        expect(sectionCreate.system.contains("Ruby:"), "create reference includes a Ruby field")
        expect(sectionCreate.system.contains("汉字｜读音"), "create reference uses 汉字｜读音")
        expect(sectionCreate.system.contains("日语歌默认注音"), "create reference defaults Japanese songs to furigana")
        expect(sectionCreate.system.contains("不注音"), "create reference lets the user skip furigana")
        expect(sectionCreate.user.contains("这是日语歌"), "Japanese create asks for Ruby on every kanji section")
        expect(sectionCreate.user.contains("都必须输出 Ruby"), "Japanese create does not treat Ruby as optional")
        expect(ImagineWorkflow.isJapaneseLanguage("ja"), "ja is Japanese")
        expect(ImagineWorkflow.isJapaneseLanguage("ja-JP"), "ja-JP is Japanese")
        expect(ImagineWorkflow.isJapaneseLanguage("zh,ja"), "ja among languages is Japanese")
        expect(ImagineWorkflow.isJapaneseLanguage("日本語"), "日本語 is Japanese")
        expect(!ImagineWorkflow.isJapaneseLanguage("en"), "en is not Japanese")
        expect(!ImagineWorkflow.isJapaneseLanguage(""), "empty language is not Japanese")
        expect(ImagineWorkflow.asksToSkipFurigana("不注音"), "不注音 skips furigana")
        expect(ImagineWorkflow.asksToSkipFurigana("不要ふりがな"), "不要ふりがな skips furigana")
        expect(ImagineWorkflow.asksToSkipFurigana("no furigana please"), "no furigana skips furigana")
        expect(!ImagineWorkflow.asksToSkipFurigana("更口语一点"), "an ordinary prompt does not skip furigana")
        expect(!ImagineWorkflow.asksToSkipFurigana(""), "empty prompt does not skip furigana")
        let skipFuri = ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: imagineDoc,
            targetLanguage: "",
            userPrompt: "不注音"
        )!
        expect(skipFuri.user.contains("禁止输出 Ruby"), "user saying 不注音 forbids Ruby")
        expect(!skipFuri.user.contains("都必须输出 Ruby"), "skipping furigana does not demand Ruby")
        var englishDoc = imagineDoc
        englishDoc.languages = "en"
        let englishCreate = ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: englishDoc,
            targetLanguage: "",
            userPrompt: ""
        )!
        expect(englishCreate.user.contains("不是日语则不要输出 Ruby"), "non-Japanese create does not require Ruby")
        expect(!englishCreate.user.contains("这是日语歌"), "English songs are not treated as Japanese")
        var blankLang = imagineDoc
        blankLang.languages = ""
        let blankLangCreate = ImagineWorkflow.compose(
            action: .create,
            scope: .song,
            document: blankLang,
            targetLanguage: "",
            userPrompt: ""
        )!
        expect(blankLangCreate.user.contains("若写成日语"), "blank language still notes the Japanese default")
        var annotatedDoc = furiganaDoc
        annotatedDoc.sections[0].annotations = [
            ImagineRuby(rangeStart: 0, rangeLength: 2, original: "東京", phonetic: "とうきょう")
        ]
        let createSeesRuby = ImagineWorkflow.compose(
            action: .create,
            scope: .section("s1"),
            document: annotatedDoc,
            targetLanguage: "",
            userPrompt: ""
        )!
        expect(createSeesRuby.user.contains("東京｜とうきょう"), "create compose sends existing readings")
        let furiSeesRuby = ImagineWorkflow.compose(
            action: .furigana,
            scope: .section("s1"),
            document: annotatedDoc,
            targetLanguage: "",
            userPrompt: ""
        )!
        expect(furiSeesRuby.user.contains("東京｜とうきょう"), "furigana compose sends existing readings")
        let droppedRuby = ImagineWorkflow.apply(
            reply: "Section: s1\nLyrics:\n新しい歌詞",
            action: .create,
            scope: .section("s1"),
            document: annotatedDoc
        )
        expectEqual(droppedRuby.sections[0].body, "新しい歌詞", "create can rewrite lyrics")
        expectEqual(droppedRuby.sections[0].annotations.count, 0, "create that rewrites lyrics drops old readings")
        let createdRuby = ImagineWorkflow.apply(
            reply: "Section: s1\nLyrics:\n東京は空\nRuby:\n東京｜とうきょう",
            action: .create,
            scope: .section("s1"),
            document: annotatedDoc
        )
        expectEqual(createdRuby.sections[0].body, "東京は空", "create with Ruby keeps the new lyrics")
        expectEqual(createdRuby.sections[0].annotations.count, 1, "create with Ruby writes the reading")
        expectEqual(createdRuby.sections[0].annotations[0].phonetic, "とうきょう", "create Ruby uses 汉字｜读音")
        let songCreatedRuby = ImagineWorkflow.apply(
            reply: "Section: s1\nLyrics:\n東京\nRuby:\n東京｜とうきょう\nSection: s2\nLyrics:\n人",
            action: .create,
            scope: .song,
            document: annotatedDoc
        )
        expectEqual(songCreatedRuby.sections[0].annotations.first?.phonetic ?? "", "とうきょう", "whole-song create writes Ruby")
        expectEqual(songCreatedRuby.sections[1].annotations.count, 0, "whole-song create drops readings when lyrics change without Ruby")

        let savedConnection = LLMConnection(baseURL: "https://api.deepseek.com", modelName: "", apiKey: "sk-test")
        let noModel = ImagineAPI.chatRequest(connection: savedConnection, system: sectionTranslate.system, user: sectionTranslate.user)!
        expect(noModel.authorization == "Bearer sk-test", "request uses bearer auth")
        expect(noModel.url.absoluteString == "https://api.deepseek.com/v1/chat/completions", "base URL gains chat completions")
        let noModelJSON = (try? JSONSerialization.jsonObject(with: Data(noModel.body.utf8))) as? [String: Any] ?? [:]
        expect(noModelJSON["model"] == nil, "empty model name is omitted")
        expect(!noModel.body.contains("deepseek-chat") && !noModel.body.contains("gpt-"), "empty model name is not invented")
        let named = ImagineAPI.chatRequest(
            connection: LLMConnection(baseURL: "https://api.openai.com/v1", modelName: "demo-model", apiKey: "sk-test"),
            system: "s",
            user: "u"
        )!
        let namedJSON = (try? JSONSerialization.jsonObject(with: Data(named.body.utf8))) as? [String: Any] ?? [:]
        expectEqual(namedJSON["model"] as? String, "demo-model", "filled model name is sent")
        expect(named.url.absoluteString == "https://api.openai.com/v1/chat/completions", "v1 base URL is not doubled")
        expect(ImagineAPI.chatRequest(connection: LLMConnection(baseURL: "", modelName: "", apiKey: "sk-test"), system: "s", user: "u") == nil, "missing URL does not build a request")
        expect(ImagineAPI.chatRequest(connection: LLMConnection(baseURL: "https://api.deepseek.com", modelName: "should-not-send", apiKey: ""), system: "s", user: "u") == nil, "missing key does not build a request")

        let okTrace = ImagineAPI.check(connection: savedConnection) { _ in
            ImagineHTTPResult(status: 200, body: "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}")
        }
        expectEqual(okTrace.outcome, .success, "accepted configuration reports success")
        expect(okTrace.request?.body.contains("\"model\"") == false, "success check does not invent a model")
        let rejected = ImagineAPI.check(connection: savedConnection) { _ in
            ImagineHTTPResult(status: 401, body: "{\"error\":{\"message\":\"no\"}}")
        }
        expectEqual(rejected.outcome, .failure, "rejected configuration reports failure")
        let missingConnection = ImagineAPI.check(connection: LLMConnection(baseURL: "", modelName: "", apiKey: "")) { _ in
            ImagineHTTPResult(status: 200, body: "{\"model\":\"gpt-4\"}")
        }
        expectEqual(missingConnection.outcome, ImagineCheckOutcome.failure, "missing key and URL report failure")
        expect(missingConnection.request == nil, "missing configuration does not substitute a model")

        // MARK: right column width and enter edge
        let settingsColumn = RightColumnMetrics.layout(for: .settings)
        expectEqual(settingsColumn.minWidth, CGFloat(480), "settings locks minimum width to the settings page")
        expectEqual(settingsColumn.idealWidth, CGFloat(480), "settings locks ideal width to the settings page")
        expectEqual(settingsColumn.maxWidth, CGFloat(480), "settings locks maximum width to the settings page")
        expectEqual(settingsColumn.enterEdge, .bottom, "settings enters from the bottom")
        expectEqual(settingsColumn.leaveEdge, .bottom, "settings leaves toward the bottom")
        let ideaColumn = RightColumnMetrics.layout(for: .idea)
        expectEqual(ideaColumn.minWidth, CGFloat(320), "idea keeps minimum 320")
        expectEqual(ideaColumn.idealWidth, CGFloat(320), "idea default width is the narrowest")
        expectEqual(ideaColumn.maxWidth, CGFloat(320), "idea stays at the narrowest, not the settings width")
        expect(ideaColumn.idealWidth != settingsColumn.idealWidth, "idea default is not the settings width")
        expectEqual(ideaColumn.enterEdge, .leading, "灵感设定 enters from the leading edge")
        let previewColumn = RightColumnMetrics.layout(for: .preview)
        expectEqual(previewColumn.minWidth, CGFloat(320), "preview keeps minimum 320")
        expectEqual(previewColumn.idealWidth, CGFloat(320), "preview default width is the narrowest")
        expectEqual(previewColumn.maxWidth, CGFloat(320), "preview stays at the narrowest, not the settings width")
        expectEqual(previewColumn.enterEdge, .trailing, "歌词预览 enters from the trailing edge")
        let offColumn = RightColumnMetrics.layout(for: .off)
        expectEqual(offColumn.minWidth, CGFloat(0), "off width minimum is 0")
        expectEqual(offColumn.idealWidth, CGFloat(0), "off width ideal is 0")
        expectEqual(offColumn.maxWidth, CGFloat(0), "off width maximum is 0")
        expectEqual(offColumn.enterEdge, .none, "off has no enter edge")

        // MARK: font scale metrics
        expectEqual(AppFontMetrics.clamp(0.5), AppFontMetrics.minScale, "clamp below min")
        expectEqual(AppFontMetrics.clamp(2), AppFontMetrics.maxScale, "clamp above max")
        expectEqual(AppFontMetrics.clamp(1), AppFontMetrics.defaultScale, "clamp default")
        expectEqual(AppFontMetrics.size(13, scale: 1), CGFloat(13), "body size at default")
        expectEqual(AppFontMetrics.size(9, scale: 0.85), CGFloat(9), "does not go below 9pt")
        expect(AppFontMetrics.size(13, scale: 1.35) > 13, "large type increases point size")
        expectEqual(AppFontMetrics.changelogFrame.minWidth, CGFloat(560), "changelog window min width is fixed")
        expectEqual(AppFontMetrics.usageGuideFrame.minWidth, CGFloat(560), "usage guide window min width is fixed")
        expectEqual(AppFontMetrics.skillExportFrame.minWidth, CGFloat(720), "skill window min width is fixed")
        expectEqual(RightColumnMetrics.layout(for: .settings).minWidth, CGFloat(480), "settings column stays 480")
        expectEqual(RightColumnMetrics.layout(for: .idea).minWidth, CGFloat(320), "idea column stays 320")
        expectEqual(AppFontMetrics.dialogWidth, CGFloat(420), "dialog width is fixed")
        expectEqual(AppFontMetrics.mainMinWidth, CGFloat(1280), "main min width is fixed")
        expectEqual(AppFontMetrics.mainMinHeight, CGFloat(680), "main min height is fixed")
        let screen = CGRect(x: 0, y: 25, width: 1728, height: 1070)
        expectEqual(MainWindowLaunch.frame(fitting: screen), screen, "launch frame fills the visible screen")
        let fallback = MainWindowLaunch.frame(fitting: .zero)
        expectEqual(fallback.width, AppFontMetrics.mainMinWidth, "missing screen falls back to min width")
        expectEqual(fallback.height, AppFontMetrics.mainMinHeight, "missing screen falls back to min height")

        func hasHangul(_ s: String) -> Bool {
            s.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
        }
        let uiLangs: [AppLanguage] = [.simplifiedChinese, .traditionalChinese, .english, .japanese, .korean, .spanish]
        for entry in ChangelogContent.entries {
            let zh = entry.markdown(for: .simplifiedChinese)
            let ko = entry.markdown(for: .korean)
            let es = entry.markdown(for: .spanish)
            expect(ko != zh, "\(entry.version) Korean changelog is not the 简体 fallback")
            expect(es != zh, "\(entry.version) Spanish changelog is not the 简体 fallback")
            expect(hasHangul(ko), "\(entry.version) Korean changelog is Korean")
            for lang in uiLangs {
                let body = entry.markdown(for: lang).trimmingCharacters(in: .whitespacesAndNewlines)
                expect(!body.isEmpty, "\(entry.version) \(lang.rawValue) changelog is non-empty")
            }
        }
        for row in ChangelogContent.displayedEntries {
            let zh = row.markdown(for: .simplifiedChinese)
            let ko = row.markdown(for: .korean)
            let es = row.markdown(for: .spanish)
            expect(ko != zh, "displayed \(row.version) Korean changelog is translated")
            expect(es != zh, "displayed \(row.version) Spanish changelog is translated")
            expect(hasHangul(ko), "displayed \(row.version) Korean changelog stays Korean after folding")
            for lang in uiLangs {
                let body = row.markdown(for: lang).trimmingCharacters(in: .whitespacesAndNewlines)
                expect(!body.isEmpty, "displayed \(row.version) \(lang.rawValue) changelog is non-empty")
            }
        }

        print("----")
        print("passed=\(passed) failed=\(failed)")
        if failed > 0 {
            exit(1)
        }
    }
}
