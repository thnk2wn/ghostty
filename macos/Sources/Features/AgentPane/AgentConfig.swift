import Foundation
#if os(macOS)
import AppKit
#endif

/// Configuration for the AI agent, loaded from Ghostty config file and Keychain.
/// This replaces the old UserDefaults-based configuration.
struct AgentConfig {
    var provider: String
    var model: String
    var mode: AgentMode
    var streamResponses: Bool
    var temperature: Double
    var autoExecuteCommands: Bool
    var maxOutputTokens: Int
    var useRichOverlays: Bool
    var ollamaUrl: String
    var reasoningLevel: ReasoningLevel

    static let `default` = AgentConfig(
        provider: "openai",
        model: "gpt-5.2",
        mode: .ask,
        streamResponses: true,
        temperature: 0.7,
        autoExecuteCommands: false,
        maxOutputTokens: 2048,
        useRichOverlays: true,
        ollamaUrl: "http://localhost:11434",
        reasoningLevel: .none
    )

    /// Load configuration from Ghostty config file.
    /// Falls back to defaults if config is not available.
    static func load(from ghosttyConfig: Ghostty.Config? = nil) -> AgentConfig {
        let config = ghosttyConfig

        // Get default mode
        let modeString = config?.aiAgentMode ?? "ask"
        let mode = AgentMode(rawValue: modeString.capitalized) ?? .ask

        // Get model for the current mode from ModelRegistry
        let registry = ModelRegistry.shared
        let defaultModelForMode = registry.defaultModel(forMode: mode)

        // Use config model if set, otherwise use mode-specific default
        let configModel = config?.aiAgentModel
        let model: String
        if let m = configModel, !m.isEmpty {
            model = m
        } else {
            model = defaultModelForMode
        }

        // Determine provider from model
        let provider = providerForModel(model)

        let temperature = Double(config?.aiAgentTemperature ?? 0.7)
        let maxTokens = Int(config?.aiAgentMaxTokens ?? 2048)
        let ollamaUrl = config?.aiAgentOllamaUrl ?? "http://localhost:11434"

        // Load reasoning level
        let reasoningLevel = registry.defaultReasoningLevel

        // useRichOverlays is still stored in UserDefaults as it's a UI preference
        let useRichOverlays = UserDefaults.standard.object(forKey: "agentUseRichOverlays") as? Bool ?? true

        return AgentConfig(
            provider: provider,
            model: model,
            mode: mode,
            streamResponses: true,
            temperature: temperature,
            autoExecuteCommands: false,
            maxOutputTokens: maxTokens,
            useRichOverlays: useRichOverlays,
            ollamaUrl: ollamaUrl,
            reasoningLevel: reasoningLevel
        )
    }

    /// Pick a default provider based on which API keys are available.
    /// Falls back to Ollama if no keys are configured.
    private static func defaultProvider() -> String {
        if hasValidAPIKey(for: "openai") {
            return "openai"
        } else if hasValidAPIKey(for: "anthropic") {
            return "anthropic"
        }
        return "ollama"
    }

    /// Determine provider for a given model name using ModelRegistry.
    static func providerForModel(_ model: String) -> String {
        // First check ModelRegistry
        if let modelDef = ModelRegistry.shared.model(byId: model) {
            return modelDef.provider
        }
        // Fallback to string matching for custom models
        if model.contains("claude") {
            return "anthropic"
        } else if model.contains("llama") || model.contains("mistral") || model.contains("codellama") || model.contains("mixtral") {
            return "ollama"
        }
        return "openai"
    }

    /// Get default model for a mode from ModelRegistry
    static func defaultModel(forMode mode: AgentMode) -> String {
        return ModelRegistry.shared.defaultModel(forMode: mode)
    }

    /// Get default model for a provider (legacy fallback)
    private static func defaultModel(for provider: String) -> String {
        switch provider {
        case "anthropic": return "claude-sonnet-4-5"
        case "ollama": return "llama3"
        default: return "gpt-5.2"
        }
    }

    /// Save UI-only preferences to UserDefaults.
    /// Model/provider changes should go through AISettingsView which writes to config file.
    func saveUIPreferences() {
        UserDefaults.standard.set(useRichOverlays, forKey: "agentUseRichOverlays")
    }

    /// Check if a valid API key exists for the given provider.
    /// This does NOT access keychain to avoid prompts.
    /// This does NOT check env vars - those are unreliable (don't work from Finder).
    /// Only checks persistent storage (Keychain cache flag, config file).
    static func hasValidAPIKey(for provider: String) -> Bool {
        // Ollama doesn't require an API key
        if provider == "ollama" {
            return true
        }

        // Check if we've cached that this provider has a key configured (via Keychain)
        let cacheKey = "aiKeyConfigured_\(provider)"
        if UserDefaults.standard.bool(forKey: cacheKey) {
            return true
        }

        // Check config file (no keychain access)
        if let key = ConfigFileWriter.readValue(key: "ai-agent-api-key"), !key.isEmpty {
            return true
        }

        // NOTE: We intentionally don't check env vars here because they don't work
        // when app is launched from Finder/Spotlight. We want the banner to show
        // so users import their keys to Keychain.

        return false
    }

