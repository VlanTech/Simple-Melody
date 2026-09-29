// Engine/ImagineWorkflow.swift
// Imagine：段落或全曲的翻译 / 创意。只按约定字段写回，不调用时由测试注入结果。

import Foundation

enum ImagineAction: Equatable {
    case translate
    case create
}

enum ImagineScope: Equatable {
    case section(String)
    case song
}

struct ImagineSection: Equatable {
    var id: String
    var marker: String
    var body: String
    var translation: String
    var notes: String
}

struct ImagineIdea: Equatable {
    var id: String
    var ideaType: String
    var content: String
}

struct ImagineDocument: Equatable {
    var title: String
    var artist: String
    var languages: String
    var bpm: Int?
    var musicalKey: String?
    var beat: String
    var ideas: String
    var ideaItems: [ImagineIdea] = []
    var sections: [ImagineSection]
}

struct ImagineComposeResult: Equatable {
    var system: String
    var user: String
}

enum ImagineWorkflow {
    static func reference(for action: ImagineAction) -> String {
        switch action {
        case .translate:
            return """
            你是歌词译者。请把给出的歌词译成指定的目标语言，做到信达雅，不丢失原意，也不要自行加戏。
            用户提示词优先于信达雅和「不要自行加戏」这些说明。没有用户提示词时，不要自己编造额外要求，只按原文和目标语言翻译。
            只翻译 Lyrics 下面的歌词正文。Notes 不是歌词，禁止把笔记翻译进 Translation，也禁止把笔记抄进 Lyrics。
            Lyrics 为空或只有空白的段落不要出现在回复里，不要为它编造译文。
            禁止输出 Notes、Lyrics、Language、BPM、Key、Beat。译文只能写在 Translation 下面，禁止把译文写进 Notes。
            只按下面的字段回复，不要加开场白或解释。每个要翻译的段落单独一块，字段名必须独占一行：
            Section: <原样抄写段落编号>
            Translation:
            <只包含歌词正文的译文>
            不要输出创作说明，不要改段落编号。不要输出 Notes。
            """
        case .create:
            return """
            你是歌词作者。请按给出的歌曲信息写可演唱的词，句长和格律要适合这首歌，语气与已有内容相称。
            用户提示词优先于本节的风格说明。没有用户提示词时，不要自己编造额外要求，只根据给出的歌曲信息来写。
            全曲任务：每个段落单独一块，按顺序输出，不要把全部歌词写进同一个 Lyrics。
            段落任务：会收到整首歌作文风参考。只输出指定的那一个 Section。禁止输出 Title、Language、BPM、Key、Beat，禁止输出其他段落，禁止输出 Idea。
            Title 是歌名，必须写在 Title 字段，禁止把歌名写进 Idea。
            Title、Language、BPM、Key、Beat 当前空白时必须补上并遵循格式。已有且没有修改必要的字段整项省略，以缩短回复、减少出错。有必要改时即使提示词没点名也要输出。
            Lyrics 只放歌词，Translation 只放译文，Notes 只放创作备注。禁止把歌词或译文写进 Notes，禁止把译文写进 Lyrics。
            全曲任务默认输出灵感设定，格式与段落一致，每条单独一块；不要把灵感写进 Notes 或 Lyrics。
            只按下面的字段回复，不要加开场白。
            Title: <歌名，空白或需要新歌名时必须输出；已有且不改则整项省略>
            Language: <语言代码，空白或需要改时输出；不改则整项省略>
            BPM: <整数，空白或需要改时输出；不改则整项省略>
            Key: <调式，空白或需要改时输出；不改则整项省略>
            Beat: <节拍，空白或需要改时输出；不改则整项省略>
            Idea: <编号或原样抄写>
            Type: Inspiration|Setting|Background|Note
            Content:
            <这一条灵感或设定>
            Section: <原样抄写段落编号或从 1 起的顺序号>
            Lyrics:
            <这一段的歌词>
            Translation:
            <只有译文时才写，没有则省略>
            Notes:
            <只有创作备注时才写，没有则省略>
            """
        }
    }

