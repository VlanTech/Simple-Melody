// Settings/UsageGuideView.swift
// v1.7.5 Beta: 使用指南（与更新日志同格式，按 LocalizationManager 语言适配）
//
// 数据源 UsageGuideContent.sections(for:) 按当前界面语言返回不同 markdown 内容

import SwiftUI

// MARK: - 独立 Window

struct UsageGuideWindow: View {
    var body: some View {
        UsageGuideView()
            .frame(minWidth: 560, idealWidth: 640, maxWidth: 720,
                   minHeight: 480, idealHeight: 640, maxHeight: 800)
    }
}

// MARK: - 视图本体

struct UsageGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(UsageGuideContent.sections(for: loc.language)) { section in
                        guideSectionView(section)
                        if section.id != UsageGuideContent.sections(for: loc.language).last?.id {
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

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.pages")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
            Text(L("使用指南"))
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
    }

    @ViewBuilder
    private func guideSectionView(_ section: UsageGuideContent.Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 章节标题
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)
                Text(section.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                Spacer()
            }
            // Markdown body
            Text(.init(section.bodyMarkdown))
                .font(.system(size: 13))
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - 多语言内容数据源

enum UsageGuideContent {
    struct Section: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let bodyMarkdown: String
    }

    static func sections(for lang: AppLanguage) -> [Section] {
        switch lang {
        case .simplifiedChinese:
            return zhSections
        case .traditionalChinese:
            return zhtSections
        case .english:
            return enSections
        case .japanese:
            return jaSections
        }
    }

    // MARK: 简体中文

