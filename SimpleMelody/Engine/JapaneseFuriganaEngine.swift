// Engine/JapaneseFuriganaEngine.swift
// 日语假名自动注音引擎
// v1.6.1: 词库扩充到约 2300 词（见 JapaneseFuriganaDictionary.swift）

import Foundation

/// 日语假名自动注音结果
struct FuriganaMatch: Hashable {
    let original: String   // 原文（汉字或词组）
    let kana: String       // 注音（平假名）
    let range: NSRange     // 在源字符串中的位置
    let confidence: Float  // 0.0~1.0
}

/// 日语假名自动注音引擎
final class JapaneseFuriganaEngine {
    static let shared = JapaneseFuriganaEngine()

    // MARK: - 字典

    /// 词组读音字典（v1.6.1: 扩充到 ~2300 词条，见 JapaneseFuriganaDictionary.swift）
    private let compoundDictionary: [String: String] = JapaneseFuriganaDictionary.standardCompound

    /// 单字读音字典（精选常用汉字）
    private let singleKanjiDictionary: [Character: String] = buildSingleKanjiDictionary()

    // MARK: - 公共接口

    /// 检查是否包含汉字
    static func containsKanji(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            // CJK Unified Ideographs (基本汉字 + 扩展A)
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    /// 自动注音：返回所有匹配的假名
    func annotate(_ text: String) -> [FuriganaMatch] {
        let nsText = text as NSString
        var matches: [FuriganaMatch] = []
        var index = 0
        let length = nsText.length

        while index < length {
            let unichar = nsText.character(at: index)
            // 跳过非汉字字符
            if !isKanji(unichar: unichar) {
                index += 1
                continue
            }

            // 1. 尝试匹配最长的词组（最多 6 字）
            var bestMatch: (kana: String, length: Int)? = nil
            for wordLen in stride(from: min(6, length - index), through: 2, by: -1) {
                let word = nsText.substring(with: NSRange(location: index, length: wordLen))
                if let kana = compoundDictionary[word] {
                    bestMatch = (kana, wordLen)
                    break
                }
            }

            if let m = bestMatch {
                matches.append(FuriganaMatch(
                    original: nsText.substring(with: NSRange(location: index, length: m.length)),
                    kana: m.kana,
                    range: NSRange(location: index, length: m.length),
                    confidence: 0.95
                ))
                index += m.length
            } else if let scalar = UnicodeScalar(unichar),
                      let kana = singleKanjiDictionary[Character(scalar)] {
                matches.append(FuriganaMatch(
                    original: nsText.substring(with: NSRange(location: index, length: 1)),
                    kana: kana,
                    range: NSRange(location: index, length: 1),
                    confidence: 0.85
                ))
                index += 1
            } else {
                // 字典中未收录
                index += 1
            }
        }

        return matches
    }

    private func isKanji(unichar: unichar) -> Bool {
        let scalar = UnicodeScalar(unichar)
        guard let value = scalar?.value else { return false }
        return (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value)
    }
}

// MARK: - 单字字典

private func buildSingleKanjiDictionary() -> [Character: String] {
    let dict: [Character: String] = [
        // 数字
        "一": "いち", "二": "に", "三": "さん", "四": "し/よん", "五": "ご",
        "六": "ろく", "七": "しち/なな", "八": "はち", "九": "きゅう/く", "十": "じゅう",
        "百": "ひゃく", "千": "せん", "万": "まん", "円": "えん",
        "半": "はん", "両": "りょう",

        // 自然
        "日": "にち/ひ", "月": "げつ/つき", "火": "か/ひ", "水": "すい/みず",
        "木": "もく/き", "金": "きん/かね", "土": "ど/つち", "石": "せき/いし",
        "山": "さん/やま", "川": "せん/かわ", "海": "うみ", "空": "そら/くう",
        "雨": "あめ", "雪": "ゆき", "風": "かぜ/ふう", "雲": "くも",
        "花": "か/はな", "草": "そう/くさ", "森": "もり/しん",

        // 人物
        "人": "じん/ひと", "子": "し/こ", "女": "じょ/おんな", "男": "だん/おとこ",
        "目": "もく/め", "耳": "じ/みみ", "口": "こう/くち", "手": "しゅ/て",
        "足": "そく/あし", "心": "しん/こころ", "体": "たい/からだ",
        "首": "くび/しゅ", "顔": "かお/がん", "髪": "かみ/はつ",

        // 工具/物品
        "本": "ほん/もと", "車": "しゃ/くるま", "船": "せん/ふね", "馬": "ま/うま",
        "鳥": "ちょう/とり", "魚": "ぎょ/さかな",

        // 方位 / 大小
        "大": "だい/おお", "小": "しょう/ちい", "中": "ちゅう/なか",
        "上": "じょう/うえ", "下": "か/した", "左": "さ/ひだり", "右": "う/みぎ",
        "前": "ぜん/まえ", "後": "ご/うしろ/あと",
        "外": "がい/そと", "内": "ない/うち",
        "北": "ほく/きた", "南": "なん/みなみ", "東": "とう/ひがし", "西": "せい/にし",
        "白": "はく/しろ", "黒": "こく/くろ", "赤": "せき/あか", "青": "せい/あお",
        "黄": "おう/き", "緑": "りょく/みどり",

        // 时间
        "時": "じ/とき", "分": "ぶん/ぷん/わける", "年": "ねん/とし", "週": "しゅう",
        "今": "いま", "先": "さき/せん", "毎": "まい",
        "来": "らい/くる", "行": "こう/いく/ゆく", "帰": "き/かえる",

        // 动作
        "見": "けん/みる", "聞": "ぶん/きく", "話": "わ/はなす", "言": "げん/いう",
        "読": "どく/よむ", "書": "しょ/かく", "思": "し/おもう",
        "知": "ち/しる",
        "生": "せい/いきる/うまれる/はえる", "死": "し/しぬ",
        "立": "りつ/たつ", "座": "ざ/すわる", "歩": "ほ/あるく", "走": "そう/はしる",
        "出": "しゅつ/でる", "入": "にゅう/はいる",
        "食": "しょく/たべる", "飲": "いん/のむ", "寝": "しん/ねる",
        "起": "き/おきる", "休": "きゅう/やすむ",
        "買": "かい/かう", "売": "ばい/うる",
        "作": "さく/つくる", "使": "し/つかう",
        "持": "じ/もつ", "取": "しゅ/とる", "置": "ち/おく",
        "待": "たい/まつ", "送": "そう/おくる",
        "会": "かい/あう", "合": "ごう/あう/あわせる", "別": "べつ/わかれる",
        "続": "ぞく/つづく", "止": "し/とまる/とめる/やめる",
        "始": "し/はじまる/はじめる", "終": "しゅう/おわる/おえる",
        "開": "かい/ひらく/あく", "閉": "へい/しめる/しまる/とじる",
        "教": "きょう/おしえる", "学": "がく/まなぶ",
        "働": "どう/はたらく", "遊": "ゆう/あそぶ",
        "呼": "こ/よぶ", "答": "とう/こたえる",
        "泣": "なき/なく", "笑": "わら/え/しょう",
        "忘": "ぼう/わすれる", "覚": "かく/おぼえる",
        "信": "しん", "疑": "ぎ/うたがう",
        "祈": "いの/き", "願": "がん/ねがう",

        // 感官/感知
        "音": "おん/おと", "声": "せい/こえ",
        "光": "こう/ひかり", "影": "えい/かげ",
        "色": "いろ/しょく", "形": "かたち/けい",

        // 世界
        "天": "てん", "地": "ち/じ",
        "家": "か/いえ", "室": "しつ/むろ",
        "駅": "えき", "道": "どう/みち", "橋": "きょう/はし",
        "国": "こく/くに", "町": "ちょう/まち", "村": "そん/むら",
        "都": "と/みやこ", "京": "きょう/みやこ",
        "語": "ご/かたる", "文": "ぶん/もん", "字": "じ/あざ",
        "名": "めい/な",

        // 形容
        "高": "こう/たか", "安": "あん/やすい",
        "新": "しん/あたらしい", "古": "こ/ふるい",
        "多": "た/おお", "少": "しょう/すこ/すくない",
        "長": "ちょう/なが", "短": "たん/みじか",
        "良": "りょう/よ", "悪": "あく/わる",
        "正": "せい/ただ", "誤": "ご/あやま",
        "美": "び/うつく", "醜": "しゅう/みにく",
        "明": "めい/あか", "暗": "あん/くら",
        "強": "きょう/つよ", "弱": "じゃく/よわ",
        "寒": "かん/さむ", "暑": "しょ/あつ",
        "楽": "らく/たの", "苦": "く/くる/にが",
        "悲": "ひ/かな", "嬉": "き/うれ",
        "好": "こう/す/この", "嫌": "けん/きら",
        "同": "どう/おな", "違": "い/ちが",
        "早": "そう/はや", "遅": "ち/おく/おそ",
        "近": "きん/ちか", "遠": "えん/とお",
        "広": "こう/ひろ", "狭": "きょう/せま",
        "深": "しん/ふか", "浅": "せん/あさ",
        "太": "たい/ふと", "細": "さい/ほそ",
        "重": "じゅう/おも", "軽": "けい/かる",
        "夢": "む/ゆめ", "現": "げん/あら",
        "愛": "あい", "恋": "こい/こう",

        // 抽象
        "魂": "たましい/こん", "命": "いのち/めい", "幸": "さいわ/しあわ",
        "歌": "うた/か", "詩": "し/うた",
        "絵": "え/かい",

        // 季节 / 时间
        "春": "はる", "夏": "なつ", "秋": "あき", "冬": "ふゆ",
        "朝": "あさ", "昼": "ひる", "晩": "ばん", "夜": "よる",
        "曜": "よう", "末": "まつ/すえ",
        "祭": "まつ/さい", "式": "しき",

        // 其他常用
        "通": "とお/つう/かよ",
        "姿": "すがた/し",
    ]
    return dict
}