    /// 用户提示词是否要求改语言、速度、调式、节拍。没要求时这些字段即使出现也跳过。
    static func asksToChangeSongBasics(_ prompt: String) -> Bool {
        let text = prompt.lowercased()
        let needles = [
            "bpm", "tempo", "meter", "time signature",
            "调式", "调性", "节拍", "拍号", "拍子", "速度",
            "歌曲语言", "改语言", "改调", "改拍", "改bpm",
            "beat:", "key:", "language:",
        ]
        return needles.contains { text.contains($0) }
    }

    /// 空的用户提示词不会写进请求。翻译必须有目标语言。找不到目标段落时返回空。
    static func compose(
        action: ImagineAction,
        scope: ImagineScope,
        document: ImagineDocument,
        targetLanguage: String,
        userPrompt: String,
        keepCurrentFormat: Bool = true,
        allowSongBasics: Bool = false
    ) -> ImagineComposeResult? {
        let prompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let language = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        if action == .translate && language.isEmpty { return nil }

        var lines: [String] = []
        switch scope {
        case .section(let id):
            guard let section = document.sections.first(where: { sameID($0.id, id) }) else { return nil }
            if action == .translate && !hasLyrics(section) { return nil }
            lines.append("Scope: section")
            if action == .translate {
                lines.append("目标语言: \(language)")
                lines.append("禁止输出 Notes、Lyrics。译文只写在 Translation 下面。")
                lines.append(contentsOf: sectionBlock(section, includeNotes: false))
            } else {
                lines.append(contentsOf: songContext(document))
                lines.append("这是段落任务。全文仅作文风参考，只返回当前这一段以保持文风一致。")
                lines.append("只输出这一个 Section: \(section.id)。禁止输出 Title、Language、BPM、Key、Beat。禁止输出其他段落。禁止输出 Idea。")
                for item in document.sections {
                    if sameID(item.id, id) {
                        lines.append("Target section: \(item.id)")
                    }
                    lines.append(contentsOf: sectionBlock(item, includeNotes: true))
                }
            }
        case .song:
            lines.append("Scope: song")
            if action == .translate {
                lines.append("目标语言: \(language)")
                lines.append("禁止输出 Notes、Lyrics。译文只写在 Translation 下面。")
            }
            lines.append(contentsOf: songContext(document))
            if action == .create {
                if keepCurrentFormat {
                    lines.append("Keep format: yes")
                    lines.append("按现有段落顺序每段一块，Section 编号原样抄写，不要增删段落，不要把全部歌词写进同一个 Lyrics。")
                    for section in document.sections {
                        lines.append(contentsOf: sectionBlock(section, includeNotes: true))
                    }
                    for idea in document.ideaItems {
                        lines.append(contentsOf: ideaBlock(idea))
                    }
                } else {
                    lines.append("Keep format: no")
                    lines.append("不要沿用用户现有段落的歌词。按演唱顺序输出若干 Section 块，从 1 起编号。不要把全部歌词写进同一个 Lyrics。")
                }
                lines.append("默认输出 Idea 块，格式与 Section 一致：Idea / Type / Content。不要把灵感写进 Notes 或 Lyrics。")
                lines.append(contentsOf: fillBlankInstructions(document))
            } else {
                let sections = document.sections.filter(hasLyrics)
                if sections.isEmpty { return nil }
                for section in sections {
                    lines.append(contentsOf: sectionBlock(section, includeNotes: false))
                }
            }
        }
        if !prompt.isEmpty {
            lines.append("用户提示词:")
            lines.append(prompt)
        }
        return ImagineComposeResult(
            system: reference(for: action),
            user: lines.joined(separator: "\n")
        )
    }

    struct ApplyResult: Equatable {
        var document: ImagineDocument
        var overreach: Bool
    }