    /// Get the API key for a provider. This WILL access keychain.
    /// Only call this when actually making an API request.
    /// Resolution order: Keychain -> Config file
    static func getAPIKey(for provider: String) -> String? {
        // Ollama doesn't require an API key
        if provider == "ollama" {
            return ""
        }

        let keychainAccount = provider.lowercased()

        // 1. Check Keychain first (most secure, works from Finder)
        if let key = KeychainHelper.load(account: keychainAccount), !key.isEmpty {
            // Cache that we have a key for this provider
            UserDefaults.standard.set(true, forKey: "aiKeyConfigured_\(provider)")
            return key
        }

        // 2. Check config file (for users who want text-based config)
        if let key = ConfigFileWriter.readValue(key: "ai-agent-api-key"), !key.isEmpty {
            return key
        }

        return nil
    }

    /// Mark that a provider has been configured (call after saving to keychain)
    static func markProviderConfigured(_ provider: String) {
        UserDefaults.standard.set(true, forKey: "aiKeyConfigured_\(provider)")
    }

    /// Clear the configured cache for a provider (call after deleting from keychain)
    static func markProviderUnconfigured(_ provider: String) {
        UserDefaults.standard.removeObject(forKey: "aiKeyConfigured_\(provider)")
    }

    /// Check if the current provider has a valid API key configured.
    func hasValidAPIKey() -> Bool {
        return AgentConfig.hasValidAPIKey(for: provider)
    }

    /// Returns all known models, with availability status based on API key presence.
    static func allModels() -> [ModelInfo] {
        let registry = ModelRegistry.shared
        return registry.allModels.map { model in
            ModelInfo(
                id: model.id,
                provider: model.provider,
                displayName: model.displayName,
                isAvailable: hasValidAPIKey(for: model.provider),
                supportsReasoning: model.supportsReasoning
            )
        }
    }

    /// Returns only the models that are available (have valid API keys).
    static func availableModels() -> [String] {
        return allModels().filter { $0.isAvailable }.map { $0.id }
    }

    /// Returns models available for a specific mode (enabled and have API keys).
    static func availableModels(forMode mode: AgentMode) -> [ModelInfo] {
        let registry = ModelRegistry.shared
        return registry.availableModelsForMode(mode).map { model in
            ModelInfo(
                id: model.id,
                provider: model.provider,
                displayName: model.displayName,
                isAvailable: true,
                supportsReasoning: model.supportsReasoning
            )
        }
    }

    /// Returns true if user has configured AI settings (any provider).
    /// Does NOT access keychain to avoid prompts.
    static func hasAnyAPIKeyConfigured() -> Bool {
        // Check if user has completed initial AI setup
        if UserDefaults.standard.bool(forKey: "aiSetupCompleted") {
            return true
        }

        // Check if any provider has a key configured
        return hasValidAPIKey(for: "openai") ||
               hasValidAPIKey(for: "anthropic")
    }

    /// Mark that user has completed AI setup (call after saving settings)
    static func markSetupCompleted() {
        UserDefaults.standard.set(true, forKey: "aiSetupCompleted")
    }

    /// Clear the setup completed flag (for testing)
    static func clearSetupCompleted() {
        UserDefaults.standard.removeObject(forKey: "aiSetupCompleted")
    }
}

/// Information about a model including availability status.
struct ModelInfo: Identifiable {
    let id: String
    let provider: String
    let displayName: String
    let isAvailable: Bool
    var supportsReasoning: Bool = false
}

// MARK: - AgentPaneViewModel Extension

extension AgentPaneViewModel {
    func loadConfig() {
        // Try to get Ghostty config from app delegate
        #if os(macOS)
        let ghosttyConfig = (NSApplication.shared.delegate as? AppDelegate)?.ghostty.config
        let config = AgentConfig.load(from: ghosttyConfig)
        #else
        let config = AgentConfig.load()
        #endif

        self.mode = config.mode
        self.useRichOverlays = config.useRichOverlays
        self.reasoningLevel = config.reasoningLevel

        // Get available models for current mode (must have API key)
        let availableForMode = AgentConfig.availableModels(forMode: self.mode)

        // Try to use mode default if available, otherwise first available model
        let registry = ModelRegistry.shared
        let modeDefault = registry.defaultModel(forMode: self.mode)

        if !modeDefault.isEmpty && availableForMode.contains(where: { $0.id == modeDefault }) {
            self.selectedModel = modeDefault
        } else if let firstAvailable = availableForMode.first {
            self.selectedModel = firstAvailable.id
        } else {
            // No models available - use Ollama as fallback (doesn't need API key)
            self.selectedModel = "llama3"
        }
    }

    func saveConfig() {
        // Only save UI preferences to UserDefaults
        // Model/provider changes go through AISettingsView -> config file
        UserDefaults.standard.set(useRichOverlays, forKey: "agentUseRichOverlays")
    }

    /// Update model selection when mode changes
    func updateModelForMode() {
        let availableForMode = AgentConfig.availableModels(forMode: self.mode)

        // If current model is not available for this mode, switch to mode's default or first available
        if !availableForMode.contains(where: { $0.id == selectedModel }) {
            let registry = ModelRegistry.shared
            let defaultForMode = registry.defaultModel(forMode: self.mode)

            if !defaultForMode.isEmpty && availableForMode.contains(where: { $0.id == defaultForMode }) {
                selectedModel = defaultForMode
            } else if let firstAvailable = availableForMode.first {
                selectedModel = firstAvailable.id
            }
        }
    }
}
