// Settings/SkillExportView.swift
// v1.7.6 Beta: 技能炼成窗口
// 展示两个 Skill（词炼成 + 曲炼成），提供"导出"按钮让用户保存为 SKILL.md
// 类似 ChangelogView 的窗口格式 + 醒目血红色警示

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 独立 Window

struct SkillExportWindow: View {
    var body: some View {
        SkillExportView()
            .frame(minWidth: 720, idealWidth: 800, maxWidth: 920,
                   minHeight: 720, idealHeight: 780, maxHeight: 900)
    }
}

// MARK: - 视图本体

struct SkillExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var loc = LocalizationManager.shared

    // 导出状态
    @State private var lastExportMessage: String = ""
    @State private var lastExportIsSuccess: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 血红色警示区
                    warningSection
                    // 介绍区
                    introSection
                    // 两个 Skill 卡片
                    skillCard(
                        icon: "doc.text.fill",
                        name: L("词炼成"),
                        skillId: "smelody-lyric-create",
                        description: L("把创作需求 → 完整的 .smelody.txt（可导入 Simple Melody）"),
                        triggerWords: L("\"做词炼成\" / \"按 smelody 格式写歌词\" / \"写一首 Simple Melody 格式的歌词\""),
                        output: L("词炼成：AI 输出完整 .smelody.txt")
                    )
                    skillCard(
                        icon: "music.note",
                        name: L("曲炼成"),
                        skillId: "smelody-music-create",
                        description: L("把 .smelody.txt → 作曲 AI 输入（SUNO / Udio）"),
                        triggerWords: L("\"做曲炼成\" / \"准备 SUNO 提示词\" / \"整理歌词给 AI 作曲\""),
                        output: L("曲炼成：AI 输出两段式（歌词 + 作曲建议）")
                    )
                    // 完整工作流
                    workflowSection
                    // 状态提示
                    if !lastExportMessage.isEmpty {
                        statusMessage
                    }
                }
                .padding(20)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }

    // MARK: 顶部 Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
            Text(L("技能炼成"))
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
                        .fill(Color.primary.opacity(0.08))
                )
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    // MARK: 血红色警示区

    private var warningSection: some View {
        VStack(spacing: 6) {
            // 第一段：Skill 需要移交给拥有 Agent 能力的智能体
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(L("Skill 需要移交给拥有 Agent 能力的智能体"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.red)
            }
            // 第二段：↑ 如果您无法理解以上内容请不要使用该功能 ↑
            Text("↑ " + L("如果您无法理解以上内容请不要使用该功能") + " ↑")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.red.opacity(0.6), lineWidth: 1.5)
        )
    }

    // MARK: 介绍区

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.tint)
                Text(L("Skill 简介"))
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(L("词炼成是把创作需求转化为可导入 Simple Melody 的 .smelody.txt 歌词文件。"))
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Text(L("曲炼成是把 .smelody.txt 提炼为作曲 AI（SUNO / Udio 等）可直接使用的两段式文件。"))
                .font(.system(size: 12))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: Skill 卡片

    @ViewBuilder
    private func skillCard(icon: String, name: String, skillId: String, description: String, triggerWords: String, output: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 卡片头
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .bold))
                    Text(skillId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // 导出按钮
                Button {
                    exportSkill(skillId: skillId)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.small)
                        Text(L("导出"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .help(L("保存为") + " " + skillId + ".md")
            }
            // 描述
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            // 触发词
            HStack(alignment: .top, spacing: 4) {
                Text(L("触发词："))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(triggerWords)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            // 输出
            HStack(alignment: .top, spacing: 4) {
                Text(L("输出") + "：")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(output)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: 完整工作流

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.tint)
                Text(L("完整工作流（推荐）"))
                    .font(.system(size: 13, weight: .semibold))
            }
            // 三步工作流
            VStack(alignment: .leading, spacing: 8) {
                workflowStep(num: "1", title: L("第一步：做词炼成"), body: L("描述歌曲主题、风格、参考等"))
                workflowStep(num: "2", title: L("第二步：做曲炼成"), body: L("把 .smelody.txt 歌词文件发给 AI Agent"))
                workflowStep(num: "3", title: L("第三步：交给 AI Agent 作曲"), body: L("把创作需求发给 AI Agent（如有 SUNO/Udio 工具）"))
            }
            // 接力步骤
            VStack(alignment: .leading, spacing: 4) {
                workflowSubStep(L("把完整歌词文件保存为 .smelody.txt"))
                workflowSubStep(L("在 Simple Melody 中导入"))
                workflowSubStep(L("AI 提炼出两段式输出文件"))
                workflowSubStep(L("上半部分歌词粘贴到 SUNO / Udio 的 Lyrics 输入框"))
                workflowSubStep(L("下半部分作曲建议作为 Style prompt 的一部分"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    @ViewBuilder
    private func workflowStep(num: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func workflowSubStep(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 12)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
        }
        .padding(.leading, 28)
    }

    // MARK: 状态消息

    private var statusMessage: some View {
        HStack(spacing: 6) {
            Image(systemName: lastExportIsSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(lastExportIsSuccess ? .green : .red)
            Text(lastExportMessage)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((lastExportIsSuccess ? Color.green : Color.red).opacity(0.10))
        )
    }

    // MARK: 导出逻辑

    private func exportSkill(skillId: String) {
        let panel = NSOpenPanel()
        panel.title = L("选择保存位置")
        panel.prompt = L("保存")
        panel.message = L("Skill 文件夹父目录")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        let response = panel.runModal()
        guard response == .OK, let parentURL = panel.url else {
            return
        }

        // 在选中的目录下建 skillId 子目录
        let folderURL = parentURL.appendingPathComponent(skillId, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        } catch {
            // 如果已存在,FileManager 会抛错; 这种情况不算致命,继续写文件
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir) || !isDir.boolValue {
                showStatus(L("保存失败") + "：" + error.localizedDescription, success: false)
                return
            }
        }

        // 目标文件: folderURL/SKILL.md
        let fileURL = folderURL.appendingPathComponent("SKILL.md")

        // 从 Bundle 读 SKILL
        let bundleURL: URL?
        if let u = Bundle.main.url(forResource: skillId, withExtension: "SKILL") {
            bundleURL = u
        } else if let u = Bundle.main.url(forResource: skillId, withExtension: "md") {
            bundleURL = u
        } else {
            bundleURL = nil
        }
        guard let src = bundleURL else {
            showStatus(L("保存失败") + L("：找不到 SKILL.md 资源"), success: false)
            return
        }

        do {
            let data = try Data(contentsOf: src)
            try data.write(to: fileURL)
            showStatus(L("保存成功") + "：" + fileURL.path, success: true)
        } catch {
            showStatus(L("保存失败") + "：" + error.localizedDescription, success: false)
        }
    }

    private func showStatus(_ message: String, success: Bool) {
        lastExportMessage = message
        lastExportIsSuccess = success
        // 3 秒后清除
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if lastExportMessage == message {
                lastExportMessage = ""
            }
        }
    }
}