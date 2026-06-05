import Combine
import Foundation

/// Scans for listening TCP ports and publishes the results for the UI.
///
/// Scanning shells out to `lsof` on a background task and the parsed,
/// `Sendable` results are handed back to the main actor for publishing.
@MainActor
final class PortScanner: ObservableObject {
    /// All listening ports discovered on the most recent scan, port-sorted.
    @Published private(set) var ports: [ListeningPort] = []
    /// Set while a scan is in flight (for a subtle UI affordance).
    @Published private(set) var isScanning = false

    private var timer: Timer?

    /// Cached health per port id, so we don't re-probe every scan.
    private var healthCache: [String: PortHealth] = [:]
    private var lastHealthCheck = Date.distantPast
    /// How often to re-probe *existing* servers over HTTP. Decoupled from the
    /// (faster) port scan so we don't spam dev servers' logs every few seconds.
    private let healthInterval: TimeInterval = 30

    /// How often to rescan, in seconds. Restarts the timer when changed.
    var refreshInterval: TimeInterval = 5 {
        didSet { startTimer() }
    }

    /// Ports we consider real dev servers (shown prominently).
    var devPorts: [ListeningPort] { ports.filter(\.isDevServer) }

    /// User-started, non-system listeners that aren't obviously dev servers.
    var otherPorts: [ListeningPort] {
        ports.filter { !$0.isDevServer && !$0.isSystem }
    }

    /// Apple/OS daemons — hidden unless the user opts to show them.
    var systemPorts: [ListeningPort] { ports.filter(\.isSystem) }

    /// Sends SIGTERM to every dev server (and only dev servers), then rescans.
    /// Deliberately scoped to dev servers so this never mass-kills other apps.
    func stopAllDevServers() async {
        let pids = Set(devPorts.map(\.pid))
        for pid in pids { ProcessKiller.send(.term, to: pid) }
        try? await Task.sleep(for: .milliseconds(400))
        await scan()
    }

    init() {
        startTimer()
        Task { await scan() }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.scan() }
        }
    }

    /// Performs one scan: the blocking `lsof`/`ps` work runs off the main
    /// actor, then results are published back here.
    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        let found = await Task.detached(priority: .utility) {
            PortScanner.discoverPorts()
        }.value

        // Re-probe health only periodically; newly seen ports are probed right
        // away so their dot appears promptly.
        let now = Date()
        let fullRefresh = now.timeIntervalSince(lastHealthCheck) >= healthInterval
        let annotated = await PortScanner.annotateHealth(found, cache: healthCache, fullRefresh: fullRefresh)
        if fullRefresh { lastHealthCheck = now }
        healthCache = Dictionary(
            annotated.map { ($0.id, $0.health) }, uniquingKeysWith: { first, _ in first })

        ports = annotated
        isScanning = false
    }

    /// Tags each non-system port with its liveness. Ports are only probed over
    /// HTTP when newly seen (absent from `cache`) or when `fullRefresh` is set;
    /// otherwise the cached value is reused, keeping network noise low.
    nonisolated static func annotateHealth(
        _ ports: [ListeningPort], cache: [String: PortHealth], fullRefresh: Bool
    ) async -> [ListeningPort] {
        let toProbe = ports.filter { !$0.isSystem && (fullRefresh || cache[$0.id] == nil) }
        let probed: [String: PortHealth] = await withTaskGroup(of: (String, PortHealth).self) { group in
            for port in toProbe {
                group.addTask { (port.id, await httpHealth(port: port.port)) }
            }
            var map: [String: PortHealth] = [:]
            for await (id, status) in group { map[id] = status }
            return map
        }
        return ports.map { port in
            var copy = port
            if port.isSystem {
                copy.health = .unknown
            } else {
                copy.health = probed[port.id] ?? cache[port.id] ?? .unknown
            }
            return copy
        }
    }

    /// Sends a quick HTTP HEAD; any HTTP reply (even an error status) means the
    /// server is alive. A timeout/refusal means it's listening but not serving.
    private nonisolated static func httpHealth(port: Int) async -> PortHealth {
        guard let url = URL(string: "http://localhost:\(port)/") else { return .unknown }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 0.7
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.7
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        do {
            let (_, response) = try await session.data(for: request)
            return response is HTTPURLResponse ? .responding : .noResponse
        } catch {
            return .noResponse
        }
    }

    // MARK: - Discovery (runs off the main actor)

    /// Lists listening TCP sockets and enriches each with executable path and
    /// working directory. Pure and `Sendable`-friendly so it can run detached.
    nonisolated static func discoverPorts() -> [ListeningPort] {
        guard
            let output = Shell.run(
                "/usr/sbin/lsof",
                ["-nP", "-iTCP", "-sTCP:LISTEN"])
        else {
            return []
        }

        var seen = Set<String>()
        var result: [ListeningPort] = []
        var exeCache: [Int32: String?] = [:]
        var cwdCache: [Int32: String?] = [:]

        for line in output.split(separator: "\n").dropFirst() {
            guard let parsed = parseLsofLine(line) else { continue }
            let (pid, command, port) = parsed

            let key = "\(pid):\(port)"
            if seen.contains(key) { continue }
            seen.insert(key)

            let exe =
                exeCache[pid]
                ?? {
                    let value = executablePath(for: pid)
                    exeCache[pid] = value
                    return value
                }()
            let cwd =
                cwdCache[pid]
                ?? {
                    let value = workingDirectory(for: pid)
                    cwdCache[pid] = value
                    return value
                }()

            result.append(
                ListeningPort(
                    pid: pid,
                    command: command,
                    port: port,
                    executablePath: exe,
                    workingDirectory: cwd
                ))
        }

        return result.sorted { $0.port < $1.port }
    }

    /// Parses one `lsof` output line into (pid, command, port).
    ///
    /// Columns are: `COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME`, where
    /// NAME looks like `*:3000`, `127.0.0.1:8080`, or `[::1]:5000`. Returns nil
    /// for the header row or anything malformed. Pure, so it's unit-testable.
    nonisolated static func parseLsofLine(_ line: Substring) -> (pid: Int32, command: String, port: Int)? {
        let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard fields.count >= 9, let pid = Int32(fields[1]) else { return nil }
        let command = fields[0]
        // The port is whatever follows the final colon (handles IPv6 brackets).
        guard let portString = fields[8].split(separator: ":").last,
            let port = Int(portString)
        else { return nil }
        return (pid, command, port)
    }

    private nonisolated static func executablePath(for pid: Int32) -> String? {
        Shell.run("/bin/ps", ["-p", "\(pid)", "-o", "comm="], timeout: 2)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private nonisolated static func workingDirectory(for pid: Int32) -> String? {
        // `lsof -Fn` prints field-formatted output; the cwd line starts with "n".
        guard let raw = Shell.run("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"], timeout: 2)
        else {
            return nil
        }
        for line in raw.split(separator: "\n") where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
