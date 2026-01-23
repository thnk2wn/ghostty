import Foundation

// MARK: - Data Models

struct ProviderDefinition: Codable, Identifiable {
    let id: String
    let displayName: String
    let requiresApiKey: Bool
    let models: [ModelDefinition]
}

struct ModelDefinition: Codable, Identifiable {
    let id: String
    let displayName: String
    let supportsReasoning: Bool
    let reasoningLevels: [String]?
    
    var provider: String = ""
    
    enum CodingKeys: String, CodingKey {
        case id, displayName, supportsReasoning, reasoningLevels
    }
}

struct DefaultModelsFile: Codable {
    let providers: [ProviderDefinition]
}

enum ReasoningLevel: String, CaseIterable, Identifiable {
    case none
    case low
    case medium
    case high
    case xhigh
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .xhigh: return "Extra High"
        }
    }
}

// MARK: - Model Registry

/// Singleton that manages model definitions and user configuration.
/// Loads bundled defaults from DefaultModels.json and merges with user settings.
class ModelRegistry: ObservableObject {
    static let shared = ModelRegistry()
    
    @Published private(set) var providers: [ProviderDefinition] = []
    @Published private(set) var allModels: [ModelDefinition] = []
    
    /// Models enabled for each mode (keyed by mode rawValue)
    @Published var enabledModelsByMode: [String: Set<String>] = [
        "Ask": [],
        "Agent": [],
        "Plan": []
    ]
    
    /// Default model for each mode
    @Published var defaultModelByMode: [String: String] = [
        "Ask": "",
        "Agent": "",
        "Plan": ""
    ]
    
    /// Default reasoning level
    @Published var defaultReasoningLevel: ReasoningLevel = .none
    
    private init() {
        loadDefaultModels()
        loadUserConfig()
    }
    
    // MARK: - Loading
    
    private func loadDefaultModels() {
        guard let url = Bundle.main.url(forResource: "DefaultModels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("ModelRegistry: Failed to load DefaultModels.json from bundle")
            loadFallbackModels()
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode(DefaultModelsFile.self, from: data)
            self.providers = decoded.providers
            
            // Flatten models with provider info
            var models: [ModelDefinition] = []
            for provider in decoded.providers {
                for var model in provider.models {
                    model.provider = provider.id
                    models.append(model)
                }
            }
            self.allModels = models
            
            // Initialize enabled models with all models if not configured
            initializeDefaultsIfNeeded()
            
        } catch {
            print("ModelRegistry: Failed to decode DefaultModels.json: \(error)")
            loadFallbackModels()
        }
    }
    
    /// Fallback models if JSON loading fails
    private func loadFallbackModels() {
        let openai = ProviderDefinition(
            id: "openai",
            displayName: "OpenAI",
            requiresApiKey: true,
            models: [
                ModelDefinition(id: "gpt-5.2", displayName: "GPT-5", supportsReasoning: false, reasoningLevels: nil),
                ModelDefinition(id: "gpt-5-mini", displayName: "GPT-5 mini", supportsReasoning: false, reasoningLevels: nil),
                ModelDefinition(id: "gpt-5-nano", displayName: "GPT-5 nano", supportsReasoning: false, reasoningLevels: nil),
                ModelDefinition(id: "gpt-5.2-codex", displayName: "GPT-5.2 (codex)", supportsReasoning: true, reasoningLevels: ["none", "low", "medium", "high", "xhigh"])
            ]
        )
        
        let anthropic = ProviderDefinition(
            id: "anthropic",
            displayName: "Anthropic",
            requiresApiKey: true,
            models: [
                ModelDefinition(id: "claude-sonnet-4-5", displayName: "Claude Sonnet 4.5", supportsReasoning: false, reasoningLevels: nil),
                ModelDefinition(id: "claude-haiku-4-5", displayName: "Claude Haiku 4.5", supportsReasoning: false, reasoningLevels: nil),
                ModelDefinition(id: "claude-opus-4-5", displayName: "Claude Opus 4.5", supportsReasoning: false, reasoningLevels: nil)
            ]
        )
        
        let ollama = ProviderDefinition(
            id: "ollama",
            displayName: "Ollama",
            requiresApiKey: false,
            models: [
                ModelDefinition(id: "llama3", displayName: "Llama 3", supportsReasoning: false, reasoningLevels: nil),
                ModelDefinition(id: "codellama", displayName: "Code Llama", supportsReasoning: false, reasoningLevels: nil),
                ModelDefinition(id: "mistral", displayName: "Mistral", supportsReasoning: false, reasoningLevels: nil)
            ]
        )
        
        self.providers = [openai, anthropic, ollama]
        
        var models: [ModelDefinition] = []
        for provider in providers {
            for var model in provider.models {
                model.provider = provider.id
                models.append(model)
            }
        }
        self.allModels = models
        
        initializeDefaultsIfNeeded()
    }
    
