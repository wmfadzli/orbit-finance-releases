import SwiftUI
import UsageCore

struct MenuContentView: View {
    @EnvironmentObject private var model: UsageViewModel
    @AppStorage("dailyBudgetUSD") private var dailyBudget: Double = 0
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if model.snapshot.providers.isEmpty {
                emptyState
            } else {
                ForEach(model.snapshot.providers) { summary in
                    ProviderCard(summary: summary, dailyBudget: dailyBudget)
                }
            }

            if showingSettings {
                Divider()
                settings
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .foregroundStyle(.tint)
            Text("TokenScope")
                .font(.headline)
            Spacer()
            if model.isLoading {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await model.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.lastError ?? "No usage yet")
                .font(.callout.weight(.semibold))
            Text("TokenScope reads local Claude Code logs from ~/.claude/projects. Use Claude Code, then refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Text("Daily budget")
                    .font(.callout)
                Spacer()
                TextField("0", value: $dailyBudget, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
            }
            Text("Set a budget to show a progress meter. 0 hides it.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Picker("Menu bar shows", selection: $model.primaryProvider) {
                ForEach(Provider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var footer: some View {
        HStack {
            if model.snapshot.generatedAt != .distantPast {
                Text("Updated \(model.snapshot.generatedAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                withAnimation { showingSettings.toggle() }
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }
}
