import Foundation

/// Configuration for an AI agent
public struct AIAgentConfiguration: Sendable {
    /// Maximum iterations for tool calling loop
    public let maxToolIterations: Int
    
    /// Delay between tool iterations (for rate limiting)
    public let toolIterationDelay: Duration
    
    /// Whether to automatically execute tool calls without approval
    public let autoExecuteTools: Bool
    
    public static let `default` = AIAgentConfiguration(
        maxToolIterations: 10,
        toolIterationDelay: .milliseconds(500),
        autoExecuteTools: false
    )
    
    public init(
        maxToolIterations: Int = 10,
        toolIterationDelay: Duration = .milliseconds(500),
        autoExecuteTools: Bool = false
    ) {
        self.maxToolIterations = maxToolIterations
        self.toolIterationDelay = toolIterationDelay
        self.autoExecuteTools = autoExecuteTools
    }
}

/// The mode the agent operates in
public enum AIAgentMode: String, Sendable {
    case agent  // Can execute tools
    case ask    // Read-only, no tool execution
    case plan   // Planning mode, no execution
}

/// An AI agent that can use tools and execute tasks
public actor AIAgent {
    public let id = UUID()
    
    private let model: AIAgentModel
    private let tools: AIToolRegistry
    private let systemPrompt: String
    private let configuration: AIAgentConfiguration
    private let mode: AIAgentMode
    
    /// Callbacks for UI updates
    public var onStreamToken: ((String) -> Void)?
    public var onToolCallRequested: (([AIAgentOutput.FunctionCall]) async -> Bool)?
    public var onToolCallResult: ((String, String) -> Void)?
    public var onIterationComplete: ((Int, [AIAgentOutput]) -> Void)?
    
    public init(
        model: AIAgentModel,
        tools: [AITool] = [],
        systemPrompt: String = "",
        mode: AIAgentMode = .agent,
        configuration: AIAgentConfiguration = .default
    ) {
        self.model = model
        self.tools = AIToolRegistry()
        self.systemPrompt = systemPrompt
        self.mode = mode
        self.configuration = configuration
        
        Task {
            await self.tools.register(tools)
        }
    }
    
    /// Add additional tools
    public func addTools(_ tools: [AITool]) async {
        await self.tools.register(tools)
    }
    
    /// Run the agent with a prompt
    /// - Parameters:
    ///   - prompt: The user's prompt
    ///   - context: Additional context to include
    /// - Returns: The final output from the agent
    public func run(prompt: String, context: String? = nil) async throws -> [AIAgentOutput] {
        var fullPrompt = prompt
        if let ctx = context {
            fullPrompt = "<context>\(ctx)</context>\n\n\(prompt)"
        }
        
        // Get tool definitions (empty for non-agent modes)
        let toolDefs = mode == .agent ? await tools.allDefinitions : []
        
        var currentPrompt = fullPrompt
        var iteration = 0
        var conversationHistory: [(role: String, content: String)] = []
        
        while iteration < configuration.maxToolIterations {
            iteration += 1
            
            // Build the full system prompt based on mode
            let fullSystem = buildSystemPrompt()
            
            // Add conversation history to prompt if we have tool results
            var messagesPrompt = currentPrompt
            if !conversationHistory.isEmpty {
                let historyStr = conversationHistory.map { 
                    "<\($0.role)>\($0.content)</\($0.role)>"
                }.joined(separator: "\n")
                messagesPrompt = "\(fullPrompt)\n\n<conversation_history>\n\(historyStr)\n</conversation_history>"
            }
            
            // Run the model
            let outputs = try await model.run(
                prompt: messagesPrompt,
                systemPrompt: fullSystem,
                tools: toolDefs.isEmpty ? nil : toolDefs,
                outputSchema: nil,
                temperature: 0.7,
                maxTokens: nil,
                streamHandler: onStreamToken
            )
            
            onIterationComplete?(iteration, outputs)
            
            // Check for function calls
            let functionCalls = outputs.allFunctionCalls
            
            if functionCalls.isEmpty {
                // No more tools to call, we're done
                return outputs
            }
            
            // In non-agent modes, don't execute tools
            if mode != .agent {
                return outputs
            }
            
            // Request approval if not auto-execute
            if !configuration.autoExecuteTools {
                if let callback = onToolCallRequested {
                    let approved = await callback(functionCalls)
                    if !approved {
                        return [.text("Tool execution cancelled by user.")]
                    }
                }
            }
            
            // Execute tool calls
            var toolResults: [(name: String, result: String)] = []
            
            for call in functionCalls {
                do {
                    let result = try await tools.call(functionCall: call)
                    toolResults.append((call.name, result))
                    onToolCallResult?(call.name, result)
                } catch {
                    let errorResult = "Error: \(error.localizedDescription)"
                    toolResults.append((call.name, errorResult))
                    onToolCallResult?(call.name, errorResult)
                }
            }
            
            // Add to conversation history
            let assistantContent = outputs.allTexts.joined(separator: "\n")
            if !assistantContent.isEmpty {
                conversationHistory.append((role: "assistant", content: assistantContent))
            }
            
            let toolResultsStr = toolResults.map {
                "<tool_result name=\"\($0.name)\">\($0.result)</tool_result>"
            }.joined(separator: "\n")
            conversationHistory.append((role: "tool_results", content: toolResultsStr))
            
            // Update prompt for next iteration
            currentPrompt = """
            \(fullPrompt)
            
            Tool results:
            \(toolResultsStr)
            
            Based on the original request, present this information appropriately:
            - For casual questions → friendly summary
            - For technical/debugging requests → show relevant code/data with formatting
            - Use markdown code blocks for JSON/code when showing data
            """
            
            // Delay before next iteration
            try await Task.sleep(for: configuration.toolIterationDelay)
        }
        
        // Max iterations reached
        throw AIAgentError.maxIterationsReached
    }
    
    private func buildSystemPrompt() -> String {
        var prompt = systemPrompt
        
        switch mode {
        case .agent:
            prompt += """
            
            You are an AI assistant helping a programmer in a terminal environment.
            
            Guidelines:
            - Use tools when needed to accomplish tasks
            - After getting tool results, decide how to present based on context:
              * For user questions (weather, time, etc.) → summarize in a friendly format
              * For technical requests (API responses, file contents, debugging) → show relevant data
              * For large datasets → show key parts or a summary, offer to show more
            - When showing JSON/code, use markdown code blocks with syntax highlighting
            - Be concise but complete
            """
            
        case .ask:
            prompt += """
            
            You are a helpful AI assistant. Answer questions and provide information.
            You cannot execute commands or modify files - only provide guidance.
            """
            
        case .plan:
            prompt += """
            
            You are a planning assistant. Create detailed plans and step-by-step instructions.
            Do not execute anything - only describe what should be done.
            Break down complex tasks into clear, actionable steps.
            """
        }
        
        return prompt
    }
}

/// Errors from the AI agent
public enum AIAgentError: Error, LocalizedError {
    case maxIterationsReached
    case toolExecutionFailed(String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .maxIterationsReached:
            return "Maximum iterations reached. The task may be too complex."
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}
