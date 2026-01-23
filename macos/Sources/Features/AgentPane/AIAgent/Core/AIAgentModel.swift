import Foundation

/// Protocol for AI language models that can be used with AIAgent
public protocol AIAgentModel: Sendable {
    /// The model identifier (e.g., "gpt-4o", "claude-sonnet-4-20250514")
    var modelId: String { get }
    
    /// Provider name (e.g., "openai", "anthropic")
    var provider: String { get }
    
    /// Human-readable description
    var displayName: String { get }
    
    /// Run a prompt with optional tools and structured output
    /// - Parameters:
    ///   - prompt: The user prompt
    ///   - systemPrompt: Optional system instructions
    ///   - tools: Tool definitions the model can call
    ///   - outputSchema: JSON schema for structured output
    ///   - temperature: Creativity level (0.0-1.0)
    ///   - maxTokens: Maximum tokens in response
    ///   - streamHandler: Optional handler for streaming tokens
    /// - Returns: Array of outputs (text, function calls, etc.)
    func run(
        prompt: String,
        systemPrompt: String?,
        tools: [AIToolDefinition]?,
        outputSchema: String?,
        temperature: Float?,
        maxTokens: Int?,
        streamHandler: ((String) -> Void)?
    ) async throws -> [AIAgentOutput]
}

// MARK: - Default Implementations

extension AIAgentModel {
    public func run(
        prompt: String,
        systemPrompt: String? = nil,
        tools: [AIToolDefinition]? = nil,
        temperature: Float? = nil,
        streamHandler: ((String) -> Void)? = nil
    ) async throws -> [AIAgentOutput] {
        try await run(
            prompt: prompt,
            systemPrompt: systemPrompt,
            tools: tools,
            outputSchema: nil,
            temperature: temperature,
            maxTokens: nil,
            streamHandler: streamHandler
        )
    }
}

// MARK: - Tool Definition

/// Definition of a tool that an AI model can call
public struct AIToolDefinition: Sendable, Codable {
    public let name: String
    public let description: String
    public let parameters: ParameterSchema
    
    public init(name: String, description: String, parameters: ParameterSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
    
    public struct ParameterSchema: Sendable, Codable {
        public let type: String
        public let properties: [String: PropertySchema]
        public let required: [String]
        
        public init(
            type: String = "object",
            properties: [String: PropertySchema] = [:],
            required: [String] = []
        ) {
            self.type = type
            self.properties = properties
            self.required = required
        }
    }
    
    public struct PropertySchema: Sendable, Codable {
        public let type: String
        public let description: String?
        public let enumValues: [String]?
        
        public init(type: String, description: String? = nil, enumValues: [String]? = nil) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case description
            case enumValues = "enum"
        }
    }
    
    /// Convert to JSON dictionary for API calls
    public var jsonDict: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "description": description
        ]
        
        var paramsDict: [String: Any] = [
            "type": parameters.type,
            "required": parameters.required
        ]
        
        var propsDict: [String: Any] = [:]
        for (key, prop) in parameters.properties {
            var propDict: [String: Any] = ["type": prop.type]
            if let desc = prop.description {
                propDict["description"] = desc
            }
            if let enumVals = prop.enumValues {
                propDict["enum"] = enumVals
            }
            propsDict[key] = propDict
        }
        paramsDict["properties"] = propsDict
        
        dict["parameters"] = paramsDict
        return dict
    }
}

// MARK: - Model Errors

public enum AIModelError: Error, LocalizedError {
    case missingAPIKey(provider: String)
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case rateLimited(retryAfter: TimeInterval?)
    case contextLengthExceeded
    case networkError(Error)
    case streamingError(String)
    case unsupportedFeature(String)
    case timeout
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider). Configure it in AI Settings."
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited. Retry after \(Int(retry)) seconds."
            }
            return "Rate limited. Please try again later."
        case .contextLengthExceeded:
            return "Message too long for model context window"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .unsupportedFeature(let feature):
            return "Unsupported feature: \(feature)"
        case .timeout:
            return "Request timed out. The AI service may be slow or unavailable."
        case .cancelled:
            return "Request was cancelled."
        }
    }
}
