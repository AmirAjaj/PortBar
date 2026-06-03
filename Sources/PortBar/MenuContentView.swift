import SwiftUI

/// The popover shown when the user clicks the menu bar item.
struct MenuContentView: View {
    @ObservedObject var scanner: PortScanner

    @AppStorage("refreshInterval") private var refreshInterval: Double = 5
    @AppStorage("showSystemPorts") private var showSystemPorts: Bool = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    /// Natural height of the scrollable list, measured so the popover sizes to
    /// its content (a bare ScrollView collapses to zero height in a window-style
    /// MenuBarExtra).
    @State private var listContentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    section(title: "Dev servers",
                            ports: scanner.devPorts,
                            emptyMessage: "No dev servers listening")

                    if !scanner.otherPorts.isEmpty {
                        section(title: "Other listeners", ports: scanner.otherPorts)
                    }

                    if showSystemPorts && !scanner.systemPorts.isEmpty {
                        section(title: "System", ports: scanner.systemPorts)
                    }
                }
                .padding(.vertical, 6)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self,
                                               value: geo.size.height)
                    }
                )
            }
            // Size to content, but never thinner than one row or taller than 360pt.
            .frame(height: min(max(listContentHeight, 48), 360))
            .onPreferenceChange(ContentHeightKey.self) { listContentHeight = $0 }

            Divider()
            footer
        }
        .frame(width: 340)
        .onAppear { scanner.refreshInterval = refreshInterval }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "powerplug.fill")
                .foregroundStyle(.tint)
            Text("PortBar").font(.headline)
            Spacer()
            if scanner.isScanning {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await scanner.scan() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Rescan now")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(title: String, ports: [ListeningPort], emptyMessage: String? = nil) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 6)

        if ports.isEmpty, let emptyMessage {
            Text(emptyMessage)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        } else {
            ForEach(ports) { port in
                PortRowView(port: port) { signal in
                    ProcessKiller.send(signal, to: port.pid)
                    // Give the process a moment to release the port, then refresh.
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        await scanner.scan()
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Refresh")
                Spacer()
                Picker("", selection: $refreshInterval) {
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                    Text("30s").tag(30.0)
                }
                .labelsHidden()
                .frame(width: 70)
                .onChange(of: refreshInterval) { _, newValue in
                    scanner.refreshInterval = newValue
                }
            }

            Toggle("Show system listeners", isOn: $showSystemPorts)
                .toggleStyle(.switch)
                .controlSize(.mini)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.set(newValue)
                }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit PortBar")
                    Spacer()
                }
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Carries the measured natural height of the list up to the parent.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// A single row: port, process, project, and hover actions.
private struct PortRowView: View {
    let port: ListeningPort
    let onKill: (ProcessKiller.Signal) -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    // `verbatim:` avoids SwiftUI localizing the port into a
                    // grouped number (e.g. "56.068" in German locales).
                    Text(verbatim: String(port.port))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    Text(port.command).foregroundStyle(.secondary).lineLimit(1)
                }
                if let project = port.projectName {
                    Text(project).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }

            Spacer()

            // Quick actions, always visible (dimmed until hover) for
            // discoverability. The right-click menu below names each one in
            // full, since hover tooltips are unreliable in a menu-bar popover.
            HStack(spacing: 4) {
                if port.localhostURL != nil {
                    actionButton("safari", help: "Open in browser") { openInBrowser() }
                }
                actionButton("stop.circle", help: "Stop (graceful)") { onKill(.term) }
                actionButton("xmark.octagon.fill", help: "Force quit", tint: .red) { onKill(.kill) }
            }
            .opacity(hovering ? 1 : 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(hovering ? Color.primary.opacity(0.06) : .clear)
        .onHover { hovering = $0 }
        .contextMenu {
            if port.localhostURL != nil {
                Button { openInBrowser() } label: {
                    Text(verbatim: "Open localhost:\(port.port) in Browser")
                }
            }
            Button { onKill(.term) } label: {
                Text(verbatim: "Stop server (graceful — lets it shut down cleanly)")
            }
            Button(role: .destructive) { onKill(.kill) } label: {
                Text(verbatim: "Force quit (kill instantly — only if Stop fails)")
            }
            Divider()
            if let wd = port.workingDirectory, wd != "/" {
                Button { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: wd) } label: {
                    Text(verbatim: "Reveal project in Finder")
                }
            }
            Text(verbatim: "PID \(port.pid) · \(port.command)")
        }
    }

    private func openInBrowser() {
        if let url = port.localhostURL { NSWorkspace.shared.open(url) }
    }

    private func actionButton(_ symbol: String, help: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(tint ?? .secondary)
        .help(help)
    }
}
