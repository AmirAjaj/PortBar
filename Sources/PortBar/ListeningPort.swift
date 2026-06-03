import Foundation

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
            "/sbin/", "/bin/", "/Library/Apple/"
        ]
        return systemPrefixes.contains { path.hasPrefix($0) }
    }

    /// Heuristic: does this look like a local development server?
    /// Either the command matches a known dev tool, or it's running out of a
    /// real project directory under the user's home folder.
    var isDevServer: Bool {
        let devCommands: Set<String> = [
            "node", "deno", "bun", "next", "vite", "nuxt", "webpack", "esbuild",
            "rollup", "parcel", "ng", "nodemon", "ts-node", "tsx", "pnpm", "yarn",
            "npm", "python", "python3", "uvicorn", "gunicorn", "flask", "ruby",
            "rails", "puma", "php", "java", "gradle", "cargo", "go", "hugo",
            "jekyll", "rustc", "dotnet", "air", "kilo"
        ]
        // lsof truncates long command names (e.g. "Code\x20H"); match on a
        // lowercased prefix so "nodemon"/"node" etc. still register.
        let lower = command.lowercased()
        if devCommands.contains(where: { lower.hasPrefix($0) }) { return true }

        if let wd = workingDirectory,
           wd != "/",
           let home = ProcessInfo.processInfo.environment["HOME"],
           wd.hasPrefix(home + "/") {
            return true
        }
        return false
    }

    /// URL to open this port in a browser.
    var localhostURL: URL? {
        URL(string: "http://localhost:\(port)")
    }
}
