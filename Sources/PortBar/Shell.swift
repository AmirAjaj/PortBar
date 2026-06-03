import Foundation

/// Minimal helper for running command-line tools and capturing their output.
///
/// PortBar leans on `lsof` and `ps` rather than private APIs, which keeps the
/// app dependency-free and easy to reason about.
enum Shell {
    /// Runs an executable with the given arguments and returns its stdout as a
    /// trimmed string. Returns `nil` if the process can't be launched.
    ///
    /// This blocks the calling thread, so callers should invoke it off the main
    /// actor (see `PortScanner.scan()`).
    static func run(_ launchPath: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()  // swallow stderr so it doesn't spam the console

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
