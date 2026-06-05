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

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        guard isEnabled != enabled else { return enabled }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("PortBar: failed to update launch-at-login: \(error)")
        }
        return isEnabled
    }
}
