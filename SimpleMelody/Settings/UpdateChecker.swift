// Settings/UpdateChecker.swift
// v1.8.0: GitHub releases/latest fetch. Launch is silent unless remote is newer.

import Foundation
import AppKit

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var isChecking = false
    @Published var statusText = ""

    private var launchCheckStarted = false

    func checkOnLaunch() {
        guard AppSettings.shared.autoCheckUpdates else { return }
        guard !launchCheckStarted else { return }
        launchCheckStarted = true
        runCheck(presentIfNewer: true, announceUpToDate: false, announceFailure: false)
    }

    func checkFromSettings() {
        runCheck(presentIfNewer: true, announceUpToDate: true, announceFailure: true)
    }

    private func runCheck(presentIfNewer: Bool, announceUpToDate: Bool, announceFailure: Bool) {
        isChecking = true
        statusText = L("正在检查更新")
        let request = AppReleaseMath.makeLatestRequest()
        let local = AppReleaseMath.displayVersion
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let snapshot = data.flatMap { AppReleaseMath.parseGitHubRelease(jsonData: $0) }
            let decision = AppReleaseMath.decision(local: local, remoteTag: snapshot?.tagName)
            DispatchQueue.main.async {
                self.isChecking = false
                switch decision {
                case .updateAvailable:
                    self.statusText = L("发现新版本") + " " + (snapshot?.tagName ?? "")
                    if presentIfNewer, let snapshot {
                        self.presentUpdateAlert(snapshot)
                    }
                case .upToDate:
                    self.statusText = announceUpToDate ? L("已是最新版本") : ""
                case .invalid:
                    self.statusText = announceFailure ? L("检查更新失败") : ""
                }
            }
        }.resume()
    }

    private func presentUpdateAlert(_ snapshot: AppReleaseMath.ReleaseSnapshot) {
        let alert = NSAlert()
        alert.messageText = L("发现新版本") + " " + snapshot.tagName
        let notes = snapshot.body.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = notes.isEmpty ? snapshot.tagName : String(notes.prefix(4000))
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("前往下载"))
        alert.addButton(withTitle: L("稍后"))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let url = URL(string: snapshot.htmlURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
