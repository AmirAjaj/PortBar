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

    @Test func processRunningFromHomeIsDevServer() {
        #expect(port(command: "someserver", cwd: "\(home)/projects/my-app").isDevServer)
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