    private static let zhSections: [Section] = [
        Section(icon: "wand.and.stars", title: "快速上手", bodyMarkdown: """
Simple Melody 是一款 macOS 原生歌词创作工具，三栏布局：左侧曲目库，中间段落编辑，右侧灵感与设定。

**基本流程**：
1. 点工具栏 `+ 新建歌曲`，或在左侧右键新建
2. 中间区添加段落（Verse / Chorus / Bridge / ...）
3. 在段落正文里写歌词，可加读音 chip
4. 右侧「灵感与设定」记录创作背景
5. 完成后点工具栏「导出」输出 `.txt` 歌词文件

**快捷键**：
- `⌘N` 新建歌曲
- `⇧⌘N` 新建段落
- `⇧⌘K` 自动标注日语假名
- `⌘D` 把选中歌曲移到回收站
- `⌘W` 关闭当前窗口
"""),
        Section(icon: "rectangle.stack.fill", title: "三栏布局", bodyMarkdown: """
**左侧栏（曲目库）**：
- 所有歌曲 / 文件夹 / 回收站
- 单击切换歌曲，右键弹出操作菜单
- 多选（⌘点击或⇧点击）后右键弹出批量菜单
- 拖动歌曲行可重排顺序

**中间栏（编辑区）**：
- 歌曲元信息（标题 / 艺术家 / 语言 / BPM / 调式 / 节拍）
- 段落列表：每个段落可设置类型（Verse / Chorus / ...）
- 段落正文 TextEditor 直接写歌词
- 注音 chip：高亮歌词中需要注音的字，hover 看读音

**右侧栏（灵感 / 歌词预览）**：
- 灵感与设定：记录创作动机、故事背景、参考资料
- 歌词预览：像音乐 App 一样看完整歌词，双击段落跳回编辑区
- 工具栏切换灵感 / 预览（互斥）
"""),
        Section(icon: "folder.fill", title: "文件夹管理", bodyMarkdown: """
**新建文件夹**：左侧右键 → 「新建文件夹」

**操作**：
- 把歌曲拖到文件夹标题行（双击文件夹展开后再拖）
- 右键歌曲 → 「上移 / 下移」（列表内排序，不跨文件夹）
- 右键文件夹内歌曲 → 「移到其他文件夹」（单选）/「批量移到其他文件夹」（多选）
- 右键文件夹 → 「上移 / 下移」（文件夹间排序，未归档歌曲始终在文件夹上方）
- 右键文件夹 → 「归并到文件夹」批量移动
- 右键文件夹 → 「解散文件夹」（歌曲回到根目录）
- 右键文件夹 → 「删除文件夹」（歌曲移到回收站）
- 右键文件夹 → 「导出文件夹」（导出整个文件夹为 `.txt`）

**系统回收站**：
- 固定在侧栏底部（红色 trash 图标）
- 移到回收站的歌曲可在回收站里**恢复**或**永久删除**
- 二次确认后才真正永久删除（不可恢复）

**多选**：⌘点击或⇧点击多选歌曲，右键弹出批量菜单（备份 / 导出 / 合并到新文件夹 / 合并到现有文件夹 / 移到回收站）
"""),
        Section(icon: "character.bubble.fill", title: "歌词编辑", bodyMarkdown: """
**段落类型**：Intro / Verse / Chorus / Bridge / Outro / 自定义

每种类型有：
- 独立颜色（蓝 / 紫 / 橙 / ...）
- 默认 tag（[Verse] / [Chorus] / ...）
- 图标（Verse 用 text.alignleft，Chorus 用 music.mic 等）

**注音**：点击段落正文下方的「添加读音」按钮
- 起始位置 + 长度（自动预览原文）
- 读音文本
- 「自动注音」按钮：日语歌曲一键自动生成假名

**段落笔记**：点击右上角「笔记」按钮展开右侧笔记面板

**折叠 / 展开**：点击段落头右侧箭头；双击段落标题行也可切换

**v1.7.10 改进**：
- 歌词正文编辑栏高度随内容自动伸缩（短歌词不会浪费空间）
- 光标在编辑栏时滚动鼠标也能滚外层页面（滚轮穿透）
- 切换歌曲有丝滑动画，灵感 / 歌词预览切换按按钮位置决定方向
- 曲目库支持右键上移 / 下移排序、移到其他文件夹（见「文件夹管理」）
"""),
        Section(icon: "music.note.list", title: "歌词预览", bodyMarkdown: """
工具栏点 `text.viewfinder` 图标打开歌词预览（与「灵感与设定」互斥）。

预览界面：
- 顶部显示歌曲标题 + 艺术家
- 「正在预览」状态标签
- 段落列表：像音乐 App 的滚动歌词
- 当前激活段落在右栏用主题色 + 大字体高亮

**互动**：
- 编辑区点击段落 → 预览自动滚动到该段并高亮
- 预览双击段落 → 编辑区滚动 + 段落闪烁 + 光标定位
"""),
        Section(icon: "square.and.arrow.up", title: "导入 / 导出", bodyMarkdown: """
**导出**：工具栏点「导出」按钮
- 单首歌曲 → `.txt` 文件（含完整元信息 + 歌词 + 读音）
- 文件夹 → 整文件夹批量导出
- 多选歌曲 → 批量导出

**导入**：工具栏点「导入」按钮
- 支持 `.smelody.txt`（本软件导出的格式）
- 多选导入，自动按元信息重建歌曲
- 导入的歌曲默认在根目录，可手动归并到文件夹

**备份**：
- 多选歌曲 → 右键 → 「批量备份」（虚拟文件夹备份）
- 文件夹 → 右键 → 「导出文件夹」（已替代旧的「备份文件夹」）
"""),
        Section(icon: "paintpalette.fill", title: "设置", bodyMarkdown: """
点工具栏 `gearshape` 打开设置。

**主题**：跟随系统 / 浅色 / 深色（切换立即生效）

**语言**：简中 / 繁中 / English / 日本語（切换立即生效，UI 全局刷新）

**数据管理**：
- 「删除前显示确认弹窗」开关（默认开启）
- 备份 / 恢复 / 清空全部数据

**帮助**：
- 「查看更新日志」
- 「使用指南」（本窗口）

**关于**：版本号 + 开发者署名
"""),
    ]

    // MARK: 繁體中文

