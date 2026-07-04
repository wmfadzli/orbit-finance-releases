import SwiftUI
import UsageCore

@main
struct TokenScopeApp: App {
    @StateObject private var model = UsageViewModel()
    // Menu bar shows just the gauge icon by default; opt in to the $ amount.
    @AppStorage("showAmountInMenuBar") private var showAmount = false

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
            // Icon-only by default; show today's spend beside it if enabled.
            if showAmount {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                    Text(model.menuBarTitle)
                }
            } else {
                Image(systemName: "gauge.with.dots.needle.33percent")
            }
        }
        .menuBarExtraStyle(.window) // Rich popover rather than a plain menu.
    }
}