    /// 只写入对得上的字段。段落 Imagine 若干了 Imagine 的活，整份不写。
    static func apply(
        reply: String,
        action: ImagineAction,
        scope: ImagineScope,
        document: ImagineDocument,
        keepCurrentFormat: Bool = true,
        allowSongBasics: Bool = false
    ) -> ImagineDocument {
        applyResult(
            reply: reply,
            action: action,
            scope: scope,
            document: document,
            keepCurrentFormat: keepCurrentFormat,
            allowSongBasics: allowSongBasics
        ).document
    }

    static func applyResult(
        reply: String,
        action: ImagineAction,
        scope: ImagineScope,
        document: ImagineDocument,
        keepCurrentFormat: Bool = true,
        allowSongBasics: Bool = false
    ) -> ApplyResult {
        let parsed = parse(reply)
        if action == .create, case .section(let id) = scope, isOverreach(parsed, target: id, document: document) {
            return ApplyResult(document: document, overreach: true)
        }

        var updated = document
        var wrote = false

        if action == .create, case .song = scope {
            if let title = parsed.title?.trimmedNonEmpty {
                updated.title = title
                wrote = true
            }
            if let language = parsed.language?.trimmedNonEmpty {
                updated.languages = language
                wrote = true
            }
            if let bpm = parsed.bpm {
                updated.bpm = bpm
                wrote = true
            }
            if let key = parsed.musicalKey?.trimmedNonEmpty {
                updated.musicalKey = key
                wrote = true
            }
            if let beat = parsed.beat?.trimmedNonEmpty {
                updated.beat = beat
                wrote = true
            }
            let placed = placeCreativeSong(parsed: parsed, document: updated, keepCurrentFormat: keepCurrentFormat)
            if placed.wrote {
                updated = placed.document
                wrote = true
            }
            if let ideas = placedIdeas(parsed: parsed, document: updated, keepCurrentFormat: keepCurrentFormat) {
                updated.ideaItems = ideas
                updated.ideas = ideas.map(\.content).joined(separator: "\n")
                wrote = true
            }
            return ApplyResult(document: wrote ? updated : document, overreach: false)
        }

        let allowedIDs: Set<String>
        switch scope {
        case .section(let id):
            allowedIDs = [canonicalID(id)]
        case .song:
            allowedIDs = Set(document.sections.map { canonicalID($0.id) })
        }

        for index in updated.sections.indices {
            let id = canonicalID(updated.sections[index].id)
            guard allowedIDs.contains(id), let fields = parsed.sections[id] else { continue }
            switch action {
            case .translate:
                guard hasLyrics(updated.sections[index]) else { continue }
                if let translation = translationText(fields) {
                    updated.sections[index].translation = translation
                    wrote = true
                }
            case .create:
                if let body = fields.lyrics?.trimmedNonEmpty {
                    updated.sections[index].body = body
                    wrote = true
                }
                if let notes = notesText(fields) {
                    updated.sections[index].notes = notes
                    wrote = true
                }
                if let translation = fields.translation?.trimmedNonEmpty {
                    updated.sections[index].translation = translation
                    wrote = true
                }
            }
        }
        return ApplyResult(document: wrote ? updated : document, overreach: false)
    }

    private static func isOverreach(_ parsed: ParsedReply, target: String, document: ImagineDocument) -> Bool {
        if parsed.title?.trimmedNonEmpty != nil { return true }
        if parsed.language?.trimmedNonEmpty != nil { return true }
        if parsed.bpm != nil { return true }
        if parsed.musicalKey?.trimmedNonEmpty != nil { return true }
        if parsed.beat?.trimmedNonEmpty != nil { return true }
        if parsed.sectionOrder.count > 1 { return true }
        if parsed.sectionOrder.contains(where: { !sameID($0, target) }) { return true }
        if !parsed.ideaOrder.isEmpty { return true }
        if dumpsOtherSectionLyrics(parsed, target: target, document: document) { return true }
        return false
    }

