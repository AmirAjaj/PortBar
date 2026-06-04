import Foundation

/// Keeps the Mac awake — including with the lid closed — so long-running agents
/// (Codex, Claude Code, builds, …) don't get paused by sleep.
///
/// This is backed by `pmset disablesleep`, the only mechanism that defeats
/// *clamshell* (lid-close) sleep. It's a system-wide setting, so:
///   • toggling it needs an admin password,
///   • while on, the Mac won't sleep at all (watch battery + heat in a bag),
///   • it persists until toggled off or the next reboot — so the toggle's
///     initial state is read back from the system, not remembered by the app.
@MainActor
final class KeepAwake: ObservableObject {
    /// Whether all sleep is currently disabled (mirrors the real system state).
    @Published private(set) var isActive: Bool

    init() {
        isActive = KeepAwake.readSystemSleepDisabled()
    }

    func setActive(_ on: Bool) {
        guard on != isActive else { return }
        if KeepAwake.writeSystemSleepDisabled(on) {
            isActive = on
        } else {
            // Admin prompt cancelled or failed — resync to whatever the system says.
            isActive = KeepAwake.readSystemSleepDisabled()
        }
    }

    /// Re-reads the system state (e.g. when the popover opens), in case it was
    /// changed elsewhere or left on from a previous run.
    func refresh() {
        isActive = KeepAwake.readSystemSleepDisabled()
    }

    /// Reads `pmset -g`'s `SleepDisabled` flag. No admin required.
    private static func readSystemSleepDisabled() -> Bool {
        guard let output = Shell.run("/usr/bin/pmset", ["-g"]) else { return false }
        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last == "1"
        }
        return false
    }

    /// Runs `pmset -a disablesleep <0|1>` behind an admin prompt. Returns true
    /// on success (false if the user cancels the authorization dialog).
    private static func writeSystemSleepDisabled(_ disabled: Bool) -> Bool {
        let value = disabled ? "1" : "0"
        let source =
            "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}
