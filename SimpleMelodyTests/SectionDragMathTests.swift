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

        expectEqual(AppReleaseMath.displayVersion, "v1.8.0", "display version is v1.8.0")
        expectEqual(AppReleaseMath.marketingVersion, "1.8.0", "marketing version is 1.8.0")
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

        print("----")
        print("passed=\(passed) failed=\(failed)")
        if failed > 0 {
            exit(1)
        }
    }
}