    /// 把其他段落的歌词整段塞进当前段，视为全文修改。
    private static func dumpsOtherSectionLyrics(_ parsed: ParsedReply, target: String, document: ImagineDocument) -> Bool {
        guard let lyrics = parsed.sections[canonicalID(target)]?.lyrics else { return false }
        for section in document.sections where !sameID(section.id, target) {
            guard let other = section.body.trimmedNonEmpty, other.count >= 8 else { continue }
            if lyrics.contains(other) { return true }
        }
        return false
    }

    private static func placeCreativeSong(
        parsed: ParsedReply,
        document: ImagineDocument,
        keepCurrentFormat: Bool
    ) -> (document: ImagineDocument, wrote: Bool) {
        let incoming: [ParsedSection] = parsed.sectionOrder.compactMap { parsed.sections[$0] }
        guard !incoming.isEmpty else { return (document, false) }
        var updated = document
        var wrote = false
        if keepCurrentFormat {
            for (index, fields) in zip(updated.sections.indices, incoming) {
                if let body = fields.lyrics?.trimmedNonEmpty {
                    updated.sections[index].body = body
                    wrote = true
                }
                if let translation = fields.translation?.trimmedNonEmpty {
                    updated.sections[index].translation = translation
                    wrote = true
                }
                if let notes = notesText(fields) {
                    updated.sections[index].notes = notes
                    wrote = true
                }
            }
            return (updated, wrote)
        }
        let filled = document.sections.filter(hasContent)
        var blankIDs = document.sections.filter { !hasContent($0) }.map(\.id)
        var placed: [ImagineSection] = []
        for fields in incoming {
            let id: String
            if blankIDs.isEmpty {
                id = UUID().uuidString
            } else {
                id = blankIDs.removeFirst()
            }
            let original = document.sections.first { sameID($0.id, id) }
            placed.append(
                ImagineSection(
                    id: id,
                    marker: original?.marker ?? "",
                    body: fields.lyrics ?? "",
                    translation: fields.translation ?? original?.translation ?? "",
                    notes: notesText(fields) ?? original?.notes ?? ""
                )
            )
            wrote = true
        }
        placed.append(contentsOf: filled)
        updated.sections = placed
        return (updated, wrote)
    }

    private static func placedIdeas(
        parsed: ParsedReply,
        document: ImagineDocument,
        keepCurrentFormat: Bool
    ) -> [ImagineIdea]? {
        let incoming: [ImagineIdea] = parsed.ideaOrder.compactMap { id in
            guard let item = parsed.ideas[id] else { return nil }
            let content = item.content?.trimmedNonEmpty ?? ""
            guard !content.isEmpty else { return nil }
            return ImagineIdea(
                id: id,
                ideaType: normalizeIdeaType(item.ideaType),
                content: content
            )
        }
        guard !incoming.isEmpty else { return nil }
        if !keepCurrentFormat || document.ideaItems.isEmpty {
            return incoming.map { idea in
                ImagineIdea(
                    id: UUID().uuidString,
                    ideaType: idea.ideaType,
                    content: idea.content
                )
            }
        }
        var items = document.ideaItems
        for (index, idea) in incoming.enumerated() {
            if index < items.count {
                items[index].content = idea.content
                items[index].ideaType = idea.ideaType
            } else {
                items.append(
                    ImagineIdea(id: UUID().uuidString, ideaType: idea.ideaType, content: idea.content)
                )
            }
        }
        return items
    }

    private static func normalizeIdeaType(_ raw: String?) -> String {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        if lower == "setting" || text == "设定" || text == "設定" { return "Setting" }
        if lower == "background" || text == "背景" { return "Background" }
        if lower == "note" || text == "备注" || text == "備註" { return "Note" }
        return "Inspiration"
    }

