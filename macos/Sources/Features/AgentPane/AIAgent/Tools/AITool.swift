import Foundation

/// Protocol for tools that can be used by an AI agent
public protocol AITool: Sendable {
    /// The tool definitions that this tool provides
    var definitions: [AIToolDefinition] { get }
    
    /// Execute a function call
    /// - Parameters:
    ///   - name: The function name to call
    ///   - arguments: The arguments passed to the function
    /// - Returns: The result of the function call as a string
    func call(name: String, arguments: [String: JSONValue]) async throws -> String
}

/// Registry for managing tools
public actor AIToolRegistry {
    private var tools: [AITool] = []
    
    public init() {}
    
    public func register(_ tool: AITool) {
        tools.append(tool)
    }
    
    public func register(_ tools: [AITool]) {
        self.tools.append(contentsOf: tools)
    }
    
    public var allDefinitions: [AIToolDefinition] {
        tools.flatMap { $0.definitions }
    }
    
    public func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        for tool in tools {
            if tool.definitions.contains(where: { $0.name == name }) {
                return try await tool.call(name: name, arguments: arguments)
            }
        }
        throw AIToolError.unknownTool(name)
    }
    
    public func call(functionCall: AIAgentOutput.FunctionCall) async throws -> String {
        try await call(name: functionCall.name, arguments: functionCall.arguments)
    }
}

/// Errors from tool execution
public enum AIToolError: Error, LocalizedError {
    case unknownTool(String)
    case invalidArguments(String)
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}

// MARK: - Simple Tool Builder

/// A simple tool that wraps a single function
public struct SimpleTool: AITool {
    public let definitions: [AIToolDefinition]
    private let handler: @Sendable ([String: JSONValue]) async throws -> String
    
    public init(
        name: String,
        description: String,
        parameters: AIToolDefinition.ParameterSchema = .init(),
        handler: @escaping @Sendable ([String: JSONValue]) async throws -> String
    ) {
        self.definitions = [AIToolDefinition(name: name, description: description, parameters: parameters)]
        self.handler = handler
    }
    
    public func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        guard definitions.contains(where: { $0.name == name }) else {
            throw AIToolError.unknownTool(name)
        }
        return try await handler(arguments)
    }
}

// MARK: - Multi-Tool Container

/// A container for multiple related tools
public struct MultiTool: AITool {
    public let definitions: [AIToolDefinition]
    private let handlers: [String: @Sendable ([String: JSONValue]) async throws -> String]
    
    public init(tools: [(AIToolDefinition, @Sendable ([String: JSONValue]) async throws -> String)]) {
        self.definitions = tools.map { $0.0 }
        self.handlers = Dictionary(uniqueKeysWithValues: tools.map { ($0.0.name, $0.1) })
    }
    
    public func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        guard let handler = handlers[name] else {
            throw AIToolError.unknownTool(name)
        }
        return try await handler(arguments)
    }
}
