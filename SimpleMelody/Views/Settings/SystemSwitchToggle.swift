// Views/Settings/SystemSwitchToggle.swift
// v1.6.1: macOS 系统原生 NSSwitch 包装
//
// 原因：SwiftUI 的 .toggleStyle(.switch) 在某些 view hierarchy（嵌套 VStack + HStack）里
//       thumb（白色滑块）首次渲染时不会画出，要点击后才出现。改用原生 NSViewRepresentable 包裹
//       NSSwitch 来确保首次渲染稳定。
//
// 关键：NSSwitch 的 thumb 是它自己在 drawRect 画的，需要在 NSSwitch 被加到 view hierarchy 后
//       显式调 layoutSubtreeIfNeeded + display 才能稳定显示。SwiftUI 在 makeNSView 阶段调用的
//       layout pass 不会触发 NSSwitch 的 layout，因此用 DispatchQueue.main.async 在下一轮
//       runloop 强制 layout + display。
//
// v1.7.7 Delta: 之前 v1.7.5 Beta 的修复（强制 frame + sizeThatFits）依然不够，用户反馈
//       "点开设置不显示开关滑块，只有触发设置页面刷新才显示"。这次用 onAppear + 异步 layout
//       兜底，确保 NSSwitch 在 view tree 稳定后立即 layout 一次。

import SwiftUI
import AppKit

struct SystemSwitchToggle: NSViewRepresentable {
    @Binding var isOn: Bool

    func makeNSView(context: Context) -> NSSwitch {
        let sw = NSSwitch()
        sw.target = context.coordinator
        sw.action = #selector(Coordinator.switchChanged(_:))
        sw.state = isOn ? .on : .off
        // 给个默认 frame，下一帧会被 updateNSView 修正
        sw.frame = NSRect(x: 0, y: 0, width: 38, height: 22)
        // 主线程下一轮：NSSwitch 已经被 SwiftUI 加到 view hierarchy 后强制 layout + display
        // 这是修首次 thumb 不显示的关键
        DispatchQueue.main.async {
            sw.frame = NSRect(x: 0, y: 0, width: 38, height: 22)
            sw.layoutSubtreeIfNeeded()
            sw.needsDisplay = true
        }
        return sw
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSwitch, context: Context) -> CGSize? {
        // 显式告诉 SwiftUI NSSwitch 的尺寸（38×22），避免 SwiftUI 用 0×0 layout
        return CGSize(width: 38, height: 22)
    }

    func updateNSView(_ nsView: NSSwitch, context: Context) {
        // 同步外部状态到原生控件
        let targetState: NSControl.StateValue = isOn ? .on : .off
        if nsView.state != targetState {
            nsView.state = targetState
        }
        context.coordinator.parent = self
        // 每次 updateNSView 都强制 frame + layout + display
        // 兜底任何漏过去的 layout 场景
        if abs(nsView.frame.width - 38) > 0.5 || abs(nsView.frame.height - 22) > 0.5 {
            nsView.frame = NSRect(x: 0, y: 0, width: 38, height: 22)
            nsView.layoutSubtreeIfNeeded()
        }
        nsView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: SystemSwitchToggle
        init(parent: SystemSwitchToggle) {
            self.parent = parent
        }

        @objc func switchChanged(_ sender: NSSwitch) {
            parent.isOn = (sender.state == .on)
        }
    }
}
