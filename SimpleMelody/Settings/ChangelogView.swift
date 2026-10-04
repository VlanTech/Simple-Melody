// Settings/ChangelogView.swift
// 更新日志窗口（支持 Markdown 渲染）
// v1.4: 改为独立 Window scene，自带标题栏 + cmd+W 正常工作
// 每次更新必须把新版本接在上方，不删除旧版本
// 带字母标的版本（GT5 / Beta / Gamma / Delta / Extra …）不再单开条目：
// 合并进对应的数字版本，日期取其中最新的一天，日志按【章节】并到同一条里

import SwiftUI

// MARK: - 独立 Window（用 WindowGroup 是为了 v1.4 beta 兼容性；macOS 14+ 可改用 Window）

struct ChangelogWindow: View {
    var body: some View {
        let frame = AppFontMetrics.changelogFrame
        ChangelogView()
            .frame(
                minWidth: frame.minWidth, idealWidth: frame.idealWidth, maxWidth: frame.maxWidth,
                minHeight: frame.minHeight, idealHeight: frame.idealHeight, maxHeight: frame.maxHeight
            )
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
 .appFont(18, weight: .medium)
 .foregroundStyle(.tint)
 Text(L("更新日志"))
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

 Divider()

 // 正文：【章节】+ • 列表（窗口不渲染 Markdown）
 ScrollView {
 VStack(alignment: .leading, spacing: 0) {
 ForEach(ChangelogContent.displayedEntries) { entry in
 changelogEntryView(entry, lang: loc.language)
 if entry.id != ChangelogContent.displayedEntries.last?.id {
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
 .appFont(18, weight: .bold, design: .rounded)
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
 Text(ChangelogDisplayText.fromMarkdown(entry.markdown(for: lang)))
 .appFont(13)
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
 var id: String { version }
 let version: String
 let date: String
 let isLatest: Bool
 /// v1.7.5 Gamma: 简中 markdown（fallback）
 let bodyMarkdown: String
 /// 繁中 / 英文 / 日文 / 韩文 / 西班牙文（optional，没填则 fallback 到简中）
 var bodyMarkdownZHT: String? = nil
 var bodyMarkdownEN: String? = nil
 var bodyMarkdownJA: String? = nil
 var bodyMarkdownKO: String? = nil
 var bodyMarkdownES: String? = nil

 /// 按语言返回正文（缺该语言时 fallback 到简中）
 func markdown(for lang: AppLanguage) -> String {
 switch lang {
 case .simplifiedChinese: return bodyMarkdown
 case .traditionalChinese: return bodyMarkdownZHT ?? bodyMarkdown
 case .english: return bodyMarkdownEN ?? bodyMarkdown
 case .japanese: return bodyMarkdownJA ?? bodyMarkdown
 case .korean: return bodyMarkdownKO ?? bodyMarkdown
 case .spanish: return bodyMarkdownES ?? bodyMarkdown
 }
 }
 }

        static var displayedEntries: [Entry] {
            let rows = entries.map {
                ChangelogRow(
                    version: $0.version,
                    date: $0.date,
                    isLatest: $0.isLatest,
                    bodyMarkdown: $0.bodyMarkdown,
                    bodyMarkdownZHT: $0.bodyMarkdownZHT ?? "",
                    bodyMarkdownEN: $0.bodyMarkdownEN ?? "",
                    bodyMarkdownJA: $0.bodyMarkdownJA ?? "",
                    bodyMarkdownKO: $0.bodyMarkdownKO ?? "",
                    bodyMarkdownES: $0.bodyMarkdownES ?? ""
                )
            }
            return ChangelogFold.fold(rows).map { row in
                Entry(
                    version: row.version,
                    date: row.date,
                    isLatest: row.isLatest,
                    bodyMarkdown: row.bodyMarkdown,
                    bodyMarkdownZHT: row.bodyMarkdownZHT.isEmpty ? nil : row.bodyMarkdownZHT,
                    bodyMarkdownEN: row.bodyMarkdownEN.isEmpty ? nil : row.bodyMarkdownEN,
                    bodyMarkdownJA: row.bodyMarkdownJA.isEmpty ? nil : row.bodyMarkdownJA,
                    bodyMarkdownKO: row.bodyMarkdownKO.isEmpty ? nil : row.bodyMarkdownKO,
                    bodyMarkdownES: row.bodyMarkdownES.isEmpty ? nil : row.bodyMarkdownES
                )
            }
        }

static let entries: [Entry] = [
        Entry(
            version: "v1.8.3",
            date: "2026-09-30",
            isLatest: true,
            bodyMarkdown: """
【新增】
• 新增Imagine的AI日语注音功能，优化了旧版注音功能交互
• 歌词文件支持导出注音等数据
【修复】
• 修复歌词栏光标显示问题 
• 创意功能判定逻辑修复
【改动】
• 弃用“自动注音”功能，现仅支持手动注音或使用Imagine注音！
""",
            bodyMarkdownZHT: """
【新增】
• 新增 Imagine 的 AI 日語注音功能，並改良舊版注音功能的操作方式
• 歌詞檔支援匯出注音等資料
【修復】
• 修正歌詞欄游標顯示的問題
• 修正創意功能的判定邏輯
【改動】
• 棄用「自動注音」功能，現僅支援手動注音或使用 Imagine 注音！
""",
            bodyMarkdownEN: """
【New】
• Imagine can now add AI Japanese furigana, and the older furigana interaction works better
• Lyric files can export furigana and other data
【Fixed】
• Fixed how the cursor shows in the lyrics box
• Fixed the decision logic behind Creative
【Changed】
• Auto furigana is retired — only manual annotations or Imagine annotations are supported now!
""",
            bodyMarkdownJA: """
【新機能】
• Imagine に AI による日本語ふりがな機能を追加し、旧版のふりがな機能の操作を改善しました
• 歌詞ファイルでふりがななどのデータを書き出せます
【修正】
• 歌詞欄のカーソル表示の問題を直しました
• 創作機能の判定ロジックを修正しました
【変更】
• 「自動ふりがな」機能を廃止しました。今後は手動のふりがな、または Imagine のふりがなのみです！
""",
            bodyMarkdownKO: """
【추가】
• Imagine에 AI 일본어 후리가나 기능을 추가하고, 예전 후리가나 기능의 조작을 개선했습니다
• 가사 파일에서 후리가나 등 데이터를 내보낼 수 있습니다
【수정】
• 가사 칸의 커서 표시 문제를 고쳤습니다
• 창작 기능의 판정 로직을 수정했습니다
【변경】
• 「자동 후리가나」 기능을 폐지했습니다. 이제는 수동 후리가나 또는 Imagine 후리가나만 지원합니다!
""",
            bodyMarkdownES: """
【Nuevo】
• Imagine añade furigana japonés con IA y mejora el manejo del furigana anterior
• Los archivos de letra pueden exportar el furigana y otros datos
【Corrección】
• Se corrigió la visualización del cursor en el recuadro de la letra
• Se corrigió la lógica de decisión de Creativo
【Cambios】
• ¡El furigana automático queda retirado: ahora solo hay anotaciones manuales o de Imagine!
"""
        ),
        Entry(
            version: "v1.8.2",
            date: "2026-09-25",
            isLatest: false,
            bodyMarkdown: """
【新增】
• Imagine功能，可在主页面右上方或段落右滑找到，支持接入LLM的API帮助你创作歌词
• 设置内可调节字体大小
【修复】
• 修复了一些Bug
""",
            bodyMarkdownZHT: """
【新增】
• Imagine 功能，可在主頁面右上方或段落右滑找到，支援接入 LLM 的 API 幫助你創作歌詞
• 設定內可調節字體大小
【修復】
• 修正了一些 Bug
""",
            bodyMarkdownEN: """
【New】
• Imagine can be found at the top right of the main window or by swiping a section right, and it can connect to an LLM API to help you write lyrics
• Font size can be adjusted in Settings
【Fixed】
• Fixed some bugs
""",
            bodyMarkdownJA: """
【新機能】
• Imagine はメイン画面の右上、またはセクションを右に滑らせると見つかります。LLM の API につないで歌詞づくりを手伝います
• 設定でフォントサイズを変えられます
【修正】
• いくつかの不具合を直しました
""",
            bodyMarkdownKO: """
【추가】
• Imagine은 메인 화면 오른쪽 위나 섹션을 오른쪽으로 밀면 찾을 수 있고, LLM API에 연결해 가사 작성을 도와줍니다
• 설정에서 글자 크기를 조절할 수 있습니다
【수정】
• 몇 가지 버그를 고쳤습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Imagine está arriba a la derecha de la ventana principal o al deslizar una sección a la derecha, y puede conectarse a una API de LLM para ayudarte a escribir la letra
• El tamaño de letra se ajusta en Ajustes
【Corrección】
• Se corrigieron algunos errores
""",
        ),
        Entry(
            version: "v1.8.1",
            date: "2026-09-24",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 按住 Command 点任意段落的笔记、译文或折叠，可批量执行全文段落
• 界面语言增加韩语、西班牙语
【改动】
• 导出按钮UI改动
• 设置页UI改动，可以保存大模型 API Key
""",
            bodyMarkdownZHT: """
【新增】
• 按住 Command 點任意段落的筆記、譯文或折疊，可批次套用到全文段落
• 介面語言增加韓語、西班牙語
【改動】
• 匯出按鈕的介面改動
• 設定頁介面改動，可以儲存大模型 API Key
""",
            bodyMarkdownEN: """
【New】
• Hold Command and click notes, translation, or collapse on any section to apply it to every section in the song
• Korean and Spanish were added to the interface languages
【Changed】
• The export button has a new UI
• The settings page has a new UI and can save an LLM API Key
""",
            bodyMarkdownJA: """
【新機能】
• Command を押しながら任意のセクションのメモ、訳文、折りたたみを押すと、曲全体のセクションにまとめて反映できます
• インターフェース言語に韓国語とスペイン語を追加しました
【変更】
• 書き出しボタンの UI を変更しました
• 設定ページの UI を変更し、大規模言語モデルの API Key を保存できます
""",
            bodyMarkdownKO: """
【추가】
• Command 키를 누른 채 아무 섹션의 메모, 번역, 접기를 누르면 곡 전체 섹션에 한꺼번에 적용됩니다
• 인터페이스 언어에 한국어와 스페인어를 추가했습니다
【변경】
• 내보내기 버튼 UI를 변경했습니다
• 설정 페이지 UI를 변경하고, 대형 언어 모델의 API Key를 저장할 수 있습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Mantén Command y pulsa notas, traducción o plegar en cualquier sección para aplicarlo a todas las secciones de la canción
• Se añadieron coreano y español a los idiomas de la interfaz
【Cambios】
• El botón de exportar cambia de aspecto
• La página de ajustes cambia de aspecto y puede guardar una API Key del modelo de lenguaje
""",
        ),
        Entry(
            version: "v1.8.0",
            date: "2026-09-19",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 设置里的下载可以检查有没有新版本。启动时会安静地查一次，只有发现新版本才提醒，也可以手动去下载
• 歌词预览里，段落下面的小字可以在笔记和译文之间切换
""",
            bodyMarkdownZHT: """
【新增】
• 設定裡的下載可以檢查有沒有新版本。啟動時會安靜地查一次，只有發現新版本才提醒，也可以手動去下載
• 歌詞預覽裡，段落下面的小字可以在筆記和譯文之間切換
""",
            bodyMarkdownEN: """
【New】
• Download in Settings can check for a new version. Launch checks quietly and only alerts when one exists, and you can download it yourself
• In the lyrics preview, the small line under a section can switch between notes and translation
""",
            bodyMarkdownJA: """
【新機能】
• 設定のダウンロードで新しいバージョンを確認できます。起動時は静かに確認し、新しい版があるときだけ知らせ、自分でダウンロードもできます
• 歌詞プレビューでは、セクションの下の小字をメモと訳文の間で切り替えられます
""",
            bodyMarkdownKO: """
【추가】
• 설정의 다운로드에서 새 버전을 확인할 수 있습니다. 시작할 때는 조용히 확인하고, 새 버전이 있을 때만 알리며 직접 받을 수도 있습니다
• 가사 미리보기에서 섹션 아래의 작은 글자를 메모와 번역 사이에서 바꿀 수 있습니다
""",
            bodyMarkdownES: """
【Nuevo】
• La descarga en Ajustes puede buscar una versión nueva. Al iniciar lo hace en silencio y solo avisa si hay una, y también se puede descargar a mano
• En la vista previa, el texto pequeño bajo una sección puede alternar entre notas y traducción
""",
        ),
        Entry(
            version: "v1.7.10",
            date: "2026-06-26",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 段落里增加了译文，与笔记互斥，歌词文件可以一并带上译文
【修复】
• 拖动段落的交互方式（目前仍存在部分问题不建议使用）
【纪念】
• 纪念 Minecraft v1.7.10 发布十二周年
""",
            bodyMarkdownZHT: """
【新增】
• 段落裡增加了譯文，與筆記互斥，歌詞檔可以一併帶上譯文
【修復】
• 拖動段落的操作方式（目前仍有部分問題，不建議使用）
【紀念】
• 紀念 Minecraft v1.7.10 發布十二週年
""",
            bodyMarkdownEN: """
【New】
• Sections gained a translation that cannot be open at the same time as notes, and a lyric file can carry the translation along
【Fixed】
• How sections are dragged (some problems remain, so it is not recommended yet)
【In memory】
• In memory of the twelfth anniversary of Minecraft v1.7.10
""",
            bodyMarkdownJA: """
【新機能】
• セクションに訳文が増え、メモとは同時に開けません。歌詞ファイルに訳文も入れられます
【修正】
• セクションのドラッグ操作（まだ一部問題が残るため、今はおすすめしません）
【記念】
• Minecraft v1.7.10 公開十二周年を記念します
""",
            bodyMarkdownKO: """
【추가】
• 섹션에 번역이 생겼고 메모와 함께 열 수 없으며, 가사 파일에 번역도 넣을 수 있습니다
【수정】
• 섹션을 끄는 조작 방식(아직 일부 문제가 있어 권장하지 않습니다)
【기념】
• Minecraft v1.7.10 출시 12주년을 기념합니다
""",
            bodyMarkdownES: """
【Nuevo】
• Las secciones tienen traducción y no se abre a la vez que las notas; el archivo de letra puede llevar la traducción
【Corrección】
• La forma de arrastrar secciones (todavía tiene problemas, así que no se recomienda)
【En memoria】
• En memoria del duodécimo aniversario de Minecraft v1.7.10
""",
        ),
        Entry(
            version: "v1.7.9",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 文件夹可以用右键向上或向下调整顺序，并修正了多语言显示
• 曲目列表可以用右键上移、下移，也可以移到别的文件夹
• 换到列表里更下面的歌时从右往左滑，换到更上面的歌时从左往右滑
• 右侧的灵感和歌词预览互相切换时，会左右滑一下
• 设置里增加了段落拖动开关，默认关闭。打开前会提醒它和歌词编辑、左滑删除可能互相影响
• 关闭段落拖动时，可以把段落向左滑来删除
【修复】
• 修正了歌词文字编辑、向左滑删除的样子，以及一些动画问题
• 修正了一批小问题
• 修正了笔记和歌曲信息展开时的动画、滚轮被挡住、换歌后光标还在，以及文字点不中的问题
• 换歌时的动画统一从右往左，快速连切也不会反方向跳
• 歌词编辑区的高度会跟着内容变
• 换歌时不再自动把光标放进歌词，只有你自己点进去才会开始输入
• 文件夹和回收站点一下就能展开或收起
• 灵感和歌词预览按按钮所在的左右方向滑入滑出。关掉右侧时，那一栏会收起来
• 灵感条目的最小高度可以选一行或两行
• 歌词编辑区的光标不会再一直停着。点到编辑区外面，光标就会消失，换歌后颜色也正常
【改动】
• 把此前的稳定修正合并进来，段落拖动开关和笔记、折叠的动画都回来了
• 笔记和折叠的动画恢复了。段落拖动暂时改回默认开启，开关先拿掉
• 段落右键里的删除更显眼，用的是红色
• 鼠标在歌词上滚动时，整页也会跟着滚
• 各处右键里的删除都改成红色垃圾桶图标
• 歌曲信息展开和收起更顺手
""",
            bodyMarkdownZHT: """
【新增】
• 資料夾可以用右鍵向上或向下調整順序，並修正了多語言顯示
• 曲目列表可以用右鍵上移、下移，也可以移到別的資料夾
• 換到列表裡更下面的歌時從右往左滑，換到更上面的歌時從左往右滑
• 右側的靈感和歌詞預覽互相切換時，會左右滑一下
• 設定裡增加了段落拖動開關，預設關閉。打開前會提醒它和歌詞編輯、左滑刪除可能互相影響
• 關閉段落拖動時，可以把段落向左滑來刪除
【修復】
• 修正了歌詞文字編輯、向左滑刪除的樣子，以及一些動畫問題
• 修正了一批小問題
• 修正了筆記和歌曲資訊展開時的動畫、滾輪被擋住、換歌後游標還在，以及文字點不中的問題
• 換歌時的動畫統一從右往左，快速連切也不會反方向跳
• 歌詞編輯區的高度會跟著內容變
• 換歌時不再自動把游標放進歌詞，只有你自己點進去才會開始輸入
• 資料夾和回收桶點一下就能展開或收起
• 靈感和歌詞預覽按按鈕所在的左右方向滑入滑出。關掉右側時，那一欄會收起來
• 靈感條目的最小高度可以選一行或兩行
• 歌詞編輯區的游標不會再一直停著。點到編輯區外面，游標就會消失，換歌後顏色也正常
【改動】
• 把此前的穩定修正合併進來，段落拖動開關和筆記、折疊的動畫都回來了
• 筆記和折疊的動畫恢復了。段落拖動暫時改回預設開啟，開關先拿掉
• 段落右鍵裡的刪除更顯眼，用的是紅色
• 滑鼠在歌詞上滾動時，整頁也會跟著滾
• 各處右鍵裡的刪除都改成紅色垃圾桶圖示
• 歌曲資訊展開和收起更順手
""",
            bodyMarkdownEN: """
【New】
• Folders can move up or down from the right-click menu, and several languages display more correctly
• Songs in the list can move up, down, or into another folder from the right-click menu
• Moving to a song lower in the list slides from right to left. Moving to a higher one slides from left to right
• Switching the right side between ideas and lyrics preview slides sideways
• Settings gained a section-drag switch, off by default. Turning it on warns that it may conflict with editing lyrics and swiping to delete
• With dragging off, a section can be deleted by swiping left
【Fixed】
• Fixed lyric text editing, the look of swipe-to-delete, and some animation problems
• Fixed a batch of small problems
• Fixed the animation when notes and song details open, the scroll wheel getting stuck, the cursor lingering after a song change, and clicks missing the text
• Changing songs always slides from right to left, even if you switch quickly
• The lyric editor grows and shrinks with the text
• Changing songs no longer drops the cursor into the lyrics. Typing starts only when you click there
• A folder or the trash opens and closes with one click
• Ideas and lyrics preview slide in from the side of their buttons. Closing the right side collapses that column
• An idea note can start at one line or two
• The cursor no longer stays stuck in the lyric editor. Click outside and it goes away, and the color is right after a song change
【Changed】
• Earlier stable fixes were merged back in. The section-drag switch and the notes and collapse animations returned
• Notes and collapse animate again. Section dragging was turned on by default for this try, and the switch was removed
• Delete in a section's right-click menu is easier to see and shown in red
• Scrolling over the lyrics also scrolls the page
• Delete items in right-click menus use a red trash icon
• Song details open and close more smoothly
""",
            bodyMarkdownJA: """
【新機能】
• フォルダを右クリックで上下に並べ替えられ、多言語の表示も直しました
• 曲一覧を右クリックで上下に動かしたり、別のフォルダへ移したりできます
• 一覧で下の曲へ移ると右から左、上の曲へ移ると左から右に滑ります
• 右側のアイデアと歌詞プレビューを入れ替えるとき、左右に滑ります
• 設定にセクション移動のスイッチが増え、既定はオフです。オンにする前に、歌詞編集や左へ滑らせて消す操作とぶつかることがあると知らせます
• 移動をオフにすると、セクションを左に滑らせて削除できます
【修正】
• 歌詞の文字編集、左に滑らせて消す見た目、いくつかのアニメーションを直しました
• 細かい不具合をまとめて直しました
• メモと曲情報を開くアニメーション、ホイールが通らないこと、曲を替えてもカーソルが残ること、文字が押しにくいことを直しました
• 曲を替えるアニメーションは右から左に統一し、素早く替えても逆向きになりません
• 歌詞の編集欄の高さは内容に合わせて変わります
• 曲を替えても、勝手に歌詞へカーソルを置きません。自分で押したときだけ入力できます
• フォルダとゴミ箱は一回のクリックで開閉します
• アイデアと歌詞プレビューは、ボタンのある側から出入りします。右を閉じるとその列はしまいます
• アイデアの最小の高さは一行か二行から選べます
• 歌詞の編集欄にカーソルが居座らなくなりました。外を押すと消え、曲を替えたあとの色も正常です
【変更】
• それまでの安定版の修正をまとめ、セクションドラッグのスイッチとメモ、折りたたみのアニメーションが戻りました
• メモと折りたたみのアニメーションが戻りました。この試行ではセクションドラッグを既定でオンにし、スイッチは外しました
• セクションの右クリックにある削除は赤く、見つけやすくなりました
• 歌詞の上でホイールを回すと、ページも一緒に動きます
• 右クリックの削除は赤いゴミ箱の絵になりました
• 曲情報の開閉が滑らかになりました
""",
            bodyMarkdownKO: """
【추가】
• 폴더를 오른쪽 클릭으로 위아래로 옮길 수 있고, 여러 언어 표시도 고쳤습니다
• 곡 목록에서 오른쪽 클릭으로 위아래 이동과 다른 폴더로 옮기기가 됩니다
• 목록에서 더 아래 곡으로 가면 오른쪽에서 왼쪽, 더 위 곡으로 가면 왼쪽에서 오른쪽으로 미끄러집니다
• 오른쪽의 아이디어와 가사 미리보기를 바꿀 때 좌우로 미끄러집니다
• 설정에 섹션 드래그 스위치가 생겼고 기본은 꺼짐입니다. 켜기 전에 가사 편집, 왼쪽으로 밀어 지우기와 부딪힐 수 있다고 알립니다
• 드래그를 끄면 섹션을 왼쪽으로 밀어 지울 수 있습니다
【수정】
• 가사 편집, 왼쪽으로 밀어 지우는 모양, 일부 애니메이션을 고쳤습니다
• 작은 문제 여러 개를 고쳤습니다
• 메모와 곡 정보를 펼치는 애니메이션, 스크롤 휠이 막히던 것, 곡을 바꿔도 커서가 남던 것, 글자를 잘 누르지 못하던 것을 고쳤습니다
• 곡을 바꿀 때의 움직임은 오른쪽에서 왼쪽으로 통일되어, 빨리 바꿔도 반대로 튀지 않습니다
• 가사 편집칸의 높이가 내용에 맞춰 변합니다
• 곡을 바꿔도 가사를 마음대로 입력 상태로 두지 않습니다. 직접 눌렀을 때만 입력합니다
• 폴더와 휴지통은 한 번 누르면 펼치거나 접힙니다
• 아이디어와 가사 미리보기는 버튼이 있는 쪽에서 들어오고 나갑니다. 오른쪽을 닫으면 그 열이 접힙니다
• 아이디어의 최소 높이를 한 줄 또는 두 줄로 고를 수 있습니다
• 가사 편집칸에 커서가 계속 남지 않습니다. 밖을 누르면 사라지고, 곡을 바꾼 뒤의 색도 정상입니다
【변경】
• 이전의 안정적인 수정을 합쳤습니다. 섹션 드래그 스위치와 메모, 접기 애니메이션이 돌아왔습니다
• 메모와 접기 애니메이션이 돌아왔습니다. 이번 시험에서는 섹션 드래그를 기본으로 켜고 스위치는 뺐습니다
• 섹션 오른쪽 클릭의 삭제가 더 잘 보이게 빨간색입니다
• 가사 위에서 휠을 굴리면 페이지도 같이 움직입니다
• 오른쪽 클릭의 삭제는 빨간 휴지통 그림입니다
• 곡 정보를 펼치고 접는 느낌이 더 부드럽습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Las carpetas se pueden subir o bajar con el clic derecho, y se corrigió la presentación en varios idiomas
• En la lista se puede subir, bajar o mover una canción a otra carpeta con el clic derecho
• Ir a una canción más abajo se desliza de derecha a izquierda, y a una más arriba, de izquierda a derecha
• Al pasar entre ideas y la vista previa, el panel derecho se desliza a un lado
• Ajustes tiene un interruptor para arrastrar secciones, apagado al principio. Al encenderlo avisa de que puede chocar con editar la letra y borrar deslizando
• Con el arrastre apagado, una sección se borra deslizando a la izquierda
【Corrección】
• Se corrigió la edición del texto, el aspecto de borrar deslizando y algunos problemas de animación
• Se corrigió un puñado de problemas pequeños
• Se corrigió la animación al abrir notas y datos de la canción, la rueda que no pasaba, el cursor que seguía al cambiar de canción y los clics que no daban en el texto
• Al cambiar de canción el movimiento va siempre de derecha a izquierda, también si se cambia muy rápido
• El alto del editor de la letra sigue al texto
• Cambiar de canción ya no deja el cursor dentro de la letra. Solo se escribe cuando se pulsa ahí
• Una carpeta o la papelera se abre y se cierra con un clic
• Ideas y la vista previa entran desde el lado de su botón. Al cerrar la derecha, esa columna se guarda
• La altura mínima de una idea puede ser de una o dos líneas
• El cursor ya no se queda fijo en el editor. Al pulsar fuera desaparece, y el color queda bien al cambiar de canción
【Cambios】
• Se unieron las correcciones estables anteriores. Volvieron el interruptor de arrastrar secciones y las animaciones de notas y plegado
• Volvieron las animaciones de notas y plegado. En esta prueba, arrastrar secciones quedó activado y se quitó el interruptor
• Eliminar en el menú contextual de la sección se ve mejor y en rojo
• La rueda sobre la letra también desplaza la página
• Eliminar en los menús contextuales usa un cubo rojo
• Los datos de la canción se abren y se cierran con más suavidad
""",
        ),
        Entry(
            version: "v1.7.8",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 段落的右键菜单可以把它移到最上面或最下面
• 点曲目列表里的歌不再慢半拍。拖动段落时，靠近顶部会自动往上滚
• 编辑区里的段落可以拖着调整顺序。拖到某一段的上半就插到它前面，拖到列表末尾就放到最后
• 向左滑删除时，只有真正点到删除按钮才会删，点到旁边会自己收回去
• 曲目列表里的歌可以拖进文件夹、拖出文件夹，或拖到另一首歌前面来排序
• 多选时的右键菜单里拿掉了和批量导出重复的备份。删除前确认的开关第一次打开就能看见滑块了
""",
            bodyMarkdownZHT: """
【新增】
• 段落的右鍵選單可以把它移到最上面或最下面
• 點曲目列表裡的歌不再慢半拍。拖動段落時，靠近頂部會自動往上滾
• 編輯區裡的段落可以拖著調整順序。拖到某一段的上半就插到它前面，拖到列表末尾就放到最後
• 向左滑刪除時，只有真正點到刪除按鈕才會刪，點到旁邊會自己收回去
• 曲目列表裡的歌可以拖進資料夾、拖出資料夾，或拖到另一首歌前面來排序
• 多選時的右鍵選單裡拿掉了和批次匯出重複的備份。刪除前確認的開關第一次打開就能看見滑塊了
""",
            bodyMarkdownEN: """
【New】
• A section's right-click menu can move it to the very top or the very bottom
• Choosing a song in the list is no longer sluggish. Dragging a section near the top scrolls upward
• Sections in the editor can be dragged to reorder them. The upper half inserts before, and the end of the list adds it last
• When swiping left to delete, only a tap on the delete button deletes. Tapping beside it closes the button
• Songs in the list can be dragged into a folder, out of a folder, or in front of another song to reorder them
• The duplicate backup item was removed from the multi-select menu. The confirm-before-delete switch shows its slider the first time it opens
""",
            bodyMarkdownJA: """
【新機能】
• セクションの右クリックから、一番上か一番下へ移せます
• 曲一覧で曲を押したときの遅れをなくしました。セクションを上の方までドラッグすると自動で上へ動きます
• 編集画面のセクションをドラッグして並べ替えられます。上半分に置くとその前、一覧の最後に置くと末尾です
• 左に滑らせて消すとき、削除ボタンを押したときだけ消えます。脇を押すとボタンは戻ります
• 曲一覧の曲をフォルダへ入れたり出したり、別の曲の前に置いて並べ替えたりできます
• 複数選択のメニューから、一括書き出しと重なるバックアップを外しました。削除前確認のスイッチは最初からつまみが見えます
""",
            bodyMarkdownKO: """
【추가】
• 섹션 오른쪽 클릭으로 맨 위나 맨 아래로 옮길 수 있습니다
• 곡 목록에서 곡을 누를 때 늦던 것을 없앴습니다. 섹션을 위쪽까지 끌면 자동으로 위로 움직입니다
• 편집 화면의 섹션을 끌어 순서를 바꿀 수 있습니다. 위쪽에 놓으면 앞에, 목록 끝에 놓으면 마지막입니다
• 왼쪽으로 밀어 지울 때, 삭제 버튼을 눌렀을 때만 지워집니다. 옆을 누르면 버튼이 들어갑니다
• 곡 목록의 곡을 폴더에 넣거나 빼고, 다른 곡 앞에 놓아 순서를 바꿀 수 있습니다
• 여러 개 선택의 메뉴에서 일괄 내보내기와 겹치던 백업을 뺐습니다. 삭제 전 확인 스위치는 처음 열어도 손잡이가 보입니다
""",
            bodyMarkdownES: """
【Nuevo】
• El menú contextual de una sección puede llevarla al principio o al final
• Elegir una canción en la lista ya no va con retraso. Arrastrar una sección cerca de arriba desplaza hacia arriba
• Las secciones del editor se pueden arrastrar para ordenarlas. La mitad superior inserta antes, y el final de la lista la deja al último
• Al deslizar para borrar, solo un toque en el botón de borrar elimina. Tocar al lado lo guarda
• Las canciones de la lista se pueden meter en una carpeta, sacar de ella o poner delante de otra para ordenarlas
• Se quitó la copia repetida del menú de selección múltiple. El interruptor de confirmar el borrado muestra su deslizador desde la primera vez
""",
        ),
        Entry(
            version: "v1.7.7",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 歌曲信息里增加了节拍器，会按速度发出拍子并闪一下
• 修正了技能说明没有翻译的问题，使用说明也补上了繁体中文
• 设置里增加了技能导出，放在帮助上面。也可以从这里打开下载页，关于里能看到开发者邮箱
• 用真正的标志图换掉了占位图，技能和使用说明的小字也整理过了
""",
            bodyMarkdownZHT: """
【新增】
• 歌曲資訊裡增加了節拍器，會按速度發出拍子並閃一下
• 修正了技能說明沒有翻譯的問題，使用說明也補上了繁體中文
• 設定裡增加了技能匯出，放在幫助上面。也可以從這裡打開下載頁，關於裡能看到開發者郵箱
• 用真正的標誌圖換掉了佔位圖，技能和使用說明的小字也整理過了
""",
            bodyMarkdownEN: """
【New】
• Song details include a metronome that clicks and flashes with the tempo
• The skill description is translated now, and the guide includes traditional Chinese
• Settings gained skill export above Help, a way to open the download page, and the developer email in About
• The placeholder picture was replaced with the real logo, and the small notes for skills and the guide were cleaned up
""",
            bodyMarkdownJA: """
【新機能】
• 曲情報にメトロノームが増え、テンポに合わせて音と点滅が出ます
• スキルの説明が翻訳されるようになり、使い方ガイドに繁体字中国語も入りました
• 設定にスキルの書き出しが増え、ヘルプの上にあります。ダウンロードページも開け、情報に開発者のメールが出ます
• 仮の絵を本物のロゴに替え、スキルと使い方の小さな注記も整えました
""",
            bodyMarkdownKO: """
【추가】
• 곡 정보에 메트로놈이 생겨, 빠르기에 맞춰 소리와 깜빡임이 납니다
• 스킬 설명이 번역되고, 사용 안내에도 번체 중국어가 들어갔습니다
• 설정에 스킬 내보내기가 도움말 위에 생겼습니다. 다운로드 페이지도 열 수 있고, 정보에 개발자 메일이 나옵니다
• 자리 표시 그림을 실제 로고로 바꾸고, 스킬과 사용 안내의 작은 글도 다듬었습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Los datos de la canción incluyen un metrónomo que suena y parpadea con el tempo
• La descripción de la habilidad ya está traducida, y la guía incluye chino tradicional
• Ajustes tiene la exportación de habilidades encima de Ayuda, un enlace de descarga y el correo del desarrollador en Acerca de
• La imagen de relleno se sustituyó por el logotipo real, y se ordenaron las notas pequeñas de las habilidades y la guía
""",
        ),
        Entry(
            version: "v1.7.5",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【新增】
• Command-N 新建歌曲，Command-D 删除选中的歌。帮助和更新日志会跟着界面语言变化
• 切换外观主题会马上生效。删除确认的开关第一次就能看见。帮助里增加了使用说明
""",
            bodyMarkdownZHT: """
【新增】
• Command-N 新建歌曲，Command-D 刪除選中的歌。幫助和更新日誌會跟著介面語言變化
• 切換外觀主題會馬上生效。刪除確認的開關第一次就能看見。幫助裡增加了使用說明
""",
            bodyMarkdownEN: """
【New】
• Command-N creates a song and Command-D deletes the selection. Help and the changelog follow the interface language
• Changing the theme applies at once. The delete-confirmation switch is visible the first time. Help includes a usage guide
""",
            bodyMarkdownJA: """
【新機能】
• Command-N で新しい曲、Command-D で選択した曲を削除します。ヘルプと更新履歴は表示言語に従います
• テーマの切り替えはすぐに反映されます。削除確認のスイッチは最初から見え、ヘルプに使い方ガイドが増えました
""",
            bodyMarkdownKO: """
【추가】
• Command-N으로 새 곡을 만들고 Command-D로 고른 곡을 지웁니다. 도움말과 업데이트 기록은 화면 언어를 따릅니다
• 테마를 바꾸면 바로 적용됩니다. 삭제 확인 스위치는 처음부터 보이고, 도움말에 사용 안내가 생겼습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Command-N crea una canción y Command-D borra la selección. La ayuda y el registro siguen el idioma de la interfaz
• El cambio de tema se aplica al momento. El interruptor de confirmar el borrado se ve desde el principio. La ayuda incluye una guía de uso
""",
        ),
        Entry(
            version: "v1.7.4",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 切换外观会马上生效，删除确认开关第一次打开就能看见滑块
【修复】
• 文件夹里面的歌也能正常弹出右键菜单。只选一首歌时不再显示已选一项的工具条
【改动】
• 整理了侧栏的右键菜单，拿掉了备份文件夹。回收站可以双击展开。删除时会播放系统的废纸篓声音
""",
            bodyMarkdownZHT: """
【新增】
• 切換外觀會馬上生效，刪除確認開關第一次打開就能看見滑塊
【修復】
• 資料夾裡面的歌也能正常彈出右鍵選單。只選一首歌時不再顯示已選一項的工具列
【改動】
• 整理了側欄的右鍵選單，拿掉了備份資料夾。回收桶可以雙擊展開。刪除時會播放系統的廢紙簍聲音
""",
            bodyMarkdownEN: """
【New】
• The theme changes at once, and the delete-confirmation switch shows its slider the first time it opens
【Fixed】
• Songs inside a folder show their right-click menu again. Selecting a single song no longer shows a one-item toolbar
【Changed】
• The sidebar menu was tidied and folder backup was removed. The trash opens with a double click. Deleting plays the system trash sound
""",
            bodyMarkdownJA: """
【新機能】
• 見た目の切り替えはすぐ反映され、削除確認のスイッチは最初からつまみが見えます
【修正】
• フォルダの中の曲でも右クリックメニューが出ます。一曲だけ選んでも「1件選択」のバーは出ません
【変更】
• サイドバーの右クリックを整え、フォルダのバックアップを外しました。ゴミ箱はダブルクリックで開き、削除時にはシステムのゴミ箱の音が鳴ります
""",
            bodyMarkdownKO: """
【추가】
• 모양을 바꾸면 바로 적용되고, 삭제 확인 스위치는 처음 열어도 손잡이가 보입니다
【수정】
• 폴더 안의 곡에서도 오른쪽 클릭 메뉴가 나옵니다. 곡 하나만 골라도 한 개 선택 막대는 나오지 않습니다
【변경】
• 사이드바 오른쪽 클릭을 정리하고 폴더 백업을 뺐습니다. 휴지통은 두 번 눌러 열리고, 지울 때 시스템 휴지통 소리가 납니다
""",
            bodyMarkdownES: """
【Nuevo】
• El tema cambia al momento y el interruptor de confirmar el borrado muestra su deslizador desde la primera apertura
【Corrección】
• Las canciones dentro de una carpeta vuelven a mostrar su menú contextual. Elegir una sola ya no muestra una barra de un elemento
【Cambios】
• Se ordenó el menú de la barra lateral y se quitó la copia de la carpeta. La papelera se abre con doble clic. Al borrar suena la papelera del sistema
""",
        ),
        Entry(
            version: "v1.7.3",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 浅色时列表上不该出现的绿色块去掉了，设置里的外观也会跟着系统或所选主题走
• 浅色模式下看不清的文字和图标改成看得清的颜色。段落四周的底色块拿掉了，改成细一点的边距和边框
【改动】
• 颜色改成跟着文字颜色走，深浅模式下都更一致。跳转后的闪烁时间从零点八秒缩短到半秒
""",
            bodyMarkdownZHT: """
【修復】
• 淺色時列表上不該出現的綠色塊去掉了，設定裡的外觀也會跟著系統或所選主題走
• 淺色模式下看不清的文字和圖示改成看得清的顏色。段落四周的底色塊拿掉了，改成細一點的邊距和邊框
【改動】
• 顏色改成跟著文字顏色走，深淺模式下都更一致。跳轉後的閃爍時間從零點八秒縮短到半秒
""",
            bodyMarkdownEN: """
【Fixed】
• The unwanted green block on the list in light mode is gone, and the app follows the system or the chosen theme
• Text and icons that vanished in light mode are readable again. The flat color behind a section was replaced with a lighter margin and border
【Changed】
• Colors now follow the text color, so light and dark stay consistent. The jump flash was shortened from eight tenths of a second to half a second
""",
            bodyMarkdownJA: """
【修正】
• ライトモードの一覧に出ていた緑の塊をなくし、見た目はシステムか選んだテーマに従います
• ライトモードで見えなかった文字とアイコンが見える色になりました。セクション背面の色塊をやめ、余白と枠にしました
【変更】
• 色は文字色に沿い、ライトとダークで揃いました。ジャンプ後の点滅は〇・八秒から〇・五秒になりました
""",
            bodyMarkdownKO: """
【수정】
• 밝은 모드 목록에 나오던 초록 덩어리를 없애고, 모양은 시스템이나 고른 테마를 따릅니다
• 밝은 모드에서 안 보이던 글자와 아이콘이 보이는 색이 되었습니다. 섹션 뒤의 색 덩어리를 없애고 여백과 테두리로 바꿨습니다
【변경】
• 색이 글자색을 따라 밝은 화면과 어두운 화면이 더 맞습니다. 이동 뒤 깜빡임은 0.8초에서 0.5초로 줄었습니다
""",
            bodyMarkdownES: """
【Corrección】
• Desapareció el bloque verde de la lista en modo claro, y la aplicación sigue al sistema o al tema elegido
• El texto y los iconos invisibles en modo claro vuelven a leerse. El bloque de color tras la sección pasó a un margen y un borde más ligeros
【Cambios】
• Los colores siguen al texto, así que el modo claro y el oscuro coinciden. El parpadeo al saltar pasó de ocho décimas a medio segundo
""",
        ),
        Entry(
            version: "v1.7.2",
            date: "2026-06-20",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 跳转后只有被点到的那一段会闪一下，不再整首歌一起闪。段落边框上多余的强调色也拿掉了
""",
            bodyMarkdownZHT: """
【修復】
• 跳轉後只有被點到的那一段會閃一下，不再整首歌一起閃。段落邊框上多餘的強調色也拿掉了
""",
            bodyMarkdownEN: """
【Fixed】
• After a jump, only the section you chose flashes, not the whole song. The extra accent on the section border was removed
""",
            bodyMarkdownJA: """
【修正】
• ジャンプしたあと点滅するのは選んだセクションだけで、曲全体は点滅しません。枠の余分な強調色も外しました
""",
            bodyMarkdownKO: """
【수정】
• 이동한 뒤에는 고른 섹션만 깜빡이고 곡 전체가 같이 깜빡이지 않습니다. 섹션 테두리의 남은 강조색도 뺐습니다
""",
            bodyMarkdownES: """
【Corrección】
• Tras un salto solo parpadea la sección elegida, no la canción entera. Se quitó el acento de más del borde
""",
        ),
        Entry(
            version: "v1.7.1",
            date: "2026-06-20",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 去掉了正在编辑的段落一直高亮、跳过去时闪烁，以及双击才把光标放进歌词这几项。安装包里的说明文本也拿掉了
""",
            bodyMarkdownZHT: """
【改動】
• 去掉了正在編輯的段落一直高亮、跳過去時閃爍，以及雙擊才把游標放進歌詞這幾項。安裝包裡的說明文本也拿掉了
""",
            bodyMarkdownEN: """
【Changed】
• The always-on section highlight, the flash on jump, and focusing the lyrics with a double click were removed. The extra readme in the installer was removed too
""",
            bodyMarkdownJA: """
【変更】
• 編集中のセクションを常に明るくすること、ジャンプ時の点滅、ダブルクリックで歌詞に入ることをやめました。インストーラの説明文も外しました
""",
            bodyMarkdownKO: """
【변경】
• 편집 중인 섹션을 항상 밝게 두던 것, 이동할 때의 깜빡임, 두 번 눌러야 가사에 들어가던 것을 뺐습니다. 설치 파일의 설명 글도 뺐습니다
""",
            bodyMarkdownES: """
【Cambios】
• Se quitaron el resalte fijo de la sección en edición, el parpadeo al saltar y el foco en la letra con doble clic. También se quitó el texto de ayuda del instalador
""",
        ),
        Entry(
            version: "v1.7",
            date: "2026-06-20",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 增加了歌词预览，和右侧的灵感轮流使用。编辑区和预览会一起跳到同一段。节拍在收起歌曲信息时也能看见
""",
            bodyMarkdownZHT: """
【新增】
• 增加了歌詞預覽，和右側的靈感輪流使用。編輯區和預覽會一起跳到同一段。節拍在收起歌曲資訊時也能看見
""",
            bodyMarkdownEN: """
【New】
• Lyrics preview was added and shares the right side with ideas. The editor and the preview jump to the same section. The meter stays visible when song details are collapsed
""",
            bodyMarkdownJA: """
【新機能】
• 歌詞プレビューが増え、右のアイデアと交代で使います。編集とプレビューは同じセクションへ動きます。曲情報を畳んでも拍子は見えます
""",
            bodyMarkdownKO: """
【추가】
• 가사 미리보기가 생겼고 오른쪽 아이디어와 번갈아 씁니다. 편집과 미리보기는 같은 섹션으로 이동합니다. 곡 정보를 접어도 박자는 보입니다
""",
            bodyMarkdownES: """
【Nuevo】
• Llegó la vista previa de la letra y comparte el lado derecho con las ideas. El editor y la vista previa saltan a la misma sección. El compás se ve aunque se plieguen los datos
""",
        ),
        Entry(
            version: "v1.6.1",
            date: "2026-06-19",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 开关改成系统原生的样子。日语读音词库扩充到两千多个词
""",
            bodyMarkdownZHT: """
【改動】
• 開關改成系統原生的樣子。日語讀音詞庫擴充到兩千多個詞
""",
            bodyMarkdownEN: """
【Changed】
• Switches now look like the system ones. The Japanese reading dictionary grew past two thousand words
""",
            bodyMarkdownJA: """
【変更】
• スイッチをシステムの見た目にしました。日本語の読み辞書は二千語を超えました
""",
            bodyMarkdownKO: """
【변경】
• 스위치가 시스템 모양이 되었습니다. 일본어 읽기 사전이 이천 단어를 넘었습니다
""",
            bodyMarkdownES: """
【Cambios】
• Los interruptores tienen el aspecto del sistema. El diccionario de lecturas japonesas pasó de dos mil palabras
""",
        ),
        Entry(
            version: "v1.6",
            date: "2026-06-19",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 增加了节拍，可选二四、三四、四四等常见拍子。导出的歌词字段用稳定的英文名字。文件夹双击可以展开或删除
""",
            bodyMarkdownZHT: """
【新增】
• 增加了節拍，可選二四、三四、四四等常見拍子。匯出的歌詞欄位用穩定的英文名字。資料夾雙擊可以展開或刪除
""",
            bodyMarkdownEN: """
【New】
• A meter field was added, with common values such as two-four, three-four, and four-four. Exported lyric fields use stable English names. Double-click a folder to open or delete it
""",
            bodyMarkdownJA: """
【新機能】
• 拍子欄が増え、二四、三四、四四などの一般的な拍子を選べます。書き出した歌詞の項目名は安定した英語です。フォルダはダブルクリックで開閉または削除できます
""",
            bodyMarkdownKO: """
【추가】
• 박자 칸이 생겼고 2/4, 3/4, 4/4 같은 흔한 박자를 고릅니다. 내보낸 가사 항목 이름은 안정된 영어입니다. 폴더는 두 번 눌러 열거나 지웁니다
""",
            bodyMarkdownES: """
【Nuevo】
• Se añadió el compás, con valores habituales como dos por cuatro, tres por cuatro y cuatro por cuatro. Los campos exportados usan nombres estables en inglés. Una carpeta se abre o se borra con doble clic
""",
        ),
        Entry(
            version: "v1.5.2",
            date: "2026-06-18",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 可以一次选多首歌，然后一起备份、导出、合并，或移到回收站。也可以把一层文件夹里的歌导进来
""",
            bodyMarkdownZHT: """
【新增】
• 可以一次選多首歌，然後一起備份、匯出、合併，或移到回收桶。也可以把一層資料夾裡的歌導進來
""",
            bodyMarkdownEN: """
【New】
• Several songs can be selected and then backed up, exported, merged, or moved to the trash together. A flat folder of songs can be imported
""",
            bodyMarkdownJA: """
【新機能】
• 複数の曲を選んで、まとめてバックアップ、書き出し、結合、ゴミ箱へ移動できます。一段のフォルダから読み込むこともできます
""",
            bodyMarkdownKO: """
【추가】
• 곡을 여러 개 고른 뒤 함께 백업, 내보내기, 합치기, 휴지통으로 옮길 수 있습니다. 한 층의 폴더에서 가져올 수도 있습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Se pueden elegir varias canciones y luego copiarlas, exportarlas, unirlas o moverlas a la papelera. También se importa una carpeta plana
""",
        ),
        Entry(
            version: "v1.5.1",
            date: "2026-06-17",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 修正了重复的词条把语言表弄崩溃的问题
""",
            bodyMarkdownZHT: """
【修復】
• 修正了重複的詞條把語言表弄崩潰的問題
""",
            bodyMarkdownEN: """
【Fixed】
• Fixed a crash caused by a repeated phrase in the language tables
""",
            bodyMarkdownJA: """
【修正】
• 言語表の重複した語句で落ちる問題を直しました
""",
            bodyMarkdownKO: """
【수정】
• 언어 표의 중복된 문구 때문에 멈추던 문제를 고쳤습니다
""",
            bodyMarkdownES: """
【Corrección】
• Se corrigió un cierre provocado por una frase repetida en las tablas de idioma
""",
        ),
        Entry(
            version: "v1.5",
            date: "2026-06-17",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 增加了文件夹和回收站。删除会先放进回收站，再确认一次才能彻底删除
""",
            bodyMarkdownZHT: """
【新增】
• 增加了資料夾和回收桶。刪除會先放進回收桶，再確認一次才能徹底刪除
""",
            bodyMarkdownEN: """
【New】
• Folders and a trash were added. Delete moves a song to the trash first, and a second confirmation is required to remove it for good
""",
            bodyMarkdownJA: """
【新機能】
• フォルダとゴミ箱を追加しました。削除はまずゴミ箱へ入り、完全に消すにはもう一度確認します
""",
            bodyMarkdownKO: """
【추가】
• 폴더와 휴지통이 생겼습니다. 삭제는 먼저 휴지통으로 가고, 완전히 지우려면 한 번 더 확인합니다
""",
            bodyMarkdownES: """
【Nuevo】
• Llegaron las carpetas y la papelera. Borrar lleva primero a la papelera, y hace falta una segunda confirmación para eliminar del todo
""",
        ),
        Entry(
            version: "v1.4",
            date: "2026-06-15",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 界面可以在简体中文、繁体中文、英语和日语之间切换。删除前可以要求确认。窗口最窄大约能到常见的宽屏宽度
""",
            bodyMarkdownZHT: """
【新增】
• 介面可以在簡體中文、繁體中文、英語和日語之間切換。刪除前可以要求確認。視窗最窄大約能到常見的寬螢幕寬度
""",
            bodyMarkdownEN: """
【New】
• The interface can switch among simplified Chinese, traditional Chinese, English, and Japanese. Delete can ask for confirmation. The window has a sensible minimum width
""",
            bodyMarkdownJA: """
【新機能】
• 表示は簡体字中国語、繁体字中国語、英語、日本語を切り替えられます。削除前に確認を求められます。ウィンドウには無理のない最小幅があります
""",
            bodyMarkdownKO: """
【추가】
• 화면 언어를 간체 중국어, 번체 중국어, 영어, 일본어 사이에서 바꿀 수 있습니다. 삭제 전에 확인을 물을 수 있습니다. 창에는 적당한 최소 너비가 있습니다
""",
            bodyMarkdownES: """
【Nuevo】
• La interfaz puede usar chino simplificado, chino tradicional, inglés y japonés. El borrado puede pedir confirmación. La ventana tiene un ancho mínimo razonable
""",
        ),
        Entry(
            version: "v1.3",
            date: "2026-06-14",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 增加了灵感与设定。段落笔记可以展开。自动注音的操作收进了同一处
""",
            bodyMarkdownZHT: """
【新增】
• 增加了靈感與設定。段落筆記可以展開。自動注音的操作收進了同一處
""",
            bodyMarkdownEN: """
【New】
• Ideas and settings were added. Section notes can expand. Automatic reading marks live in one place
""",
            bodyMarkdownJA: """
【新機能】
• アイデアと設定が増えました。セクションのメモは展開できます。自動の読みがなは一か所にまとめました
""",
            bodyMarkdownKO: """
【추가】
• 아이디어와 설정이 생겼습니다. 섹션 메모를 펼칠 수 있습니다. 자동 읽기 표기는 한곳으로 모았습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Llegaron las ideas y la ambientación. Las notas de la sección se despliegan. La lectura automática quedó reunida
""",
        ),
        Entry(
            version: "v1.2",
            date: "2026-06-13",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 歌曲语言里的简体和繁体合并成中文。可以手动给字加上读音
""",
            bodyMarkdownZHT: """
【改動】
• 歌曲語言裡的簡體和繁體合併成中文。可以手動給字加上讀音
""",
            bodyMarkdownEN: """
【Changed】
• Simplified and traditional Chinese in a song's languages were merged into Chinese. Readings can be added by hand
""",
            bodyMarkdownJA: """
【変更】
• 曲の言語では簡体字と繁体字を中国語にまとめました。読みは手でも付けられます
""",
            bodyMarkdownKO: """
【변경】
• 곡 언어에서 간체와 번체를 중국어로 합쳤습니다. 읽기는 손으로도 달 수 있습니다
""",
            bodyMarkdownES: """
【Cambios】
• El chino simplificado y el tradicional del idioma de la canción se unieron en chino. Las lecturas se pueden añadir a mano
""",
        ),
        Entry(
            version: "v1.1",
            date: "2026-06-12",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 修正了歌曲语言的保存方式，旧数据换到新的存法后才能继续打开
""",
            bodyMarkdownZHT: """
【修復】
• 修正了歌曲語言的儲存方式，舊資料換到新的存法後才能繼續打開
""",
            bodyMarkdownEN: """
【Fixed】
• Fixed how a song's languages are stored, so older data can be opened with the new layout
""",
            bodyMarkdownJA: """
【修正】
• 曲の言語の保存方法を直し、古いデータを新しい形で開けるようにしました
""",
            bodyMarkdownKO: """
【수정】
• 곡 언어를 저장하는 방식을 고쳐, 예전 데이터를 새 형태로 열 수 있습니다
""",
            bodyMarkdownES: """
【Corrección】
• Se corrigió cómo se guardan los idiomas de la canción, para que los datos antiguos se abran con la forma nueva
""",
        ),
        Entry(
            version: "v1.0",
            date: "2026-06-10",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 第一次发布。这是给苹果芯片准备的歌词写作工具，带十二种常见段落，也可以自己加，并能给日语自动标读音
""",
            bodyMarkdownZHT: """
【新增】
• 第一次發布。這是給蘋果晶片準備的歌詞寫作工具，帶十二種常見段落，也可以自己加，並能給日語自動標讀音
""",
            bodyMarkdownEN: """
【New】
• First release. A lyric-writing tool for Apple silicon, with twelve common section types plus a custom one, and automatic Japanese readings
""",
            bodyMarkdownJA: """
【新機能】
• 最初の公開です。Apple シリコン向けの歌詞ツールで、よく使うセクションが十二種あり、自分でも追加でき、日本語の読みを自動で付けられます
""",
            bodyMarkdownKO: """
【추가】
• 첫 공개입니다. 애플 실리콘용 가사 도구로, 흔한 섹션 열두 가지와 직접 추가가 있고, 일본어 읽기를 자동으로 달 수 있습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Primera versión. Una herramienta de letras para Apple silicon, con doce tipos habituales de sección más uno propio, y lecturas japonesas automáticas
""",
        ),
    ]
}

#Preview {
 ChangelogView()
}