    private static let zhtSections: [Section] = [
        Section(icon: "wand.and.stars", title: "快速上手", bodyMarkdown: """
Simple Melody 是一款 macOS 原生歌詞創作工具，三欄佈局：左側曲目庫，中間段落編輯，右側靈感與設定。

**基本流程**：
1. 點工具列 `+ 新建歌曲`，或在左側右鍵新增
2. 中間區新增段落（Verse / Chorus / Bridge / ...）
3. 在段落內文裡寫歌詞，可加讀音 chip
4. 右側「靈感與設定」記錄創作背景
5. 完成後點工具列「匯出」輸出 `.txt` 歌詞檔案

**快捷鍵**：
- `⌘N` 新建歌曲
- `⇧⌘N` 新建段落
- `⇧⌘K` 自動標註日語假名
- `⌘D` 把選中歌曲移到回收站
- `⌘W` 關閉當前視窗
"""),
        Section(icon: "rectangle.stack.fill", title: "三欄佈局", bodyMarkdown: """
**左側欄（曲目庫）**：
- 所有歌曲 / 資料夾 / 回收桶
- 單擊切換歌曲，右鍵彈出操作選單
- 多選（⌘點擊或⇧點擊）後右鍵彈出批次選單
- 拖動歌曲行可重排順序

**中間欄（編輯區）**：
- 歌曲元資訊（標題 / 藝人 / 語言 / BPM / 調式 / 節拍）
- 段落列表：每個段落可設定類型（Verse / Chorus / ...）
- 段落內文 TextEditor 直接寫歌詞
- 注音 chip：標亮歌詞中需要注音的字，hover 看讀音

**右側欄（靈感 / 歌詞預覽）**：
- 靈感與設定：記錄創作動機、故事背景、參考資料
- 歌詞預覽：像音樂 App 一樣看完整歌詞，雙擊段落跳回編輯區
- 工具列切換靈感 / 預覽（互斥）
"""),
        Section(icon: "folder.fill", title: "資料夾管理", bodyMarkdown: """
**新建資料夾**：左側右鍵 → 「新建資料夾」

**操作**：
- 把歌曲拖到資料夾標題行（雙擊資料夾展開後再拖）
- 右鍵歌曲 → 「上移 / 下移」（列表內排序，不跨資料夾）
- 右鍵資料夾內歌曲 → 「移到其他資料夾」（單選）/「批量移到其他資料夾」（多選）
- 右鍵資料夾 → 「上移 / 下移」（資料夾間排序，未歸檔歌曲始終在資料夾上方）
- 右鍵資料夾 → 「歸併到資料夾」批次移動
- 右鍵資料夾 → 「解散資料夾」（歌曲回到根目錄）
- 右鍵資料夾 → 「刪除資料夾」（歌曲移到回收桶）
- 右鍵資料夾 → 「匯出資料夾」（匯出整個資料夾為 `.txt`）

**系統回收桶**：
- 固定在側欄底部（紅色 trash 圖示）
- 移到回收桶的歌曲可在回收桶裡**恢復**或**永久刪除**
- 二次確認後才真正永久刪除（不可恢復）

**多選**：⌘點擊或⇧點擊多選歌曲，右鍵彈出批次選單（備份 / 匯出 / 合併到新資料夾 / 合併到現有資料夾 / 移到回收桶）
"""),
        Section(icon: "character.bubble.fill", title: "歌詞編輯", bodyMarkdown: """
**段落類型**：Intro / Verse / Chorus / Bridge / Outro / 自訂

每種類型有：
- 獨立顏色（藍 / 紫 / 橙 / ...）
- 預設 tag（[Verse] / [Chorus] / ...）
- 圖示（Verse 用 text.alignleft，Chorus 用 music.mic 等）

**注音**：點擊段落內文下方的「新增讀音」按鈕
- 起始位置 + 長度（自動預覽原文）
- 讀音文字
- 「自動注音」按鈕：日語歌曲一鍵自動產生假名

**段落筆記**：點擊右上角「筆記」按鈕展開右側筆記面板

**折疊 / 展開**：點擊段落頭右側箭頭；雙擊段落標題行也可切換

**v1.7.10 改進**：
- 歌詞內文編輯欄高度隨內容自動伸縮（短歌詞不會浪費空間）
- 游標在編輯欄時滾動滑鼠也能滾外層頁面（滾輪穿透）
- 切換歌曲有絲滑動畫，靈感 / 歌詞預覽切換按按鈕位置決定方向
- 曲目庫支援右鍵上移 / 下移排序、移到其他資料夾（見「資料夾管理」）
"""),
        Section(icon: "music.note.list", title: "歌詞預覽", bodyMarkdown: """
工具列點 `text.viewfinder` 圖示開啟歌詞預覽（與「靈感與設定」互斥）。

預覽介面：
- 頂部顯示歌曲標題 + 藝人
- 「正在預覽」狀態標籤
- 段落列表：像音樂 App 的捲動歌詞
- 當前啟用段落在右欄用主題色 + 大字體高亮

**互動**：
- 編輯區點擊段落 → 預覽自動捲動到該段並高亮
- 預覽雙擊段落 → 編輯區捲動 + 段落閃爍 + 游標定位
"""),
        Section(icon: "square.and.arrow.up", title: "匯入 / 匯出", bodyMarkdown: """
**匯出**：工具列點「匯出」按鈕
- 單首歌曲 → `.txt` 檔案（含完整元資訊 + 歌詞 + 讀音）
- 資料夾 → 整資料夾批次匯出
- 多選歌曲 → 批次匯出

**匯入**：工具列點「匯入」按鈕
- 支援 `.smelody.txt`（本軟體匯出的格式）
- 多選匯入，自動按元資訊重建歌曲
- 匯入的歌曲預設在根目錄，可手動歸併到資料夾

**備份**：
- 多選歌曲 → 右鍵 → 「批次備份」（虛擬資料夾備份）
- 資料夾 → 右鍵 → 「匯出資料夾」（已替代舊的「備份資料夾」）
"""),
        Section(icon: "paintpalette.fill", title: "設定", bodyMarkdown: """
點工具列 `gearshape` 開啟設定。

**主題**：跟隨系統 / 淺色 / 深色（切換立即生效）

**語言**：簡中 / 繁中 / English / 日本語（切換立即生效，UI 全域重新整理）

**資料管理**：
- 「刪除前顯示確認彈窗」開關（預設開啟）
- 備份 / 恢復 / 清空全部資料

**說明**：
- 「查看更新日誌」
- 「使用指南」（本視窗）

**關於**：版本號 + 開發者署名
"""),
    ]

