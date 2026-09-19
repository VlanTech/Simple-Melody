// Engine/SectionDragMath.swift
// v1.7.10 Extra: pure helpers for section drop-insert, auto-scroll edge, and lyrics-drop rejection.
// SongEditorView / PassthroughTextView call these; tests compile this same file.

import Foundation
import CoreGraphics

enum SectionDragMath {
    /// Custom pasteboard / UTType id for section drag. Not `public.utf8-plain-text`,
    /// so NSTextView does not treat the payload as insertable lyrics.
    static let sectionIDTypeIdentifier = "com.simplemelody.section-id"

    /// Distance from the scroll view's top edge that starts auto-scroll (points).
    static let defaultTopEdgeThreshold: CGFloat = 50

    /// Auto-scroll tick distance (points).
    static let defaultScrollDelta: CGFloat = 32

    // MARK: Drop insert

    /// `true` when the drop is on the top half of the target (insert before).
    /// Equal-to-midpoint counts as after.
    static func insertsBefore(dropY: CGFloat, targetMidY: CGFloat) -> Bool {
        dropY < targetMidY
    }

    /// Insertion index in `filteredOrder` (dragged items already removed).
    /// Returns nil when the drop cannot be applied.
    static func insertIndex(
        targetIndex: Int,
        dropY: CGFloat,
        targetMidY: CGFloat,
        filteredCount: Int
    ) -> Int? {
        guard filteredCount >= 0, targetIndex >= 0, targetIndex < filteredCount else { return nil }
        let raw = insertsBefore(dropY: dropY, targetMidY: targetMidY) ? targetIndex : targetIndex + 1
        return min(max(raw, 0), filteredCount)
    }

    /// Full reorder. Returns nil for empty drag, self-only drop, or missing target.
    /// Dragged IDs that equal `targetID` are ignored (self-drop no-op if nothing else is dragged).
    static func reorderedIDs(
        orderedIDs: [UUID],
        draggedIDs: [UUID],
        targetID: UUID,
        dropY: CGFloat,
        targetMidY: CGFloat
    ) -> [UUID]? {
        let draggedOthers = Set(draggedIDs).subtracting([targetID])
        guard !draggedOthers.isEmpty else { return nil }

        let filtered = orderedIDs.filter { !draggedOthers.contains($0) }
        guard let targetIndex = filtered.firstIndex(of: targetID) else { return nil }
        guard let index = insertIndex(
            targetIndex: targetIndex,
            dropY: dropY,
            targetMidY: targetMidY,
            filteredCount: filtered.count
        ) else { return nil }

        let draggedInOrder = orderedIDs.filter { draggedOthers.contains($0) }
        var result = filtered
        for (offset, id) in draggedInOrder.enumerated() {
            result.insert(id, at: min(index + offset, result.count))
        }
        return result
    }

    // MARK: Auto-scroll edge (Cocoa window space: origin bottom-left)

    /// Whether the mouse is inside the scroll view and within `threshold` of its **top** edge.
    /// `mouseInWindow` and `scrollViewInWindow` are both window coordinates (y up).
    static func isInTopAutoScrollEdge(
        mouseInWindow: CGPoint,
        scrollViewInWindow: CGRect,
        threshold: CGFloat
    ) -> Bool {
        guard scrollViewInWindow.width > 0, scrollViewInWindow.height > 0, threshold > 0 else {
            return false
        }
        let inX = mouseInWindow.x >= scrollViewInWindow.minX && mouseInWindow.x <= scrollViewInWindow.maxX
        let inY = mouseInWindow.y >= scrollViewInWindow.minY && mouseInWindow.y <= scrollViewInWindow.maxY
        guard inX && inY else { return false }
        let distanceFromTop = scrollViewInWindow.maxY - mouseInWindow.y
        return distanceFromTop >= 0 && distanceFromTop < threshold
    }

    /// Next clip-view origin Y when auto-scrolling **up** (reveal content above).
    static func nextScrollOriginY(
        currentY: CGFloat,
        isFlipped: Bool,
        delta: CGFloat,
        documentHeight: CGFloat,
        clipHeight: CGFloat
    ) -> CGFloat {
        if isFlipped {
            return max(0, currentY - delta)
        }
        let maxY = max(0, documentHeight - clipHeight)
        return min(maxY, currentY + delta)
    }

    /// Previous section index for proxy-based fallback scroll. Nil at the top.
    static func previousSectionIndex(currentIndex: Int) -> Int? {
        guard currentIndex > 0 else { return nil }
        return currentIndex - 1
    }

    // MARK: Auto-scroll during NSDragging (event-tracking run loop)

    enum DragEventKind: Equatable {
        case leftMouseDragged
        case leftMouseUp
        case other
    }

    enum DragAutoScrollCommand: Equatable {
        /// Scroll on this event, then keep a timer running for held-still hover.
        case scrollNowAndEnsureTimer
        case stopTimer
        case ignore
    }

    /// Same raw value as AppKit `RunLoop.Mode.eventTracking` / `NSEventTrackingRunLoopMode`.
    /// Declared as a string so this file stays Foundation-only for tests.
    static let eventTrackingRunLoopMode = RunLoop.Mode(rawValue: "NSEventTrackingRunLoopMode")

    /// Modes the auto-scroll timer must be added to. `.common` includes default;
    /// event-tracking is required because NSDragging runs `NSEventTrackingRunLoopMode`
    /// (a default-mode-only `Timer.scheduledTimer` will not fire).
    static let autoScrollTimerRunLoopModes: [RunLoop.Mode] = [.common, eventTrackingRunLoopMode]

    /// Decision table used by `DragAutoScroller.handleEvent` on the same stack as the NSEvent monitor.
    static func commandForDragEvent(kind: DragEventKind, inTopEdge: Bool) -> DragAutoScrollCommand {
        switch kind {
        case .leftMouseDragged:
            return inTopEdge ? .scrollNowAndEnsureTimer : .stopTimer
        case .leftMouseUp:
            return .stopTimer
        case .other:
            return .ignore
        }
    }

    /// Repeating timer that fires inside the drag tracking loop. Does **not** use
    /// `Timer.scheduledTimer` (default mode only). Caller must `invalidate()`.
    @discardableResult
    static func scheduleAutoScrollTimer(
        interval: TimeInterval,
        on runLoop: RunLoop = .main,
        action: @escaping () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            action()
        }
        for mode in autoScrollTimerRunLoopModes {
            runLoop.add(timer, forMode: mode)
        }
        return timer
    }

    // MARK: Lyrics drop rejection

    /// True when `string` is a section-id UUID (the old String-drag payload).
    static func isSectionIDPayload(_ string: String) -> Bool {
        UUID(uuidString: string.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    /// Lyrics NSTextView should refuse this drop.
    static func shouldRejectLyricsDrop(pasteboardStrings: [String], pasteboardTypeIDs: [String]) -> Bool {
        if pasteboardTypeIDs.contains(sectionIDTypeIdentifier) {
            return true
        }
        return pasteboardStrings.contains { isSectionIDPayload($0) }
    }

    static func shouldAcceptLyricsStringDrop(_ string: String) -> Bool {
        !isSectionIDPayload(string)
    }
}