    private static func fillBlankInstructions(_ document: ImagineDocument) -> [String] {
        var missing: [String] = []
        if document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Title") }
        if document.languages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Language") }
        if document.bpm == nil { missing.append("BPM") }
        if (document.musicalKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Key") }
        if document.beat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Beat") }
        let fromScratch = document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && document.sections.allSatisfy { !hasContent($0) }
        var lines = [
            "歌名必须写在 Title 字段，禁止把歌名写进 Idea。",
        ]
        if fromScratch {
            lines.append("这是从空白歌曲创建。必须输出 Title、Language、BPM、Key、Beat，并遵循格式。")
        } else if !missing.isEmpty {
            lines.append("当前空白必须补上并遵循格式: \(missing.joined(separator: ", "))。")
        }
        lines.append("已有且没有修改必要的 Title、Language、BPM、Key、Beat 整项省略。有必要改时即使提示词没点名也要输出。")
        return lines
    }

    private static func songContext(_ document: ImagineDocument) -> [String] {
        var lines = [
            "Title: \(document.title)",
            "Artist: \(document.artist)",
            "Language: \(document.languages)",
            "BPM: \(document.bpm.map(String.init) ?? "")",
            "Key: \(document.musicalKey ?? "")",
            "Beat: \(document.beat)",
        ]
        if !document.ideaItems.isEmpty {
            for idea in document.ideaItems {
                lines.append(contentsOf: ideaBlock(idea))
            }
        } else {
            let ideas = document.ideas.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ideas.isEmpty {
                lines.append("Ideas:")
                lines.append(ideas)
            }
        }
        return lines
    }

    private static func ideaBlock(_ idea: ImagineIdea) -> [String] {
        [
            "Idea: \(idea.id)",
            "Type: \(normalizeIdeaType(idea.ideaType))",
            "Content:",
            idea.content,
        ]
    }

    private static func sameID(_ lhs: String, _ rhs: String) -> Bool {
        canonicalID(lhs) == canonicalID(rhs)
    }

    private static func canonicalID(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func hasLyrics(_ section: ImagineSection) -> Bool {
        section.body.trimmedNonEmpty != nil
    }

    private static func hasContent(_ section: ImagineSection) -> Bool {
        hasLyrics(section)
            || section.notes.trimmedNonEmpty != nil
            || section.translation.trimmedNonEmpty != nil
    }

    /// 翻译只认 Translation；若模型误把译文写在 Notes 下，仍写入译文栏，不写入笔记。
    private static func translationText(_ fields: ParsedSection) -> String? {
        if let translation = fields.translation?.trimmedNonEmpty {
            return translation
        }
        if fields.lyrics?.trimmedNonEmpty == nil {
            return fields.notes?.trimmedNonEmpty
        }
        return nil
    }

    /// 笔记不得与歌词或译文相同，避免把译文/歌词落到笔记里。
    private static func notesText(_ fields: ParsedSection) -> String? {
        guard let notes = fields.notes?.trimmedNonEmpty else { return nil }
        if let lyrics = fields.lyrics?.trimmedNonEmpty, notes == lyrics { return nil }
        if let translation = fields.translation?.trimmedNonEmpty, notes == translation { return nil }
        return notes
    }

    private static func sectionBlock(_ section: ImagineSection, includeNotes: Bool) -> [String] {
        var lines = [
            "Section: \(section.id)",
            "Marker: \(section.marker)",
            "Lyrics:",
            section.body,
        ]
        if !section.translation.isEmpty {
            lines.append("Translation:")
            lines.append(section.translation)
        }
        if includeNotes, !section.notes.isEmpty {
            lines.append("Notes:")
            lines.append(section.notes)
        }
        return lines
    }

    private struct ParsedReply {
        var title: String?
        var language: String?
        var bpm: Int?
        var musicalKey: String?
        var beat: String?
        var sections: [String: ParsedSection] = [:]
        var sectionOrder: [String] = []
        var ideas: [String: ParsedIdea] = [:]
        var ideaOrder: [String] = []
    }

    private struct ParsedSection {
        var lyrics: String?
        var translation: String?
        var notes: String?
    }

    private struct ParsedIdea {
        var ideaType: String?
        var content: String?
    }

    private enum Field {
        case title, language, bpm, key, beat, lyrics, translation, notes, ideaType, ideaContent
    }

    private static func parse(_ reply: String) -> ParsedReply {
        var parsed = ParsedReply()
        var currentID: String?
        var currentIdeaID: String?
        var field: Field?
        var buffer = ""

        func flush() {
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = ""
            guard let field else { return }
            switch field {
            case .title:
                if !text.isEmpty { parsed.title = text }
            case .language:
                if !text.isEmpty { parsed.language = text }
            case .bpm:
                if let value = text.split(whereSeparator: { !$0.isNumber }).compactMap({ Int($0) }).first {
                    parsed.bpm = value
                }
            case .key:
                if !text.isEmpty { parsed.musicalKey = text }
            case .beat:
                if !text.isEmpty { parsed.beat = text }
            case .lyrics, .translation, .notes:
                guard let id = currentID else { return }
                var section = parsed.sections[id] ?? ParsedSection()
                switch field {
                case .lyrics: section.lyrics = text
                case .translation: section.translation = text
                case .notes: section.notes = text
                default: break
                }
                parsed.sections[id] = section
            case .ideaType, .ideaContent:
                guard let id = currentIdeaID else { return }
                var idea = parsed.ideas[id] ?? ParsedIdea()
                switch field {
                case .ideaType: idea.ideaType = text
                case .ideaContent: idea.content = text
                default: break
                }
                parsed.ideas[id] = idea
            }
        }

        for raw in reply.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if let (name, rest) = label(raw) {
                flush()
                switch name {
                case "Section":
                    currentIdeaID = nil
                    currentID = canonicalID(rest)
                    field = nil
                    if let currentID {
                        parsed.sections[currentID] = parsed.sections[currentID] ?? ParsedSection()
                        if !parsed.sectionOrder.contains(currentID) {
                            parsed.sectionOrder.append(currentID)
                        }
                    }
                case "Idea":
                    currentID = nil
                    currentIdeaID = canonicalID(rest)
                    field = nil
                    if let currentIdeaID {
                        parsed.ideas[currentIdeaID] = parsed.ideas[currentIdeaID] ?? ParsedIdea()
                        if !parsed.ideaOrder.contains(currentIdeaID) {
                            parsed.ideaOrder.append(currentIdeaID)
                        }
                    }
                case "Title":
                    field = .title
                    buffer = rest
                case "Language":
                    field = .language
                    buffer = rest
                case "BPM":
                    field = .bpm
                    buffer = rest
                case "Key":
                    field = .key
                    buffer = rest
                case "Beat":
                    field = .beat
                    buffer = rest
                case "Lyrics":
                    field = .lyrics
                    buffer = rest
                case "Translation":
                    field = .translation
                    buffer = rest
                case "Notes":
                    field = .notes
                    buffer = rest
                case "Type":
                    field = .ideaType
                    buffer = rest
                case "Content":
                    field = .ideaContent
                    buffer = rest
                default:
                    field = nil
                }
            } else if field != nil {
                if !buffer.isEmpty { buffer += "\n" }
                buffer += raw
            }
        }
        flush()
        return parsed
    }

    private static func label(_ line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let aliases: [(String, [String])] = [
            ("Translation", ["Translation:", "翻译:", "翻譯:", "译文:", "譯文:"]),
            ("Notes", ["Notes:", "笔记:", "筆記:"]),
            ("Lyrics", ["Lyrics:", "歌词:", "歌詞:"]),
            ("Section", ["Section:", "段落:"]),
            ("Idea", ["Idea:", "灵感:", "靈感:"]),
            ("Type", ["Type:", "类型:", "類型:"]),
            ("Content", ["Content:", "内容:", "內容:"]),
            ("Title", ["Title:", "标题:", "標題:", "歌名:", "曲名:"]),
            ("Language", ["Language:"]),
            ("BPM", ["BPM:"]),
            ("Key", ["Key:"]),
            ("Beat", ["Beat:"]),
        ]
        for (name, prefixes) in aliases {
            for prefix in prefixes.sorted(by: { $0.count > $1.count }) {
                if trimmed.hasPrefix(prefix) {
                    return (name, String(trimmed.dropFirst(prefix.count)))
                }
            }
        }
        return nil
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ImagineLanguageMemory {
    static let storageKey = "imagine.lastTargetLanguage"

    static func last(defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: storageKey) ?? ""
    }

    static func remember(_ language: String, defaults: UserDefaults = .standard) {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: storageKey)
    }
}

struct ImagineChatRequest: Equatable {
    var url: URL
    var authorization: String
    var body: String
}

struct ImagineHTTPResult: Equatable {
    var status: Int
    var body: String
}

enum ImagineCheckOutcome: Equatable {
    case success
    case failure
}

struct ImagineCheckTrace: Equatable {
    var request: ImagineChatRequest?
    var outcome: ImagineCheckOutcome
}

enum ImagineAPI {
    static func chatCompletionsURL(from base: String) -> URL? {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }
        guard var components = URLComponents(string: trimmed), components.host != nil else { return nil }
        var path = components.path
        if path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        let lower = path.lowercased()
        if lower.hasSuffix("/chat/completions") {
            // 用户已经给到完整路径。
        } else if lower.hasSuffix("/v1") {
            path += "/chat/completions"
        } else {
            path += "/v1/chat/completions"
        }
        components.path = path.isEmpty ? "/v1/chat/completions" : path
        return components.url
    }

