import SwiftUI
import KnowledgeVaultCore

struct LLMConfigView: View {
    @Environment(\.dismiss) private var dismiss

    var store: LLMConfigStore
    var editing: SavedLLMConfig?
    var onSave: (() -> Void)? = nil

    @State private var name: String = ""
    @State private var provider: String = "openai"
    @State private var model: String = ""
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var showSuccessAlert = false
    @State private var errorMessage: String? = nil

    private let providers = ["openai", "qwen", "anthropic", "custom"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("配置名称（如：工作用 GPT-4o）", text: $name)
                    .autocorrectionDisabled()
                Picker("Provider", selection: $provider) {
                    ForEach(providers, id: \.self) { p in
                        Text(p.capitalized).tag(p)
                    }
                }
                .onChange(of: provider) { _, newProvider in
                    if model.isEmpty { model = defaultModel(for: newProvider) }
                }
                TextField("模型名称（如：gpt-4o）", text: $model)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
            }

            Section("认证") {
                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                if provider == "custom" {
                    TextField("Base URL", text: $baseURL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
            }

            if let msg = errorMessage {
                Section {
                    Text(msg)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button("保存") {
                    saveConfig()
                }
                .disabled(!isFormValid)
            }
        }
        .navigationTitle(editing == nil ? "新建配置" : "编辑配置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("保存成功", isPresented: $showSuccessAlert) {
            Button("确定", role: .cancel) { dismiss() }
        }
        .onAppear {
            if let cfg = editing {
                name = cfg.name
                provider = cfg.provider
                model = cfg.model
                baseURL = cfg.baseURL
                apiKey = (try? KeychainManager.apiKey(for: cfg.id)) ?? ""
            } else {
                model = defaultModel(for: provider)
            }
        }
    }

    private func saveConfig() {
        let id = editing?.id ?? UUID().uuidString
        let cfg = SavedLLMConfig(id: id, name: name, provider: provider, model: model, baseURL: baseURL)
        do {
            try KeychainManager.saveAPIKey(for: id, key: apiKey)
            store.save(cfg)
            onSave?()
            errorMessage = nil
            showSuccessAlert = true
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func defaultModel(for provider: String) -> String {
        switch provider {
        case "openai": return "gpt-4o"
        case "qwen": return "qwen-plus"
        case "anthropic": return "claude-3-5-sonnet-latest"
        default: return ""
        }
    }
}
