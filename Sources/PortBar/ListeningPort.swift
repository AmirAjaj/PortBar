import Foundation

/// Result of probing a port over HTTP.
enum PortHealth: Sendable {
    case unknown  // not yet checked
    case responding  // answered an HTTP request
    case noResponse  // socket is open but didn't answer in time (hung / non-HTTP)
}

/// A single listening TCP port together with the process that owns it.
struct ListeningPort: Identifiable, Hashable, Sendable {
    let pid: Int32
    let command: String
    let port: Int
    /// Absolute path to the owning process's executable, when resolvable.
    let executablePath: String?
    /// The process's current working directory — our best hint for *which*
    /// project a dev server belongs to.
    let workingDirectory: String?
    /// Liveness as of the last scan (set asynchronously after discovery).
    var health: PortHealth = .unknown

    /// Stable identity for SwiftUI diffing: a process can listen on several
    /// ports, so we key on both.
    var id: String { "\(pid):\(port)" }

    /// Last path component of the working directory, e.g. `my-app`.
    var projectName: String? {
        guard let wd = workingDirectory, wd != "/" else { return nil }
        let name = URL(fileURLWithPath: wd).lastPathComponent
        return name.isEmpty ? nil : name
    }

    /// True for Apple/OS daemons that live in protected system locations.
    /// These are hidden by default — users don't start them and shouldn't kill them.
    var isSystem: Bool {
        guard let path = executablePath else { return false }
        let systemPrefixes = [
            "/System/", "/usr/bin/", "/usr/sbin/", "/usr/libexec/",
            "/sbin/", "/bin/", "/Library/Apple/",
        ]
        return systemPrefixes.contains { path.hasPrefix($0) }
    }

    /// Heuristic: does this look like a local development server?
    /// Either the command matches a known dev tool, or it's running out of a
    /// real project directory under the user's home folder.
    var isDevServer: Bool {
        if isSystem { return false }
        if Self.isKnownDevCommand(command) { return true }

        guard let wd = workingDirectory else { return false }
        return Self.looksLikeProjectDirectory(wd)
    }

    private static let exactDevCommands: Set<String> = [
        "node", "nodejs", "deno", "bun", "next", "vite", "nuxt", "webpack", "esbuild",
        "rollup", "parcel", "ng", "nodemon", "ts-node", "tsx", "pnpm", "yarn",
        "npm", "python", "python3", "uvicorn", "gunicorn", "flask", "ruby",
        "rails", "puma", "php", "java", "gradle", "cargo", "go", "hugo",
        "jekyll", "rustc", "dotnet", "air", "kilo",
    ]

    private static let prefixedDevCommandRoots: Set<String> = [
        "node", "python", "python3", "ruby", "php", "java", "gradle", "cargo",
        "dotnet", "bun", "deno", "npm", "pnpm", "yarn", "webpack", "uvicorn",
        "gunicorn", "flask", "rails",
    ]

    private static let projectMarkerNames: Set<String> = [
        ".git", "package.json", "pnpm-workspace.yaml", "deno.json", "deno.jsonc",
        "bun.lock", "bun.lockb", "vite.config.js", "vite.config.ts", "next.config.js",
        "next.config.mjs", "nuxt.config.ts", "pyproject.toml", "requirements.txt",
        "Pipfile", "poetry.lock", "uv.lock", "Gemfile", "Cargo.toml", "go.mod",
        "composer.json", "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle",
        "Package.swift",
    ]

    private static let excludedHomeChildren: Set<String> = [
        "Applications", "Library", ".Trash",
    ]

    private static func isKnownDevCommand(_ command: String) -> Bool {
        let lower = command.lowercased()
        if exactDevCommands.contains(lower) { return true }

        return prefixedDevCommandRoots.contains { root in
            lower.hasPrefix(root + "-") || lower.hasPrefix(root + ".") || lower.hasPrefix(root + "_")
        }
    }

    private static func looksLikeProjectDirectory(_ path: String) -> Bool {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return false }

        let directory = URL(fileURLWithPath: path).standardizedFileURL
        let homeDirectory = URL(fileURLWithPath: home).standardizedFileURL
        let directoryPath = directory.path
        let homePath = homeDirectory.path

        guard directoryPath.hasPrefix(homePath + "/") else { return false }

        let relativePath = String(directoryPath.dropFirst(homePath.count + 1))
        guard let firstComponent = relativePath.split(separator: "/").first.map(String.init),
            !excludedHomeChildren.contains(firstComponent)
        else {
            return false
        }

        return containsProjectMarker(startingAt: directory, stopAt: homeDirectory)
    }

    private static func containsProjectMarker(startingAt directory: URL, stopAt homeDirectory: URL) -> Bool {
        let fileManager = FileManager.default
        let homePath = homeDirectory.path
        var current = directory

        while current.path != homePath && current.path.hasPrefix(homePath + "/") {
            for marker in projectMarkerNames {
                if fileManager.fileExists(atPath: current.appendingPathComponent(marker).path) {
                    return true
                }
            }
            current.deleteLastPathComponent()
        }

        return false
    }

    /// URL to open this port in a browser.
    var localhostURL: URL? {
        URL(string: "http://localhost:\(port)")
    }
}