    private func initializeDefaultsIfNeeded() {
        let allModelIds = Set(allModels.map { $0.id })
        
        for mode in ["Ask", "Agent", "Plan"] {
            if enabledModelsByMode[mode]?.isEmpty ?? true {
                enabledModelsByMode[mode] = allModelIds
            }
            if defaultModelByMode[mode]?.isEmpty ?? true {
                defaultModelByMode[mode] = allModels.first?.id ?? ""
            }
        }
    }
    
    // MARK: - User Config Loading/Saving
    
    func loadUserConfig() {
        // Load enabled models per mode from config
        if let askModels = ConfigFileWriter.readValue(key: "ai-agent-models-ask"), !askModels.isEmpty {
            enabledModelsByMode["Ask"] = Set(askModels.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
        }
        if let agentModels = ConfigFileWriter.readValue(key: "ai-agent-models-agent"), !agentModels.isEmpty {
            enabledModelsByMode["Agent"] = Set(agentModels.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
        }
        if let planModels = ConfigFileWriter.readValue(key: "ai-agent-models-plan"), !planModels.isEmpty {
            enabledModelsByMode["Plan"] = Set(planModels.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
        }
        
        // Load default models per mode
        if let askDefault = ConfigFileWriter.readValue(key: "ai-agent-default-model-ask"), !askDefault.isEmpty {
            defaultModelByMode["Ask"] = askDefault
        }
        if let agentDefault = ConfigFileWriter.readValue(key: "ai-agent-default-model-agent"), !agentDefault.isEmpty {
            defaultModelByMode["Agent"] = agentDefault
        }
        if let planDefault = ConfigFileWriter.readValue(key: "ai-agent-default-model-plan"), !planDefault.isEmpty {
            defaultModelByMode["Plan"] = planDefault
        }
        
        // Load default reasoning level
        if let reasoning = ConfigFileWriter.readValue(key: "ai-agent-default-reasoning"),
           let level = ReasoningLevel(rawValue: reasoning) {
            defaultReasoningLevel = level
        }
    }
    
    func saveUserConfig() {
        // Save enabled models per mode
        let askModels = enabledModelsByMode["Ask"]?.sorted().joined(separator: ",") ?? ""
        let agentModels = enabledModelsByMode["Agent"]?.sorted().joined(separator: ",") ?? ""
        let planModels = enabledModelsByMode["Plan"]?.sorted().joined(separator: ",") ?? ""
        
        ConfigFileWriter.updateValues([
            "ai-agent-models-ask": askModels,
            "ai-agent-models-agent": agentModels,
            "ai-agent-models-plan": planModels,
            "ai-agent-default-model-ask": defaultModelByMode["Ask"] ?? "",
            "ai-agent-default-model-agent": defaultModelByMode["Agent"] ?? "",
            "ai-agent-default-model-plan": defaultModelByMode["Plan"] ?? "",
            "ai-agent-default-reasoning": defaultReasoningLevel.rawValue
        ])
        
        // Post notification
        NotificationCenter.default.post(name: .aiSettingsDidChange, object: nil)
    }
    
    // MARK: - Queries
    
    /// Get models enabled for a specific mode
    func modelsForMode(_ mode: AgentMode) -> [ModelDefinition] {
        let enabledIds = enabledModelsByMode[mode.rawValue] ?? []
        return allModels.filter { enabledIds.contains($0.id) }
    }
    
    /// Get models enabled for a mode that also have valid API keys
    func availableModelsForMode(_ mode: AgentMode) -> [ModelDefinition] {
        return modelsForMode(mode).filter { model in
            let provider = providerFor(model: model.id)
            return AgentConfig.hasValidAPIKey(for: provider)
        }
    }
    
    /// Check if a model is enabled for a mode
    func isModelEnabled(_ modelId: String, forMode mode: AgentMode) -> Bool {
        return enabledModelsByMode[mode.rawValue]?.contains(modelId) ?? false
    }
    
    /// Toggle model enabled state for a mode
    func toggleModel(_ modelId: String, forMode mode: AgentMode) {
        if enabledModelsByMode[mode.rawValue]?.contains(modelId) ?? false {
            enabledModelsByMode[mode.rawValue]?.remove(modelId)
        } else {
            enabledModelsByMode[mode.rawValue]?.insert(modelId)
        }
    }
    
    /// Get provider ID for a model
    func providerFor(model modelId: String) -> String {
        return allModels.first { $0.id == modelId }?.provider ?? "openai"
    }
    
    /// Get model definition by ID
    func model(byId id: String) -> ModelDefinition? {
        return allModels.first { $0.id == id }
    }
    
    /// Get provider definition by ID
    func provider(byId id: String) -> ProviderDefinition? {
        return providers.first { $0.id == id }
    }
    
    /// Get default model for a mode
    func defaultModel(forMode mode: AgentMode) -> String {
        return defaultModelByMode[mode.rawValue] ?? allModels.first?.id ?? ""
    }
    
    /// Set default model for a mode
    func setDefaultModel(_ modelId: String, forMode mode: AgentMode) {
        defaultModelByMode[mode.rawValue] = modelId
    }
}
