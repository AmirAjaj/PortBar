import Foundation
import Testing

@testable import PortBar

struct ListeningPortTests {
    private var home: String { ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory() }

    private func port(command: String = "node", exe: String? = nil, cwd: String? = nil) -> ListeningPort {
        ListeningPort(
            pid: 1234, command: command, port: 3000,
            executablePath: exe, workingDirectory: cwd)
    }

    private func temporaryHomeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: home)
            .appendingPathComponent(".portbar-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func systemPathsAreFlagged() {
        #expect(port(exe: "/usr/libexec/rapportd").isSystem)
        #expect(
            port(exe: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter").isSystem)
        #expect(port(exe: "/usr/sbin/cupsd").isSystem)
    }

    @Test func userAppsAreNotSystem() {
        #expect(!port(exe: "/Applications/Cursor.app/Contents/MacOS/Cursor").isSystem)
        #expect(!port(exe: "/usr/local/bin/ollama").isSystem)  // /usr/local is user-installed
        #expect(!port(exe: nil).isSystem)
    }

    @Test(arguments: ["node", "vite", "python3", "cargo", "bun", "Python"])
    func knownDevCommandsAreDevServers(_ cmd: String) {
        #expect(port(command: cmd, cwd: "/opt/whatever").isDevServer)
    }

    @Test func systemProcessWithDevCommandIsNotDevServer() {
        #expect(!port(command: "node", exe: "/usr/bin/node", cwd: "/").isDevServer)
    }

    @Test func commandPrefixesDoNotOvermatchNonDevTools() {
        #expect(!port(command: "Google", cwd: nil).isDevServer)
        #expect(!port(command: "nginx", cwd: nil).isDevServer)
    }

    @Test func processRunningFromHomeProjectIsDevServer() throws {
        let directory = try temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("package.json").path,
            contents: Data("{}".utf8))

        #expect(port(command: "someserver", cwd: directory.path).isDevServer)
    }

    @Test func processRunningBelowHomeProjectIsDevServer() throws {
        let directory = try temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent(".git"),
            withIntermediateDirectories: true)
        let nestedDirectory = directory.appendingPathComponent("apps/api")
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)

        #expect(port(command: "someserver", cwd: nestedDirectory.path).isDevServer)
    }

    @Test func unknownHomeProcessWithoutProjectMarkerIsNotDevServer() throws {
        let directory = try temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(!port(command: "someserver", cwd: directory.path).isDevServer)
    }

    @Test func homeLibraryProcessIsNotDevServer() {
        #expect(
            !port(command: "someserver", cwd: "\(home)/Library/Application Support/someserver").isDevServer)
    }

    @Test func randomDaemonNotFromHomeIsNotDevServer() {
        #expect(!port(command: "rapportd", cwd: "/").isDevServer)
        #expect(!port(command: "Discord", cwd: nil).isDevServer)
    }

    @Test func projectNameIsLastPathComponent() {
        #expect(port(cwd: "\(home)/code/portbar").projectName == "portbar")
    }

    @Test func projectNameNilForRootOrMissing() {
        #expect(port(cwd: "/").projectName == nil)
        #expect(port(cwd: nil).projectName == nil)
    }

    @Test func localhostURLIsWellFormed() {
        #expect(port().localhostURL?.absoluteString == "http://localhost:3000")
    }
}
