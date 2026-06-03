import Foundation

/// Sends signals to processes by PID using the C `kill(2)` call.
enum ProcessKiller {
    enum Signal {
        case term // graceful (SIGTERM)
        case kill // forceful (SIGKILL)

        var rawValue: Int32 {
            switch self {
            case .term: return SIGTERM
            case .kill: return SIGKILL
            }
        }
    }

    /// Sends `signal` to `pid`. Returns true on success.
    @discardableResult
    static func send(_ signal: Signal, to pid: Int32) -> Bool {
        kill(pid, signal.rawValue) == 0
    }
}
