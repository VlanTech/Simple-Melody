// Settings/ChangelogView.swift
// 更新日志窗口（支持 Markdown 渲染）
// v1.4: 改为独立 Window scene，自带标题栏 + cmd+W 正常工作
// 每次更新必须把新版本接在上方，不删除旧版本

import SwiftUI

// MARK: - 独立 Window（用 WindowGroup 是为了 v1.4 beta 兼容性；macOS 14+ 可改用 Window）

struct ChangelogWindow: View {
 var body: some View {
 ChangelogView()
 .frame(minWidth: 560, idealWidth: 640, maxWidth: 720,
 minHeight: 420, idealHeight: 560, maxHeight: 720)
 }
}

// MARK: - 视图本体

struct ChangelogView: View {
 @Environment(\.dismiss) private var dismiss
 @Environment(\.colorScheme) private var colorScheme
 @ObservedObject private var loc = LocalizationManager.shared

 var body: some View {
 VStack(spacing: 0) {
 // Header
 HStack(spacing: 10) {
 Image(systemName: "doc.text.magnifyingglass")
 .font(.system(size: 18, weight: .medium))
 .foregroundStyle(.tint)
 Text(L("更新日志"))
 .font(.system(size: 16, weight: .semibold))
 Spacer()
 Button {
 dismiss()
 } label: {
 HStack(spacing: 4) {
 Image(systemName: "xmark")
 .imageScale(.small)
 Text(L("关闭"))
 .font(.system(size: 12, weight: .medium))
 }
 .padding(.horizontal, 10)
 .padding(.vertical, 5)
 .background(
 RoundedRectangle(cornerRadius: 6)
 .fill(Color.secondary.opacity(0.1))
 )
 .foregroundStyle(.secondary)
 }
 .buttonStyle(.plain)
 .keyboardShortcut(.cancelAction)
 .help(L("关闭（⌘W）"))
 }
 .padding(.horizontal, 20)
 .padding(.vertical, 12)
 .background(.regularMaterial)

 Divider()

 // Markdown 内容
 ScrollView {
 VStack(alignment: .leading, spacing: 0) {
 ForEach(ChangelogContent.entries) { entry in
 changelogEntryView(entry, lang: loc.language)
 if entry.id != ChangelogContent.entries.last?.id {
 Divider()
 .padding(.horizontal, 20)
 }
 }
 }
 .padding(.horizontal, 24)
 .padding(.vertical, 16)
 .frame(maxWidth: .infinity, alignment: .leading)
 }
 .background(Color(NSColor.textBackgroundColor))
 }
 }

 @ViewBuilder
 private func changelogEntryView(_ entry: ChangelogContent.Entry, lang: AppLanguage) -> some View {
 VStack(alignment: .leading, spacing: 8) {
 // 版本头
 HStack(alignment: .firstTextBaseline, spacing: 8) {
 Text(entry.version)
 .font(.system(size: 18, weight: .bold, design: .rounded))
 .foregroundStyle(.tint)
 Text(entry.date)
 .font(.caption.monospacedDigit())
 .foregroundStyle(.secondary)
 if entry.isLatest {
 Text(L("最新"))
 .font(.caption2.weight(.semibold))
 .padding(.horizontal, 6)
 .padding(.vertical, 2)
 .background(Capsule().fill(Color.accentColor.opacity(0.18)))
 .foregroundStyle(.tint)
 }
 Spacer()
 }
 // Markdown body（用 .init 让 SwiftUI 解析 markdown 语法；v1.7.5 Gamma 按当前语言返回）
 Text(.init(entry.markdown(for: lang)))
 .font(.system(size: 13))
 .lineSpacing(4)
 .textSelection(.enabled)
 .frame(maxWidth: .infinity, alignment: .leading)
 .fixedSize(horizontal: false, vertical: true)
 }
 .padding(.vertical, 14)
 }
}

/// 更新日志数据源（每次发布新版本时把新条目插入到 entries 数组最前面）
enum ChangelogContent {
 struct Entry: Identifiable {
 let id = UUID()
 let version: String
 let date: String
 let isLatest: Bool
 /// v1.7.5 Gamma: 简中 markdown（fallback）
 let bodyMarkdown: String
 /// v1.7.5 Gamma: 繁中 / 英文 / 日文 markdown（optional，没填则 fallback 到简中）
 var bodyMarkdownZHT: String? = nil
 var bodyMarkdownEN: String? = nil
 var bodyMarkdownJA: String? = nil

