// 段落放下插入、顶部自动滚动，以及歌词框拒绝段落拖放。编辑器和测试共用这一份。

import Foundation
import CoreGraphics

enum SectionDragMath {
    /// 段落拖放的专用类型标识。不用纯文本，避免歌词框把段落编号当成歌词插进去。
    static let sectionIDTypeIdentifier = "com.simplemelody.section-id"

    /// 距滚动视图顶边多少点开始自动滚动。
    static let defaultTopEdgeThreshold: CGFloat = 50

    /// 自动滚动每步的距离（点）。
    static let defaultScrollDelta: CGFloat = 32

    /// 左键拖动超过这一点才算重排，避免和点按放光标打架。
    static let sectionReorderSlop: CGFloat = 4

    /// 右键要拖过这么远，才把 Imagine / 删除滑出来。没拖过就仍是右键菜单。
    static let sectionRevealMinimum: CGFloat = 40

    /// 左键是重排。右键是滑出按钮；触控板双指拖动若被系统报成右键，也走这一侧。
    enum SectionPointerButton: Equatable {
        case primary
        case secondary
    }

    enum SectionGestureIntent: Equatable {
        case reorder
        case revealImagine
        case revealDelete
        case contextMenu
        case pending
    }

    static func sectionPointerButton(rightButton: Bool) -> SectionPointerButton {
        rightButton ? .secondary : .primary
    }

    /// 按住并移动之后才区分动作。左键拖动只重排；右键拖动只滑出按钮。
    /// 右键松开且没有拖成水平滑动时，仍是段落菜单。
    static func sectionGestureIntent(
        button: SectionPointerButton,
        translationX: CGFloat,
        translationY: CGFloat,
        ended: Bool,
        alreadyRevealing: Bool = false
    ) -> SectionGestureIntent {
        switch button {
        case .primary:
            if hypot(translationX, translationY) >= sectionReorderSlop {
                return .reorder
            }
            return .pending
        case .secondary:
            if alreadyRevealing {
                return translationX >= 0 ? .revealImagine : .revealDelete
            }
            let horizontal = abs(translationX) >= sectionRevealMinimum
                && abs(translationX) > abs(translationY) * 2
            if !horizontal {
                return ended ? .contextMenu : .pending
            }
            return translationX > 0 ? .revealImagine : .revealDelete
        }
    }

    /// 不按下的双指拖动走滚轮。自然滚动时增量已经跟手指同向，关掉自然滚动时要翻回来。
    static func trackpadFingerDelta(
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        naturalScrolling: Bool
    ) -> (x: CGFloat, y: CGFloat) {
        if naturalScrolling {
            return (scrollingDeltaX, scrollingDeltaY)
        }
        return (-scrollingDeltaX, -scrollingDeltaY)
    }

    /// 触控板不按下的双指滑动。竖直的仍滚动页面；水平的滑出按钮，不开右键菜单，也不重排。
    enum TrackpadSectionScroll: Equatable {
        case pass
        case hold
        case reveal(SectionGestureIntent)
    }

    static func trackpadSectionScroll(
        fingerX: CGFloat,
        fingerY: CGFloat,
        ended: Bool,
        alreadyRevealing: Bool = false
    ) -> TrackpadSectionScroll {
        let intent = sectionGestureIntent(
            button: .secondary,
            translationX: fingerX,
            translationY: fingerY,
            ended: false,
            alreadyRevealing: alreadyRevealing
        )
        switch intent {
        case .revealImagine, .revealDelete:
            return .reveal(intent)
        case .reorder:
            return .pass
        case .contextMenu, .pending:
            if abs(fingerY) >= sectionReorderSlop && abs(fingerY) > abs(fingerX) {
                return .pass
            }
            if abs(fingerX) > abs(fingerY) * 2 && abs(fingerX) >= sectionReorderSlop {
                return ended ? .pass : .hold
            }
            return .pass
        }
    }

    // MARK: 放下插入

    /// 落在目标上半部时插到前面。刚好在中线算后面。
    static func insertsBefore(dropY: CGFloat, targetMidY: CGFloat) -> Bool {
        dropY < targetMidY
    }

