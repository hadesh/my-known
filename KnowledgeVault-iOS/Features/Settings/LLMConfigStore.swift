import Foundation
import Observation

struct SavedLLMConfig: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var provider: String
    var model: String
    var baseURL: String

    init(id: String = UUID().uuidString, name: String, provider: String, model: String, baseURL: String = "") {
        self.id = id
        self.name = name
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
    }
}

@Observable
final class LLMConfigStore {
    private(set) var configs: [SavedLLMConfig] = []

    private let defaultsKey = "saved_llm_configs"

    init() {
        load()
    }

    func save(_ config: SavedLLMConfig) {
        if let idx = configs.firstIndex(where: { $0.id == config.id }) {
            configs[idx] = config
        } else {
            configs.append(config)
        }
        persist()
    }

    func delete(_ config: SavedLLMConfig) {
        configs.removeAll { $0.id == config.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([SavedLLMConfig].self, from: data) else { return }
        configs = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
