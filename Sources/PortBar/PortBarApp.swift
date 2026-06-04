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
            // popover. A cup is shown while "keep awake" is on so you don't
            // forget it's draining battery. Embedding symbols in the Text forces
            // them to render (a bare Label collapses to icon-only).
            if keepAwake.isActive {
                Text(
                    "\(Image(systemName: "cup.and.saucer.fill")) \(Image(systemName: "powerplug.fill")) \(scanner.devPorts.count)"
                )
            } else {
                Text("\(Image(systemName: "powerplug.fill")) \(scanner.devPorts.count)")
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
