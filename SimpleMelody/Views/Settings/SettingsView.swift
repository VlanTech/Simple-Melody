// Views/Settings/SettingsView.swift
// 设置面板（v1.3 重构）
// 顶部可扩展内容（主题/语言/备份/删除警告/更新日志）
// 底部固定"关于 Simple Melody"（永远最底，版本号 + 开发者署名 Vlan_Tech）

import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext

    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var appSettings = AppSettings.shared

    @State private var isBackingUp = false
    @State private var apiBaseURL = ""
    @State private var apiModelName = ""
    @State private var apiKeyDraft = ""
    @State private var apiTesting = false
    @State private var apiTestMessage = ""
    private let apiKeyStore = LLMAPIKeyStore()

    /// v1.7.9 GT: 段落拖动开关（默认关闭，开启时弹警告）
    @AppStorage("sectionDragEnabled") private var sectionDragEnabled: Bool = false
    @State private var showDragWarningAlert: Bool = false

    /// v1.4: 用 OpenWindowAction 打开独立 changelog window
    @Environment(\.openWindow) private var openWindow

    @ObservedObject private var updateChecker = UpdateChecker.shared

    /// 当前应用版本号（与 AppReleaseMath.displayVersion 同源）
    private let currentVersion = AppReleaseMath.displayVersion
    private let developerName = "Vlan_Tech"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    // ====== 顶部可扩展内容（未来新功能加在这里） ======

                    // 主题
                    SettingsGroup(title: L("主题"), icon: "paintpalette") {
                        Picker("", selection: Binding(
                            get: { themeManager.theme },
                            set: { themeManager.setTheme($0) }
                        )) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    SettingsGroup(title: L("字体大小"), icon: "textformat.size") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Text(L("较小"))
                                    .appFont(11)
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                                Slider(
                                    value: $appSettings.fontScale,
                                    in: Double(AppFontMetrics.minScale)...Double(AppFontMetrics.maxScale),
                                    step: 0.05
                                )
                                Text(L("较大"))
                                    .appFont(16, weight: .medium)
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            Text("\(Int((appSettings.fontScale * 100).rounded()))%")
                                .appFont(12)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // 界面语言：列表，含跟随系统。不再为每种语言放一颗按钮。
                    SettingsGroup(title: L("界面语言"), icon: "globe") {
                        Picker(L("界面语言"), selection: languageSelection) {
                            Text(L("跟随系统")).tag(LanguagePreference.followSystemToken)
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang.rawValue)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    SettingsGroup(title: L("接入大模型"), icon: "key") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("供以后的注音、翻译等功能使用"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(L("供应商网址"))
                                .appFont(13, weight: .medium)
                            TextField(L("供应商网址"), text: $apiBaseURL)
                                .textFieldStyle(.roundedBorder)
                            Text(L("模型名"))
                                .appFont(13, weight: .medium)
                            TextField(L("模型名"), text: $apiModelName)
                                .textFieldStyle(.roundedBorder)
                            Text(L("模型名可以留空"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(L("API Key"))
                                .appFont(13, weight: .medium)
                            SecureField(L("API Key"), text: $apiKeyDraft)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Button(L("保存")) {
                                    apiKeyStore.save(LLMConnection(
                                        baseURL: apiBaseURL,
                                        modelName: apiModelName,
                                        apiKey: apiKeyDraft
                                    ))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                Button(L("清除")) {
                                    apiKeyStore.clear()
                                    apiBaseURL = ""
                                    apiModelName = ""
                                    apiKeyDraft = ""
                                    apiTestMessage = ""
                                }
                                .controlSize(.small)
                                Button(L("测试连接")) {
                                    let connection = LLMConnection(
                                        baseURL: apiBaseURL,
                                        modelName: apiModelName,
                                        apiKey: apiKeyDraft
                                    )
                                    guard ImagineAPI.chatRequest(connection: connection, system: "ping", user: "ping") != nil else {
                                        apiTestMessage = L("请先填写供应商网址和 API Key")
                                        return
                                    }
                                    apiTesting = true
                                    apiTestMessage = L("正在测试连接")
                                    Task {
                                        let outcome = await ImagineAPI.checkLive(connection)
                                        await MainActor.run {
                                            apiTesting = false
                                            apiTestMessage = outcome == .success ? L("连接成功") : L("连接失败")
                                        }
                                    }
                                }
                                .controlSize(.small)
                                .disabled(apiTesting)
                                Spacer()
                            }
                            if !apiTestMessage.isEmpty {
                                Text(apiTestMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(L("建议选用参数量更大的模型，以便翻译、注音和创作更准确"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // 数据管理
                    SettingsGroup(title: L("数据管理"), icon: "externaldrive") {
                        VStack(alignment: .leading, spacing: 10) {
                            // 一键备份（v1.5：保留文件夹结构）
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("一键备份曲目库"))
                                        .appFont(13, weight: .medium)
                                    Text(L("备份曲目库（含文件夹结构）"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    backupAllSongs()
                                } label: {
                                    if isBackingUp {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 70)
                                    } else {
                                        Label(L("备份"), systemImage: "square.and.arrow.down.on.square")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(isBackingUp)
                            }

                            Divider()

                            // 删除警告开关（v1.4：修复 Toggle 显示错位 — 改为 HStack 显式布局）
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("删除前显示确认弹窗"))
                                        .appFont(13, weight: .medium)
                                        .lineLimit(1)
                                    Text(L("删除歌曲、段落、灵感前提示确认（暂不可恢复）"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                // v1.7.5 Beta: 强制 frame 尺寸 + onAppear 强制 layout（避免 NSSwitch 首次渲染 thumb 不显示）
                                SystemSwitchToggle(isOn: $appSettings.confirmBeforeDelete)
                                    .frame(width: 38, height: 22)
                                    .fixedSize()
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // 技能炼成（v1.7.6 Gamma：词炼成 + 曲炼成的导出入口，位置在帮助上方）

                    // v1.7.9 GT: 段落拖动开关（恢复——开关关闭时启用左滑删除，开启时启用任意位置拖动）
                    SettingsGroup(title: L("段落拖动"), icon: "rectangle.3.group") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L("拖动段落重排"))
                                    .appFont(13, weight: .medium)
                                Text(L("段落拖动开关说明"))
                                    .appFont(11)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            SystemSwitchToggle(isOn: $sectionDragEnabled)
                                .frame(width: 38, height: 22)
                                .fixedSize()
                        }
                    }
                    .onChange(of: sectionDragEnabled) { _, newValue in
                        if newValue {
                            showDragWarningAlert = true
                        }
                    }
                    .alert(L("开启段落拖动功能？"), isPresented: $showDragWarningAlert) {
                        Button(L("取消"), role: .cancel) {
                            sectionDragEnabled = false
                        }
                        Button(L("继续开启")) {
                            // 确认开启：歌词编辑栏已拒绝段落 id 落入正文
                        }
                    } message: {
                        Text(L("段落拖动开关说明"))
                    }

                    SettingsGroup(title: L("技能炼成"), icon: "wand.and.stars") {
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                openWindow(id: "skill-export")
                            } label: {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L("技能炼成"))
                                            .appFont(13, weight: .medium)
                                        Text(L("把 Simple Melody 的歌词 Skill 导出给 AI Agent 用"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .imageScale(.small)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 帮助
                    SettingsGroup(title: L("帮助"), icon: "questionmark.circle") {
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                // v1.4: 改为打开独立 Window（自带标题栏 + cmd+W）
                                openWindow(id: "changelog")
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L("查看更新日志"))
                                            .appFont(13, weight: .medium)
                                        Text(L("查看每个版本的更新内容"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .imageScale(.small)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // v1.7.5 Beta: 使用指南（与更新日志同格式，按语言适配）
                            Button {
                                openWindow(id: "usage")
                            } label: {
                                HStack {
                                    Image(systemName: "book.pages")
                                        .foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L("使用指南"))
                                            .appFont(13, weight: .medium)
                                        Text(L("软件介绍 + 各功能使用说明（随界面语言切换）"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .imageScale(.small)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 歌词预览小字
                    SettingsGroup(title: L("歌词预览"), icon: "text.viewfinder") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("预览段落小字"))
                                .appFont(13, weight: .medium)
                            Text(L("预览段落小字说明"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $appSettings.previewCaptionSource) {
                                Text(L("笔记")).tag(PreviewCaptionSource.notes)
                                Text(L("译文")).tag(PreviewCaptionSource.translation)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }

                    // 下载链接（v1.7.7 Beta：在版本信息上方；v1.8.0：检查更新 + 启动自检）
                    downloadLinkSection

                    // ====== 底部固定"关于"栏目（永远最底） ======
                    aboutSection

                    Spacer(minLength: 8)
                }
                .padding(16)
            }
        }
        .frame(width: RightColumnMetrics.layout(for: .settings).minWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            let saved = apiKeyStore.current()
            apiBaseURL = saved.baseURL
            apiModelName = saved.modelName
            apiKeyDraft = saved.apiKey
        }
    }

    /// 跟随系统时选中「跟随系统」，而不是它此刻解析出的那种语言。
    private var languageSelection: Binding<String> {
        Binding(
            get: {
                loc.followsSystem ? LanguagePreference.followSystemToken : loc.language.rawValue
            },
            set: { raw in
                if raw == LanguagePreference.followSystemToken {
                    loc.setFollowSystem()
                } else if let lang = AppLanguage(rawValue: raw) {
                    loc.setLanguage(lang)
                }
            }
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.fill")
                .appFont(18, weight: .medium)
                .foregroundStyle(.tint)
            Text(L("设置"))
                .appFont(16, weight: .semibold)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        // v1.7.3 Delta: 设置面板内也应用 ThemeManager（之前只在主视图加，这里也加确保设置本身跟随系统设置）
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    // MARK: 下载链接（v1.7.7 Beta：在版本信息上方；v1.8.0：检查更新 + 启动自检）

    /// 下载、检查更新、启动时检查放在同一个二级菜单里，不再占一级分组。
    private var downloadLinkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Menu {
                Button {
                    if let url = URL(string: AppReleaseMath.downloadPageURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(L("下载链接"), systemImage: "arrow.up.right.square")
                }
                Button {
                    updateChecker.checkFromSettings()
                } label: {
                    Label(L("检查版本更新"), systemImage: "arrow.clockwise")
                }
                .disabled(updateChecker.isChecking)
                Toggle(L("启动时检查更新"), isOn: $appSettings.autoCheckUpdates)
            } label: {
                HStack {
                    Image(systemName: "arrow.down.app.fill")
                        .foregroundStyle(.tint)
                    Text(L("下载链接"))
                        .appFont(13, weight: .medium)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            if !updateChecker.statusText.isEmpty {
                Text(updateChecker.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 关于栏目（永远最底，固定位置）

    private var aboutSection: some View {
        VStack(spacing: 10) {
            // Logo + 名字（v1.7.7 Beta：优先用 logo_monogram assetset，失败兜底仍用 music.note 符号）
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: "logo_monogram")
                      ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .shadow(color: .accentColor.opacity(0.2), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Simple Melody")
                        .appFont(16, weight: .bold, design: .rounded)
                    Text("\(currentVersion) · \(L("Apple Silicon 原生"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // 详细信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L("版本"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentVersion)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text(L("开发者"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(developerName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("vlantech@126.com")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text(L("平台"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("macOS 14+ · Apple Silicon")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text(L("界面语言"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(loc.language.displayName)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }

            // 版权
            Text("© 2026 Simple Melody · \(developerName)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - 操作

    /// 一键备份所有歌曲（v1.5：保留文件夹层级）
    private func backupAllSongs() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L("选择这里")
        panel.message = L("选择保存备份的文件夹")
        panel.title = L("备份曲目库")

        panel.begin { response in
            guard response == .OK, let folderURL = panel.url else { return }
            isBackingUp = true

            // 关键：先在主线程 fetch（ModelContext 是 main-actor 绑定的）
            let snapshot = fetchBackupSnapshot()
            let folderPath = folderURL.path

            DispatchQueue.global(qos: .userInitiated).async {
                // 后台只处理纯数据（不访问 modelContext）
                let result = SongExporter.backupLibrary(
                    rootFolders: snapshot.rootFolders,
                    rootSongs: snapshot.rootSongs,
                    to: folderURL
                )
                DispatchQueue.main.async {
                    isBackingUp = false
                    let alert = NSAlert()
                    if result.failed.isEmpty {
                        alert.messageText = L("备份完成")
                        alert.informativeText = L("成功备份 %d 首歌曲到\n%@").localized(with: result.success, folderPath)
                        alert.alertStyle = .informational
                    } else {
                        alert.messageText = L("备份部分失败")
                        alert.informativeText = L("成功 %d 首，失败 %d 首").localized(with: result.success, result.failed.count)
                        alert.alertStyle = .warning
                    }
                    alert.addButton(withTitle: L("确定"))
                    alert.runModal()
                }
            }
        }
    }

    /// 备份快照（主线程 fetch，避免后台访问 ModelContext）
    private func fetchBackupSnapshot() -> SongExporter.LibrarySnapshot {
        let songsDescriptor = FetchDescriptor<Song>(sortBy: [SortDescriptor(\.sortOrder)])
        let allSongs = (try? modelContext.fetch(songsDescriptor)) ?? []
        let foldersDescriptor = FetchDescriptor<SongFolder>(sortBy: [SortDescriptor(\.sortOrder)])
        let allFolders = (try? modelContext.fetch(foldersDescriptor)) ?? []
        let rootFolders = allFolders.filter { !$0.isSystem }
        let rootSongs = allSongs.filter { $0.folder == nil }
        return SongExporter.LibrarySnapshot(rootFolders: rootFolders, rootSongs: rootSongs, allFolders: allFolders, allSongs: allSongs)
    }
}

// MARK: - 设置分组

struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(title)
                    .appFont(12, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

extension AppTheme {
    var displayName: String {
        switch self {
        case .system: return L("跟随系统")
        case .light: return L("浅色")
        case .dark: return L("深色")
        }
    }
}