    // MARK: English

    private static let enSections: [Section] = [
        Section(icon: "wand.and.stars", title: "Quick Start", bodyMarkdown: """
Simple Melody is a native macOS lyric-writing app with a three-column layout: library on the left, editor in the middle, ideas/preview on the right.

**Basic workflow**:
1. Click `+ New Song` in the toolbar (or right-click in the sidebar)
2. Add sections (Verse / Chorus / Bridge / ...) in the middle pane
3. Write lyrics in each section's text editor; add pronunciation chips if needed
4. Use the right pane "Ideas" to capture creative background
5. Export to `.txt` when done

**Keyboard shortcuts**:
- `⌘N` new song
- `⇧⌘N` new section
- `⇧⌘K` auto-annotate Japanese furigana
- `⌘D` move selected songs to Trash
- `⌘W` close current window
"""),
        Section(icon: "rectangle.stack.fill", title: "Three-Pane Layout", bodyMarkdown: """
**Left (Library)**:
- All songs / folders / Trash
- Click to switch; right-click for actions
- Multi-select with ⌘/⇧ click, then right-click for batch menu
- Drag songs to reorder

**Middle (Editor)**:
- Song metadata (title / artist / language / BPM / key / beat)
- Section list with types (Verse / Chorus / ...)
- Lyrics text editor
- Pronunciation chips: highlight characters that need readings

**Right (Ideas / Lyrics Preview)**:
- Ideas: capture creative background
- Lyrics Preview: read complete lyrics like a music app; double-click a section to jump back to editor
- Toolbar toggles Ideas / Preview (mutually exclusive)
"""),
        Section(icon: "folder.fill", title: "Folders & Trash", bodyMarkdown: """
**Create folder**: right-click in sidebar → New Folder

**Operations**:
- Drag songs onto a folder header
- Right-click song → Move Up / Move Down (within list, no cross-folder)
- Right-click song in folder → Move to Other Folder (single) / Batch Move to Other Folder (multi)
- Right-click folder → Move Up / Move Down (between folders; unarchived songs always stay above folders)
- Right-click folder → Move to Folder (batch)
- Right-click folder → Disband (songs back to root)
- Right-click folder → Delete (songs move to Trash)
- Right-click folder → Export Folder

**Trash**:
- Always at the bottom of the sidebar (red trash icon)
- Restore or permanently delete from Trash
- Permanent delete requires double confirmation (irreversible)

**Multi-select**: ⌘/⇧ click songs, right-click for batch menu
"""),
        Section(icon: "character.bubble.fill", title: "Lyric Editing", bodyMarkdown: """
**Section types**: Intro / Verse / Chorus / Bridge / Outro / Custom

Each type has its own color, default tag, and icon.

**Pronunciation**: click "Add Reading" below the text editor
- Start position + length (auto-preview source text)
- Phonetic text
- "Auto Furigana" button for Japanese songs

**Section notes**: click the "Notes" button (top-right) to expand a notes panel

**Collapse/Expand**: click the arrow on the section header; double-click also toggles

**v1.7.10 improvements**:
- Lyrics editor height auto-sizes with content (short lyrics don't waste space)
- Scrolling the mouse while the cursor is in the editor scrolls the outer page (scroll-wheel passthrough)
- Smooth song-switching animation; Ideas / Preview panel switch follows the button positions
- Library supports right-click move up/down sorting and move to other folder (see "Folders & Trash")
"""),
        Section(icon: "music.note.list", title: "Lyrics Preview", bodyMarkdown: """
Click `text.viewfinder` in the toolbar to open the lyrics preview.

Preview shows:
- Song title + artist at the top
- "Previewing" badge
- Section list with scroll-spy style highlighting
- Active section uses accent color and slightly larger font

**Interaction**:
- Click a section in the editor → preview scrolls and highlights it
- Double-click a section in preview → editor scrolls + flashes + cursor focus
"""),
        Section(icon: "square.and.arrow.up", title: "Import / Export", bodyMarkdown: """
**Export**: click Export in the toolbar
- Single song → `.txt` file
- Folder → batch export
- Multi-select songs → batch export

**Import**: click Import in the toolbar
- Supports `.smelody.txt` files
- Multi-select import; songs land in the root by default

**Backup**:
- Multi-select songs → right-click → "Batch Backup"
- Folder → right-click → "Export Folder"
"""),
        Section(icon: "paintpalette.fill", title: "Settings", bodyMarkdown: """
Click `gearshape` in the toolbar to open Settings.

**Theme**: Follow System / Light / Dark

**Language**: Simplified Chinese / Traditional Chinese / English / 日本語

**Data**:
- "Show confirmation before delete" toggle (on by default)
- Backup / restore / clear all data

**Help**:
- Changelog
- Usage Guide (this window)

**About**: version + developer signature
"""),
    ]

