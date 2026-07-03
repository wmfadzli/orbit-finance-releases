import SwiftUI
import UsageCore

@main
struct TokenScopeApp: App {
    @StateObject private var model = UsageViewModel()

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
