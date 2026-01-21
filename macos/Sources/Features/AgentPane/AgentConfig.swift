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

    static let `default` = AgentConfig(
        provider: "openai",
        model: "gpt-4o",
        mode: .ask,
        streamResponses: true,
        temperature: 0.7,
        autoExecuteCommands: false,
        maxOutputTokens: 2048,
        useRichOverlays: true,
        ollamaUrl: "http://localhost:11434"
    )

    /// Load configuration from Ghostty config file.
    /// Falls back to defaults if config is not available.
    static func load(from ghosttyConfig: Ghostty.Config? = nil) -> AgentConfig {
        // Use provided config or try to get from app delegate
        let config = ghosttyConfig

        // Get provider from config, but fall back if that provider has no API key
        let configProvider = config?.aiAgentProvider ?? "openai"
        let provider = hasValidAPIKey(for: configProvider) ? configProvider : defaultProvider()

        // Use config model if set, otherwise default for the chosen provider
        let configModel = config?.aiAgentModel
        let model: String
        if let m = configModel, !m.isEmpty, providerForModel(m) == provider {
            model = m
        } else {
            model = defaultModel(for: provider)
        }

        let modeString = config?.aiAgentMode ?? "ask"
        let mode = AgentMode(rawValue: modeString.capitalized) ?? .ask
        let temperature = Double(config?.aiAgentTemperature ?? 0.7)
        let maxTokens = Int(config?.aiAgentMaxTokens ?? 2048)
        let ollamaUrl = config?.aiAgentOllamaUrl ?? "http://localhost:11434"

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
            ollamaUrl: ollamaUrl
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

    /// Determine provider for a given model name.
    private static func providerForModel(_ model: String) -> String {
        if model.contains("claude") {
            return "anthropic"
        } else if model.contains("llama") || model.contains("mistral") || model.contains("codellama") || model.contains("mixtral") {
            return "ollama"
        }
        return "openai"
    }

    private static func defaultModel(for provider: String) -> String {
        switch provider {
        case "anthropic": return "claude-3-5-sonnet-latest"
        case "ollama": return "llama3"
        default: return "gpt-4o"
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
        var models: [ModelInfo] = []

        let hasOpenAI = hasValidAPIKey(for: "openai")
        let hasAnthropic = hasValidAPIKey(for: "anthropic")
        let hasOllama = true // Ollama doesn't require API key

        // OpenAI models
        for model in ["gpt-4o", "gpt-4o-mini", "o1-preview", "o1-mini"] {
            models.append(ModelInfo(
                id: model,
                provider: "openai",
                displayName: model,
                isAvailable: hasOpenAI
            ))
        }

        // Anthropic models
        for model in ["claude-3-5-sonnet-latest", "claude-3-opus-latest", "claude-3-haiku-latest"] {
            models.append(ModelInfo(
                id: model,
                provider: "anthropic",
                displayName: model,
                isAvailable: hasAnthropic
            ))
        }

        // Ollama models
        for model in ["llama3", "codellama", "mistral"] {
            models.append(ModelInfo(
                id: model,
                provider: "ollama",
                displayName: model,
                isAvailable: hasOllama
            ))
        }

        return models
    }

    /// Returns only the models that are available (have valid API keys).
    static func availableModels() -> [String] {
        return allModels().filter { $0.isAvailable }.map { $0.id }
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

        self.selectedModel = config.model
        self.mode = config.mode
        self.useRichOverlays = config.useRichOverlays
    }

    func saveConfig() {
        // Only save UI preferences to UserDefaults
        // Model/provider changes go through AISettingsView -> config file
        UserDefaults.standard.set(useRichOverlays, forKey: "agentUseRichOverlays")
    }
}
