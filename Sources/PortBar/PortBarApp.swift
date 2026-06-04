import AppKit
import SwiftUI

@main
struct PortBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var scanner = PortScanner()
    @StateObject private var updates = UpdateChecker()
    @StateObject private var keepAwake = KeepAwake()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(scanner: scanner, updates: updates, keepAwake: keepAwake)
        } label: {
            // Plug icon + the live dev-server count, visible without opening the
            // popover. A coffee emoji is prefixed while "keep awake" is on so you
            // don't forget it's draining battery. (Two SF Symbols in one menu-bar
            // Text don't both render, so the cup is a plain emoji.)
            Text(
                "\(keepAwake.isActive ? "☕ " : "")\(Image(systemName: "powerplug.fill")) \(scanner.devPorts.count)"
            )
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
