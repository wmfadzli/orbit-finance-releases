import SwiftUI
import UsageCore

@main
struct TokenScopeApp: App {
    @StateObject private var model = UsageViewModel()

    init() {
        // On first launch, opt into launch-at-login by default (users generally
        // want a menu-bar utility to come back after a reboot). The Settings
        // toggle lets them turn it off; we only auto-enable once.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "didConfigureLoginItem") {
            LoginItem.setEnabled(true)
            defaults.set(true, forKey: "didConfigureLoginItem")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
                .onAppear { model.start() }
        } label: {
            // Menu-bar label: a small gauge glyph plus today's spend.
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                Text(model.menuBarTitle)
            }
        }
        .menuBarExtraStyle(.window) // Rich popover rather than a plain menu.
    }
}
