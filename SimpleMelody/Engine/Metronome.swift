// Engine/Metronome.swift
// v1.7.7 Delta: 节拍器（声音 + 视觉闪烁）
//
// 声音设计：
//   - tick.wav（滴/弱拍）= 1500Hz 正弦波 + 1ms 攻击噪声，50ms 指数衰减
//   - tock.wav（答/强拍）= 800Hz 方波 + 1ms 攻击噪声，60ms 指数衰减
//   - 两个 WAV 都是程序生成的（详见 ~/.minimax/skills 里同源方法），加到 app bundle 的 Resources/
//   - 4/4 = 滴滴滴答、3/4 = 滴滴答、2/4 = 滴答、6/8 = 滴滴滴滴滴答
//
// 播放方案（替换之前的 NSSound，因为 NSSound 不支持真正并发）：
//   - ClickPlayerPool 持 N 个 AVAudioPlayer 实例（默认 8）
//   - 每次 play() 拿下一个 player，currentTime = 0 后 play()
//   - AVAudioPlayer 每个实例是独立的 AVAudioPlayerNode，可真正并发
//   - 池大小 8 足够覆盖 BPM 300（每拍 0.2s）以下的连续播放
//
// Timer 调度：
//   - Timer.scheduledTimer 每 60/BPM 秒触发一次 fireBeat
//   - fireBeat 不等前一个音播完，立即用池中下一个 player 触发新声音

import AppKit
import AVFoundation
import SwiftUI
import Combine

// MARK: - 池化播放器

/// 池化的短音播放器：N 个 AVAudioPlayer 实例循环使用
/// 解决单实例 AVAudioPlayer 多次 play() 会被截断的问题
final class ClickPlayerPool {
    private var players: [AVAudioPlayer]
    private var nextIndex: Int = 0
    private let lock = NSLock()

    /// - Parameters:
    ///   - url: WAV 文件 URL
    ///   - count: 池大小（BPM 300 / 拍长 0.2s 下 8 个够用，密度更高可调大）
    init?(url: URL, count: Int = 8) {
        var pool: [AVAudioPlayer] = []
        for _ in 0..<count {
            // 每个实例独立加载
            guard let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.prepareToPlay()  // 预解码，避免 play() 时延迟
            p.volume = 1.0
            pool.append(p)
        }
        guard !pool.isEmpty else { return nil }
        self.players = pool
    }

    /// 播放一次（不等前一个音完成，直接触发新的）
    func play() {
        lock.lock()
        let p = players[nextIndex]
        nextIndex = (nextIndex + 1) % players.count
        lock.unlock()
        // 重新从头播放；如果上一个还没播完会被截断（这是短音，正常）
        p.currentTime = 0
        p.play()
    }
}

// MARK: - 控制器

@MainActor
final class MetronomeController: ObservableObject {
    @Published var isRunning: Bool = false
    /// 0..<beatsPerMeasure，当前拍高亮（用于视觉闪烁）
    @Published var currentBeat: Int = 0

    private var timer: Timer?
    private var bpm: Int = 120
    private var beatsPerMeasure: Int = 4

    // 弱拍（滴）+ 强拍（答）两个池
    private let tickPool: ClickPlayerPool?
    private let tockPool: ClickPlayerPool?

    init() {
        // 从 bundle 加载两个 WAV
        let tickURL = Bundle.main.url(forResource: "tick", withExtension: "wav")
        let tockURL = Bundle.main.url(forResource: "tock", withExtension: "wav")
        self.tickPool = tickURL.flatMap { ClickPlayerPool(url: $0, count: 8) }
        self.tockPool = tockURL.flatMap { ClickPlayerPool(url: $0, count: 8) }
    }

    func update(bpm: Int?, beat: String) {
        let b = max(20, min(bpm ?? 120, 300))
        self.bpm = b
        self.beatsPerMeasure = Self.beatsCount(from: beat)
    }

    /// 从 "4/4" / "3/4" / "6/8" 等解析每小节拍数
    static func beatsCount(from beat: String) -> Int {
        let trimmed = beat.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: "/")
        guard parts.count == 2, let n = Int(parts[0]) else { return 4 }
        return max(1, min(n, 12))
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentBeat = 0
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
    }

    private func scheduleTimer() {
        let interval = 60.0 / Double(bpm)
        // 启动时立即响一次，给用户即时反馈
        fireBeat()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fireBeat()
            }
        }
    }

    private func fireBeat() {
        // 强拍 = 每小节最后一拍（index == beatsPerMeasure - 1）
        // 4/4 = 滴滴滴答、3/4 = 滴滴答、2/4 = 滴答、6/8 = 滴滴滴滴滴答
        let isAccent = (currentBeat == beatsPerMeasure - 1)
        let pool = isAccent ? tockPool : tickPool
        pool?.play()  // 池中下一个 player 立即播放（不等前一个完成）
        // 更新 currentBeat 让视觉高亮跟随
        currentBeat = (currentBeat + 1) % beatsPerMeasure
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - SwiftUI 视图

struct MetronomeView: View {
    @ObservedObject var controller: MetronomeController
    let bpm: Int?
    let beat: String

    /// 视觉闪烁的"亮"状态：每拍 currentBeat 变化瞬间变亮，0.10s 回落
    @State private var flashOn: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // 闪烁指示圆点：外圈光环 + 内圈实心
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .scaleEffect(flashOn && controller.isRunning ? 2.4 : 1.0)
                    .opacity(flashOn && controller.isRunning ? 0.0 : 0.0)
                    .animation(.easeOut(duration: 0.30), value: flashOn)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .scaleEffect(flashOn && controller.isRunning ? 1.7 : (controller.isRunning ? 1.0 : 0.6))
                    .opacity(flashOn && controller.isRunning ? 1.0 : (controller.isRunning ? 0.7 : 0.3))
                    .animation(.easeOut(duration: 0.10), value: flashOn)
            }
            .frame(width: 24, height: 24)
            .onChange(of: controller.currentBeat) { _, _ in
                guard controller.isRunning else { return }
                // 每拍 currentBeat 变时触发一次闪烁
                flashOn = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    flashOn = false
                }
            }

            // 启动 / 停止按钮
            Button {
                controller.update(bpm: bpm, beat: beat)
                controller.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                        .imageScale(.small)
                    Text(controller.isRunning ? L("停止") : L("节拍器"))
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(controller.isRunning
                              ? Color.red.opacity(0.15)
                              : Color.accentColor.opacity(0.12))
                )
                .foregroundStyle(controller.isRunning ? Color.red : Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(controller.isRunning ? L("停止节拍器") : L("启动节拍器"))
        }
    }
}
