// Settings/ChangelogView.swift
// 更新日志窗口（支持 Markdown 渲染）
// v1.4: 改为独立 Window scene，自带标题栏 + cmd+W 正常工作
// 每次更新必须把新版本接在上方，不删除旧版本

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
            version: "v1.8.2",
            date: "2026-09-25",
            isLatest: true,
            bodyMarkdown: """
【新增】
• 歌词段落向右滑，左边会出现蓝色的 Imagine 按钮，只处理这一段。导出按钮左边也有一个同样的 Imagine，用来处理整首歌
• 点开后可以选择翻译或创意。翻译要选目标语言，下次会记住上次的语言，也可以另外写要求。创意会根据这首歌已有的内容重写指定段落或整首歌
• 整首歌的 Imagine 还可以让模型填写歌曲语言、速度、调式和节拍
• 模型名可以留空。设置里可以测试连接是否可用，并建议选用参数量更大的模型，翻译和创作会更准确
• 整首歌的创意会按段落拆开写回，不再全部塞进同一段歌词。创意可选「依照当前格式」，默认开启
• 创意执行前会再确认一次，因为改动可能无法撤销或出错
• 段落Imagine不能干 Imagine 的活：不能改整首歌或其他段落，遇到这种情况会停下来并提醒
• 段落Imagine的创意会把整首歌交给模型作参考，只写回当前这一段，好让文风一致
• 整首歌的创意会补上空白的歌名、语言、速度、调式和节拍；歌名写在标题，不写进灵感设定。没有修改必要时这些字段可以省略
• 设置里可以用滑块调节界面字体大小。只改文字大小，窗口和分栏宽度不变
• 打开软件时主窗口默认铺满屏幕
""",
            bodyMarkdownZHT: """
【新增】
• 歌詞段落向右滑，左邊會出現藍色的 Imagine 按鈕，只處理這一段。匯出按鈕左邊也有一個同樣的 Imagine，用來處理整首歌
• 點開後可以選擇翻譯或創意。翻譯要選目標語言，下次會記住上次的語言，也可以另外寫要求。創意會根據這首歌已有的內容重寫指定段落或整首歌
• 整首歌的 Imagine 還可以讓模型填寫歌曲語言、速度、調式和節拍
• 模型名可以留空。設定裡可以測試連線是否可用，並建議選用參數量更大的模型，翻譯和創作會更準確
• 整首歌的創意會按段落拆開寫回，不再全部塞進同一段歌詞。創意可選「依照當前格式」，預設開啟
• 創意執行前會再確認一次，因為改動可能無法撤銷或出錯
• 段落Imagine不能幹 Imagine 的活：不能改整首歌或其他段落，遇到這種情況會停下來並提醒
• 段落Imagine的創意會把整首歌交給模型作參考，只寫回當前這一段，好讓文風一致
• 整首歌的創意會補上空白的歌名、語言、速度、調式和節拍；歌名寫在標題，不寫進靈感設定。沒有修改必要時這些欄位可以省略
• 設定裡可以用滑桿調節介面字體大小。只改文字大小，視窗和分欄寬度不變
• 打開軟體時主視窗預設鋪滿螢幕
""",
            bodyMarkdownEN: """
【New】
• Swipe a lyric section to the right and a blue Imagine button appears on the left. It changes only that section. The same Imagine button sits to the left of Export and can change the whole song
• It offers Translation or Creative. Translation asks for a target language, remembers it next time, and can take an extra request. Creative rewrites the chosen section or the whole song from what the song already contains
• The whole-song Imagine can also let the model fill in language, tempo, key, and meter
• The model name can be left empty. Settings includes Test connection, and suggests a large-parameter model so translation and writing stay more accurate
• Whole-song Creative splits labeled sections in order instead of dumping them into one lyrics box, with Follow current format on by default
• Creative asks for confirmation first, because the change may be irreversible or wrong
• Section Imagine cannot do Imagine's job: it cannot change the whole song or other sections, and it stops with an alert
• Section Imagine Creative sends the whole song for style, and writes back only the current section
• Whole-song Creative fills a blank title, language, tempo, key, and meter. The title goes in the title field, not Ideas. Fields with no need to change may be omitted
• Settings has a slider for interface font size. Only the text size changes; windows and column widths stay put
• The main window fills the screen when the app opens
""",
            bodyMarkdownJA: """
【新機能】
• 歌詞のセクションを右に滑らせると、左に青い Imagine ボタンが出て、そのセクションだけを扱います。書き出しボタンの左にも同じ Imagine があり、曲全体を扱えます
• 開くと翻訳か創作を選べます。翻訳は訳す言語を選び、次回はその言語が選ばれ、追加の要望も書けます。創作は曲にある内容から、指定したセクションか曲全体を書き直します
• 曲全体の Imagine では、言語、テンポ、調、拍子もモデルに任せられます
• モデル名は空でも構いません。設定で接続を試し、翻訳と創作がより正確になるよう、パラメータの大きいモデルを勧めています
• 曲全体の創作はセクションごとに分けて書き戻し、一つの歌詞欄にまとめません。「現在の形式に合わせる」は既定でオンです
• 創作の前に確認します。取り消せなかったり誤ったりすることがあるためです
• 段落 Imagine は Imagine の仕事はできません。曲全体や他のセクションは変えられず、止めて知らせます
• 段落 Imagine の創作は曲全体を文風の参考として渡し、今のセクションだけを書き戻します
• 曲全体の創作は空の曲名、言語、テンポ、調、拍子を補います。曲名はタイトル欄へ書き、アイデアには書きません。変える必要がない項目は省略できます
• 設定にフォントサイズのスライダーを追加。変わるのは文字の大きさだけで、ウィンドウと欄の幅はそのままです
• 起動時、メインウィンドウは画面いっぱいに開きます
""",
            bodyMarkdownKO: """
【추가】
• 가사 섹션을 오른쪽으로 밀면 왼쪽에 파란 Imagine 버튼이 나오고, 그 섹션만 바꿉니다. 내보내기 버튼 왼쪽에도 같은 Imagine이 있어 곡 전체를 다룰 수 있습니다
• 열면 번역 또는 창작을 고릅니다. 번역은 목표 언어를 고르고 다음에도 그 언어를 기억하며, 추가 요청을 쓸 수 있습니다. 창작은 곡에 있는 내용으로 지정한 섹션이나 곡 전체를 다시 씁니다
• 곡 전체 Imagine은 언어, 빠르기, 조성, 박자도 모델이 채우게 할 수 있습니다
• 모델 이름은 비워 둘 수 있습니다. 설정에서 연결을 시험할 수 있고, 번역과 창작이 더 정확하도록 매개변수가 큰 모델을 권합니다
• 곡 전체 창작은 섹션을 나눠 순서대로 넣고, 한 칸에 몰아 넣지 않습니다. 「현재 형식을 따름」은 기본으로 켜져 있습니다
• 창작 전에 한 번 더 확인합니다. 되돌릴 수 없거나 잘못될 수 있기 때문입니다
• 단락 Imagine은 Imagine 일을 할 수 없습니다. 곡 전체나 다른 섹션을 바꾸지 못하며, 멈추고 알립니다
• 단락 Imagine 창작은 문체를 맞추려고 곡 전체를 보내고, 지금 섹션만 다시 씁니다
• 곡 전체 창작은 빈 제목, 언어, 빠르기, 조성, 박자를 채웁니다. 제목은 제목 칸에 쓰고 아이디어에는 쓰지 않습니다. 바꿀 필요가 없는 항목은 생략할 수 있습니다
• 설정에 화면 글자 크기 슬라이더가 있습니다. 글자 크기만 바뀌고, 창과 칸 너비는 그대로입니다
• 앱을 열면 메인 창이 화면을 채웁니다
""",
            bodyMarkdownES: """
【Nuevo】
• Desliza una sección de la letra a la derecha y aparece un botón azul de Imagine a la izquierda. Solo cambia esa sección. El mismo Imagine está a la izquierda de Exportar y puede cambiar la canción entera
• Al abrirlo se elige Traducción o Creativo. La traducción pide un idioma, lo recuerda la próxima vez y admite un pedido extra. Creativo reescribe la sección elegida o la canción con lo que ya contiene
• El Imagine de toda la canción también puede dejar que el modelo complete idioma, tempo, tonalidad y compás
• El nombre del modelo puede quedar vacío. En Ajustes se puede probar la conexión, y se recomienda un modelo grande para traducir y escribir con más precisión
• Lo creativo de toda la canción reparte las secciones en orden, no las vuelca en un solo recuadro, y Seguir el formato actual viene activado
• Lo creativo pide confirmación primero, porque el cambio puede no deshacerse o salir mal
• El Imagine de sección no puede hacer el trabajo de Imagine: no cambia la canción entera ni otras secciones, y se detiene con un aviso
• Lo creativo de Imagine de sección envía la canción entera para el estilo y solo escribe de nuevo la sección actual
• Lo creativo de toda la canción completa un título, idioma, tempo, tonalidad y compás en blanco. El título va al campo de título, no a Ideas. Los campos que no hace falta cambiar se pueden omitir
• Ajustes incluye un control deslizante para el tamaño de letra. Solo cambia el texto; las ventanas y el ancho de las columnas no se mueven
• Al abrir la app, la ventana principal llena la pantalla
""",
        ),
        Entry(
            version: "v1.8.1",
            date: "2026-09-24",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 按住 Command 点任意段落的笔记、译文或折叠，会对整首歌做同样的打开或收起，已经是那个状态的段落不动
• 界面语言增加韩语、西班牙语
• 编辑区右上角的导出按钮改成导出的样子，并留出以后再加按钮的位置
【改动】
• 设置改到右边栏，和灵感设定、歌词预览切换。打开设置时右边栏宽度固定成设置页的宽度，回到灵感设定或歌词预览后恢复。设置从下往上进入
• 做词和做曲的提示改为：技能需要交给能做文件处理的模型
• 设置页去掉关闭按钮。界面语言改成列表，并增加跟随系统。下载相关收进二级菜单。可以保存大模型 API Key
""",
            bodyMarkdownZHT: """
【新增】
• 按住 Command 點任意段落的筆記、譯文或折疊，會對整首歌做同樣的打開或收起，已經是那個狀態的段落不動
• 介面語言增加韓語、西班牙語
• 編輯區右上角的匯出按鈕改成匯出的樣子，並留出以後再加按鈕的位置
【改動】
• 設定改到右邊欄，和靈感設定、歌詞預覽切換。打開設定時右邊欄寬度固定成設定頁的寬度，回到靈感設定或歌詞預覽後恢復。設定從下往上進入
• 做詞和做曲的提示改為：技能需要交給能做檔案處理的模型
• 設定頁去掉關閉按鈕。介面語言改成列表，並增加跟隨系統。下載相關收進二級選單。可以儲存大型模型 API Key
""",
            bodyMarkdownEN: """
【New】
• Hold Command and click notes, translation, or collapse on any section to open or close that on the whole song. Sections already in that state stay as they are
• Korean and Spanish were added
• The export button at the top right of the editor looks like export, with room for later buttons
【Changed】
• Settings opens in the right column and switches with Ideas and Lyrics Preview. Its width is fixed to the settings page, then returns afterward. Settings enters from the bottom
• The lyric and music forge hint now says the skill must be handed to a model that can handle files
• The settings close button is gone. Interface language is a list and adds Follow System. Download items sit in a second-level menu. An API key can be saved
""",
            bodyMarkdownJA: """
【新機能】
• Command を押しながら任意のセクションのメモ、訳文、折りたたみを押すと、曲全体が同じ開閉になります。すでにその状態のセクションはそのままです
• 韓国語とスペイン語を追加しました
• 編集画面右上の書き出しボタンを書き出しの形にし、後からボタンを足す余白を残しました
【変更】
• 設定は右カラムで開き、インスピレーションと歌詞プレビューと切り替えます。開いている間、幅は設定ページの幅になり、戻すと元に戻ります。設定は下から入ります
• 作詞・作曲の注意は、ファイルを扱えるモデルにスキルを渡す、に変わりました
• 設定の閉じるボタンをなくしました。言語はリストになり、システムに合わせるを追加しました。ダウンロードは二次メニューです。API キーを保存できます
""",
            bodyMarkdownKO: """
【추가】
• Command를 누른 채 아무 섹션의 메모, 번역, 접기를 누르면 곡 전체가 같이 열리거나 닫힙니다. 이미 그 상태인 섹션은 그대로입니다
• 한국어와 스페인어를 추가했습니다
• 편집 화면 오른쪽 위 내보내기 버튼을 내보내기 모양으로 바꾸고, 나중에 버튼을 둘 자리를 남겼습니다
【변경】
• 설정은 오른쪽 열에서 열리고 아이디어, 가사 미리보기와 전환됩니다. 열어 둔 동안 너비는 설정 페이지 너비로 고정되고, 돌아가면 원래대로입니다. 설정은 아래에서 들어옵니다
• 작사·작곡 안내는 파일을 다룰 수 있는 모델에 스킬을 넘기라고 바뀌었습니다
• 설정의 닫기 버튼을 없앴습니다. 언어는 목록에서 고르며 시스템을 따름을 추가했습니다. 다운로드는 2단 메뉴입니다. API 키를 저장할 수 있습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Mantén Command y pulsa notas, traducción o plegado de cualquier sección para abrir o cerrar eso en toda la canción. Lo que ya está así no cambia
• Se añadieron coreano y español
• El botón de exportar arriba a la derecha tiene forma de exportación y deja sitio para más botones
【Cambios】
• Ajustes se abre en la columna derecha y se alterna con Ideas y la vista previa. Su anchura queda fija en la de la página de ajustes y luego vuelve. Ajustes entra desde abajo
• El aviso de la forja de letra y música dice que la habilidad debe ir a un modelo que pueda manejar archivos
• Se quitó el botón de cerrar. El idioma es una lista e incluye Seguir el sistema. La descarga está en un menú de segundo nivel. Se puede guardar una clave de API
""",
        ),
        Entry(
            version: "v1.8.0",
            date: "2026-09-19",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 设置里的下载可以检查有没有新版本。启动时会安静地查一次，只有发现新版本才提醒，也可以手动去下载
• 歌词预览里，段落下面的小字可以在笔记和译文之间换。默认是笔记，没有内容就不显示
• 删除歌曲前的确认里，会写出有多少条译文
""",
            bodyMarkdownZHT: """
【新增】
• 設定裡的下載可以檢查有沒有新版本。啟動時會安靜地查一次，只有發現新版本才提醒，也可以手動去下載
• 歌詞預覽裡，段落下面的小字可以在筆記和譯文之間換。預設是筆記，沒有內容就不顯示
• 刪除歌曲前的確認裡，會寫出有多少條譯文
""",
            bodyMarkdownEN: """
【New】
• Download in Settings can look for a new version. Launch checks quietly and only alerts when one exists, and you can download it yourself
• In lyrics preview, the small line under a section can switch between notes and translation. Notes are the default, and an empty line stays hidden
• The delete confirmation now says how many translations the song has
""",
            bodyMarkdownJA: """
【新機能】
• 設定のダウンロードで新しい版を確認できます。起動時は静かに確認し、新しい版があるときだけ知らせ、自分でダウンロードもできます
• 歌詞プレビューでは、セクション下の小字をメモと訳文で切り替えられます。既定はメモで、空なら表示しません
• 曲を削除する前の確認に、訳文が何件あるか出ます
""",
            bodyMarkdownKO: """
【추가】
• 설정의 다운로드에서 새 버전을 확인할 수 있습니다. 시작할 때는 조용히 확인하고, 새 버전이 있을 때만 알리며 직접 받을 수도 있습니다
• 가사 미리보기에서 섹션 아래 작은 글자를 메모와 번역 사이에서 바꿀 수 있습니다. 기본은 메모이고, 비어 있으면 보이지 않습니다
• 곡을 지우기 전 확인에 번역이 몇 개인지 나옵니다
""",
            bodyMarkdownES: """
【Nuevo】
• La descarga en Ajustes puede buscar una versión nueva. Al iniciar lo hace en silencio y solo avisa si hay una, y también se puede descargar a mano
• En la vista previa, el texto pequeño bajo cada sección puede alternar entre notas y traducción. Las notas son lo habitual y, si está vacío, no se muestra
• La confirmación de borrado indica cuántas traducciones tiene la canción
""",
        ),
        Entry(
            version: "v1.7.10 Extra",
            date: "2026-06-26",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 段落里增加了译文，和笔记不能同时展开。歌词文件可以一并带上译文
【修复】
• 拖动段落时，放在目标段的上半就插到它前面，放在下半就插到它后面
• 拖到列表靠近顶部时，列表现在会真正往上滚动
• 拖动段落时，不会再把一段编号写进歌词里
""",
            bodyMarkdownZHT: """
【新增】
• 段落裡增加了譯文，和筆記不能同時展開。歌詞檔可以一併帶上譯文
【修復】
• 拖動段落時，放在目標段的上半就插到它前面，放在下半就插到它後面
• 拖到列表靠近頂部時，列表現在會真正往上捲動
• 拖動段落時，不會再把一段編號寫進歌詞裡
""",
            bodyMarkdownEN: """
【New】
• Sections gained a translation next to notes. They cannot both be open. A lyric file can carry the translation
【Fixed】
• Dropping a section on the upper half inserts it before that section, and the lower half inserts it after
• Dragging near the top of the list now really scrolls upward
• Dragging a section no longer pastes a stray identifier into the lyrics
""",
            bodyMarkdownJA: """
【新機能】
• セクションに訳文が増え、メモとは同時に開けません。歌詞ファイルに訳文も入れられます
【修正】
• 段落を置くとき、相手の上半分ならその前、下半分ならその後に入ります
• 一覧の上の方まで拖ると、本当に上へスクロールします
• 段落を拖っても、番号が歌詞に紛れ込まなくなりました
""",
            bodyMarkdownKO: """
【추가】
• 섹션에 번역이 생겼고 메모와 동시에 열 수 없습니다. 가사 파일에 번역도 넣을 수 있습니다
【수정】
• 섹션을 놓을 때 대상의 위쪽이면 앞에, 아래쪽이면 뒤에 들어갑니다
• 목록 위쪽까지 끌면 이제 정말로 위로 스크롤됩니다
• 섹션을 끌어도 번호가 가사 안에 들어가지 않습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Las secciones tienen traducción junto a las notas. No se abren a la vez. El archivo de la letra puede llevar la traducción
【Corrección】
• Soltar una sección en la mitad superior la inserta antes, y en la inferior, después
• Arrastrar cerca de la parte superior de la lista ahora sí desplaza hacia arriba
• Arrastrar una sección ya no mete un identificador suelto dentro de la letra
""",
        ),
        Entry(
            version: "v1.7.10",
            date: "2026-06-26",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 纪念 Minecraft v1.7.10 发布十二周年
""",
            bodyMarkdownZHT: """
【改動】
• 紀念 Minecraft v1.7.10 發布十二週年
""",
            bodyMarkdownEN: """
【Changed】
• In memory of the twelfth anniversary of Minecraft v1.7.10
""",
            bodyMarkdownJA: """
【変更】
• Minecraft v1.7.10 公開十二周年を記念します
""",
            bodyMarkdownKO: """
【변경】
• Minecraft v1.7.10 출시 12주년을 기념합니다
""",
            bodyMarkdownES: """
【Cambios】
• En memoria del duodécimo aniversario de Minecraft v1.7.10
""",
        ),
        Entry(
            version: "v1.7.9 GT5",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 文件夹可以用右键向上或向下调整顺序，并修正了多语言显示
""",
            bodyMarkdownZHT: """
【新增】
• 資料夾可以用右鍵向上或向下調整順序，並修正了多語言顯示
""",
            bodyMarkdownEN: """
【New】
• Folders can move up or down from the right-click menu, and several languages display more correctly
""",
            bodyMarkdownJA: """
【新機能】
• フォルダを右クリックで上下に並べ替えられ、多言語の表示も直しました
""",
            bodyMarkdownKO: """
【추가】
• 폴더를 오른쪽 클릭으로 위아래로 옮길 수 있고, 여러 언어 표시도 고쳤습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Las carpetas se pueden subir o bajar con el clic derecho, y se corrigió la presentación en varios idiomas
""",
        ),
        Entry(
            version: "v1.7.9 GT4",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 曲目列表可以用右键上移、下移，也可以移到别的文件夹
""",
            bodyMarkdownZHT: """
【新增】
• 曲目列表可以用右鍵上移、下移，也可以移到別的資料夾
""",
            bodyMarkdownEN: """
【New】
• Songs in the list can move up, down, or into another folder from the right-click menu
""",
            bodyMarkdownJA: """
【新機能】
• 曲一覧を右クリックで上下に動かしたり、別のフォルダへ移したりできます
""",
            bodyMarkdownKO: """
【추가】
• 곡 목록에서 오른쪽 클릭으로 위아래 이동과 다른 폴더로 옮기기가 됩니다
""",
            bodyMarkdownES: """
【Nuevo】
• En la lista se puede subir, bajar o mover una canción a otra carpeta con el clic derecho
""",
        ),
        Entry(
            version: "v1.7.9 GT3",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 修正了歌词文字编辑、向左滑删除的样子，以及一些动画问题
""",
            bodyMarkdownZHT: """
【修復】
• 修正了歌詞文字編輯、向左滑刪除的樣子，以及一些動畫問題
""",
            bodyMarkdownEN: """
【Fixed】
• Fixed lyric text editing, the look of swipe-to-delete, and some animation problems
""",
            bodyMarkdownJA: """
【修正】
• 歌詞の文字編集、左に滑らせて消す見た目、いくつかのアニメーションを直しました
""",
            bodyMarkdownKO: """
【수정】
• 가사 편집, 왼쪽으로 밀어 지우는 모양, 일부 애니메이션을 고쳤습니다
""",
            bodyMarkdownES: """
【Corrección】
• Se corrigió la edición del texto, el aspecto de borrar deslizando y algunos problemas de animación
""",
        ),
        Entry(
            version: "v1.7.9 GT2",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 修正了一批小问题
""",
            bodyMarkdownZHT: """
【修復】
• 修正了一批小問題
""",
            bodyMarkdownEN: """
【Fixed】
• Fixed a batch of small problems
""",
            bodyMarkdownJA: """
【修正】
• 細かい不具合をまとめて直しました
""",
            bodyMarkdownKO: """
【수정】
• 작은 문제 여러 개를 고쳤습니다
""",
            bodyMarkdownES: """
【Corrección】
• Se corrigió un puñado de problemas pequeños
""",
        ),
        Entry(
            version: "v1.7.9 GT",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 把此前的稳定修正合并进来，段落拖动开关和笔记、折叠的动画都回来了
""",
            bodyMarkdownZHT: """
【改動】
• 把此前的穩定修正合併進來，段落拖動開關和筆記、折疊的動畫都回來了
""",
            bodyMarkdownEN: """
【Changed】
• Earlier stable fixes were merged back in. The section-drag switch and the notes and collapse animations returned
""",
            bodyMarkdownJA: """
【変更】
• それまでの安定版の修正をまとめ、セクション拖動のスイッチとメモ、折りたたみのアニメーションが戻りました
""",
            bodyMarkdownKO: """
【변경】
• 이전의 안정적인 수정을 합쳤습니다. 섹션 드래그 스위치와 메모, 접기 애니메이션이 돌아왔습니다
""",
            bodyMarkdownES: """
【Cambios】
• Se unieron las correcciones estables anteriores. Volvieron el interruptor de arrastrar secciones y las animaciones de notas y plegado
""",
        ),
        Entry(
            version: "v1.7.9 Test",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 笔记和折叠的动画恢复了。段落拖动暂时改回默认开启，开关先拿掉
""",
            bodyMarkdownZHT: """
【改動】
• 筆記和折疊的動畫恢復了。段落拖動暫時改回預設開啟，開關先拿掉
""",
            bodyMarkdownEN: """
【Changed】
• Notes and collapse animate again. Section dragging was turned on by default for this try, and the switch was removed
""",
            bodyMarkdownJA: """
【変更】
• メモと折りたたみのアニメーションが戻りました。この試行ではセクション拖動を既定でオンにし、スイッチは外しました
""",
            bodyMarkdownKO: """
【변경】
• 메모와 접기 애니메이션이 돌아왔습니다. 이번 시험에서는 섹션 드래그를 기본으로 켜고 스위치는 뺐습니다
""",
            bodyMarkdownES: """
【Cambios】
• Volvieron las animaciones de notas y plegado. En esta prueba, arrastrar secciones quedó activado y se quitó el interruptor
""",
        ),
        Entry(
            version: "v1.7.9 BugStable",
            date: "2026-06-25",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 修正了笔记和歌曲信息展开时的动画、滚轮被挡住、换歌后光标还在，以及文字点不中的问题
""",
            bodyMarkdownZHT: """
【修復】
• 修正了筆記和歌曲資訊展開時的動畫、滾輪被擋住、換歌後游標還在，以及文字點不中的問題
""",
            bodyMarkdownEN: """
【Fixed】
• Fixed the animation when notes and song details open, the scroll wheel getting stuck, the cursor lingering after a song change, and clicks missing the text
""",
            bodyMarkdownJA: """
【修正】
• メモと曲情報を開くアニメーション、ホイールが通らないこと、曲を替えてもカーソルが残ること、文字が押しにくいことを直しました
""",
            bodyMarkdownKO: """
【수정】
• 메모와 곡 정보를 펼치는 애니메이션, 스크롤 휠이 막히던 것, 곡을 바꿔도 커서가 남던 것, 글자를 잘 누르지 못하던 것을 고쳤습니다
""",
            bodyMarkdownES: """
【Corrección】
• Se corrigió la animación al abrir notas y datos de la canción, la rueda que no pasaba, el cursor que seguía al cambiar de canción y los clics que no daban en el texto
""",
        ),
        Entry(
            version: "v1.7.9 Delta",
            date: "2026-06-24",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 换歌时的动画统一从右往左，快速连切也不会反方向跳
• 歌词编辑区的高度会跟着内容变
• 换歌时不再自动把光标放进歌词，只有你自己点进去才会开始输入
• 文件夹和回收站点一下就能展开或收起
• 灵感和歌词预览按按钮所在的左右方向滑入滑出。关掉右侧时，那一栏会收起来
• 灵感条目的最小高度可以选一行或两行
""",
            bodyMarkdownZHT: """
【修復】
• 換歌時的動畫統一從右往左，快速連切也不會反方向跳
• 歌詞編輯區的高度會跟著內容變
• 換歌時不再自動把游標放進歌詞，只有你自己點進去才會開始輸入
• 資料夾和回收桶點一下就能展開或收起
• 靈感和歌詞預覽按按鈕所在的左右方向滑入滑出。關掉右側時，那一欄會收起來
• 靈感條目的最小高度可以選一行或兩行
""",
            bodyMarkdownEN: """
【Fixed】
• Changing songs always slides from right to left, even if you switch quickly
• The lyric editor grows and shrinks with the text
• Changing songs no longer drops the cursor into the lyrics. Typing starts only when you click there
• A folder or the trash opens and closes with one click
• Ideas and lyrics preview slide in from the side of their buttons. Closing the right side collapses that column
• An idea note can start at one line or two
""",
            bodyMarkdownJA: """
【修正】
• 曲を替えるアニメーションは右から左に統一し、素早く替えても逆向きになりません
• 歌詞の編集欄の高さは内容に合わせて変わります
• 曲を替えても、勝手に歌詞へカーソルを置きません。自分で押したときだけ入力できます
• フォルダとゴミ箱は一回のクリックで開閉します
• アイデアと歌詞プレビューは、ボタンのある側から出入りします。右を閉じるとその列はしまいます
• アイデアの最小の高さは一行か二行から選べます
""",
            bodyMarkdownKO: """
【수정】
• 곡을 바꿀 때의 움직임은 오른쪽에서 왼쪽으로 통일되어, 빨리 바꿔도 반대로 튀지 않습니다
• 가사 편집칸의 높이가 내용에 맞춰 변합니다
• 곡을 바꿔도 가사를 마음대로 입력 상태로 두지 않습니다. 직접 눌렀을 때만 입력합니다
• 폴더와 휴지통은 한 번 누르면 펼치거나 접힙니다
• 아이디어와 가사 미리보기는 버튼이 있는 쪽에서 들어오고 나갑니다. 오른쪽을 닫으면 그 열이 접힙니다
• 아이디어의 최소 높이를 한 줄 또는 두 줄로 고를 수 있습니다
""",
            bodyMarkdownES: """
【Corrección】
• Al cambiar de canción el movimiento va siempre de derecha a izquierda, también si se cambia muy rápido
• El alto del editor de la letra sigue al texto
• Cambiar de canción ya no deja el cursor dentro de la letra. Solo se escribe cuando se pulsa ahí
• Una carpeta o la papelera se abre y se cierra con un clic
• Ideas y la vista previa entran desde el lado de su botón. Al cerrar la derecha, esa columna se guarda
• La altura mínima de una idea puede ser de una o dos líneas
""",
        ),
        Entry(
            version: "v1.7.9 Gamma",
            date: "2026-06-24",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 换到列表里更下面的歌时从右往左滑，换到更上面的歌时从左往右滑
• 右侧的灵感和歌词预览互相切换时，会左右滑一下
【修复】
• 歌词编辑区的光标不会再一直停着。点到编辑区外面，光标就会消失，换歌后颜色也正常
""",
            bodyMarkdownZHT: """
【新增】
• 換到列表裡更下面的歌時從右往左滑，換到更上面的歌時從左往右滑
• 右側的靈感和歌詞預覽互相切換時，會左右滑一下
【修復】
• 歌詞編輯區的游標不會再一直停著。點到編輯區外面，游標就會消失，換歌後顏色也正常
""",
            bodyMarkdownEN: """
【New】
• Moving to a song lower in the list slides from right to left. Moving to a higher one slides from left to right
• Switching the right side between ideas and lyrics preview slides sideways
【Fixed】
• The cursor no longer stays stuck in the lyric editor. Click outside and it goes away, and the color is right after a song change
""",
            bodyMarkdownJA: """
【新機能】
• 一覧で下の曲へ移ると右から左、上の曲へ移ると左から右に滑ります
• 右側のアイデアと歌詞プレビューを入れ替えるとき、左右に滑ります
【修正】
• 歌詞の編集欄にカーソルが居座らなくなりました。外を押すと消え、曲を替えたあとの色も正常です
""",
            bodyMarkdownKO: """
【추가】
• 목록에서 더 아래 곡으로 가면 오른쪽에서 왼쪽, 더 위 곡으로 가면 왼쪽에서 오른쪽으로 미끄러집니다
• 오른쪽의 아이디어와 가사 미리보기를 바꿀 때 좌우로 미끄러집니다
【수정】
• 가사 편집칸에 커서가 계속 남지 않습니다. 밖을 누르면 사라지고, 곡을 바꾼 뒤의 색도 정상입니다
""",
            bodyMarkdownES: """
【Nuevo】
• Ir a una canción más abajo se desliza de derecha a izquierda, y a una más arriba, de izquierda a derecha
• Al pasar entre ideas y la vista previa, el panel derecho se desliza a un lado
【Corrección】
• El cursor ya no se queda fijo en el editor. Al pulsar fuera desaparece, y el color queda bien al cambiar de canción
""",
        ),
        Entry(
            version: "v1.7.9 Beta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 设置里增加了段落拖动开关，默认关闭。打开前会提醒它和歌词编辑、左滑删除可能互相影响
• 关闭段落拖动时，可以把段落向左滑来删除
【改动】
• 段落右键里的删除更显眼，用的是红色
• 鼠标在歌词上滚动时，整页也会跟着滚
• 各处右键里的删除都改成红色垃圾桶图标
• 歌曲信息展开和收起更顺手
""",
            bodyMarkdownZHT: """
【新增】
• 設定裡增加了段落拖動開關，預設關閉。打開前會提醒它和歌詞編輯、左滑刪除可能互相影響
• 關閉段落拖動時，可以把段落向左滑來刪除
【改動】
• 段落右鍵裡的刪除更顯眼，用的是紅色
• 滑鼠在歌詞上滾動時，整頁也會跟著滾
• 各處右鍵裡的刪除都改成紅色垃圾桶圖示
• 歌曲資訊展開和收起更順手
""",
            bodyMarkdownEN: """
【New】
• Settings gained a section-drag switch, off by default. Turning it on warns that it may conflict with editing lyrics and swiping to delete
• With dragging off, a section can be deleted by swiping left
【Changed】
• Delete in a section's right-click menu is easier to see and shown in red
• Scrolling over the lyrics also scrolls the page
• Delete items in right-click menus use a red trash icon
• Song details open and close more smoothly
""",
            bodyMarkdownJA: """
【新機能】
• 設定にセクション移動のスイッチが増え、既定はオフです。オンにする前に、歌詞編集や左へ滑らせて消す操作とぶつかることがあると知らせます
• 移動をオフにすると、セクションを左に滑らせて削除できます
【変更】
• セクションの右クリックにある削除は赤く、見つけやすくなりました
• 歌詞の上でホイールを回すと、ページも一緒に動きます
• 右クリックの削除は赤いゴミ箱の絵になりました
• 曲情報の開閉が滑らかになりました
""",
            bodyMarkdownKO: """
【추가】
• 설정에 섹션 드래그 스위치가 생겼고 기본은 꺼짐입니다. 켜기 전에 가사 편집, 왼쪽으로 밀어 지우기와 부딪힐 수 있다고 알립니다
• 드래그를 끄면 섹션을 왼쪽으로 밀어 지울 수 있습니다
【변경】
• 섹션 오른쪽 클릭의 삭제가 더 잘 보이게 빨간색입니다
• 가사 위에서 휠을 굴리면 페이지도 같이 움직입니다
• 오른쪽 클릭의 삭제는 빨간 휴지통 그림입니다
• 곡 정보를 펼치고 접는 느낌이 더 부드럽습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Ajustes tiene un interruptor para arrastrar secciones, apagado al principio. Al encenderlo avisa de que puede chocar con editar la letra y borrar deslizando
• Con el arrastre apagado, una sección se borra deslizando a la izquierda
【Cambios】
• Eliminar en el menú contextual de la sección se ve mejor y en rojo
• La rueda sobre la letra también desplaza la página
• Eliminar en los menús contextuales usa un cubo rojo
• Los datos de la canción se abren y se cierran con más suavidad
""",
        ),
        Entry(
            version: "v1.7.8 Delta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 段落的右键菜单可以把它移到最上面或最下面
• 点曲目列表里的歌不再慢半拍。拖动段落时，靠近顶部会自动往上滚
""",
            bodyMarkdownZHT: """
【新增】
• 段落的右鍵選單可以把它移到最上面或最下面
• 點曲目列表裡的歌不再慢半拍。拖動段落時，靠近頂部會自動往上滾
""",
            bodyMarkdownEN: """
【New】
• A section's right-click menu can move it to the very top or the very bottom
• Choosing a song in the list is no longer sluggish. Dragging a section near the top scrolls upward
""",
            bodyMarkdownJA: """
【新機能】
• セクションの右クリックから、一番上か一番下へ移せます
• 曲一覧で曲を押したときの遅れをなくしました。セクションを上の方まで拖ると自動で上へ動きます
""",
            bodyMarkdownKO: """
【추가】
• 섹션 오른쪽 클릭으로 맨 위나 맨 아래로 옮길 수 있습니다
• 곡 목록에서 곡을 누를 때 늦던 것을 없앴습니다. 섹션을 위쪽까지 끌면 자동으로 위로 움직입니다
""",
            bodyMarkdownES: """
【Nuevo】
• El menú contextual de una sección puede llevarla al principio o al final
• Elegir una canción en la lista ya no va con retraso. Arrastrar una sección cerca de arriba desplaza hacia arriba
""",
        ),
        Entry(
            version: "v1.7.8 Gamma",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 编辑区里的段落可以拖着调整顺序。拖到某一段的上半就插到它前面，拖到列表末尾就放到最后
• 向左滑删除时，只有真正点到删除按钮才会删，点到旁边会自己收回去
""",
            bodyMarkdownZHT: """
【新增】
• 編輯區裡的段落可以拖著調整順序。拖到某一段的上半就插到它前面，拖到列表末尾就放到最後
• 向左滑刪除時，只有真正點到刪除按鈕才會刪，點到旁邊會自己收回去
""",
            bodyMarkdownEN: """
【New】
• Sections in the editor can be dragged to reorder them. The upper half inserts before, and the end of the list adds it last
• When swiping left to delete, only a tap on the delete button deletes. Tapping beside it closes the button
""",
            bodyMarkdownJA: """
【新機能】
• 編集画面のセクションを拖って並べ替えられます。上半分に置くとその前、一覧の最後に置くと末尾です
• 左に滑らせて消すとき、削除ボタンを押したときだけ消えます。脇を押すとボタンは戻ります
""",
            bodyMarkdownKO: """
【추가】
• 편집 화면의 섹션을 끌어 순서를 바꿀 수 있습니다. 위쪽에 놓으면 앞에, 목록 끝에 놓으면 마지막입니다
• 왼쪽으로 밀어 지울 때, 삭제 버튼을 눌렀을 때만 지워집니다. 옆을 누르면 버튼이 들어갑니다
""",
            bodyMarkdownES: """
【Nuevo】
• Las secciones del editor se pueden arrastrar para ordenarlas. La mitad superior inserta antes, y el final de la lista la deja al último
• Al deslizar para borrar, solo un toque en el botón de borrar elimina. Tocar al lado lo guarda
""",
        ),
        Entry(
            version: "v1.7.8 Beta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 曲目列表里的歌可以拖进文件夹、拖出文件夹，或拖到另一首歌前面来排序
• 多选时的右键菜单里拿掉了和批量导出重复的备份。删除前确认的开关第一次打开就能看见滑块了
""",
            bodyMarkdownZHT: """
【新增】
• 曲目列表裡的歌可以拖進資料夾、拖出資料夾，或拖到另一首歌前面來排序
• 多選時的右鍵選單裡拿掉了和批次匯出重複的備份。刪除前確認的開關第一次打開就能看見滑塊了
""",
            bodyMarkdownEN: """
【New】
• Songs in the list can be dragged into a folder, out of a folder, or in front of another song to reorder them
• The duplicate backup item was removed from the multi-select menu. The confirm-before-delete switch shows its slider the first time it opens
""",
            bodyMarkdownJA: """
【新機能】
• 曲一覧の曲をフォルダへ入れたり出したり、別の曲の前に置いて並べ替えたりできます
• 複数選択のメニューから、一括書き出しと重なるバックアップを外しました。削除前確認のスイッチは最初からつまみが見えます
""",
            bodyMarkdownKO: """
【추가】
• 곡 목록의 곡을 폴더에 넣거나 빼고, 다른 곡 앞에 놓아 순서를 바꿀 수 있습니다
• 여러 개 선택의 메뉴에서 일괄 내보내기와 겹치던 백업을 뺐습니다. 삭제 전 확인 스위치는 처음 열어도 손잡이가 보입니다
""",
            bodyMarkdownES: """
【Nuevo】
• Las canciones de la lista se pueden meter en una carpeta, sacar de ella o poner delante de otra para ordenarlas
• Se quitó la copia repetida del menú de selección múltiple. El interruptor de confirmar el borrado muestra su deslizador desde la primera vez
""",
        ),
        Entry(
            version: "v1.7.7 Delta",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 歌曲信息里增加了节拍器，会按速度发出拍子并闪一下
• 修正了技能说明没有翻译的问题，使用说明也补上了繁体中文
""",
            bodyMarkdownZHT: """
【新增】
• 歌曲資訊裡增加了節拍器，會按速度發出拍子並閃一下
• 修正了技能說明沒有翻譯的問題，使用說明也補上了繁體中文
""",
            bodyMarkdownEN: """
【New】
• Song details include a metronome that clicks and flashes with the tempo
• The skill description is translated now, and the guide includes traditional Chinese
""",
            bodyMarkdownJA: """
【新機能】
• 曲情報にメトロノームが増え、テンポに合わせて音と点滅が出ます
• スキルの説明が翻訳されるようになり、使い方ガイドに繁体字中国語も入りました
""",
            bodyMarkdownKO: """
【추가】
• 곡 정보에 메트로놈이 생겨, 빠르기에 맞춰 소리와 깜빡임이 납니다
• 스킬 설명이 번역되고, 사용 안내에도 번체 중국어가 들어갔습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Los datos de la canción incluyen un metrónomo que suena y parpadea con el tempo
• La descripción de la habilidad ya está traducida, y la guía incluye chino tradicional
""",
        ),
        Entry(
            version: "v1.7.7 Gamma",
            date: "2026-06-23",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 设置里增加了技能导出，放在帮助上面。也可以从这里打开下载页，关于里能看到开发者邮箱
• 用真正的标志图换掉了占位图，技能和使用说明的小字也整理过了
""",
            bodyMarkdownZHT: """
【新增】
• 設定裡增加了技能匯出，放在幫助上面。也可以從這裡打開下載頁，關於裡能看到開發者郵箱
• 用真正的標誌圖換掉了佔位圖，技能和使用說明的小字也整理過了
""",
            bodyMarkdownEN: """
【New】
• Settings gained skill export above Help, a way to open the download page, and the developer email in About
• The placeholder picture was replaced with the real logo, and the small notes for skills and the guide were cleaned up
""",
            bodyMarkdownJA: """
【新機能】
• 設定にスキルの書き出しが増え、ヘルプの上にあります。ダウンロードページも開け、情報に開発者のメールが出ます
• 仮の絵を本物のロゴに替え、スキルと使い方の小さな注記も整えました
""",
            bodyMarkdownKO: """
【추가】
• 설정에 스킬 내보내기가 도움말 위에 생겼습니다. 다운로드 페이지도 열 수 있고, 정보에 개발자 메일이 나옵니다
• 자리 표시 그림을 실제 로고로 바꾸고, 스킬과 사용 안내의 작은 글도 다듬었습니다
""",
            bodyMarkdownES: """
【Nuevo】
• Ajustes tiene la exportación de habilidades encima de Ayuda, un enlace de descarga y el correo del desarrollador en Acerca de
• La imagen de relleno se sustituyó por el logotipo real, y se ordenaron las notas pequeñas de las habilidades y la guía
""",
        ),
        Entry(
            version: "v1.7.5 Gamma",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【新增】
• Command-N 新建歌曲，Command-D 删除选中的歌。帮助和更新日志会跟着界面语言变化
""",
            bodyMarkdownZHT: """
【新增】
• Command-N 新建歌曲，Command-D 刪除選中的歌。幫助和更新日誌會跟著介面語言變化
""",
            bodyMarkdownEN: """
【New】
• Command-N creates a song and Command-D deletes the selection. Help and the changelog follow the interface language
""",
            bodyMarkdownJA: """
【新機能】
• Command-N で新しい曲、Command-D で選択した曲を削除します。ヘルプと更新履歴は表示言語に従います
""",
            bodyMarkdownKO: """
【추가】
• Command-N으로 새 곡을 만들고 Command-D로 고른 곡을 지웁니다. 도움말과 업데이트 기록은 화면 언어를 따릅니다
""",
            bodyMarkdownES: """
【Nuevo】
• Command-N crea una canción y Command-D borra la selección. La ayuda y el registro siguen el idioma de la interfaz
""",
        ),
        Entry(
            version: "v1.7.5 Beta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 切换外观主题会马上生效。删除确认的开关第一次就能看见。帮助里增加了使用说明
""",
            bodyMarkdownZHT: """
【新增】
• 切換外觀主題會馬上生效。刪除確認的開關第一次就能看見。幫助裡增加了使用說明
""",
            bodyMarkdownEN: """
【New】
• Changing the theme applies at once. The delete-confirmation switch is visible the first time. Help includes a usage guide
""",
            bodyMarkdownJA: """
【新機能】
• テーマの切り替えはすぐに反映されます。削除確認のスイッチは最初から見え、ヘルプに使い方ガイドが増えました
""",
            bodyMarkdownKO: """
【추가】
• 테마를 바꾸면 바로 적용됩니다. 삭제 확인 스위치는 처음부터 보이고, 도움말에 사용 안내가 생겼습니다
""",
            bodyMarkdownES: """
【Nuevo】
• El cambio de tema se aplica al momento. El interruptor de confirmar el borrado se ve desde el principio. La ayuda incluye una guía de uso
""",
        ),
        Entry(
            version: "v1.7.4 Delta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【新增】
• 切换外观会马上生效，删除确认开关第一次打开就能看见滑块
""",
            bodyMarkdownZHT: """
【新增】
• 切換外觀會馬上生效，刪除確認開關第一次打開就能看見滑塊
""",
            bodyMarkdownEN: """
【New】
• The theme changes at once, and the delete-confirmation switch shows its slider the first time it opens
""",
            bodyMarkdownJA: """
【新機能】
• 見た目の切り替えはすぐ反映され、削除確認のスイッチは最初からつまみが見えます
""",
            bodyMarkdownKO: """
【추가】
• 모양을 바꾸면 바로 적용되고, 삭제 확인 스위치는 처음 열어도 손잡이가 보입니다
""",
            bodyMarkdownES: """
【Nuevo】
• El tema cambia al momento y el interruptor de confirmar el borrado muestra su deslizador desde la primera apertura
""",
        ),
        Entry(
            version: "v1.7.4 Gamma",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 文件夹里面的歌也能正常弹出右键菜单。只选一首歌时不再显示已选一项的工具条
""",
            bodyMarkdownZHT: """
【修復】
• 資料夾裡面的歌也能正常彈出右鍵選單。只選一首歌時不再顯示已選一項的工具列
""",
            bodyMarkdownEN: """
【Fixed】
• Songs inside a folder show their right-click menu again. Selecting a single song no longer shows a one-item toolbar
""",
            bodyMarkdownJA: """
【修正】
• フォルダの中の曲でも右クリックメニューが出ます。一曲だけ選んでも「1件選択」のバーは出ません
""",
            bodyMarkdownKO: """
【수정】
• 폴더 안의 곡에서도 오른쪽 클릭 메뉴가 나옵니다. 곡 하나만 골라도 한 개 선택 막대는 나오지 않습니다
""",
            bodyMarkdownES: """
【Corrección】
• Las canciones dentro de una carpeta vuelven a mostrar su menú contextual. Elegir una sola ya no muestra una barra de un elemento
""",
        ),
        Entry(
            version: "v1.7.4 Beta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 整理了侧栏的右键菜单，拿掉了备份文件夹。回收站可以双击展开。删除时会播放系统的废纸篓声音
""",
            bodyMarkdownZHT: """
【改動】
• 整理了側欄的右鍵選單，拿掉了備份資料夾。回收桶可以雙擊展開。刪除時會播放系統的廢紙簍聲音
""",
            bodyMarkdownEN: """
【Changed】
• The sidebar menu was tidied and folder backup was removed. The trash opens with a double click. Deleting plays the system trash sound
""",
            bodyMarkdownJA: """
【変更】
• サイドバーの右クリックを整え、フォルダのバックアップを外しました。ゴミ箱はダブルクリックで開き、削除時にはシステムのゴミ箱の音が鳴ります
""",
            bodyMarkdownKO: """
【변경】
• 사이드바 오른쪽 클릭을 정리하고 폴더 백업을 뺐습니다. 휴지통은 두 번 눌러 열리고, 지울 때 시스템 휴지통 소리가 납니다
""",
            bodyMarkdownES: """
【Cambios】
• Se ordenó el menú de la barra lateral y se quitó la copia de la carpeta. La papelera se abre con doble clic. Al borrar suena la papelera del sistema
""",
        ),
        Entry(
            version: "v1.7.3 Delta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 浅色时列表上不该出现的绿色块去掉了，设置里的外观也会跟着系统或所选主题走
""",
            bodyMarkdownZHT: """
【修復】
• 淺色時列表上不該出現的綠色塊去掉了，設定裡的外觀也會跟著系統或所選主題走
""",
            bodyMarkdownEN: """
【Fixed】
• The unwanted green block on the list in light mode is gone, and the app follows the system or the chosen theme
""",
            bodyMarkdownJA: """
【修正】
• ライトモードの一覧に出ていた緑の塊をなくし、見た目はシステムか選んだテーマに従います
""",
            bodyMarkdownKO: """
【수정】
• 밝은 모드 목록에 나오던 초록 덩어리를 없애고, 모양은 시스템이나 고른 테마를 따릅니다
""",
            bodyMarkdownES: """
【Corrección】
• Desapareció el bloque verde de la lista en modo claro, y la aplicación sigue al sistema o al tema elegido
""",
        ),
        Entry(
            version: "v1.7.3 Gamma",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【修复】
• 浅色模式下看不清的文字和图标改成看得清的颜色。段落四周的底色块拿掉了，改成细一点的边距和边框
""",
            bodyMarkdownZHT: """
【修復】
• 淺色模式下看不清的文字和圖示改成看得清的顏色。段落四周的底色塊拿掉了，改成細一點的邊距和邊框
""",
            bodyMarkdownEN: """
【Fixed】
• Text and icons that vanished in light mode are readable again. The flat color behind a section was replaced with a lighter margin and border
""",
            bodyMarkdownJA: """
【修正】
• ライトモードで見えなかった文字とアイコンが見える色になりました。セクション背面の色塊をやめ、余白と枠にしました
""",
            bodyMarkdownKO: """
【수정】
• 밝은 모드에서 안 보이던 글자와 아이콘이 보이는 색이 되었습니다. 섹션 뒤의 색 덩어리를 없애고 여백과 테두리로 바꿨습니다
""",
            bodyMarkdownES: """
【Corrección】
• El texto y los iconos invisibles en modo claro vuelven a leerse. El bloque de color tras la sección pasó a un margen y un borde más ligeros
""",
        ),
        Entry(
            version: "v1.7.3 Beta",
            date: "2026-06-21",
            isLatest: false,
            bodyMarkdown: """
【改动】
• 颜色改成跟着文字颜色走，深浅模式下都更一致。跳转后的闪烁时间从零点八秒缩短到半秒
""",
            bodyMarkdownZHT: """
【改動】
• 顏色改成跟著文字顏色走，深淺模式下都更一致。跳轉後的閃爍時間從零點八秒縮短到半秒
""",
            bodyMarkdownEN: """
【Changed】
• Colors now follow the text color, so light and dark stay consistent. The jump flash was shortened from eight tenths of a second to half a second
""",
            bodyMarkdownJA: """
【変更】
• 色は文字色に沿い、ライトとダークで揃いました。ジャンプ後の点滅は〇・八秒から〇・五秒になりました
""",
            bodyMarkdownKO: """
【변경】
• 색이 글자색을 따라 밝은 화면과 어두운 화면이 더 맞습니다. 이동 뒤 깜빡임은 0.8초에서 0.5초로 줄었습니다
""",
            bodyMarkdownES: """
【Cambios】
• Los colores siguen al texto, así que el modo claro y el oscuro coinciden. El parpadeo al saltar pasó de ocho décimas a medio segundo
""",
        ),
        Entry(
            version: "v1.7.2 Beta",
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
            version: "v1.7 Beta",
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
            version: "v1.6.1 Beta",
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
            version: "v1.6 Beta",
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
            version: "v1.5.2 Beta",
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
            version: "v1.5 Beta",
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
            version: "v1.4 Beta",
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
            version: "v1.3 Beta",
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
            version: "v1.2 Beta",
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