    /// 模型名为空时不写入 model，也不另填一个默认名字。
    static func chatRequest(
        connection: LLMConnection,
        system: String,
        user: String
    ) -> ImagineChatRequest? {
        let key = connection.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, let url = chatCompletionsURL(from: connection.baseURL) else { return nil }
        var payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        let model = connection.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty {
            payload["model"] = model
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let body = String(data: data, encoding: .utf8) else { return nil }
        return ImagineChatRequest(url: url, authorization: "Bearer \(key)", body: body)
    }

    static func interpret(status: Int, body: String) -> ImagineCheckOutcome {
        guard (200..<300).contains(status) else { return .failure }
        if let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
           object["error"] != nil {
            return .failure
        }
        return .success
    }

    static func check(
        connection: LLMConnection,
        exchange: (ImagineChatRequest) -> ImagineHTTPResult
    ) -> ImagineCheckTrace {
        guard let request = chatRequest(connection: connection, system: "Reply with the single word ok.", user: "ping") else {
            return ImagineCheckTrace(request: nil, outcome: .failure)
        }
        let http = exchange(request)
        return ImagineCheckTrace(request: request, outcome: interpret(status: http.status, body: http.body))
    }

    static func assistantText(from body: String) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : content
    }

    static func checkLive(_ connection: LLMConnection) async -> ImagineCheckOutcome {
        guard let request = chatRequest(connection: connection, system: "Reply with the single word ok.", user: "ping") else {
            return .failure
        }
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(request.authorization, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = Data(request.body.utf8)
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            return interpret(status: status, body: body)
        } catch {
            return .failure
        }
    }

    static func send(_ request: ImagineChatRequest) async -> Result<String, ImagineSendError> {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(request.authorization, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = Data(request.body.utf8)
        let box = ImagineRequestBox()
        return await withTaskCancellationHandler {
            do {
                let (data, response) = try await box.run(urlRequest)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let body = String(data: data, encoding: .utf8) ?? ""
                guard case .success = interpret(status: status, body: body) else { return .failure(.rejected) }
                guard let text = assistantText(from: body) else { return .failure(.unreadable) }
                return .success(text)
            } catch let error as URLError where error.code == .cancelled {
                return .failure(.cancelled)
            } catch is CancellationError {
                return .failure(.cancelled)
            } catch {
                return .failure(.transport)
            }
        } onCancel: {
            box.cancel()
        }
    }
}

private final class ImagineRequestBox: @unchecked Sendable {
    private var task: URLSessionTask?

    func cancel() {
        task?.cancel()
    }

    func run(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            self.task = task
            task.resume()
        }
    }
}

enum ImagineSendError: Error {
    case rejected
    case unreadable
    case transport
    case cancelled
}
