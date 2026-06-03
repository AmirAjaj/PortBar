import Foundation

/// Checks GitHub Releases for a newer version and exposes the result to the UI.
///
/// This is a lightweight nudge, not a silent updater: when a newer release
/// exists we surface a "download" link. Real in-place updates would need
/// Sparkle plus a notarized, Developer ID–signed build.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var latestVersion: String?
    @Published private(set) var updateAvailable = false

    /// Where the "download" button sends people.
    let releasesURL = URL(string: "https://github.com/AmirAjaj/PortBar/releases/latest")!

    private let apiURL = URL(string: "https://api.github.com/repos/AmirAjaj/PortBar/releases/latest")!

    /// The running app's version, from its bundle (falls back to the last
    /// shipped version when run unbundled via `swift run`).
    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    init() {
        Task { await check() }
    }

    func check() async {
        guard let tag = await fetchLatestTag() else { return }
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        latestVersion = latest
        updateAvailable = Self.isNewer(latest, than: currentVersion)
    }

    private nonisolated func fetchLatestTag() async -> String? {
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 5
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["tag_name"] as? String
        } catch {
            return nil
        }
    }

    /// Compares dot-separated version strings numerically (e.g. "0.10.0" > "0.9.0").
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
