// SimpleMelodyApp.swift
// 应用入口
// Created by Mavis for Simple Melody

import SwiftUI
import SwiftData

@main
struct SimpleMelodyApp: App {
    @StateObject private var themeManager = ThemeManager()
    @ObservedObject private var localization = LocalizationManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self,
            SongSection.self,
            PronunciationAnnotation.self,
            SongIdea.self,
            SongFolder.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // v1.5: 启动时确保系统回收站存在
            Self.ensureSystemFolders(in: container)
            return container
        } catch {
            // v1.0 → v1.1 schema 不兼容（language → languagesString），
            // 删除旧 store 后重新创建。用户数据会丢失，但避免崩溃。
            print("⚠️ SwiftData store migration failed: \(error)")
            print("🔄 Removing old store and reinitializing...")
            Self.removeOldStore()
            // 再试一次
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                Self.ensureSystemFolders(in: container)
                return container
            } catch {
                // 还是失败则用内存存储（数据只存在于本次会话）
                print("⚠️ Reinit failed, falling back to memory store: \(error)")
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [memoryConfig])
                } catch {
                    fatalError("SwiftData 容器初始化失败: \(error)")
                }
            }
        }
    }()

    /// 删除旧的 SwiftData store 文件（schema migration 失败时使用）
    private static func removeOldStore() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeURL = appSupport.appendingPathComponent("default.store")
        let filesToRemove = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal"),
        ]
        for url in filesToRemove {
            try? fm.removeItem(at: url)
            print("🗑️ Removed: \(url.lastPathComponent)")
        }
    }

    /// v1.5: 启动时确保系统回收站存在
    private static func ensureSystemFolders(in container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SongFolder>(
            predicate: #Predicate { $0.isSystem == true }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            let trash = SongFolder(
                name: "回收站",
                isSystem: true,
                parent: nil,
                sortOrder: Int.max,
                colorHex: "#E74C3C"
            )
            context.insert(trash)
            try? context.save()
            print("🗑️ Created system Trash folder")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .environment(\.locale, Locale(identifier: localization.language.rawValue))
                .id(localization.language) // 语言变化时重置整个 view 树
                .frame(minWidth: 1280, minHeight: 680)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SongCommands()
        }

        // v1.4: 更新日志独立 Window scene（自带标题栏 + cmd+W 关闭）
        Window("更新日志", id: "changelog") {
            ChangelogWindow()
                .environment(\.locale, Locale(identifier: localization.language.rawValue))
                .id(localization.language)
        }
        .defaultSize(width: 640, height: 560)
        .windowResizability(.contentSize)

        // v1.7.5 Beta: 使用指南独立 Window scene（与更新日志同格式）
        Window("使用指南", id: "usage") {
            UsageGuideWindow()
                .environment(\.locale, Locale(identifier: localization.language.rawValue))
                .id(localization.language)
        }
        .defaultSize(width: 640, height: 560)
        .windowResizability(.contentSize)

        // v1.7.6 Beta: 技能炼成独立 Window（导出词炼成 + 曲炼成 Skill 文件）
        Window("技能炼成", id: "skill-export") {
            SkillExportWindow()
                .environment(\.locale, Locale(identifier: localization.language.rawValue))
                .id(localization.language)
        }
        .defaultSize(width: 800, height: 780)
        .windowResizability(.contentSize)
    }
}

struct SongCommands: Commands {
    @FocusedValue(\.selectedSongID) var selectedSongID

    var body: some Commands {
        // v1.7.5 Gamma: 用 replacing 替换默认 .newItem 组，让 ⌘N 真正接管新建歌曲
        // （之前用 after，新 button 排在系统默认"新建窗口"之后，⌘N 仍触发系统行为）
        CommandGroup(replacing: .newItem) {
            Button(L("新建歌曲")) {
                NotificationCenter.default.post(name: .newSongRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(L("新建段落")) {
                NotificationCenter.default.post(name: .newSectionRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button(L("自动标注日语假名")) {
                NotificationCenter.default.post(name: .autoFuriganaRequested, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            Divider()
            // v1.7.5 Gamma: ⌘D 触发删除多选歌曲
            Button(L("移到回收站")) {
                NotificationCenter.default.post(name: .deleteSelectedSongsRequested, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command])
        }
        CommandGroup(replacing: .help) {
            Button(L("Simple Melody 帮助")) {
                NotificationCenter.default.post(name: .showHelpRequested, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let newSongRequested = Notification.Name("sm.newSongRequested")
    static let newSectionRequested = Notification.Name("sm.newSectionRequested")
    static let autoFuriganaRequested = Notification.Name("sm.autoFuriganaRequested")
    static let showHelpRequested = Notification.Name("sm.showHelpRequested")
    static let deleteSelectedSongsRequested = Notification.Name("sm.deleteSelectedSongsRequested")
}

// FocusedValue 让 command 可以访问当前选中的歌曲
struct SelectedSongIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    var selectedSongID: UUID? {
        get { self[SelectedSongIDKey.self] }
        set { self[SelectedSongIDKey.self] = newValue }
    }
}
