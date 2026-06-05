import AppKit

/// Relaunches PortBar: starts a fresh instance, then quits the current one.
enum AppRelauncher {
    static func restart() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { app, error in
            if let error {
                NSLog("PortBar: failed to restart: \(error)")
                return
            }
            guard app != nil else {
                NSLog("PortBar: failed to restart: no running application returned")
                return
            }
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}
