import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+). Registers the running app
/// bundle as a login item; requires a stable location + valid signature.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("ClipStack: failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}
