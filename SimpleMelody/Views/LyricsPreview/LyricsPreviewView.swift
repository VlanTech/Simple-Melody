// Views/LyricsPreview/LyricsPreviewView.swift
// 歌词预览视图（v1.7）
// 设计原则：简洁、像音乐播放器、可滑动、与编辑区域联动

import SwiftUI
import AppKit

struct LyricsPreviewView: View {
    @Bindable var song: Song
    /// 当前激活的段落 ID（从编辑区传过来，高亮用）
    let activeSectionID: UUID?
    /// 用户双击预览里的段落 → 通知编辑区跳转
    let onSelectSection: (UUID) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    songHeader
                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    lyricsBody
                }
                .padding(.bottom, 60)
            }
            // v1.7.9 Delta+: panel 自身限定最小宽度 320（不被外层 NavigationSplitView 拖窄挤压）
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 500)
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: activeSectionID) { _, new in
                guard let id = new else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    // MARK: 歌曲信息头

    private var songHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "正在预览" 状态标签
            HStack(spacing: 5) {
                Image(systemName: "play.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(.tint)
                Text(L("正在预览"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }

            // 曲名
            Text(song.title.isEmpty ? L("未命名歌曲") : song.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // 艺术家
            Text(song.artist.isEmpty ? L("未知艺术家") : song.artist)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    // MARK: 歌词正文

    @ViewBuilder
    private var lyricsBody: some View {
        if song.orderedSections.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text(L("暂无歌词"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(song.orderedSections) { section in
                    sectionView(section)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
        }
    }

    /// 单个段落（高亮 + 双击交互）
    @ViewBuilder
    private func sectionView(_ section: SongSection) -> some View {
        let isActive = (activeSectionID == section.id)

        VStack(alignment: .leading, spacing: 8) {
            // 段落 tag（小号灰字，像音乐 App 的章节标签）
            Text(section.marker)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(ThemeColor.mediumFill)
                )

            // 歌词正文
            if section.body.isEmpty {
                Text("　")
                    .font(.system(size: isActive ? 16 : 14))
                    .foregroundStyle(.secondary)
            } else {
                Text(section.body)
                    .font(.system(size: isActive ? 16 : 14))
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isActive ? Color.accentColor.opacity(0.10) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isActive ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            }

            // 段落笔记（折叠显示在歌词下面）
            if !section.notes.isEmpty {
                Text(section.notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
            }
        }
        .id(section.id)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onSelectSection(section.id)
        }
        .help(L("双击跳转到段落"))
    }
}