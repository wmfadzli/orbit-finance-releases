import Foundation
import UsageCore

/// Persists the latest `UsageSnapshot` where both the menu-bar app and the
/// widget extension can read it.
///
/// The two targets are separate processes that can't share memory, so the app
/// writes a JSON file into the shared App Group container and the widget reads
/// it back. Keep `appGroupID` in sync with the App Group capability configured
/// on both targets in Xcode (see project.yml / README).
public enum SharedUsageStore {

    /// ⚠️ Must match the App Group entitlement on BOTH targets.
    public static let appGroupID = "group.com.tokenscope.app"

    private static let fileName = "usage-snapshot.json"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Called by the app after each refresh.
    public static func write(_ snapshot: UsageSnapshot) {
        guard let url = fileURL else { return }
        guard let data = try? makeEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    /// Called by the widget timeline provider (and by the app on launch).
    public static func read() -> UsageSnapshot? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? makeDecoder().decode(UsageSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
