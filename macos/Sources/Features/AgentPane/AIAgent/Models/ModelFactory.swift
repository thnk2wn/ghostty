import Foundation

/// Factory for creating AI models based on configuration
public enum ModelFactory {
    
    /// Known model IDs and their providers
    public static let knownModels: [(id: String, provider: String, displayName: String)] = [
        // OpenAI
        ("gpt-4o", "openai", "GPT-4o"),
        ("gpt-4o-mini", "openai", "GPT-4o Mini"),
        ("gpt-4-turbo", "openai", "GPT-4 Turbo"),
        ("o1", "openai", "o1"),
        ("o1-mini", "openai", "o1 Mini"),
        ("o3-mini", "openai", "o3 Mini"),
        
        // Anthropic
        ("claude-sonnet-4-20250514", "anthropic", "Claude Sonnet 4"),
        ("claude-3-5-sonnet-20241022", "anthropic", "Claude 3.5 Sonnet"),
        ("claude-3-5-haiku-20241022", "anthropic", "Claude 3.5 Haiku"),
        ("claude-3-opus-20240229", "anthropic", "Claude 3 Opus"),
    ]
    
    /// Create a model from a model ID and API key
    public static func create(
        modelId: String,
        apiKey: String,
        baseURL: URL? = nil
    ) -> AIAgentModel? {
        let provider = providerForModel(modelId)
        
        switch provider {
        case "openai":
            if let url = baseURL {
                return OpenAIModel(modelId: modelId, apiKey: apiKey, baseURL: url)
            }
            return OpenAIModel(modelId: modelId, apiKey: apiKey)
            
        case "anthropic":
            if let url = baseURL {
                return AnthropicModel(modelId: modelId, apiKey: apiKey, baseURL: url)
            }
            return AnthropicModel(modelId: modelId, apiKey: apiKey)
            
        default:
            return nil
        }
    }
    
    /// Get the provider for a model ID
    public static func providerForModel(_ modelId: String) -> String {
        // Check known models first
        if let known = knownModels.first(where: { $0.id == modelId }) {
            return known.provider
        }
        
        // Fallback to string matching
        if modelId.contains("claude") {
            return "anthropic"
        }
        if modelId.contains("gpt") || modelId.starts(with: "o1") || modelId.starts(with: "o3") {
            return "openai"
        }
        
        // Default to OpenAI for unknown models (allows custom deployments)
        return "openai"
    }
    
    /// Get display name for a model ID
    public static func displayName(for modelId: String) -> String {
        if let known = knownModels.first(where: { $0.id == modelId }) {
            return known.displayName
        }
        return modelId
    }
    
    /// Get all available models for a provider
    public static func models(for provider: String) -> [(id: String, displayName: String)] {
        knownModels
            .filter { $0.provider == provider }
            .map { ($0.id, $0.displayName) }
    }
}