    /// 在已去掉被拖项的顺序里计算插入下标。放不进去时返回空。
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

    /// 完整重排。空拖动、只拖到自己身上、或找不到目标时返回空。
    /// 与目标相同的编号忽略；若除此之外没有别的项，拖到自己身上不做任何事。
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

    /// 非拖放的段落上下移动。上移、下移只和相邻段交换；至顶、至底放到同歌两端。
    /// 已经在那一端、或找不到这段时返回空，调用方不改序号。
    enum SectionOrderMove: Equatable {
        case up
        case down
        case top
        case bottom
    }

    static func sectionIDs(
        after move: SectionOrderMove,
        orderedIDs: [UUID],
        movingID: UUID
    ) -> [UUID]? {
        guard let index = orderedIDs.firstIndex(of: movingID) else { return nil }
        var result = orderedIDs
        switch move {
        case .up:
            guard index > 0 else { return nil }
            result.swapAt(index, index - 1)
        case .down:
            guard index + 1 < result.count else { return nil }
            result.swapAt(index, index + 1)
        case .top:
            guard index > 0 else { return nil }
            let id = result.remove(at: index)
            result.insert(id, at: 0)
        case .bottom:
            guard index + 1 < result.count else { return nil }
            let id = result.remove(at: index)
            result.append(id)
        }
        return result
    }

    /// 曲目库同一组歌曲的新顺序。上半插到目标前面，中线和下半插到后面。
    /// 拖动项里只有目标自己时保持原顺序。曲目行放下和测试都走这一份。
    static func reorderedSiblingIDs(
        orderedIDs: [UUID],
        draggedIDs: [UUID],
        targetID: UUID,
        dropY: CGFloat,
        targetMidY: CGFloat
    ) -> [UUID] {
        reorderedIDs(
            orderedIDs: orderedIDs,
            draggedIDs: draggedIDs,
            targetID: targetID,
            dropY: dropY,
            targetMidY: targetMidY
        ) ?? orderedIDs
    }

    /// 这次拖动算段落、歌曲，还是都不是。横条归哪一侧只看它。
    enum ReorderDragSubject: Equatable {
        case section
        case song
        case none
    }

    struct ReorderLineSides: Equatable {
        var songLibrary: Bool
        var sectionList: Bool
    }

    /// 拖段落时只有段落列表画横条；拖歌曲时只有曲目库画。都不是时两侧都不画。
    static func reorderLineSides(for subject: ReorderDragSubject) -> ReorderLineSides {
        switch subject {
        case .section:
            return ReorderLineSides(songLibrary: false, sectionList: true)
        case .song:
            return ReorderLineSides(songLibrary: true, sectionList: false)
        case .none:
            return ReorderLineSides(songLibrary: false, sectionList: false)
        }
    }

    /// 按下点是否在歌曲行里，由调用方用整行屏幕矩形（含左右边缘）判断。
    /// 只有这一下在歌曲行里才算拖歌曲。剪贴板上的编号本身不让曲目库认领横条。
    /// 新的段落类型或只含编号的 JSON 优先。过期剪贴板忽略。
    static func reorderDragSubject(
        pointerBeganInsideSongRow: Bool,
        pasteboardTypeIDs: [String],
        pasteboardStrings: [String],
        pasteboardChangeIsFresh: Bool
    ) -> ReorderDragSubject {
        if pasteboardChangeIsFresh {
            if pasteboardTypeIDs.contains(where: isSectionDragType)
                || pasteboardStrings.contains(where: isJSONSectionPayload) {
                return .section
            }
        }
        if pointerBeganInsideSongRow {
            return .song
        }
        return .none
    }

    /// 指针落在这一行里（含上下边缘）。纵坐标从上往下增大。
    static func pointerOwnsRow(dropY: CGFloat, rowHeight: CGFloat) -> Bool {
        rowHeight > 0 && dropY >= 0 && dropY <= rowHeight
    }

    /// 顶头那一首，插到前面的区域占行高的三分之二。
    static let groupTopBeforeFraction: CGFloat = 2.0 / 3.0
    /// 垫底那一首，从行高的三分之一起算插到后面。
    static let groupBottomBeforeFraction: CGFloat = 1.0 / 3.0
    /// 栏内第一首的上方、最后一首的下方，这个距离内仍算那一条边。
    static let groupEdgeSlack: CGFloat = 28