 /// v1.7.5 Gamma: 按语言返回 markdown（缺该语言时 fallback 到简中）
 func markdown(for lang: AppLanguage) -> String {
 switch lang {
 case .simplifiedChinese: return bodyMarkdown
 case .traditionalChinese: return bodyMarkdownZHT ?? bodyMarkdown
 case .english: return bodyMarkdownEN ?? bodyMarkdown
 case .japanese: return bodyMarkdownJA ?? bodyMarkdown
 }
 }
 }

static let entries: [Entry] = [
        Entry(
            version: "v1.7.10",
            date: "2026-06-26",
            isLatest: true,
            bodyMarkdown: "纪念Minecraft v1.7.10发布12周年。",
            bodyMarkdownZHT: "紀念Minecraft v1.7.10發布12週年。",
            bodyMarkdownEN: "In memory of the 12th anniversary of Minecraft v1.7.10.",
            bodyMarkdownJA: "Minecraft v1.7.10リリース12周年を記念。"
        ),
        Entry(
            version: "v1.7.9 GT5",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: "新增文件夹右键上移/下移排序，修复多语言适配",
            bodyMarkdownZHT: "新增資料夾右鍵上移/下移排序，修復多語言適配",
            bodyMarkdownEN: "Added folder right-click move up/down sorting, fixed localization",
            bodyMarkdownJA: "フォルダの右クリックで上下移動並べ替えを追加、ローカライズを修正"
        ),
        Entry(
            version: "v1.7.9 GT4",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: "新增曲目库右键上移/下移排序、移到其他文件夹功能",
            bodyMarkdownZHT: "新增曲目庫右鍵上移/下移排序、移到其他資料夾功能",
            bodyMarkdownEN: "Added right-click move up/down sorting and move to other folder in library",
            bodyMarkdownJA: "ライブラリの右クリックで上下移動並べ替え、別のフォルダに移動機能を追加"
        ),
        Entry(
            version: "v1.7.9 GT3",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: "修复文本编辑栏交互、左滑删除样式、动画问题",
            bodyMarkdownZHT: "修復文字編輯欄互動、左滑刪除樣式、動畫問題",
            bodyMarkdownEN: "Fixed text editor interaction, swipe-delete style, animation issues",
            bodyMarkdownJA: "テキストエディタの操作、スワイプ削除のスタイル、アニメーションの問題を修正"
        ),
        Entry(
            version: "v1.7.9 GT2",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: "修改了一堆 Bug",
            bodyMarkdownZHT: "修改了一堆 Bug",
            bodyMarkdownEN: "Fixed a bunch of bugs",
            bodyMarkdownJA: "いくつかのバグを修正"
        ),
        Entry(
            version: "v1.7.9 GT",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: "合并 BugStable 与 Test：恢复段落拖动开关 + 笔记/折叠动画",
            bodyMarkdownZHT: "合併 BugStable 與 Test：恢復段落拖動開關 + 筆記/折疊動畫",
            bodyMarkdownEN: "Merged BugStable and Test: restored section drag toggle + notes/fold animations",
            bodyMarkdownJA: "BugStable と Test を統合：セクションドラッグスイッチ + ノート/折りたたみアニメーションを復元"
        ),
        Entry(
            version: "v1.7.9 Test",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: "恢复笔记/折叠动画；段落拖动改回默认开启（去掉开关）",
            bodyMarkdownZHT: "恢復筆記/折疊動畫；段落拖動改回預設開啟（去掉開關）",
            bodyMarkdownEN: "Restored notes/fold animations; section drag on by default (toggle removed)",
            bodyMarkdownJA: "ノート/折りたたみアニメーションを復元；セクションドラッグをデフォルト ON（スイッチ削除）"
        ),
        Entry(
            version: "v1.7.9 BugStable",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: "修复笔记/元信息面板展开动画、滚轮穿透、切歌光标、文字居中点击问题",
            bodyMarkdownZHT: "修復筆記/元資訊面板展開動畫、滾輪穿透、切歌游標、文字置中點擊問題",
            bodyMarkdownEN: "Fixed notes/metadata panel animation, scroll-wheel passthrough, song-switch cursor, text-centering click issue",
            bodyMarkdownJA: "ノート/メタ情報パネルの展開アニメ、スクロールホイール透過、切替カーソル、テキスト中央配置クリック問題を修正"
        ),
        Entry(
            version: "v1.7.9 Delta",
            date: "2026-06-24",
            isLatest: false,
            bodyMarkdown: """
## 修复

- 切歌动画统一从右往左，规避快速切换下的反向动画
- 歌词编辑栏高度自适应内容（intrinsicContentSize + didChangeText 重算）
- 切歌不放光标；只有用户主动行为才聚焦
- 文件夹 / 回收站单击 toggle 展开（不被外层 selection 误选）
- 灵感 / 歌词预览切换按按钮位置决定方向；关闭时详情栏宽度收缩到 0
- 灵感词条最小高度可调（1 行 / 2 行）
""",
            bodyMarkdownZHT: """
## 修復

- 切歌動畫統一從右往左，規避快速切換下的反向動畫
- 歌詞編輯欄高度自適應內容（intrinsicContentSize + didChangeText 重算）
- 切歌不放光標；只有用戶主動行為才聚焦
- 文件夾 / 回收站單擊 toggle 展開（不被外層 selection 誤選）
- 靈感 / 歌詞預覽切換按按鈕位置決定方向；關閉時詳情欄寬度收縮到 0
- 靈感詞條最小高度可調（1 行 / 2 行）
""",
            bodyMarkdownEN: """
## Fixed

- Song switching animation unified to right-to-left to avoid reverse bugs during rapid switching
- Lyrics editor height auto-sizes with content (intrinsicContentSize + didChangeText)
- Switching songs no longer places the text cursor; only user-initiated actions trigger focus
- Folder / trash single click toggles expansion without leaking to the outer List selection
- Ideas / Preview panel switch follows the button positions; off collapses the detail column to width 0
- Ideas note text editor minimum height is now configurable (1 / 2 lines)
""",
            bodyMarkdownJA: """
## 修正

- 楽曲切替アニメーションを右から左へ統一、高速切替時の逆方向バグを回避
- 歌詞エディタの高さを内容に合わせて自動調整（intrinsicContentSize + didChangeText）
- 楽曲切替時はカーソルを表示しない。ユーザー操作時のみフォーカス
- フォルダ / ゴミ箱のシングルクリックで展開。外側 List selection に漏れない
- アイデア / 歌詞プレビューの切替はボタン位置に従う。off 時は詳細カラム幅を 0 に折りたたむ
- アイデアのノートテキストボックスの最小高さを調整可能に（1 行 / 2 行）
"""
        ),
        Entry(
            version: "v1.7.9 Gamma",
            date: "2026-06-24",
            isLatest: false,
            bodyMarkdown: """
## 新增

- 切换歌词的动画方向感知：切到列表下方（更旧的歌）从右往左滑；切到列表上方（更新的歌）从左往右滑，符合直觉
- 灵感与设定 / 歌词预览两个右栏之间切换加入左右滑动动画（spring）

## 修复

- 修复歌词编辑栏的光标常驻 bug：现在点击 TextEditor 之外的空白区域会自动让 window resignFirstResponder，关掉光标。修好之后切换曲目库时歌词栏颜色显示恢复正常（之前是 NSTextView 一直 firstResponder 导致 SwiftUI 视图状态未及时同步）
""",
            bodyMarkdownZHT: """
## 新增

- 切換歌詞的動畫方向感知：切到列表下方（更舊的歌）從右往左滑；切到列表上方（更新的歌）從左往右滑，符合直覺
- 靈感與設定 / 歌詞預覽兩個右欄之間切換加入左右滑動動畫（spring）

## 修復

- 修復歌詞編輯欄的光標常駐 bug：現在點擊 TextEditor 之外的空白區域會自動讓 window resignFirstResponder，關掉光標。修好之後切換曲目庫時歌詞欄顏色顯示恢復正常（之前是 NSTextView 一直 firstResponder 導致 SwiftUI 視圖狀態未及時同步）
""",
            bodyMarkdownEN: """
## New

- Direction-aware song switching animation: switching to a song lower in the list (older) slides right-to-left; switching to a song higher in the list (newer) slides left-to-right — matches user intuition
- Added a left/right slide animation when switching between the Ideas & Settings and Lyrics Preview right panels (spring)

## Fixed

- Fixed the persistent text-cursor bug in the lyrics editor: clicking anywhere outside the TextEditor now automatically makes the window resignFirstResponder, turning off the cursor. This also fixes the color rendering glitch that happened when switching songs in the library (previously NSTextView stayed as firstResponder and SwiftUI view state didn't sync in time)
""",
            bodyMarkdownJA: """
## 新機能

- 楽曲切替のアニメーション方向を感知：リスト下方（より古い楽曲）への切替は右から左へスライド、リスト上方（より新しい楽曲）への切替は左から右へスライド、直感的な操作感に
- アイデア＆設定 / 歌詞プレビューの 2 つの右パネル間の切替に左右スライドアニメーションを追加（spring）

## 修正

- 歌詞エディタのカーソル常駐バグを修正：TextEditor 以外の余白をクリックすると window が resignFirstResponder し、カーソルが消えるようになりました。これにより、ライブラリの楽曲切替時に歌詞パネルの色が正常表示されるようになりました（以前は NSTextView がずっと firstResponder のままで、SwiftUI のビュー状態が同期されていなかった）
"""
        ),
        Entry(
            version: "v1.7.9 Beta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
## 新增

- 设置新增「段落拖动」开关（默认关闭）。开启后会弹窗提示存在缺陷（与歌词编辑栏 / 左滑删除冲突），确认后启用 List 系统级拖动
- 关闭「段落拖动」时启用段落左滑删除

## 改动

- 段落右键菜单的「删除」按钮改用红色 Label + destructive role，更显眼
- 歌词编辑栏的滚轮穿透到外层 ScrollView（光标在编辑栏时滚动鼠标也能滚整页）
- 所有右键删除按钮（歌词段、注音、灵感、曲库歌曲）改用 `trash.fill` 图标 + `.tint(.red)`，垃圾桶和文字都显红色
- 元信息展开 / 收起改用 spring 动画，最丝滑手感

## 修复

- 修复「段落拖动」开关的 Toggle 滑块不显示问题（与删除警告开关一致，改用 SystemSwitchToggle）
- 修复曲目库「将歌曲移到回收站？」多语言未适配问题（key 漏了问号导致 fallback 到中文）
""",
            bodyMarkdownZHT: """
## 新增

- 設定新增「段落拖動」開關（預設關閉）。開啟後會彈窗提示存在缺陷（與歌詞編輯欄 / 左滑刪除衝突），確認後啟用 List 系統級拖動
- 關閉「段落拖動」時啟用段落左滑刪除

## 改動

- 段落右鍵選單的「刪除」按鈕改用紅色 Label + destructive role，更顯眼
- 歌詞編輯欄的滾輪穿透到外層 ScrollView（游標在編輯欄時滾動滑鼠也能滾整頁）
- 所有右鍵刪除按鈕（歌詞段、注音、靈感、曲庫歌曲）改用 `trash.fill` 圖示 + `.tint(.red)`，垃圾桶和文字都顯紅色
- 歌詞元資訊展開 / 收合改用 spring 動畫，最絲滑手感

## 修復

- 修復「段落拖動」開關的 Toggle 滑塊不顯示問題（與刪除警告開關一致，改用 SystemSwitchToggle）
- 修復曲庫「將歌曲移到回收站？」多語系未適配問題（key 漏了問號導致 fallback 到中文）
""",
            bodyMarkdownEN: """
## New

- New "Section Drag" toggle in Settings (off by default). Enabling shows a warning dialog about defects (conflicts with lyrics editor / swipe-to-delete). After confirmation, List system-level drag is enabled
- When "Section Drag" is off, swipe-to-delete is enabled for sections

## Changed

- Section context menu "Delete" button now uses a red Label + destructive role for better visibility
- Lyrics editor scroll wheel now passes through to the outer ScrollView (scrolling while the cursor is in the editor also scrolls the page)
- All right-click delete buttons (sections, annotations, ideas, library songs) now use `trash.fill` icon + `.tint(.red)` for clearly red trash icon and text
- Song metadata expand/collapse switched to spring animation for the smoothest feel

## Fixed

- Fixed the "Section Drag" toggle's invisible thumb (same issue as the delete-confirm toggle; now uses SystemSwitchToggle)
- Fixed missing localization for "Move song to Trash?" library prompt (the key had a stray question mark causing fallback to Chinese)
""",
            bodyMarkdownJA: """
## 新機能

- 設定に「セクションドラッグ」スイッチを追加（デフォルトは無効）。有効化すると欠陥に関する警告ダイアログ（歌詞エディタ / スワイプ削除と競合）が表示され、確認後に List システムレベルのドラッグが有効になります
- 「セクションドラッグ」を無効にしている間は、セクションのスワイプ削除が有効

## 変更

- セクション右クリックメニューの「削除」ボタンを赤色 Label + destructive role に変更し、より目立つように
- 歌詞エディタのスクロールホイールを外側 ScrollView に透過（カーソルがエディタ内でもページ全体スクロール可能）
- すべての右クリック削除ボタン（セクション、注音、アイデア、ライブラリ楽曲）を `trash.fill` アイコン + `.tint(.red)` に変更、ゴミ箱アイコンと文字がはっきり赤色に
- 楽曲メタ情報の展開 / 折りたたみを spring アニメーションに変更、より滑らかな手触りに

## 修正

- 「セクションドラッグ」スイッチのトグルつまみが表示されない問題を修正（削除確認スイッチと同じく SystemSwitchToggle を使用）
- ライブラリの「楽曲をゴミ箱へ移動しますか？」のローカライズ漏れを修正（キーに余分なクエスチョンマークがあり、中国語にフォールバックしていた）
"""
        ),
        Entry(
            version: "v1.7.8 Delta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
## 新增功能

- 段落右键菜单新增「上移至顶部」「下移至底部」

## 优化

- 修复曲目库点击歌曲 0.3s 延迟（去掉视图强制重建 + Set 加速 contains）
- 段落拖动改用 ScrollView + LazyVStack，任意位置按住即可拖；新增拖动时光标接近顶部自动向上滚动
""",
            bodyMarkdownZHT: """
## 新增功能

- 段落右鍵選單新增「上移至頂部」「下移至底部」

## 優化

- 修復曲目庫點擊歌曲 0.3s 延遲（去掉視圖強制重建 + Set 加速 contains）
- 段落拖動改用 ScrollView + LazyVStack，任意位置按住即可拖；新增拖動時游標接近頂部自動向上捲動
""",
            bodyMarkdownEN: """
## New Features

- Section context menu: added "Move to Top" and "Move to Bottom"

## Improvements

- Fixed 0.3s delay when clicking a song in the library (removed forced view rebuild + Set-based contains)
- Section drag rewritten with ScrollView + LazyVStack — press anywhere to drag; auto-scrolls up when cursor approaches the top
""",
            bodyMarkdownJA: """
## 新機能

- セクションの右クリックメニューに「一番上に移動」「一番下に移動」を追加

## 改善

- 楽曲庫で曲をクリックしたときの 0.3 秒遅延を修正（ビュー強制再構築を削除 + Set で contains を高速化）
- セクションのドラッグを ScrollView + LazyVStack で再実装：任意の位置で長押ししてドラッグ可能に、ドラッグ中にカーソルが上部近くに来たら自動で上方向にスクロール
"""
        ),
        Entry(
            version: "v1.7.8 Gamma",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
## 新增功能

- 编辑区歌词段落可拖动重排：拖到目标段落**上方**插入到该段之前；拖到列表末尾的虚线占位区添加到末尾；拖动时目标位置显示系统条带（2.5pt 高蓝色横线）
- 歌词段落拖动不依赖 List 编辑模式（任意时刻按住段落即可拖）

## Bug 修复

- 修复歌词段落左滑删除按钮判定范围太广的问题：`.onDelete` 替换为 `.swipeActions(edge: .trailing, allowsFullSwipe: false)`，删除按钮判定严格限制在按钮内，点击空白处自动 dismiss
""",
            bodyMarkdownZHT: """
## 新增功能

- 編輯區歌詞段落可拖動重排：拖到目標段落**上方**插入到該段之前；拖到列表末尾的虛線佔位區添加到末尾；拖動時目標位置顯示系統條帶（2.5pt 高藍色橫線）
- 歌詞段落拖動不依賴 List 編輯模式（任意時刻按住段落即可拖）

## Bug 修復

- 修復歌詞段落左滑刪除按鈕判定範圍太廣的問題：`.onDelete` 替換為 `.swipeActions(edge: .trailing, allowsFullSwipe: false)`，刪除按鈕判定嚴格限制在按鈕內，點擊空白處自動 dismiss
""",
            bodyMarkdownEN: """
## New Features

- Sections can now be dragged to reorder: drop on the **top edge** of a target section to insert before it; drop on the dashed placeholder at the end of the list to append; a 2.5pt blue bar shows the drop position while dragging
- Section drag no longer requires List edit mode — just press and drag anytime

## Bug Fixes

- Fixed swipe-to-delete button having too wide a hit area: replaced `.onDelete` with `.swipeActions(edge: .trailing, allowsFullSwipe: false)`. The delete button now only triggers when the button itself is tapped, and the action auto-dismisses on outside tap
""",
            bodyMarkdownJA: """
## 新機能

- 編集エリアの歌詞セクションをドラッグして並び替え可能：ターゲットセクションの**上端**にドロップするとそのセクションの前に挿入、リスト末尾の破線プレースホルダにドロップすると末尾に追加、ドラッグ中はドロップ位置にシステムバンド（高さ 2.5pt の青い線）が表示される
- セクションのドラッグは List の編集モードに依存しない（いつでも長押しでドラッグ可能）

## バグ修正

- セクションのスワイプ削除ボタンのタップ判定が広すぎる問題を修正：`.onDelete` を `.swipeActions(edge: .trailing, allowsFullSwipe: false)` に置き換え、削除ボタンの判定をボタン内に厳格に限定、外側をタップすると自動で閉じる
"""
        ),
        Entry(
            version: "v1.7.8 Beta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
## 新增功能

- 曲目库歌曲可拖动：拖到文件夹移入 / 拖到根目录歌曲移出 / 拖到目标歌曲前插入 + 手动改排序
- 多选右键菜单移除「批量备份」（与「批量导出」功能相同）

## Bug 修复

- 修复设置里"删除前确认"开关滑块首次打开不显示的 Bug：用 `DispatchQueue.main.async` 在 NSSwitch 加入 view hierarchy 后强制 layout + display，每次 updateNSView 兜底
""",
            bodyMarkdownZHT: """
## 新增功能

- 曲目庫歌曲可拖動：拖到資料夾移入 / 拖到根目錄歌曲移出 / 拖到目標歌曲前插入 + 手動改排序
- 多選右鍵選單移除「批次備份」（與「批次匯出」功能相同）

## Bug 修復

- 修復設定裡「刪除前確認」開關滑塊首次打開不顯示的 Bug：用 `DispatchQueue.main.async` 在 NSSwitch 加入 view hierarchy 後強制 layout + display，每次 updateNSView 兜底
""",
            bodyMarkdownEN: """
## New Features

- Song library is now drag-and-drop: drag onto a folder to move in, drag onto a root song to move out, drop before a target song to insert and reorder
- Removed "Batch Backup" from the multi-select right-click menu (identical to "Batch Export")

## Bug Fixes

- Fixed: the "Confirm before delete" toggle thumb was not visible on first open of Settings. Now forces NSSwitch layout + display via `DispatchQueue.main.async` after it's added to the view hierarchy, with a fallback in every `updateNSView`
""",
            bodyMarkdownJA: """
## 新機能

- 曲目ライブラリの楽曲をドラッグ可能：フォルダにドロップして移動 / ルート上の曲にドロップしてルートへ戻す / 対象曲の前にドロップして挿入 + 手動で並び替え
- 複数選択の右クリックメニューから「一括バックアップ」を削除（「一括エクスポート」と機能重複のため）

## バグ修正

- 修正：設定の「削除前に確認」スイッチのサムが初回オープン時に表示されないバグ。`DispatchQueue.main.async` で NSSwitch が view hierarchy に追加された直後に layout + display を強制し、各 `updateNSView` でもフォールバック処理を行うように修正
"""
        ),
        Entry(
            version: "v1.7.7 Delta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: "歌曲元信息新增节拍器（BPM + 拍号发声 + 闪烁）；修复设置里技能炼成副标题未做多语言适配；使用指南新增繁中 zhtSections",
            bodyMarkdownZHT: "歌曲元資訊新增節拍器（BPM + 拍號發聲 + 閃爍）；修復設定裡技能煉成副標題未做多語系適配；使用指南新增繁中 zhtSections",
            bodyMarkdownEN: "Song metadata adds Metronome (BPM + beat sound + blink); fixed missing localization on the Skill Integrated caption; Usage Guide adds Traditional Chinese zhtSections",
            bodyMarkdownJA: "楽曲メタ情報にメトロノーム追加（BPM + 拍子発声 + フラッシュ）；設定のスキル錬成キャプションのローカライズ漏れを修正；使い方ガイドに繁体中文 zhtSections 追加"
        ),
        Entry(
            version: "v1.7.7 Gamma",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: "设置新增技能炼成（位置在帮助上方）；下载链接（跳转 GitHub）；版本信息开发者栏加 vlantech@126.com；技能炼成导出改文件夹结构；用真 logo 图替换占位图；技能炼成小字注释补 4 语言；使用指南小字删括号注释",
            bodyMarkdownZHT: "設定新增技能煉成（位置在說明上方）；下載連結（跳轉 GitHub）；版本資訊開發者欄加 vlantech@126.com；技能煉成匯出改資料夾結構；用真 logo 圖替換佔位圖；技能煉成小字註釋補 4 語系；使用指南小字刪括號註解",
            bodyMarkdownEN: "Settings adds Skill Integrated (above Help); Download Link (opens GitHub); Developer row gets vlantech@126.com; Skill Integrated export uses folder layout; replace placeholder logo with real logo image; Skill Integrated caption localized to 4 languages; remove parenthetical from Usage Guide caption",
            bodyMarkdownJA: "設定にスキル錬成追加（ヘルプの上）；ダウンロードリンク（GitHub へ移動）；バージョン情報の開発者行に vlantech@126.com 追加；スキル錬成のエクスポートをフォルダ構造に変更；プレースホルダ logo を本物の logo 画像に差し替え；スキル錬成キャプションの 4 言語化；使い方ガイドキャプションの括弧注釈を削除"
        ),
                Entry(
            version: "v1.7.5 Gamma",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "⌘N 接管新建歌曲、⌘D 删除多选、帮助栏目 + 更新日志做多语言适配（4 语言）",
            bodyMarkdownZHT: "⌘N 接管新建歌曲、⌘D 刪除多選、說明欄目 + 更新日誌做多語系適配（4 語系）",
            bodyMarkdownEN: "⌘N now triggers New Song; ⌘D deletes selected songs; Help section + Changelog localized to 4 languages",
            bodyMarkdownJA: "⌘N で新規楽曲、⌘D で選択削除；ヘルプと更新履歴を 4 言語化"
        ),
        Entry(
            version: "v1.7.5 Beta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "主题切换立即生效；删除确认开关首次可见；帮助栏目新增使用指南（4 语言）",
            bodyMarkdownZHT: "主題切換立即生效；刪除確認開關首次可見；說明欄目新增使用指南（4 語系）",
            bodyMarkdownEN: "Theme switch now instant; delete-confirm toggle visible on first open; Help section adds Usage Guide (4 languages)",
            bodyMarkdownJA: "テーマ切替が即時反映；削除確認スイッチが初表示で見える；ヘルプに使用ガイド追加（4 言語）"
        ),
        Entry(
            version: "v1.7.4 Delta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "主题切换立即生效；删除确认开关首次打开即可见滑块",
            bodyMarkdownZHT: "主題切換立即生效；刪除確認開關首次打開即可見滑塊",
            bodyMarkdownEN: "Theme switch now instant; delete-confirm toggle visible on first open",
            bodyMarkdownJA: "テーマ切替が即時反映；削除確認スイッチが初表示で見える"
        ),
        Entry(
            version: "v1.7.4 Gamma",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "修复文件夹内歌曲右键不出菜单；单选不再显示「已选 1 项」工具栏；清理累积的 isLatest 标记",
            bodyMarkdownZHT: "修復資料夾內歌曲右鍵不出選單；單選不再顯示「已選 1 項」工具列；清理累積的 isLatest 標記",
            bodyMarkdownEN: "Fixed: right-click menu missing inside folders; single-select no longer shows \"1 selected\" toolbar; cleaned up stale isLatest flags",
            bodyMarkdownJA: "フォルダ内曲の右クリックメニューが出ない問題を修正；単一選択時は「1 項選択済」ツールバーを表示しない；isLatest フラグを整理"
        ),
        Entry(
            version: "v1.7.4 Beta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "侧栏右键菜单逻辑梳理；删除「备份文件夹」；回收站支持双击展开；所有删除操作播放系统 trash 音效",
            bodyMarkdownZHT: "側欄右鍵選單邏輯梳理；刪除「備份資料夾」；回收桶支援雙擊展開；所有刪除操作播放系統 trash 音效",
            bodyMarkdownEN: "Sidebar right-click menu logic cleanup; removed \"Backup Folder\"; trash supports double-click expand; all delete ops play system trash sound",
            bodyMarkdownJA: "サイドバー右クリックメニュー整理；「フォルダをバックアップ」を削除；ゴミ箱はダブルクリックで展開対応；全削除操作でシステム trash 効果音再生"
        ),
        Entry(
            version: "v1.7.3 Delta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "彻底修复「绿色块」（去除 `List(selection:)` 系统 tint）；ContentView 加 .preferredColorScheme(themeManager.preferredColorScheme)",
            bodyMarkdownZHT: "徹底修復「綠色塊」（去除 `List(selection:)` 系統 tint）；ContentView 加 .preferredColorScheme(themeManager.preferredColorScheme)",
            bodyMarkdownEN: "Finally killed the green block (removed `List(selection:)` system tint); ContentView adds .preferredColorScheme(themeManager.preferredColorScheme)",
            bodyMarkdownJA: "「緑色のブロック」を完全除去（`List(selection:)` のシステム tint を削除）；ContentView に .preferredColorScheme(themeManager.preferredColorScheme) を追加"
        ),
        Entry(
            version: "v1.7.3 Gamma",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "彻底修复浅色模式文字图标不可视（所有 .secondary/.tertiary → .primary）；删除段落背景系统色块 + 加外层 5pt 间距 2pt 系统色粗边框",
            bodyMarkdownZHT: "徹底修復淺色模式文字圖示不可視（所有 .secondary/.tertiary → .primary）；刪除段落背景系統色塊 + 加外層 5pt 間距 2pt 系統色粗邊框",
            bodyMarkdownEN: "Fixed invisible text/icons in light mode (all .secondary/.tertiary → .primary); removed section background system color block + added 5pt padding + 2pt system color border",
            bodyMarkdownJA: "ライトモードで文字・アイコンが見えない問題を完全修正（.secondary/.tertiary → .primary）；セクション背景のシステムカラーブロックを除去 + 外側 5pt 余白 + 2pt システムカラー太枠を追加"
        ),
        Entry(
            version: "v1.7.3 Beta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: "引入 ThemeColor 色板（基于 Color.primary.opacity）；闪烁时长 800ms → 500ms",
            bodyMarkdownZHT: "引入 ThemeColor 色板（基於 Color.primary.opacity）；閃爍時長 800ms → 500ms",
            bodyMarkdownEN: "Introduced ThemeColor palette (based on Color.primary.opacity); flash duration 800ms → 500ms",
            bodyMarkdownJA: "ThemeColor パレット導入（Color.primary.opacity ベース）；点滅時間 800ms → 500ms"
        ),
        Entry(
            version: "v1.7.2 Beta",
            date: "2026-06-20",
            isLatest: false,
            bodyMarkdown: "闪烁只触发指定段落（不再全部段落一起闪）；段落 border fallback accent 删掉",
            bodyMarkdownZHT: "閃爍只觸發指定段落（不再全部段落一起閃）；段落 border fallback accent 刪除",
            bodyMarkdownEN: "Flash now only triggers the target section (no more flashing all sections); removed section border accent fallback",
            bodyMarkdownJA: "点滅は指定セクションのみ発火（全セクション同時点滅を解消）；セクション border のフォールバック accent を削除"
        ),
        Entry(
            version: "v1.7.1",
            date: "2026-06-20",
            isLatest: false,
            bodyMarkdown: "去除编辑段落常亮高亮 + 跳转闪烁动画 + 双击跳转聚焦 TextEditor + 删除 dmg README.txt",
            bodyMarkdownZHT: "去除編輯段落常亮高亮 + 跳轉閃爍動畫 + 雙擊跳轉聚焦 TextEditor + 刪除 dmg README.txt",
            bodyMarkdownEN: "Removed edit-section persistent highlight + jump flash animation + double-click jump focus TextEditor + dropped dmg README.txt",
            bodyMarkdownJA: "編集セクション常時ハイライト + ジャンプ点滅アニメ + ダブルクリックで TextEditor フォーカス を削除；dmg README.txt を削除"
        ),
        Entry(
            version: "v1.7 Beta",
            date: "2026-06-20",
            isLatest: false,
            bodyMarkdown: "歌词预览模块（与右栏灵感互斥切换）；编辑区 ↔ 预览区联动；节拍字段在折叠状态显示",
            bodyMarkdownZHT: "歌詞預覽模組（與右欄靈感互斥切換）；編輯區 ↔ 預覽區聯動；節拍欄位在折疊狀態顯示",
            bodyMarkdownEN: "Lyrics preview module (toggles with right Ideas panel); editor ↔ preview cross-link; beat field shown when collapsed",
            bodyMarkdownJA: "歌詞プレビューモジュール（右パネル Ideas と排他切替）；編集 ↔ プレビュー連動；拍子フィールドは折りたたみ時表示"
        ),
        Entry(
            version: "v1.6.1 Beta",
            date: "2026-06-19",
            isLatest: false,
            bodyMarkdown: "SystemSwitchToggle（NSViewRepresentable 包裹 NSSwitch）；日语假名词典扩到 2298 词",
            bodyMarkdownZHT: "SystemSwitchToggle（NSViewRepresentable 包裹 NSSwitch）；日語假名詞典擴到 2298 詞",
            bodyMarkdownEN: "SystemSwitchToggle (NSViewRepresentable wrapping NSSwitch); Japanese furigana dictionary expanded to 2298 words",
            bodyMarkdownJA: "SystemSwitchToggle（NSViewRepresentable で NSSwitch をラップ）；日本語ふりがな辞書を 2298 語に拡張"
        ),
        Entry(
            version: "v1.6 Beta",
            date: "2026-06-19",
            isLatest: false,
            bodyMarkdown: "节拍字段（2/4 / 3/4 / 4/4 / 6/8 / 7/8 / 9/8 / 12/8）；歌词导出全部用英文 key；文件夹双击展开/删除",
            bodyMarkdownZHT: "節拍欄位（2/4 / 3/4 / 4/4 / 6/8 / 7/8 / 9/8 / 12/8）；歌詞匯出全部用英文 key；資料夾雙擊展開/刪除",
            bodyMarkdownEN: "Beat field (2/4 / 3/4 / 4/4 / 6/8 / 7/8 / 9/8 / 12/8); lyric export uses English keys; folder double-click to expand/delete",
            bodyMarkdownJA: "拍子フィールド（2/4 / 3/4 / 4/4 / 6/8 / 7/8 / 9/8 / 12/8）；歌詞エクスポートは英文キー；フォルダはダブルクリックで展開/削除"
        ),
        Entry(
            version: "v1.5.2 Beta",
            date: "2026-06-18",
            isLatest: false,
            bodyMarkdown: "多选（Set<UUID>）；批量操作（备份/导出/合并/移到回收站）；扁平文件夹导入",
            bodyMarkdownZHT: "多選（Set<UUID>）；批次操作（備份/匯出/合併/移到回收桶）；扁平資料夾匯入",
            bodyMarkdownEN: "Multi-select (Set<UUID>); batch ops (backup/export/merge/move to trash); flat folder import",
            bodyMarkdownJA: "複数選択（Set<UUID>）；一括操作（バックアップ/エクスポート/マージ/ゴミ箱へ）；フラットフォルダインポート"
        ),
        Entry(
            version: "v1.5.1",
            date: "2026-06-17",
            isLatest: false,
            bodyMarkdown: "修复重复 key 导致的本地化表崩溃",
            bodyMarkdownZHT: "修復重複 key 導致的本地化表崩潰",
            bodyMarkdownEN: "Fixed: duplicate key crash in localization table",
            bodyMarkdownJA: "ローカライズテーブルの重複キーによるクラッシュを修正"
        ),
        Entry(
            version: "v1.5 Beta",
            date: "2026-06-17",
            isLatest: false,
            bodyMarkdown: "文件夹系统 + 系统回收站（SongFolder isSystem + fetchTrashFolder）；删除走系统废纸篓；二次确认才能永久删除",
            bodyMarkdownZHT: "資料夾系統 + 系統回收桶（SongFolder isSystem + fetchTrashFolder）；刪除走系統垃圾桶；二次確認才能永久刪除",
            bodyMarkdownEN: "Folder system + system trash (SongFolder isSystem + fetchTrashFolder); deletes go through system trash; permanent delete requires double confirm",
            bodyMarkdownJA: "フォルダシステム + システムゴミ箱（SongFolder isSystem + fetchTrashFolder）；削除はシステムゴミ箱経由；完全削除は 2 段階確認"
        ),
        Entry(
            version: "v1.4 Beta",
            date: "2026-06-15",
            isLatest: false,
            bodyMarkdown: "i18n（简中/繁中/英语/日语 4 语言）；删除警告开关；窗口最窄 1280",
            bodyMarkdownZHT: "i18n（簡中/繁中/英語/日語 4 語系）；刪除警告開關；視窗最窄 1280",
            bodyMarkdownEN: "i18n (4 languages: Simplified / Traditional Chinese / English / 日本語); delete warning toggle; window min width 1280",
            bodyMarkdownJA: "i18n（簡体中文 / 繁体中文 / English / 日本語の 4 言語）；削除警告スイッチ；ウィンドウ最小幅 1280"
        ),
        Entry(
            version: "v1.3 Beta",
            date: "2026-06-14",
            isLatest: false,
            bodyMarkdown: "灵感与设定栏目；段落笔记展开面板；自动注音 UI 整合",
            bodyMarkdownZHT: "靈感與設定欄目；段落筆記展開面板；自動注音 UI 整合",
            bodyMarkdownEN: "Ideas & Settings panel; section notes expand panel; auto-furigana UI integrated",
            bodyMarkdownJA: "インスピレーション・設定欄目；セクションノート展開パネル；自動ふりがな UI 統合"
        ),
        Entry(
            version: "v1.2 Beta",
            date: "2026-06-13",
            isLatest: false,
            bodyMarkdown: "歌曲语言多选合并（简/繁 → 中文）；手动注音 chip 列表",
            bodyMarkdownZHT: "歌曲語言多選合併（簡/繁 → 中文）；手動注音 chip 列表",
            bodyMarkdownEN: "Song language multi-select merged (Simplified / Traditional → Chinese); manual furigana chip list",
            bodyMarkdownJA: "楽曲言語の複数選択を統合（簡体/繁体 → 中文）；手動ふりがなチップ一覧"
        ),
        Entry(
            version: "v1.1",
            date: "2026-06-12",
            isLatest: false,
            bodyMarkdown: "Schema 修复（languagesString 替代 language）",
            bodyMarkdownZHT: "Schema 修復（languagesString 替代 language）",
            bodyMarkdownEN: "Schema fix (languagesString replaces language)",
            bodyMarkdownJA: "Schema 修正（languagesString が language を置換）"
        ),
        Entry(
            version: "v1.0",
            date: "2026-06-10",
            isLatest: false,
            bodyMarkdown: "首次发布：SwiftUI + SwiftData 原生 macOS 应用；Apple Silicon ARM64；12 种段落类型预设 + 自定义；日语假名自动注音",
            bodyMarkdownZHT: "首次發布：SwiftUI + SwiftData 原生 macOS 應用；Apple Silicon ARM64；12 種段落類型預設 + 自訂；日語假名自動注音",
            bodyMarkdownEN: "First release: SwiftUI + SwiftData native macOS app; Apple Silicon ARM64; 12 section-type presets + custom; automatic Japanese furigana",
            bodyMarkdownJA: "初版リリース：SwiftUI + SwiftData ネイティブ macOS アプリ；Apple Silicon ARM64；セクションタイプ 12 種プリセット + カスタム；日本語ふりがな自動付与"
        ),
    ]
}

#Preview {
 ChangelogView()
}