import AppKit
import SwiftUI

@main
struct PortBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var scanner = PortScanner()
    @StateObject private var updates = UpdateChecker()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(scanner: scanner, updates: updates)
        } label: {
            // The menu bar title: a plug icon plus the live dev-server count.
            Label("\(scanner.devPorts.count)", systemImage: "powerplug.fill")
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
