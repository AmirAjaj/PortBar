import Combine
import Foundation

/// Finds local Git repositories and publishes their working-tree status.
@MainActor
final class RepoScanner: ObservableObject {
    @Published private(set) var repositories: [GitRepositoryStatus] = []
    @Published private(set) var hiddenRepositoryPaths: Set<String>
    @Published private(set) var isScanning = false

    private let userDefaults: UserDefaults
    private let hiddenRepositoriesKey = "hiddenGitRepositoryPaths"

    var attentionCount: Int {
        repositories.filter(\.needsAttention).count
    }

    var hiddenRepositoryCount: Int {
        hiddenRepositoryPaths.count
    }

    var attentionRepositories: [GitRepositoryStatus] {
        repositories.filter(\.needsAttention)
    }

    var cleanRepositories: [GitRepositoryStatus] {
        repositories.filter { !$0.needsAttention }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hiddenRepositoryPaths = Set(userDefaults.stringArray(forKey: hiddenRepositoriesKey) ?? [])
        Task { await scan() }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        let found = await Task.detached(priority: .utility) {
            RepoScanner.discoverRepositories()
        }.value
        repositories = found.filter { !hiddenRepositoryPaths.contains($0.path) }
        isScanning = false
    }

    func hide(_ repository: GitRepositoryStatus) {
        hiddenRepositoryPaths.insert(repository.path)
        saveHiddenRepositoryPaths()
        repositories.removeAll { $0.path == repository.path }
    }

    func showAllHiddenRepositories() async {
        hiddenRepositoryPaths.removeAll()
        saveHiddenRepositoryPaths()
        await scan()
    }

    nonisolated static func discoverRepositories() -> [GitRepositoryStatus] {
        let paths = findRepositoryPaths(in: defaultRootPaths())
        return paths.compactMap(status(for:)).sorted(by: sortRepositories)
    }

    nonisolated static func status(for path: String) -> GitRepositoryStatus? {
        guard
            let output = Shell.run(
                "/usr/bin/git",
                ["-C", path, "status", "--porcelain=v1", "-b"],
                timeout: 3)
        else {
            return nil
        }

        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let header = lines.first, header.hasPrefix("## ") else { return nil }

        let counts = parseChangeCounts(lines.dropFirst())
        let remote = Shell.run("/usr/bin/git", ["-C", path, "remote", "get-url", "origin"], timeout: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return GitRepositoryStatus(
            path: path,
            name: URL(fileURLWithPath: path).lastPathComponent,
            branch: parseBranch(from: header),
            changedCount: counts.changed,
            untrackedCount: counts.untracked,
            ahead: parseCount(named: "ahead", from: header),
            behind: parseCount(named: "behind", from: header),
            remoteHost: parseRemoteHost(remote)
        )
    }

    nonisolated static func parseBranch(from header: String) -> String {
        let body = header.dropFirst(3)
        let name = body.split(separator: " ", maxSplits: 1).first.map(String.init) ?? String(body)
        if name == "HEAD" || name.contains("no branch") { return "detached" }
        return name.split(separator: "...", maxSplits: 1).first.map(String.init) ?? name
    }

    nonisolated static func parseChangeCounts<S: Sequence>(_ lines: S) -> (changed: Int, untracked: Int)
    where S.Element == String {
        var changed = 0
        var untracked = 0

        for line in lines where line.count >= 2 {
            if line.hasPrefix("??") {
                untracked += 1
            } else {
                changed += 1
            }
        }

        return (changed, untracked)
    }

    nonisolated static func parseRemoteHost(_ remote: String?) -> String? {
        guard let remote, !remote.isEmpty else { return nil }

        if let url = URL(string: remote), let host = url.host {
            return stripWWW(from: host)
        }

        if let at = remote.firstIndex(of: "@"),
            let colon = remote[remote.index(after: at)...].firstIndex(of: ":")
        {
            return stripWWW(from: String(remote[remote.index(after: at)..<colon]))
        }

        return nil
    }

    private nonisolated static func defaultRootPaths() -> [String] {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return [] }
        let names = ["Desktop", "Developer", "Code", "Projects", "Sites"]
        let fileManager = FileManager.default

        return
            names
            .map { URL(fileURLWithPath: home).appendingPathComponent($0).path }
            .filter { path in
                var isDirectory = ObjCBool(false)
                return fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
            }
    }

    private nonisolated static func findRepositoryPaths(in roots: [String]) -> [String] {
        let fileManager = FileManager.default
        var paths = Set<String>()

        for root in roots {
            let rootURL = URL(fileURLWithPath: root).standardizedFileURL
            guard isDirectory(rootURL, fileManager: fileManager) else { continue }

            if isRepository(rootURL, fileManager: fileManager) {
                paths.insert(rootURL.path)
                continue
            }

            guard
                let enumerator = fileManager.enumerator(
                    at: rootURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsPackageDescendants])
            else {
                continue
            }

            for case let url as URL in enumerator {
                guard isDirectory(url, fileManager: fileManager) else { continue }

                let name = url.lastPathComponent
                if shouldSkipDirectory(named: name) || depth(from: rootURL, to: url) > 5 {
                    enumerator.skipDescendants()
                    continue
                }

                if isRepository(url, fileManager: fileManager) {
                    paths.insert(url.standardizedFileURL.path)
                    enumerator.skipDescendants()
                }
            }
        }

        return Array(paths)
    }

    private nonisolated static func isRepository(_ url: URL, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: url.appendingPathComponent(".git").path)
    }

    private nonisolated static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory = ObjCBool(false)
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private nonisolated static func shouldSkipDirectory(named name: String) -> Bool {
        let ignored = [
            ".build", ".cache", ".git", ".swiftpm", "DerivedData", "Library",
            "node_modules", "Pods", "dist",
        ]
        return name.hasPrefix(".") || ignored.contains(name)
    }

    private nonisolated static func depth(from root: URL, to url: URL) -> Int {
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        return max(0, components.count - rootComponents.count)
    }

    private nonisolated static func parseCount(named label: String, from header: String) -> Int {
        guard let range = header.range(of: "\(label) ") else { return 0 }
        let tail = header[range.upperBound...]
        let digits = tail.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    private nonisolated static func stripWWW(from host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private nonisolated static func sortRepositories(
        _ lhs: GitRepositoryStatus, _ rhs: GitRepositoryStatus
    ) -> Bool {
        if lhs.needsAttention != rhs.needsAttention { return lhs.needsAttention }
        if lhs.isDirty != rhs.isDirty { return lhs.isDirty }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func saveHiddenRepositoryPaths() {
        userDefaults.set(Array(hiddenRepositoryPaths).sorted(), forKey: hiddenRepositoriesKey)
    }
}
