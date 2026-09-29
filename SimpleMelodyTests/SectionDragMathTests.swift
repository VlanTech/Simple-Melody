// SimpleMelodyTests/SectionDragMathTests.swift
// Compiles against the shipped Engine/SectionDragMath.swift (not a reimplementation).
//
//   swiftc -o section-drag-tests \
//     SimpleMelody/Engine/SectionDragMath.swift \
//     SimpleMelodyTests/SectionDragMathTests.swift
//   ./section-drag-tests

import Foundation
import CoreGraphics

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

        // MARK: v1.8.0 version compare + GitHub payload (injected)

        expectEqual(AppReleaseMath.displayVersion, "v1.8.2", "display version is v1.8.2")
        expectEqual(AppReleaseMath.marketingVersion, "1.8.2", "marketing version is 1.8.2")
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

        // MARK: v1.8.2 identity and changelog
        expectEqual(AppReleaseMath.displayVersion, "v1.8.2", "shipped display version")
        expectEqual(AppReleaseMath.marketingVersion, "1.8.2", "shipped marketing version")
        let shown = ChangelogContent.displayedEntries
        let latest = shown.filter(\.isLatest)
        expectEqual(latest.map(\.version), ["v1.8.2"], "only latest changelog row is v1.8.2")
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
        expectEqual(bodies.filter { !$0.isEmpty }.count, 6, "v1.8.2 has six language bodies")
        let imagineNotes = [
            ["Imagine", "Imagine", "Imagine", "Imagine", "Imagine", "Imagine"],
            ["翻译", "翻譯", "Translation", "翻訳", "번역", "raducción"],
            ["创意", "創意", "Creative", "創作", "창작", "reativo"],
            ["模型名", "模型", "model name", "モデル名", "모델", "modelo"],
            ["测试", "測試", "Test connection", "接続", "연결", "robar"],
            ["依照当前格式", "依照當前格式", "current format", "形式に合わせる", "현재 형식", "formato actual"],
            ["拆开", "拆開", "in order", "分けて", "나눠", "en orden"],
            ["无法撤销", "無法撤銷", "irreversible", "取り消せ", "되돌릴", "deshacerse"],
            ["段落Imagine", "段落Imagine", "Section Imagine", "段落 Imagine", "단락 Imagine", "Imagine de sección"],
            ["文风", "文風", "style", "文風", "문체", "estilo"],
            ["歌名", "歌名", "title", "曲名", "제목", "título"],
            ["滑块", "滑桿", "slider", "スライダー", "슬라이더", "deslizante"],
            ["字体大小", "字體大小", "font size", "フォントサイズ", "글자 크기", "tamaño de letra"],
            ["窗口和分栏宽度不变", "視窗和分欄寬度不變", "stay put", "そのまま", "그대로", "no se mueven"],
            ["铺满屏幕", "鋪滿螢幕", "fills the screen", "画面いっぱい", "화면을 채", "llena la pantalla"],
        ]
        for (index, body) in bodies.enumerated() {
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
        let columnNotes = [
            ["右边栏", "右邊欄", "right column", "右カラム", "오른쪽 열", "columna derecha"],
            ["宽度", "寬度", "width", "幅", "너비", "anchura"],
            ["下往上", "下往上", "bottom", "下から", "아래", "abajo"],
            ["文件处理", "檔案處理", "handle files", "ファイル", "파일", "archivos"],
        ]
        for (index, body) in previousBodies.enumerated() {
            for phrases in columnNotes {
                expect(body.contains(phrases[index]), "v1.8.1 body \(index) mentions \(phrases[index])")
            }
            expect(!body.contains("##"), "v1.8.1 source body \(index) has no markdown heading")
            expect(!body.contains("**"), "v1.8.1 source body \(index) has no markdown bold")
            expect(!body.contains("`"), "v1.8.1 source body \(index) has no backticks")
        }
        let settingsNotes = [
            ["关闭", "關閉", "close button", "閉じる", "닫기", "cerrar"],
            ["跟随系统", "跟隨系統", "Follow System", "システムに合わせる", "시스템을 따름", "Seguir el sistema"],
            ["列表", "列表", "list", "リスト", "목록", "lista"],
            ["二级菜单", "二級選單", "second-level menu", "二次メニュー", "2단 메뉴", "segundo nivel"],
            ["API Key", "API Key", "API key", "API キー", "API 키", "clave de API"],
        ]
        for (index, body) in previousBodies.enumerated() {
            for phrases in settingsNotes {
                expect(body.contains(phrases[index]), "v1.8.1 body \(index) mentions \(phrases[index])")
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
