// Settings/UsageGuideView.swift
// 使用指南（与更新日志同格式，按 LocalizationManager 语言适配）
//
// 数据源 UsageGuideContent.sections(for:) 按当前界面语言返回不同 markdown 内容

import SwiftUI

// MARK: - 独立 Window

struct UsageGuideWindow: View {
    var body: some View {
        let frame = AppFontMetrics.usageGuideFrame
        UsageGuideView()
            .frame(
                minWidth: frame.minWidth, idealWidth: frame.idealWidth, maxWidth: frame.maxWidth,
                minHeight: frame.minHeight, idealHeight: frame.idealHeight, maxHeight: frame.maxHeight
            )
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
                .appFont(18, weight: .medium)
                .foregroundStyle(.tint)
            Text(L("使用指南"))
                .appFont(16, weight: .semibold)
            Spacer()
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                    Text(L("关闭"))
                        .appFont(12, weight: .medium)
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: section.icon)
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(.tint)
                Text(section.title)
                    .appFont(17, weight: .bold, design: .rounded)
                    .foregroundStyle(.tint)
                Spacer()
            }
            Text(.init(section.bodyMarkdown))
                .appFont(13)
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
        case .korean:
            return koSections
        case .spanish:
            return esSections
        }
    }

    // MARK: 简体中文

    private static let zhSections: [Section] = [
        Section(icon: "wand.and.stars", title: "快速上手", bodyMarkdown: """
Simple Melody 是一款 macOS 原生歌词创作工具。打开后主窗口会铺满当前屏幕（菜单栏和程序坞仍在），之后可以自己改大小。

**基本流程**：
1. 点工具栏 `+ 新建歌曲`，或在左侧右键新建
2. 中间区添加段落（Verse / Chorus / Bridge / ...）
3. 在段落正文里写歌词，可加读音，也可打开译文
4. 右侧「灵感与设定」记录创作背景
5. 完成后点工具栏「导出」输出 `.smelody.txt`

**快捷键**：
- `⌘N` 新建歌曲
- `⇧⌘N` 新建段落
- `⇧⌘K` 自动标注日语假名
- `⌘D` 把选中歌曲移到回收站
- `⌘W` 关闭当前窗口
- `Command-Esc` 取消正在进行的 Imagine
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
- 段落正文直接写歌词；注音 chip 高亮需要读音的字
- 导出按钮左边是整首歌的 Imagine

**右侧栏（灵感 / 歌词预览 / 设置）**：
- 三个入口互斥：灵感与设定、歌词预览、设置
- 灵感与设定：记录创作动机、故事背景、参考资料
- 歌词预览：像音乐 App 一样看完整歌词
- 打开设置时右边栏变宽，关掉后恢复
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
**段落类型**：Intro / Verse / Chorus / Bridge / Outro / 自定义。每种类型有独立颜色、默认 tag 和图标。

**注音**：点击段落正文下方的「添加读音」
- 起始位置 + 长度（自动预览原文）
- 读音文本
- 「自动注音」：日语歌曲一键生成假名

**笔记和译文**：点段落上的「笔记」或「译文」。两者不能同时展开。按住 Command 再点笔记、译文或折叠，会对整首歌做同样的打开或收起。

**折叠 / 展开**：点击段落头右侧箭头；双击段落标题行也可切换。

**段落拖动**（设置里默认关闭）：
- 开启后：拖到目标段上半插入其前、下半插入其后；靠近列表顶部会自动向上滚动
- 歌词编辑栏不会把段落编号写进正文

**编辑栏**：高度随内容伸缩。光标在编辑栏里时，滚轮仍能滚外层页面。
"""),
        Section(icon: "sparkles", title: "Imagine", bodyMarkdown: """
先在设置里填写大模型的供应商网址和 API Key，模型名可以留空。建议用参数量更大的模型。

**入口**：
- **Imagine**（导出按钮左边）：处理整首歌
- **段落Imagine**（歌词段落向右滑，左边蓝色按钮）：只处理这一段

点开后选 **翻译** 或 **创意**。注音即将推出。

**翻译**：
- 选择目标语言，下次会记住
- 可以另外写要求；提示词也可以留空
- 没有歌词的段落会跳过，不会把笔记当成歌词
- 只写回译文，不改歌词和笔记

**创意**：
- 会根据这首歌已有的内容重写
- 执行前会再确认一次，因为改动可能无法撤销或出错
- 整首歌的创意默认「依照当前格式」，会按段落拆开写回，不会堆进一个歌词框
- 整首歌还可以让模型补上空白的歌名、语言、速度、调式和节拍。歌名写在标题，不写进灵感设定
- 段落Imagine的创意会把整首歌交给模型作参考，只写回当前这一段，好让文风一致
- 段落Imagine不能改整首歌或其他段落。遇到这种情况会停下来并提醒，不会写入

正在请模型处理时，按 `Command-Esc` 取消。取消的回复不会写进歌里。
"""),
        Section(icon: "music.note.list", title: "歌词预览", bodyMarkdown: """
工具栏点歌词预览图标打开（与「灵感与设定」「设置」互斥）。

预览界面：
- 顶部显示歌曲标题 + 艺术家
- 段落列表：像音乐 App 的滚动歌词
- 当前激活段落用主题色 + 稍大字体高亮

**段落下的小字**（在设置里切换）：
- **笔记**：整段歌词下面跟一条灰色笔记
- **译文**：每一行歌词下面紧跟同一行的灰色译文。空行会占位，后面的行不会错位；多出来的译文行也会留下

**互动**：
- 编辑区点击段落 → 预览自动滚动到该段并高亮
- 预览双击段落 → 编辑区滚动 + 段落闪烁 + 光标定位
"""),
        Section(icon: "square.and.arrow.up", title: "导入 / 导出", bodyMarkdown: """
**导出**：工具栏点「导出」按钮
- 单首歌曲 → `.smelody.txt`（含元信息、歌词、读音、译文）
- 文件夹 → 整文件夹批量导出
- 多选歌曲 → 批量导出

**导入**：工具栏点「导入」按钮
- 支持 `.smelody.txt`
- 多选导入，自动按元信息重建歌曲
- 导入的歌曲默认在根目录，可手动归并到文件夹

**备份**：
- 多选歌曲 → 右键 → 「批量备份」
- 设置里也可以一键备份整个曲目库（含文件夹结构）
"""),
        Section(icon: "gearshape", title: "设置", bodyMarkdown: """
点工具栏齿轮，设置在**右边栏**打开，没有关闭按钮。再点一次，或改去灵感 / 预览即可离开。

**主题**：跟随系统 / 浅色 / 深色

**字体大小**：滑块只改文字大小，窗口和分栏宽度不变

**界面语言**：列表选择，可「跟随系统」。支持简体中文 / 繁體中文 / English / 日本語 / 한국어 / Español

**接入大模型**：供应商网址、模型名（可留空）、API Key。保存后可「测试连接」

**数据管理**：删除前确认、一键备份曲目库

**段落拖动**：默认关闭。开启前会提示

**技能炼成**：把词炼成 / 曲炼成 Skill 导出给能处理文件的模型使用

**帮助**：更新日志、本使用指南

**下载**：二级菜单里检查更新。启动时会安静查一次，只有发现新版本才提醒
"""),
    ]

    // MARK: 繁體中文

    private static let zhtSections: [Section] = [
        Section(icon: "wand.and.stars", title: "快速上手", bodyMarkdown: """
Simple Melody 是一款 macOS 原生歌詞創作工具。打開後主視窗會鋪滿目前螢幕（選單列和 Dock 仍在），之後可以自己改大小。

**基本流程**：
1. 點工具列 `+ 新建歌曲`，或在左側右鍵新增
2. 中間區新增段落（Verse / Chorus / Bridge / ...）
3. 在段落內文裡寫歌詞，可加讀音，也可打開譯文
4. 右側「靈感與設定」記錄創作背景
5. 完成後點工具列「匯出」輸出 `.smelody.txt`

**快捷鍵**：
- `⌘N` 新建歌曲
- `⇧⌘N` 新建段落
- `⇧⌘K` 自動標註日語假名
- `⌘D` 把選中歌曲移到回收桶
- `⌘W` 關閉當前視窗
- `Command-Esc` 取消正在進行的 Imagine
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
- 段落內文直接寫歌詞；注音 chip 標亮需要讀音的字
- 匯出按鈕左邊是整首歌的 Imagine

**右側欄（靈感 / 歌詞預覽 / 設定）**：
- 三個入口互斥：靈感與設定、歌詞預覽、設定
- 靈感與設定：記錄創作動機、故事背景、參考資料
- 歌詞預覽：像音樂 App 一樣看完整歌詞
- 打開設定時右邊欄變寬，關掉後恢復
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
**段落類型**：Intro / Verse / Chorus / Bridge / Outro / 自訂。每種類型有獨立顏色、預設 tag 和圖示。

**注音**：點擊段落內文下方的「新增讀音」
- 起始位置 + 長度（自動預覽原文）
- 讀音文字
- 「自動注音」：日語歌曲一鍵產生假名

**筆記和譯文**：點段落上的「筆記」或「譯文」。兩者不能同時展開。按住 Command 再點筆記、譯文或折疊，會對整首歌做同樣的打開或收起。

**折疊 / 展開**：點擊段落頭右側箭頭；雙擊段落標題行也可切換。

**段落拖動**（設定裡預設關閉）：
- 開啟後：拖到目標段上半插入其前、下半插入其後；靠近列表頂部會自動向上捲動
- 歌詞編輯欄不會把段落編號寫進正文

**編輯欄**：高度隨內容伸縮。游標在編輯欄裡時，滾輪仍能滾外層頁面。
"""),
        Section(icon: "sparkles", title: "Imagine", bodyMarkdown: """
先在設定裡填寫大型模型的供應商網址和 API Key，模型名可以留空。建議用參數量更大的模型。

**入口**：
- **Imagine**（匯出按鈕左邊）：處理整首歌
- **段落Imagine**（歌詞段落向右滑，左邊藍色按鈕）：只處理這一段

點開後選 **翻譯** 或 **創意**。注音即將推出。

**翻譯**：
- 選擇目標語言，下次會記住
- 可以另外寫要求；提示詞也可以留空
- 沒有歌詞的段落會跳過，不會把筆記當成歌詞
- 只寫回譯文，不改歌詞和筆記

**創意**：
- 會根據這首歌已有的內容重寫
- 執行前會再確認一次，因為改動可能無法撤銷或出錯
- 整首歌的創意預設「依照當前格式」，會按段落拆開寫回，不會堆進一個歌詞框
- 整首歌還可以讓模型補上空白的歌名、語言、速度、調式和節拍。歌名寫在標題，不寫進靈感設定
- 段落Imagine的創意會把整首歌交給模型作參考，只寫回當前這一段，好讓文風一致
- 段落Imagine不能改整首歌或其他段落。遇到這種情況會停下來並提醒，不會寫入

正在請模型處理時，按 `Command-Esc` 取消。取消的回覆不會寫進歌裡。
"""),
        Section(icon: "music.note.list", title: "歌詞預覽", bodyMarkdown: """
工具列點歌詞預覽圖示開啟（與「靈感與設定」「設定」互斥）。

預覽介面：
- 頂部顯示歌曲標題 + 藝人
- 段落列表：像音樂 App 的捲動歌詞
- 當前啟用段落用主題色 + 稍大字體高亮

**段落下的小字**（在設定裡切換）：
- **筆記**：整段歌詞下面跟一條灰色筆記
- **譯文**：每一行歌詞下面緊跟同一行的灰色譯文。空行會佔位，後面的行不會錯位；多出來的譯文行也會留下

**互動**：
- 編輯區點擊段落 → 預覽自動捲動到該段並高亮
- 預覽雙擊段落 → 編輯區捲動 + 段落閃爍 + 游標定位
"""),
        Section(icon: "square.and.arrow.up", title: "匯入 / 匯出", bodyMarkdown: """
**匯出**：工具列點「匯出」按鈕
- 單首歌曲 → `.smelody.txt`（含元資訊、歌詞、讀音、譯文）
- 資料夾 → 整資料夾批次匯出
- 多選歌曲 → 批次匯出

**匯入**：工具列點「匯入」按鈕
- 支援 `.smelody.txt`
- 多選匯入，自動按元資訊重建歌曲
- 匯入的歌曲預設在根目錄，可手動歸併到資料夾

**備份**：
- 多選歌曲 → 右鍵 → 「批次備份」
- 設定裡也可以一鍵備份整個曲目庫（含資料夾結構）
"""),
        Section(icon: "gearshape", title: "設定", bodyMarkdown: """
點工具列齒輪，設定在**右邊欄**打開，沒有關閉按鈕。再點一次，或改去靈感 / 預覽即可離開。

**主題**：跟隨系統 / 淺色 / 深色

**字體大小**：滑桿只改文字大小，視窗和分欄寬度不變

**介面語言**：列表選擇，可「跟隨系統」。支援簡體中文 / 繁體中文 / English / 日本語 / 한국어 / Español

**接入大型模型**：供應商網址、模型名（可留空）、API Key。儲存後可「測試連接」

**資料管理**：刪除前確認、一鍵備份曲目庫

**段落拖動**：預設關閉。開啟前會提示

**技能煉成**：把詞煉成 / 曲煉成 Skill 匯出給能處理檔案的模型使用

**說明**：更新日誌、本使用指南

**下載**：二級選單裡檢查更新。啟動時會安靜查一次，只有發現新版本才提醒
"""),
    ]

    // MARK: English

    private static let enSections: [Section] = [
        Section(icon: "wand.and.stars", title: "Quick Start", bodyMarkdown: """
Simple Melody is a native macOS lyric-writing app. The main window fills the screen when it opens (menu bar and Dock stay). You can resize it afterward.

**Basic workflow**:
1. Click `+ New Song` in the toolbar (or right-click in the sidebar)
2. Add sections (Verse / Chorus / Bridge / ...) in the middle pane
3. Write lyrics; add pronunciation chips or open translation
4. Use the right pane "Ideas" for creative background
5. Export to `.smelody.txt` when done

**Keyboard shortcuts**:
- `⌘N` new song
- `⇧⌘N` new section
- `⇧⌘K` auto-annotate Japanese furigana
- `⌘D` move selected songs to Trash
- `⌘W` close current window
- `Command-Esc` cancel an in-flight Imagine
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
- Lyrics editor and pronunciation chips
- Imagine for the whole song sits to the left of Export

**Right (Ideas / Lyrics Preview / Settings)**:
- The three entries are mutually exclusive
- Ideas: capture creative background
- Lyrics Preview: read complete lyrics like a music app
- Opening Settings widens the column; leaving it restores the width
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
**Section types**: Intro / Verse / Chorus / Bridge / Outro / Custom. Each type has its own color, default tag, and icon.

**Pronunciation**: click "Add Reading" below the text editor
- Start position + length (auto-preview source text)
- Phonetic text
- "Auto Furigana" for Japanese songs

**Notes and translation**: open Notes or Translation on a section. They cannot both be open. Hold Command and click notes, translation, or collapse to do the same on the whole song.

**Collapse/Expand**: click the arrow on the section header; double-click also toggles.

**Section Drag** (off by default in Settings):
- Drop on the top half of a section to insert before it, bottom half to insert after; the list auto-scrolls near the top
- The lyrics editor never pastes a section id into the text

**Editor height** grows with content. Scrolling the mouse while the cursor is in the editor still scrolls the outer page.
"""),
        Section(icon: "sparkles", title: "Imagine", bodyMarkdown: """
Fill in the provider URL and API key in Settings first. The model name may be empty. A larger-parameter model is recommended.

**Where to start**:
- **Imagine** (left of Export): the whole song
- **Section Imagine** (swipe a lyric section right, blue button on the left): only that section

Choose **Translation** or **Creative**. Pronunciation is coming later.

**Translation**:
- Pick a target language; it is remembered next time
- Extra instructions are optional; the prompt may be empty
- Sections with no lyrics are skipped; notes are not treated as lyrics
- Only translation is written back

**Creative**:
- Rewrites from what the song already contains
- Asks for confirmation first, because the change may be irreversible or wrong
- Whole-song Creative defaults to Follow current format and splits labeled sections in order
- Whole-song Creative can fill a blank title, language, tempo, key, and meter. The title goes in the title field, not Ideas
- Section Imagine Creative sends the whole song for style and writes back only the current section
- Section Imagine cannot change the whole song or other sections. It stops with an alert and writes nothing

While the model is working, press `Command-Esc` to cancel. A cancelled reply is not written into the song.
"""),
        Section(icon: "music.note.list", title: "Lyrics Preview", bodyMarkdown: """
Click the lyrics-preview icon in the toolbar (mutually exclusive with Ideas and Settings).

Preview shows:
- Song title + artist at the top
- Section list with scroll-spy highlighting
- The active section uses accent color and a slightly larger font

**Small text under a section** (chosen in Settings):
- **Notes**: one gray notes caption under the whole lyric block
- **Translation**: each lyric line is paired with the gray translation line at the same index. Blank translation lines keep later lines aligned; extra translation lines are kept

**Interaction**:
- Click a section in the editor → preview scrolls and highlights it
- Double-click a section in preview → editor scrolls + flashes + cursor focus
"""),
        Section(icon: "square.and.arrow.up", title: "Import / Export", bodyMarkdown: """
**Export**: click Export in the toolbar
- Single song → `.smelody.txt` (metadata, lyrics, readings, translation)
- Folder → batch export
- Multi-select songs → batch export

**Import**: click Import in the toolbar
- Supports `.smelody.txt`
- Multi-select import; songs land in the root by default

**Backup**:
- Multi-select songs → right-click → Batch Backup
- Settings can also back up the whole library, including folders
"""),
        Section(icon: "gearshape", title: "Settings", bodyMarkdown: """
Click the toolbar gear. Settings opens in the **right column** and has no close button. Click the gear again, or switch to Ideas / Preview, to leave.

**Theme**: Follow System / Light / Dark

**Font size**: the slider changes text only; windows and column widths stay put

**Interface language**: a list, plus Follow System. Simplified Chinese / Traditional Chinese / English / 日本語 / 한국어 / Español

**LLM**: provider URL, model name (optional), API key. Save, then Test connection

**Data**: confirm before delete; one-click library backup

**Section Drag**: off by default; turning it on asks first

**Skill Integrated**: export Lyric Forge / Music Forge skills to a model that can handle files

**Help**: Changelog, this Usage Guide

**Download**: a second-level menu checks for updates. Launch checks quietly and only alerts when a new version exists
"""),
    ]

    // MARK: 日本語

    private static let jaSections: [Section] = [
        Section(icon: "wand.and.stars", title: "クイックスタート", bodyMarkdown: """
Simple Melody は macOS ネイティブの歌詞作成ツールです。起動するとメインウィンドウが画面いっぱいに開きます（メニューバーと Dock はそのまま）。あとからサイズは変えられます。

**基本フロー**:
1. ツールバーの `+ 新規作成` をクリック
2. 中央エリアでセクション（Verse / Chorus / ...）を追加
3. 歌詞を書き、フリガナや訳文を付けられます
4. 右側の「アイデアと設定」で創作背景を記録
5. 完了後ツールバーの「エクスポート」で `.smelody.txt` を出力

**ショートカット**:
- `⌘N` 新規作成
- `⇧⌘N` 新規セクション
- `⇧⌘K` 日本語ふりがな自動付与
- `⌘D` 選択中の楽曲をゴミ箱へ
- `⌘W` 現在のウィンドウを閉じる
- `Command-Esc` 進行中の Imagine を中止
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
- 歌詞テキストエディタとフリガナ chip
- 書き出しボタンの左が曲全体の Imagine

**右カラム（アイデア / 歌詞プレビュー / 設定）**:
- 3 つは排他
- アイデアと設定：創作背景
- 歌詞プレビュー：音楽アプリのように歌詞全体を表示
- 設定を開くと右カラムが広くなり、閉じると戻ります
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
**セクションタイプ**: Intro / Verse / Chorus / Bridge / Outro / カスタム。各タイプに固有の色・タグ・アイコンがあります。

**フリガナ**: テキストエディタ下の「読み追加」をクリック
- 開始位置 + 長さ（原文を自動プレビュー）
- 読みテキスト
- 「自動フリガナ」（日本語楽曲）

**メモと訳文**: セクションの「メモ」または「訳文」を開きます。同時には開けません。Command を押しながらメモ、訳文、折りたたみを押すと、曲全体が同じ開閉になります。

**折りたたみ / 展開**: セクションヘッダーの矢印をクリック。ダブルクリックでも切替。

**セクションドラッグ**（設定では既定オフ）:
- 上半分にドロップするとその前、下半分だとその後へ挿入。リスト上部付近では自動で上スクロール
- 歌詞エディタにセクション ID は入りません

**エディタの高さ**は内容に合わせて伸びます。カーソルがエディタ内でもホイールでページ全体をスクロールできます。
"""),
        Section(icon: "sparkles", title: "Imagine", bodyMarkdown: """
先に設定でプロバイダ URL と API キーを入れてください。モデル名は空でも構いません。パラメータの大きいモデルを勧めます。

**入口**:
- **Imagine**（書き出しの左）：曲全体
- **段落Imagine**（歌詞セクションを右に滑らせ、左の青いボタン）：そのセクションだけ

**翻訳**か**創作**を選びます。フリガナは近日対応。

**翻訳**:
- 訳す言語を選び、次回もその言語が選ばれます
- 追加の要望は任意。プロンプトは空でも構いません
- 歌詞のないセクションは飛ばし、メモを歌詞扱いしません
- 書き戻すのは訳文だけです

**創作**:
- 曲にある内容から書き直します
- 取り消せなかったり誤ったりすることがあるため、先に確認します
- 曲全体の創作は「現在の形式に合わせる」が既定で、セクションごとに分けて書き戻します
- 曲全体では空の曲名、言語、テンポ、調、拍子を補えます。曲名はタイトル欄へ書き、アイデアには書きません
- 段落Imagineの創作は曲全体を文風の参考として渡し、今のセクションだけを書き戻します
- 段落Imagineは曲全体や他のセクションを変えられません。止めて知らせ、書き込みません

モデル処理中は `Command-Esc` で中止できます。中止した返信は曲に入りません。
"""),
        Section(icon: "music.note.list", title: "歌詞プレビュー", bodyMarkdown: """
ツールバーの歌詞プレビューアイコンで開きます（アイデア・設定と排他）。

プレビュー：
- 上部に楽曲タイトル + アーティスト
- セクションリスト（スクロールスパイ風ハイライト）
- アクティブセクションはアクセント色 + 大きめのフォント

**セクション下の小字**（設定で切替）:
- **メモ**: 歌詞ブロックの下に灰色のメモを 1 本
- **訳文**: 各歌詞行の下に同じ番号の灰色の訳。空行は位置を保ち、余った訳行も残します

**インタラクション**:
- エディタでセクションをクリック → プレビューがスクロールしてハイライト
- プレビューでダブルクリック → エディタがスクロール + フラッシュ + カーソルフォーカス
"""),
        Section(icon: "square.and.arrow.up", title: "インポート / エクスポート", bodyMarkdown: """
**エクスポート**: ツールバーのエクスポート
- 単曲 → `.smelody.txt`（メタ情報、歌詞、読み、訳文）
- フォルダ → 一括エクスポート
- 複数選択楽曲 → 一括エクスポート

**インポート**: ツールバーのインポート
- `.smelody.txt` 対応
- 複数選択インポート、楽曲はルートに配置

**バックアップ**:
- 複数選択 → 右クリック → 「バッチバックアップ」
- 設定からライブラリ全体（フォルダ構造込み）もバックアップできます
"""),
        Section(icon: "gearshape", title: "設定", bodyMarkdown: """
ツールバーの歯車をクリックすると、設定は**右カラム**で開きます。閉じるボタンはありません。もう一度押すか、アイデア / プレビューに切り替えます。

**テーマ**: システムに追従 / ライト / ダーク

**フォントサイズ**: スライダーは文字の大きさだけを変え、ウィンドウと欄の幅はそのままです

**言語**: リストで選び、「システムに合わせる」も選べます。簡体中文 / 繁体中文 / English / 日本語 / 한국어 / Español

**LLM**: プロバイダ URL、モデル名（空可）、API キー。保存してから接続を試せます

**データ**: 削除前の確認、ライブラリの一括バックアップ

**セクションドラッグ**: 既定オフ。オンにする前に確認します

**スキル錬成**: 作詞 / 作曲の Skill を、ファイルを扱えるモデルへ書き出します

**ヘルプ**: 変更履歴、この使用ガイド

**ダウンロード**: 二次メニューで更新を確認。起動時は静かに調べ、新しい版があるときだけ知らせます
"""),
    ]

    // MARK: 한국어

    private static let koSections: [Section] = [
        Section(icon: "wand.and.stars", title: "빠른 시작", bodyMarkdown: """
Simple Melody는 macOS 네이티브 가사 작성 앱입니다. 열면 메인 창이 화면을 채웁니다(메뉴 바와 Dock은 그대로). 나중에 크기를 바꿀 수 있습니다.

**기본 흐름**:
1. 도구 막대에서 `+ 새 곡`을 누르거나 왼쪽에서 우클릭
2. 가운데에 섹션(Verse / Chorus / Bridge / ...)을 추가
3. 가사를 쓰고, 발음을 달거나 번역을 엽니다
4. 오른쪽 「아이디어」에 창작 배경을 적습니다
5. 끝나면 「내보내기」로 `.smelody.txt`를 만듭니다

**단축키**:
- `⌘N` 새 곡
- `⇧⌘N` 새 섹션
- `⇧⌘K` 일본어 후리가나 자동
- `⌘D` 선택한 곡을 휴지통으로
- `⌘W` 현재 창 닫기
- `Command-Esc` 진행 중인 Imagine 취소
"""),
        Section(icon: "rectangle.stack.fill", title: "세 칸 레이아웃", bodyMarkdown: """
**왼쪽(곡 목록)**:
- 모든 곡 / 폴더 / 휴지통
- 클릭으로 전환, 우클릭으로 메뉴
- ⌘/⇧ 클릭으로 여러 개 선택한 뒤 우클릭
- 끌어다 순서 바꾸기

**가운데(편집)**:
- 곡 정보(제목 / 아티스트 / 언어 / BPM / 조성 / 박자)
- 섹션 목록
- 가사 편집과 발음 칩
- 내보내기 왼쪽이 곡 전체 Imagine

**오른쪽(아이디어 / 가사 미리보기 / 설정)**:
- 세 가지는 동시에 열리지 않습니다
- 아이디어: 창작 배경
- 가사 미리보기: 음악 앱처럼 가사 전체
- 설정을 열면 오른쪽이 넓어지고, 나가면 돌아갑니다
"""),
        Section(icon: "folder.fill", title: "폴더와 휴지통", bodyMarkdown: """
**폴더 만들기**: 왼쪽에서 우클릭 → 새 폴더

**조작**:
- 곡을 폴더 제목 줄에 끌어다 놓기
- 곡 우클릭 → 위로 / 아래로 (목록 안, 폴더를 넘지 않음)
- 폴더 안 곡 우클릭 → 다른 폴더로 / 일괄 이동
- 폴더 우클릭 → 위로 / 아래로 (폴더 사이; 미분류 곡은 항상 폴더 위)
- 폴더 우클릭 → 폴더로 합치기, 해체, 삭제, 내보내기

**휴지통**:
- 사이드바 맨 아래(빨간 아이콘)
- 복원 또는 영구 삭제
- 영구 삭제는 두 번 확인합니다(되돌릴 수 없음)

**여러 선택**: ⌘/⇧ 클릭 후 우클릭
"""),
        Section(icon: "character.bubble.fill", title: "가사 편집", bodyMarkdown: """
**섹션 종류**: Intro / Verse / Chorus / Bridge / Outro / 사용자 지정. 색, 태그, 아이콘이 다릅니다.

**발음**: 편집기 아래 「읽기 추가」
- 시작 위치 + 길이(원문 미리보기)
- 발음 텍스트
- 「자동 후리가나」(일본어)

**메모와 번역**: 섹션에서 메모 또는 번역을 엽니다. 동시에 열 수 없습니다. Command를 누른 채 메모, 번역, 접기를 누르면 곡 전체가 같이 열리거나 닫힙니다.

**접기 / 펼치기**: 섹션 머리의 화살표. 두 번 클릭도 됩니다.

**섹션 끌기**(설정에서 기본 꺼짐):
- 위쪽에 놓으면 앞, 아래쪽에 놓으면 뒤. 목록 위쪽에서는 자동으로 위로 스크롤
- 가사 칸에 섹션 번호가 들어가지 않습니다

**편집기 높이**는 내용에 맞춰 늘어납니다. 커서가 안에 있어도 휠로 바깥 페이지를 굴릴 수 있습니다.
"""),
        Section(icon: "sparkles", title: "Imagine", bodyMarkdown: """
먼저 설정에 공급자 주소와 API 키를 넣습니다. 모델 이름은 비워 둘 수 있습니다. 매개변수가 큰 모델을 권합니다.

**시작 위치**:
- **Imagine**(내보내기 왼쪽): 곡 전체
- **단락 Imagine**(가사 섹션을 오른쪽으로 밀면 왼쪽 파란 버튼): 그 섹션만

**번역** 또는 **창작**을 고릅니다. 발음은 곧 나옵니다.

**번역**:
- 목표 언어를 고르면 다음에도 기억합니다
- 추가 요청은 선택. 프롬프트는 비워도 됩니다
- 가사가 없는 섹션은 건너뛰고, 메모를 가사로 쓰지 않습니다
- 번역만 다시 씁니다

**창작**:
- 곡에 있는 내용으로 다시 씁니다
- 되돌릴 수 없거나 잘못될 수 있어 먼저 확인합니다
- 곡 전체 창작은 「현재 형식을 따름」이 기본이며 섹션을 나눠 넣습니다
- 빈 제목, 언어, 빠르기, 조성, 박자를 채울 수 있습니다. 제목은 제목 칸에 쓰고 아이디어에는 쓰지 않습니다
- 단락 Imagine 창작은 문체를 맞추려고 곡 전체를 보내고, 지금 섹션만 다시 씁니다
- 단락 Imagine은 곡 전체나 다른 섹션을 바꾸지 못합니다. 멈추고 알리며 쓰지 않습니다

모델이 일하는 동안 `Command-Esc`로 취소합니다. 취소한 답은 곡에 들어가지 않습니다.
"""),
        Section(icon: "music.note.list", title: "가사 미리보기", bodyMarkdown: """
도구 막대에서 가사 미리보기 아이콘을 누릅니다(아이디어·설정과 함께 열리지 않음).

미리보기:
- 위에 제목 + 아티스트
- 섹션 목록과 스크롤 하이라이트
- 활성 섹션은 강조색과 조금 큰 글자

**섹션 아래 작은 글** (설정에서 고름):
- **메모**: 가사 덩어리 아래에 회색 메모 한 줄
- **번역**: 각 가사 줄 아래에 같은 번호의 회색 번역. 빈 줄은 자리를 지키고, 남는 번역 줄도 남습니다

**상호작용**:
- 편집에서 섹션을 클릭 → 미리보기가 그곳으로 스크롤하고 강조
- 미리보기에서 두 번 클릭 → 편집이 스크롤 + 깜빡임 + 커서
"""),
        Section(icon: "square.and.arrow.up", title: "가져오기 / 내보내기", bodyMarkdown: """
**내보내기**: 도구 막대의 내보내기
- 한 곡 → `.smelody.txt` (정보, 가사, 발음, 번역)
- 폴더 → 일괄 내보내기
- 여러 곡 → 일괄 내보내기

**가져오기**: 도구 막대의 가져오기
- `.smelody.txt` 지원
- 여러 개 가져오면 기본적으로 루트에 둡니다

**백업**:
- 여러 곡 우클릭 → 일괄 백업
- 설정에서 폴더 구조까지 라이브러리 전체를 백업할 수 있습니다
"""),
        Section(icon: "gearshape", title: "설정", bodyMarkdown: """
도구 막대 톱니를 누르면 설정이 **오른쪽 열**에서 열립니다. 닫기 버튼은 없습니다. 다시 누르거나 아이디어 / 미리보기로 나갑니다.

**테마**: 시스템 따름 / 밝게 / 어둡게

**글자 크기**: 슬라이더는 글자만 바꿉니다. 창과 칸 너비는 그대로입니다

**언어**: 목록에서 고르고 「시스템을 따름」도 있습니다. 简体中文 / 繁體中文 / English / 日本語 / 한국어 / Español

**LLM**: 공급자 주소, 모델 이름(비워도 됨), API 키. 저장한 뒤 연결을 시험합니다

**데이터**: 지우기 전 확인, 라이브러리 한 번에 백업

**섹션 끌기**: 기본 꺼짐. 켜기 전에 물어봅니다

**스킬 연마**: 작사 / 작곡 스킬을 파일을 다룰 수 있는 모델로 내보냅니다

**도움말**: 변경 기록, 이 사용 가이드

**다운로드**: 2단 메뉴에서 업데이트를 확인합니다. 시작할 때는 조용히 확인하고, 새 버전이 있을 때만 알립니다
"""),
    ]

    // MARK: Español

    private static let esSections: [Section] = [
        Section(icon: "wand.and.stars", title: "Inicio rápido", bodyMarkdown: """
Simple Melody es una app nativa de macOS para escribir letras. Al abrirla, la ventana principal llena la pantalla (la barra de menú y el Dock se quedan). Luego se puede cambiar el tamaño.

**Flujo básico**:
1. Pulsa `+ Nueva canción` en la barra (o clic derecho a la izquierda)
2. Añade secciones (Verse / Chorus / Bridge / ...) en el centro
3. Escribe la letra; puedes añadir pronunciación o abrir la traducción
4. Usa Ideas a la derecha para el fondo creativo
5. Exporta a `.smelody.txt` al terminar

**Atajos**:
- `⌘N` nueva canción
- `⇧⌘N` nueva sección
- `⇧⌘K` furigana japonés automático
- `⌘D` enviar las canciones elegidas a la Papelera
- `⌘W` cerrar la ventana actual
- `Command-Esc` cancelar un Imagine en curso
"""),
        Section(icon: "rectangle.stack.fill", title: "Tres columnas", bodyMarkdown: """
**Izquierda (canciones)**:
- Todas las canciones / carpetas / Papelera
- Clic para cambiar; clic derecho para acciones
- Selección múltiple con ⌘/⇧ y luego clic derecho
- Arrastra para reordenar

**Centro (editor)**:
- Datos de la canción (título / artista / idioma / BPM / tonalidad / compás)
- Lista de secciones
- Editor de letra y chips de pronunciación
- Imagine de toda la canción está a la izquierda de Exportar

**Derecha (Ideas / vista previa / Ajustes)**:
- Las tres entradas son excluyentes
- Ideas: fondo creativo
- Vista previa: la letra completa, como en una app de música
- Al abrir Ajustes la columna se ensancha; al salir vuelve
"""),
        Section(icon: "folder.fill", title: "Carpetas y Papelera", bodyMarkdown: """
**Crear carpeta**: clic derecho a la izquierda → Nueva carpeta

**Operaciones**:
- Arrastra canciones al encabezado de una carpeta
- Clic derecho en la canción → Subir / Bajar (dentro de la lista)
- Clic derecho en una canción de carpeta → Mover a otra / Mover en lote
- Clic derecho en la carpeta → Subir / Bajar, reunir, disolver, borrar, exportar

**Papelera**:
- Siempre abajo del todo (icono rojo)
- Restaurar o borrar para siempre
- El borrado definitivo pide confirmación doble (irreversible)

**Selección múltiple**: ⌘/⇧ clic y luego clic derecho
"""),
        Section(icon: "character.bubble.fill", title: "Edición de la letra", bodyMarkdown: """
**Tipos de sección**: Intro / Verse / Chorus / Bridge / Outro / personalizado. Cada tipo tiene color, etiqueta e icono.

**Pronunciación**: pulsa «Añadir lectura» bajo el editor
- Posición inicial + longitud (vista previa del texto)
- Texto fonético
- «Furigana automático» para canciones en japonés

**Notas y traducción**: abre Notas o Traducción en una sección. No se abren a la vez. Mantén Command y pulsa notas, traducción o plegado para hacer lo mismo en toda la canción.

**Plegar / desplegar**: la flecha del encabezado; también con doble clic.

**Arrastre de secciones** (apagado por defecto en Ajustes):
- Suelta en la mitad superior para insertar antes, en la inferior para después; cerca del borde superior la lista se desplaza sola
- El editor no pega un identificador de sección en la letra

**La altura del editor** crece con el contenido. Con el cursor dentro, la rueda sigue desplazando la página.
"""),
        Section(icon: "sparkles", title: "Imagine", bodyMarkdown: """
Primero rellena en Ajustes la URL del proveedor y la clave de API. El nombre del modelo puede quedar vacío. Se recomienda un modelo grande.

**Dónde empezar**:
- **Imagine** (a la izquierda de Exportar): toda la canción
- **Imagine de sección** (desliza una sección a la derecha, botón azul a la izquierda): solo esa sección

Elige **Traducción** o **Creativo**. La pronunciación llegará más adelante.

**Traducción**:
- Elige el idioma; se recuerda la próxima vez
- Las instrucciones extra son opcionales; el aviso puede quedar vacío
- Las secciones sin letra se saltan; las notas no se tratan como letra
- Solo se escribe de nuevo la traducción

**Creativo**:
- Reescribe a partir de lo que ya tiene la canción
- Pide confirmación primero, porque el cambio puede no deshacerse o salir mal
- En toda la canción, Seguir el formato actual viene activado y reparte las secciones en orden
- Puede completar un título, idioma, tempo, tonalidad y compás en blanco. El título va al campo de título, no a Ideas
- Lo creativo de Imagine de sección envía la canción entera para el estilo y solo escribe de nuevo la sección actual
- Imagine de sección no puede cambiar la canción entera ni otras secciones. Se detiene con un aviso y no escribe nada

Mientras el modelo trabaja, pulsa `Command-Esc` para cancelar. Una respuesta cancelada no se escribe en la canción.
"""),
        Section(icon: "music.note.list", title: "Vista previa", bodyMarkdown: """
Pulsa el icono de vista previa en la barra (no se abre a la vez que Ideas o Ajustes).

La vista previa muestra:
- Título + artista arriba
- Lista de secciones con resaltado al desplazarse
- La sección activa usa el color de acento y una letra un poco mayor

**Texto pequeño bajo la sección** (se elige en Ajustes):
- **Notas**: un pie gris bajo todo el bloque de letra
- **Traducción**: cada línea de letra va con la línea gris de traducción del mismo índice. Las líneas en blanco mantienen el alineado; las de más se conservan

**Interacción**:
- Clic en una sección del editor → la vista previa se desplaza y la resalta
- Doble clic en la vista previa → el editor se desplaza + parpadea + enfoca el cursor
"""),
        Section(icon: "square.and.arrow.up", title: "Importar / Exportar", bodyMarkdown: """
**Exportar**: pulsa Exportar en la barra
- Una canción → `.smelody.txt` (datos, letra, lecturas, traducción)
- Carpeta → exportación por lotes
- Varias canciones → exportación por lotes

**Importar**: pulsa Importar en la barra
- Admite `.smelody.txt`
- La importación múltiple deja las canciones en la raíz

**Copia de seguridad**:
- Varias canciones → clic derecho → copia por lotes
- En Ajustes también se puede copiar toda la biblioteca, con carpetas
"""),
        Section(icon: "gearshape", title: "Ajustes", bodyMarkdown: """
Pulsa el engranaje. Ajustes se abre en la **columna derecha** y no tiene botón de cerrar. Vuelve a pulsarlo, o pasa a Ideas / vista previa, para salir.

**Tema**: Seguir el sistema / Claro / Oscuro

**Tamaño de letra**: el control solo cambia el texto; las ventanas y el ancho de las columnas no se mueven

**Idioma**: una lista, más Seguir el sistema. 简体中文 / 繁體中文 / English / 日本語 / 한국어 / Español

**LLM**: URL del proveedor, nombre del modelo (opcional), clave de API. Guarda y luego prueba la conexión

**Datos**: confirmar antes de borrar; copia de la biblioteca de un clic

**Arrastre de secciones**: apagado por defecto; al encenderlo pregunta

**Habilidades integradas**: exporta las skills de letra / música a un modelo que pueda manejar archivos

**Ayuda**: registro de cambios, esta guía

**Descarga**: un menú de segundo nivel busca actualizaciones. Al iniciar lo hace en silencio y solo avisa si hay una versión nueva
"""),
    ]
}
