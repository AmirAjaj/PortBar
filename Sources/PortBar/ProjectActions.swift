import AppKit

/// Opening a port's project directory in common dev tools.
enum ProjectActions {
    /// A code editor we know how to open folders in.
    struct Editor: Identifiable {
        let id: String  // bundle identifier
        let name: String
        var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) }
        var isInstalled: Bool { appURL != nil }
    }

    /// Editors we offer, in preference order. Only installed ones are shown.
    static let knownEditors: [Editor] = [
        Editor(id: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
        Editor(id: "com.microsoft.VSCode", name: "Visual Studio Code"),
        Editor(id: "dev.zed.Zed", name: "Zed"),
        Editor(id: "com.sublimetext.4", name: "Sublime Text"),
    ]

    static var installedEditors: [Editor] { knownEditors.filter(\.isInstalled) }

    /// Opens `directory` in the given editor.
    static func open(_ directory: String, in editor: Editor) {
        guard let appURL = editor.appURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: directory)],
            withApplicationAt: appURL,
            configuration: config)
    }

    /// Reveals `directory` in Finder.
    static func revealInFinder(_ directory: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory)
    }

    /// Opens `directory` in the user's terminal (Terminal.app, or iTerm if present).
    static func openInTerminal(_ directory: String) {
        let terminalIDs = ["com.googlecode.iterm2", "com.apple.Terminal"]
        let appURL =
            terminalIDs
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .first
        guard let appURL else { return }
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: directory)],
            withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration())
    }
}