    // MARK: 日本語

    private static let jaSections: [Section] = [
        Section(icon: "wand.and.stars", title: "クイックスタート", bodyMarkdown: """
Simple Melody は macOS ネイティブの歌詞作成ツールで、3 カラムレイアウト：左にライブラリ、中央にエディタ、右にアイデア/プレビュー。

**基本フロー**:
1. ツールバーの `+ 新規作成` をクリック
2. 中央エリアでセクション（Verse / Chorus / ...）を追加
3. セクション本文に歌詞を書く、フリガナ chip を追加可能
4. 右側の「アイデアと設定」で創作背景を記録
5. 完了後ツールバーの「エクスポート」で `.txt` 出力

**ショートカット**:
- `⌘N` 新規作成
- `⇧⌘N` 新規セクション
- `⇧⌘K` 日本語ふりがな自動付与
- `⌘D` 選択中の楽曲をゴミ箱へ
- `⌘W` 現在のウィンドウを閉じる
"""),
        Section(icon: "rectangle.stack.fill", title: "3 カラムレイアウト", bodyMarkdown: """
**左カラム（ライブラリ）**:
- 全楽曲 / フォルダ / ゴミ箱
- クリックで楽曲切替、右クリックで操作メニュー
- ⌘ / ⇧ クリックで複数選択後、右クリックでバッチメニュー
- ドラッグで楽曲並び替え

**中央カラム（エディタ）**:
- 楽曲メタ情報（タイトル / アーティスト / 言語 / BPM / キー / 拍子）
- セクションリスト
- 歌詞テキストエディタ
- フリガナ chip

**右カラム（アイデア / 歌詞プレビュー）**:
- アイデアと設定：創作背景
- 歌詞プレビュー：音楽アプリのように歌詞全体を表示
- ツールバーでアイデア / プレビュー切替（排他）
"""),
        Section(icon: "folder.fill", title: "フォルダとゴミ箱", bodyMarkdown: """
**フォルダ作成**: 左側で右クリック → 新規フォルダ

**操作**:
- 楽曲をフォルダヘッダーにドラッグ
- 右クリック楽曲 → 上に移動 / 下に移動（リスト内並べ替え、フォルダ間移動なし）
- 右クリック フォルダ内楽曲 → 別のフォルダに移動（単選）/ 一括で別のフォルダに移動（複数選択）
- 右クリック フォルダ → 上に移動 / 下に移動（フォルダ間並べ替え、未アーカイブ楽曲は常にフォルダより上）
- 右クリック → フォルダに統合（バッチ）
- 右クリック → フォルダ解散（楽曲をルートに戻す）
- 右クリック → フォルダ削除（楽曲をゴミ箱へ）
- 右クリック → フォルダエクスポート

**ゴミ箱**:
- サイドバー最下部（赤いアイコン）
- 復元または完全削除
- 完全削除は二重確認が必要（復元不可）

**複数選択**: ⌘ / ⇧ クリック
"""),
        Section(icon: "character.bubble.fill", title: "歌詞編集", bodyMarkdown: """
**セクションタイプ**: Intro / Verse / Chorus / Bridge / Outro / カスタム

各タイプに固有の色・タグ・アイコンがあります。

**フリガナ**: テキストエディタ下の「読み追加」をクリック
- 開始位置 + 長さ（原文を自動プレビュー）
- 読みテキスト
- 「自動フリガナ」ボタン（日本語楽曲で一键生成）

**セクションのメモ**: 右上の「メモ」ボタンで展開

**折りたたみ / 展開**: セクションヘッダーの矢印をクリック

**v1.7.10 改善**:
- 歌詞エディタの高さが内容に合わせて自動調整（短い歌詞はスペースを無駄にしない）
- エディタ内にカーソルがある時もマウスホイールでページ全体スクロール可能（ホイール透過）
- 楽曲切替のスムーズなアニメーション、アイデア / 歌詞プレビューの切替はボタン位置に従う
- ライブラリで右クリックの上下移動並べ替え、別のフォルダに移動に対応（「フォルダとゴミ箱」を参照）
"""),
        Section(icon: "music.note.list", title: "歌詞プレビュー", bodyMarkdown: """
ツールバーの `text.viewfinder` で歌詞プレビューを開きます。

プレビュー：
- 上部に楽曲タイトル + アーティスト
- 「プレビュー中」バッジ
- セクションリスト（スクロールスパイ風ハイライト）
- アクティブセクションはアクセント色 + 大きめのフォント

**インタラクション**:
- エディタでセクションをクリック → プレビューがスクロールしてハイライト
- プレビューでダブルクリック → エディタがスクロール + フラッシュ + カーソルフォーカス
"""),
        Section(icon: "square.and.arrow.up", title: "インポート / エクスポート", bodyMarkdown: """
**エクスポート**: ツールバーのエクスポート
- 単曲 → `.txt` ファイル
- フォルダ → 一括エクスポート
- 複数選択楽曲 → 一括エクスポート

**インポート**: ツールバーのインポート
- `.smelody.txt` ファイル対応
- 複数選択インポート、楽曲はルートに配置

**バックアップ**:
- 複数選択 → 右クリック → 「バッチバックアップ」
- フォルダ → 右クリック → 「フォルダエクスポート」
"""),
        Section(icon: "paintpalette.fill", title: "設定", bodyMarkdown: """
ツールバーの `gearshape` で設定を開きます。

**テーマ**: システムに追従 / ライト / ダーク

**言語**: 簡体中文 / 繁体中文 / English / 日本語

**データ**:
- 「削除前に確認ダイアログを表示」トグル（デフォルトオン）
- バックアップ / 復元 / 全データ消去

**ヘルプ**:
- 変更履歴
- 使用ガイド（このウィンドウ）

**について**: バージョン + 開発者署名
"""),
    ]
}