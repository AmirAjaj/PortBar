import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService` for the "Launch at Login" toggle.
///
/// Only works for a properly bundled, signed `.app`. When PortBar is run as a
/// bare executable via `swift run`, toggling is a no-op and `isEnabled`
/// reflects the (unregistered) state gracefully.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("PortBar: failed to update launch-at-login: \(error)")
        }
    }
}
