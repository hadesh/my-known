import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddConfig = false

    private var store: LLMConfigStore { appState.configStore }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                llmSection
                syncSection
                aboutSection
            }
            .navigationTitle("设置")
            .navigationDestination(isPresented: $showAddConfig) {
                LLMConfigView(store: store, onSave: { appState.refreshProviders() })
            }
        }
    }

    private var llmSection: some View {
        Section {
            if store.configs.isEmpty {
                Text("暂无配置")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.configs) { cfg in
                    NavigationLink {
                        LLMConfigView(store: store, editing: cfg, onSave: { appState.refreshProviders() })
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cfg.name)
                                .font(.body)
                            Text("\(cfg.provider.capitalized) · \(cfg.model)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { store.configs[$0] }.forEach { store.delete($0) }
                    appState.refreshProviders()
                }
            }

            Button {
                showAddConfig = true
            } label: {
                Label("添加配置", systemImage: "plus.circle")
            }
        } header: {
            Text("LLM 配置")
        }
    }

    private var syncSection: some View {
        Section("同步设置") {
            NavigationLink("同步配置") {
                SyncSettingsView()
            }
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
