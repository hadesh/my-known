import SwiftUI
import KnowledgeVaultCore

@Observable
final class AppState {
    var selectedTab: Int = 0

    let fileManager: VaultFileManagerImpl
    let llmAgent: LLMAgent
    let ragPipeline: RAGPipeline
    let configStore: LLMConfigStore

    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let vaultURL = documentsURL.appendingPathComponent("KnowledgeVault", isDirectory: true)

        let fm = VaultFileManagerImpl(vaultURL: vaultURL)
        self.fileManager = fm

        let config = LLMConfig()
        let agent = LLMAgent(config: config)
        self.llmAgent = agent

        let store = LLMConfigStore()
        self.configStore = store

        let searchEngine = VaultSearchEngine(fileManager: fm)
        self.ragPipeline = RAGPipeline(searchEngine: searchEngine, llmAgent: agent, fileManager: fm)

        Task { await Self.applyConfigs(store.configs, to: agent) }
    }

    func refreshProviders() {
        Task { await Self.applyConfigs(configStore.configs, to: llmAgent) }
    }

    private static func applyConfigs(_ configs: [SavedLLMConfig], to agent: LLMAgent) async {
        await agent.clearProviders()

        for cfg in configs {
            guard let apiKey = try? KeychainManager.apiKey(for: cfg.id), !apiKey.isEmpty else {
                continue
            }

            switch cfg.provider {
            case "openai":
                let provider = OpenAIProvider(
                    name: cfg.id,
                    apiKey: apiKey,
                    defaultModel: cfg.model
                )
                await agent.registerProvider(provider)

            case "anthropic":
                let provider = AnthropicProvider(
                    name: cfg.id,
                    apiKey: apiKey,
                    defaultModel: cfg.model
                )
                await agent.registerProvider(provider)

            case "qwen":
                let provider = QwenProvider(
                    name: cfg.id,
                    apiKey: apiKey,
                    defaultModel: cfg.model
                )
                await agent.registerProvider(provider)

            case "custom":
                guard !cfg.baseURL.isEmpty,
                      let url = URL(string: cfg.baseURL) else { continue }
                let provider = CustomProvider(
                    name: cfg.id,
                    baseURL: url,
                    apiKey: apiKey,
                    defaultModel: cfg.model
                )
                await agent.registerProvider(provider)

            default:
                break
            }
        }

        if let first = configs.first {
            await agent.setDefaultProvider(first.id)
        }
    }
}

// MARK: - VaultSearchEngine

final class VaultSearchEngine: SearchEngine {
    private let fileManager: VaultFileManagerImpl

    init(fileManager: VaultFileManagerImpl) {
        self.fileManager = fileManager
    }

    func indexFile(_ file: MarkdownFile) async throws {}

    func updateIndex(fileID: String) async throws {}

    func search(query: String, mode: SearchMode, limit: Int) async throws -> [SearchResult] {
        let results = try await fileManager.search(query: query, mode: mode)
        return Array(results.prefix(limit))
    }

    func rebuildIndex() async throws {}
}
