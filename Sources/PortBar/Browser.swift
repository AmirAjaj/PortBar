import AppKit

/// Helpers for the user's default web browser.
///
/// We read the *installed* browser's own icon at runtime (Chrome, Safari, Arc,
/// …) rather than bundling a brand logo — that keeps the "open in browser"
/// button instantly recognizable without shipping trademarked artwork.
enum Browser {
    /// Icon of the default browser, resolved and cached once.
    static let defaultIcon: NSImage? = {
        guard let probe = URL(string: "https://example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }()
}
