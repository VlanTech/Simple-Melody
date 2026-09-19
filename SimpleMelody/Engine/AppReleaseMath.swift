// Engine/AppReleaseMath.swift
// v1.8.0: compare local vs GitHub release tags; parse releases/latest JSON.
// UpdateChecker and tests call these; no live network in this file.

import Foundation

enum AppReleaseMath {
    static let displayVersion = "v1.8.0"
    static let marketingVersion = "1.8.0"
    static let githubLatestURL = "https://api.github.com/repos/VlanTech/Simple-Melody/releases/latest"
    static let downloadPageURL = "https://github.com/VlanTech/Simple-Melody"

    /// Numeric parts of "v1.7.10 Extra" / "1.8.0" / "v1.7.9 GT5" — letter suffixes ignored.
    static func numericComponents(_ raw: String) -> [Int] {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.first == "v" || s.first == "V" {
            s.removeFirst()
        }
        var num = ""
        for ch in s {
            if ch.isNumber || ch == "." {
                num.append(ch)
            } else {
                break
            }
        }
        while num.last == "." { num.removeLast() }
        return num.split(separator: ".").compactMap { Int($0) }
    }

    /// -1 local < remote, 0 equal, 1 local > remote.
    static func compare(local: String, remote: String) -> Int {
        let a = numericComponents(local)
        let b = numericComponents(remote)
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x < y { return -1 }
            if x > y { return 1 }
        }
        return 0
    }

    enum Decision: Equatable {
        case upToDate
        case updateAvailable
        case invalid
    }

    /// Launch popup only when this returns `updateAvailable`.
    static func decision(local: String, remoteTag: String?) -> Decision {
        guard let remote = remoteTag?.trimmingCharacters(in: .whitespacesAndNewlines),
              !remote.isEmpty,
              !numericComponents(remote).isEmpty else {
            return .invalid
        }
        return compare(local: local, remote: remote) < 0 ? .updateAvailable : .upToDate
    }

    struct ReleaseSnapshot: Equatable {
        var tagName: String
        var body: String
        var htmlURL: String
    }

    static func parseGitHubRelease(jsonData: Data) -> ReleaseSnapshot? {
        guard let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let tag = obj["tag_name"] as? String else {
            return nil
        }
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let body = obj["body"] as? String ?? ""
        let url = (obj["html_url"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? downloadPageURL
        return ReleaseSnapshot(tagName: trimmed, body: body, htmlURL: url)
    }

    static func makeLatestRequest(url: URL = URL(string: githubLatestURL)!) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("SimpleMelody/\(marketingVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }
}
