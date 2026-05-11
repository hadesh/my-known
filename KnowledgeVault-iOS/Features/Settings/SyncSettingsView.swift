import SwiftUI
import KnowledgeVaultCore

struct SyncSettingsView: View {
    @State private var iCloudEnabled: Bool = false
    @State private var syncStatusText: String = "未启用"
    @State private var isLoading: Bool = false
    
    private let syncManager = SyncManager(
        vaultURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    )
    
    var body: some View {
        Form {
            Section {
                Toggle("启用 iCloud 同步", isOn: $iCloudEnabled)
                    .onChange(of: iCloudEnabled) { _, newValue in
                        Task {
                            await handleSyncToggle(newValue)
                        }
                    }
            }
            
            Section("同步状态") {
                Text(syncStatusText)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Button("立即同步") {
                    Task {
                        await performSync()
                    }
                }
                .disabled(!iCloudEnabled || isLoading)
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("同步设置")
        .onAppear {
            Task {
                await updateSyncStatus()
            }
        }
    }
    
    private func handleSyncToggle(_ enabled: Bool) async {
        isLoading = true
        do {
            if enabled {
                try await syncManager.enableICloud()
            } else {
                try await syncManager.disableICloud()
            }
            await updateSyncStatus()
        } catch {
            syncStatusText = "错误: \(error.localizedDescription)"
            iCloudEnabled = !enabled
        }
        isLoading = false
    }
    
    private func performSync() async {
        isLoading = true
        do {
            try await syncManager.syncNow()
            await updateSyncStatus()
        } catch {
            syncStatusText = "同步失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func updateSyncStatus() async {
        let status = await syncManager.syncStatus()
        switch status {
        case .idle:
            syncStatusText = "空闲"
        case .syncing:
            syncStatusText = "同步中"
        case .error(let error):
            syncStatusText = "错误: \(error.localizedDescription)"
        case .disabled:
            syncStatusText = "未启用"
            iCloudEnabled = false
        }
    }
}