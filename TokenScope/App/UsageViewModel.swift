import Foundation
import Combine
import WidgetKit
import UsageCore

/// Owns the current snapshot and keeps it fresh. The menu bar reads
/// `@Published` properties; after every reload it mirrors the snapshot into the
/// shared store and nudges the widget to refresh.
@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    /// Which provider drives the menu-bar title.
    @Published var primaryProvider: Provider = .claude

    private let service: UsageService
    private var timer: Timer?
    private let refreshInterval: TimeInterval

    init(service: UsageService = .standard(), refreshInterval: TimeInterval = 60) {
        self.service = service
        self.refreshInterval = refreshInterval
        // Show the last persisted snapshot instantly on launch, then refresh.
        if let cached = SharedUsageStore.read() {
            self.snapshot = cached
        }
    }

    func start() {
        Task { await reload() }
        let timer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.reload() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Parsing can touch thousands of files, so do it off the main actor and hop
    /// back to publish.
    func reload() async {
        isLoading = true
        defer { isLoading = false }

        let service = self.service
        let fresh = await Task.detached(priority: .utility) {
            service.snapshot()
        }.value

        snapshot = fresh
        lastError = fresh.providers.isEmpty ? "No usage logs found." : nil

        SharedUsageStore.write(fresh)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The compact string shown in the menu bar, e.g. "$125.36".
    var menuBarTitle: String {
        guard let summary = snapshot.summary(for: primaryProvider) else { return "—" }
        return UsageFormatter.cost(summary.today.costUSD)
    }
}
