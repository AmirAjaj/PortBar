import AppKit
import SwiftUI

@main
struct PortBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var scanner = PortScanner()
    @StateObject private var repoScanner = RepoScanner()
    @StateObject private var updates = UpdateChecker()
    @StateObject private var keepAwake = KeepAwake()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                scanner: scanner, repoScanner: repoScanner, updates: updates, keepAwake: keepAwake)
        } label: {
            HStack(spacing: 4) {
                if keepAwake.isActive {
                    Text("☕")
                }
                Image(systemName: "powerplug.fill")
                Text("\(scanner.devPorts.count)")
                if repoScanner.attentionCount > 0 {
                    Text("·")
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(repoScanner.attentionCount)")
                }
            }
        }
        .menuBarExtraStyle(.window)  // richer popover UI with scrolling + buttons
    }
}

/// Hides the Dock icon so PortBar lives purely in the menu bar, even when run
/// as a bare executable (an Info.plist `LSUIElement` handles the bundled case).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
