// Views/IdeaPanel/IdeaPanelView.swift
// 灵感与设定分栏（独立于正文，不导出到歌词正文）

import SwiftUI
import SwiftData

struct IdeaPanelView: View {
    @Environment(\.modelContext) private var context
    @Bindable var song: Song

    @State private var ideaTypeFilter: String = "All"
    @State private var newIdeaContent: String = ""
    @State private var newIdeaType: String = "Inspiration"

    var filteredIdeas: [SongIdea] {
        let base = song.orderedIdeas
        if ideaTypeFilter == "All" { return base }
        return base.filter { $0.ideaType == ideaTypeFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            quickAddBar
            Divider()
            if filteredIdeas.isEmpty {
                emptyState
            } else {
                ideaList
            }
        }
        // v1.7.9 Delta+: panel 自身限定最小宽度 320（不被外层 NavigationSplitView 拖窄挤压）
        .frame(minWidth: 320, idealWidth: 380, maxWidth: 500)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(nsImage: NSImage(named: "idea_lightbulb") ?? NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 0) {
                    Text(L("灵感与设定"))
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(song.orderedIdeas.count) \(L("条记录"))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // 类型过滤器（v1.4：chip 锁定 fixedSize 防错位）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    TypeChip(label: L("全部"), symbol: "tray.full", color: .secondary, isOn: ideaTypeFilter == "All") {
                        ideaTypeFilter = "All"
                    }
                    .fixedSize()
                    ForEach(IdeaTypePreset.all) { type in
                        // v1.4: 用 preset.localizedName（key 驱动，自动随界面语言切换）
                        TypeChip(
                            label: type.localizedName,
                            symbol: type.symbol,
                            color: type.color,
                            isOn: ideaTypeFilter == type.name
                        ) {
                            ideaTypeFilter = type.name
                        }
                        .fixedSize()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: 快速添加

    private var quickAddBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            // v1.4: 类型选择按钮带 fixedSize 防止错位
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(IdeaTypePreset.all) { type in
                        Button {
                            newIdeaType = type.name
                        } label: {
                            Label(type.localizedName, systemImage: type.symbol)
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(newIdeaType == type.name
                                              ? type.color.opacity(0.25)
                                              : Color.secondary.opacity(0.08))
                                )
                                .foregroundStyle(newIdeaType == type.name ? type.color : .secondary)
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(L("记录灵感、背景故事、设定..."), text: $newIdeaContent, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit { addIdea() }

                Button {
                    addIdea()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(newIdeaContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: 列表

    private var ideaList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(filteredIdeas) { idea in
                    IdeaCard(idea: idea) {
                        delete(idea)
                    } onTypeChange: { newType in
                        idea.ideaType = newType
                        try? context.save()
                    }
                }
            }
            .padding(14)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(L("还没有灵感或设定"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(L("在这里记录创作灵感、角色设定或背景故事。") + "\n" + L("这些内容不会出现在歌词正文里。"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    // MARK: 操作

    private func addIdea() {
        let trimmed = newIdeaContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let idea = SongIdea(order: song.orderedIdeas.count, content: trimmed, ideaType: newIdeaType)
        idea.song = song
        song.ideas.append(idea)
        song.updatedAt = Date()
        try? context.save()
        newIdeaContent = ""
    }

    private func delete(_ idea: SongIdea) {
        // v1.3：删除前确认
        // v1.4: localizedName 已经是翻译后的字符串（key 驱动），不要再包 L()
        let title = idea.typePreset.localizedName
        let preview = idea.content.prefix(20)
        let message = L("将删除条目") + "「\(preview)」"
        guard DeleteConfirmator.confirm(title: title, message: message) else { return }
        // 重新排序
        for i in song.orderedIdeas where i.order > idea.order {
            i.order -= 1
        }
        context.delete(idea)
        try? context.save()
    }
}

// MARK: - 卡片视图

private struct IdeaCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var idea: SongIdea
    let onDelete: () -> Void
    let onTypeChange: (String) -> Void

    var type: IdeaTypePreset { idea.typePreset }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: type.symbol)
                    .foregroundStyle(type.color)
                    .font(.system(size: 12, weight: .semibold))
                Text(type.localizedName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(type.color)
                Spacer()
                // v1.5: 加大按钮到 28×28，修复错位
                Menu {
                    ForEach(IdeaTypePreset.all) { t in
                        Button {
                            onTypeChange(t.name)
                        } label: {
                            Label(t.localizedName, systemImage: t.symbol)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(L("删除"), systemImage: "trash.fill")
                    }
                    .tint(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28, height: 28)
                .fixedSize()
            }

            // v1.7.9 GT3: 改回 PassthroughScrollTextEditor（NSViewRepresentable NSTextView）
            // 解决：点击空白区域聚焦 + 文字顶格 + 回车换行正常 + 高度随内容自适应
            PassthroughScrollTextEditor(
                text: $idea.content,
                isFocused: .constant(false),
                fontSize: 13,
                minHeight: 30
            )
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.05))
            )

            HStack {
                Text(idea.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.textBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(type.color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Type Chip

private struct TypeChip: View {
    let label: String
    let symbol: String
    let color: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(label)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isOn ? color.opacity(0.25) : Color.secondary.opacity(0.08))
            )
            .foregroundStyle(isOn ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}