    /// 一条高亮横线的归属。同一栏里相邻两首只共用上一首的下沿。
    struct SongReorderLineSpan: Equatable {
        var id: UUID
        var minY: CGFloat
        var height: CGFloat
        /// 根目录歌曲共用一个值，每个文件夹用自己的。
        var groupID: UUID
        var isGroupTop: Bool
        var isGroupBottom: Bool
        var maxY: CGFloat { minY + height }
    }

    struct SongReorderLineWinner: Equatable {
        var id: UUID
        var insertsBefore: Bool
    }

    /// 顶头放宽上沿，垫底放宽下沿。只有一首时仍在中线分开。其余歌曲在中线分开。
    static func reorderSplitY(rowHeight: CGFloat, isGroupTop: Bool, isGroupBottom: Bool) -> CGFloat {
        guard rowHeight > 0 else { return 0 }
        if isGroupTop && !isGroupBottom {
            return rowHeight * groupTopBeforeFraction
        }
        if isGroupBottom && !isGroupTop {
            return rowHeight * groupBottomBeforeFraction
        }
        return rowHeight / 2
    }

    /// 同一栏两首之间只留上一首的下沿。下一首的上沿不画。
    /// 栏内第一首的上方、最后一首的下方用更宽的边距。
    static func exclusiveReorderClaim(
        pointerY: CGFloat,
        rows: [SongReorderLineSpan],
        edgeSlack: CGFloat = groupEdgeSlack
    ) -> SongReorderLineWinner? {
        let rows = rows.filter { $0.height > 0 }.sorted { lhs, rhs in
            if lhs.minY != rhs.minY { return lhs.minY < rhs.minY }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        guard !rows.isEmpty else { return nil }

        var inside: (span: SongReorderLineSpan, distance: CGFloat)?
        for row in rows {
            let dropY = pointerY - row.minY
            guard pointerOwnsRow(dropY: dropY, rowHeight: row.height) else { continue }
            let distance = abs(dropY - row.height / 2)
            if let current = inside {
                if distance < current.distance {
                    inside = (row, distance)
                }
            } else {
                inside = (row, distance)
            }
        }
        if let inside {
            return line(for: inside.span, dropY: pointerY - inside.span.minY, rows: rows)
        }

        var nearest: (winner: SongReorderLineWinner, distance: CGFloat, minY: CGFloat)?
        func consider(_ winner: SongReorderLineWinner, distance: CGFloat, minY: CGFloat) {
            if let current = nearest {
                let closer = distance < current.distance
                let tiePreferUpper = distance == current.distance && minY < current.minY
                if closer || tiePreferUpper {
                    nearest = (winner, distance, minY)
                }
            } else {
                nearest = (winner, distance, minY)
            }
        }

        for index in rows.indices {
            let row = rows[index]
            if index + 1 < rows.count {
                let next = rows[index + 1]
                if row.groupID == next.groupID, pointerY > row.maxY, pointerY < next.minY {
                    let distance = min(pointerY - row.maxY, next.minY - pointerY)
                    consider(
                        SongReorderLineWinner(id: row.id, insertsBefore: false),
                        distance: distance,
                        minY: row.minY
                    )
                }
            }
            if edgeSlack > 0, row.isGroupTop {
                let above = row.minY - pointerY
                if above > 0, above <= edgeSlack {
                    consider(
                        SongReorderLineWinner(id: row.id, insertsBefore: true),
                        distance: above,
                        minY: row.minY
                    )
                }
            }
            if edgeSlack > 0, row.isGroupBottom {
                let below = pointerY - row.maxY
                if below > 0, below <= edgeSlack {
                    consider(
                        SongReorderLineWinner(id: row.id, insertsBefore: false),
                        distance: below,
                        minY: row.minY
                    )
                }
            }
        }
        return nearest?.winner
    }

    /// 非顶头歌曲的“插到前面”画在同一栏上一首的下沿，避免一条缝两根线。
    private static func line(
        for row: SongReorderLineSpan,
        dropY: CGFloat,
        rows: [SongReorderLineSpan]
    ) -> SongReorderLineWinner {
        let split = reorderSplitY(
            rowHeight: row.height,
            isGroupTop: row.isGroupTop,
            isGroupBottom: row.isGroupBottom
        )
        let before = insertsBefore(dropY: dropY, targetMidY: split)
        if before, !row.isGroupTop, let previous = previousSameGroup(of: row, in: rows) {
            return SongReorderLineWinner(id: previous.id, insertsBefore: false)
        }
        return SongReorderLineWinner(id: row.id, insertsBefore: before)
    }

    private static func previousSameGroup(
        of row: SongReorderLineSpan,
        in rows: [SongReorderLineSpan]
    ) -> SongReorderLineSpan? {
        guard let index = rows.firstIndex(where: { $0.id == row.id }), index > 0 else { return nil }
        let previous = rows[index - 1]
        guard previous.groupID == row.groupID else { return nil }
        return previous
    }

    // MARK: 自动滚动边缘（窗口坐标，原点在左下）

    /// 鼠标在滚动视图内，且距顶边小于阈值。两个矩形都是窗口坐标，纵轴向上。
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

    /// 向上自动滚动时，裁剪视图下一个原点的纵坐标（露出上方内容）。
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

    /// 代理滚动用的上一段下标。已经在最上面时为空。
    static func previousSectionIndex(currentIndex: Int) -> Int? {
        guard currentIndex > 0 else { return nil }
        return currentIndex - 1
    }

    // MARK: 拖放期间的自动滚动（事件跟踪运行循环）

    enum DragEventKind: Equatable {
        case leftMouseDragged
        case leftMouseUp
        case other
    }

    enum DragAutoScrollCommand: Equatable {
        /// 这一帧先滚，再留着定时器，以便鼠标停住时继续滚。
        case scrollNowAndEnsureTimer
        case stopTimer
        case ignore
    }

    /// 与系统拖放时的事件跟踪运行循环同名。写成字符串，测试才能不依赖界面框架编译本文件。
    static let eventTrackingRunLoopMode = RunLoop.Mode(rawValue: "NSEventTrackingRunLoopMode")

    /// 自动滚动定时器必须同时加进这些模式。common 含默认模式；
    /// 拖放走的是事件跟踪模式，只登记默认模式的定时器不会触发。
    static let autoScrollTimerRunLoopModes: [RunLoop.Mode] = [.common, eventTrackingRunLoopMode]

    /// 与系统事件监视器同一层调用的决策表。
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

    /// 在拖放跟踪循环里重复触发的定时器。不用只跑默认模式的定时器。调用方必须作废它。
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

    // MARK: 歌词框拒绝段落拖放

    /// 字符串是段落编号时为真。纯文本编号、四周空白，以及只含编号的 JSON 都算。
    static func isSectionIDPayload(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if UUID(uuidString: trimmed) != nil { return true }
        let unquoted = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if unquoted != trimmed, UUID(uuidString: unquoted) != nil { return true }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object.count == 1,
              let id = object["id"] as? String,
              UUID(uuidString: id) != nil else {
            return false
        }
        return true
    }

    /// 歌词文本框应拒绝这次放下。专用类型一出现就拒绝；编号晚一点才变成字符串也拒绝。
    static func shouldRejectLyricsDrop(pasteboardStrings: [String], pasteboardTypeIDs: [String]) -> Bool {
        if pasteboardTypeIDs.contains(where: isSectionDragType) {
            return true
        }
        return pasteboardStrings.contains { isSectionIDPayload($0) }
    }

    private static func isSectionDragType(_ typeID: String) -> Bool {
        typeID == sectionIDTypeIdentifier || typeID.hasSuffix(sectionIDTypeIdentifier)
    }

    /// 只含一个 id 键、值是编号的 JSON。裸编号字符串不算，那也可能是歌曲。
    private static func isJSONSectionPayload(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{",
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object.count == 1,
              let id = object["id"] as? String,
              UUID(uuidString: id) != nil else {
            return false
        }
        return true
    }

    static func shouldAcceptLyricsStringDrop(_ string: String) -> Bool {
        !isSectionIDPayload(string)
    }
}
