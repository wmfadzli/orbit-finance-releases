import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService` for "launch at login".
///
/// On macOS 13+ the app registers itself as a login item — no separate helper
/// bundle needed. Registration sticks best when the app is signed and living in
/// /Applications (the installer copies it there); an ad-hoc-signed local build
/// still works for the current user.
enum LoginItem {

    /// Whether TokenScope is currently set to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Turn launch-at-login on or off. Returns the resulting state; on failure
    /// it logs and returns the unchanged current state so the UI can resync.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("TokenScope: could not \(enabled ? "enable" : "disable") launch-at-login: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
