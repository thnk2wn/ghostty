import Foundation
import GhosttyKit

/// Bridge between Ghostty's UI and the AIAgent framework
@MainActor
class GhosttyAgentBridge: ObservableObject {
    private var agent: AIAgent?
    private var currentModel: AIAgentModel?
    private let surface: Ghostty.SurfaceView
    
    @Published var isProcessing = false
    @Published var currentOutput: String = ""
    @Published var pendingToolCalls: [AIAgentOutput.FunctionCall] = []
    @Published var error: String?
    
    /// Callback for streaming tokens to UI
    var onStreamToken: ((String) -> Void)?
    
    /// Callback when tool approval is needed
    var onToolApprovalNeeded: (([AIAgentOutput.FunctionCall]) -> Void)?
    
    init(surface: Ghostty.SurfaceView) {
        self.surface = surface
    }
    
    /// Run a prompt with the specified model and mode
    func run(
        prompt: String,
        modelId: String,
        mode: AgentMode,
        apiKey: String,
        systemPrompt: String? = nil
    ) async {
        isProcessing = true
        currentOutput = ""
        error = nil
        pendingToolCalls = []
        
        // Create the model
        guard let model = ModelFactory.create(modelId: modelId, apiKey: apiKey) else {
            error = "Unknown model: \(modelId)"
            isProcessing = false
            return
        }
        currentModel = model
        
        // Map Ghostty's mode to AIAgent mode
        let agentMode: AIAgentMode
        switch mode {
        case .agent: agentMode = .agent
        case .ask: agentMode = .ask
        case .plan: agentMode = .plan
        }
        
        // Create modular tools
        let terminalTools = TerminalTools(surface: surface)
        let fileIO = FileIOTool()
        let dateTime = DateTimeTool()
        let fetch = FetchTool()
        let shell = ShellTool()
        
        // Build system prompt
        let fullSystemPrompt = buildSystemPrompt(mode: mode, customPrompt: systemPrompt)
        
        // Create agent with modular tools
        let agent = AIAgent(
            model: model,
            tools: [terminalTools, fileIO, dateTime, fetch, shell],
            systemPrompt: fullSystemPrompt,
            mode: agentMode,
            configuration: .init(
                maxToolIterations: 10,
                toolIterationDelay: .milliseconds(500),
                autoExecuteTools: false
            )
        )
        self.agent = agent
        
        // Set up callbacks
        await agent.setCallbacks(
            onStream: { [weak self] token in
                Task { @MainActor in
                    self?.currentOutput += token
                    self?.onStreamToken?(token)
                }
            },
            onToolCall: { [weak self] calls in
                await MainActor.run {
                    self?.pendingToolCalls = calls
                    self?.onToolApprovalNeeded?(calls)
                }
                // Wait for approval - this will be resolved by approveToolCalls/rejectToolCalls
                return await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        self?.toolApprovalContinuation = continuation
                    }
                }
            },
            onToolResult: { [weak self] name, result in
                Task { @MainActor in
                    self?.currentOutput += "\n\n**Tool Result (\(name)):**\n\(result)"
                }
            }
        )
        
        // Gather context
        let context = gatherContext()
        
        // Run the agent
        do {
            let outputs = try await agent.run(prompt: prompt, context: context)
            
            // Process final outputs
            let finalText = outputs.allTexts.joined(separator: "\n")
            if !finalText.isEmpty && finalText != currentOutput {
                currentOutput = finalText
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isProcessing = false
        self.agent = nil
    }
    
    // MARK: - Tool Approval
    
    private var toolApprovalContinuation: CheckedContinuation<Bool, Never>?
    
    func approveToolCalls() {
        toolApprovalContinuation?.resume(returning: true)
        toolApprovalContinuation = nil
        pendingToolCalls = []
    }
    
    func rejectToolCalls() {
        toolApprovalContinuation?.resume(returning: false)
        toolApprovalContinuation = nil
        pendingToolCalls = []
    }
    
    // MARK: - Helpers
    
    private func buildSystemPrompt(mode: AgentMode, customPrompt: String?) -> String {
        var prompt = customPrompt ?? ""
        
        // Add terminal context
        prompt += """
        
        You are an AI assistant integrated into Ghostty, a terminal emulator.
        The user is working in a terminal environment.
        """
        
        switch mode {
        case .agent:
            prompt += """
            
            You can execute shell commands and interact with files on the user's system.
            Always explain what you're about to do before using a tool.
            Be careful with destructive operations - confirm with the user if unsure.
            """
        case .ask:
            prompt += """
            
            You can answer questions and provide guidance, but cannot execute commands.
            Suggest commands the user can run, but do not execute them.
            """
        case .plan:
            prompt += """
            
            Create detailed plans and step-by-step instructions.
            Do not execute anything - only describe the approach.
            """
        }
        
        return prompt
    }
    
    private func gatherContext() -> String {
        var context: [String] = []
        
        // Get current working directory
        let cwd = FileManager.default.currentDirectoryPath
        context.append("Current directory: \(cwd)")
        
        // Get shell info
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            context.append("Shell: \(shell)")
        }
        
        // Get OS info
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        context.append("OS: macOS \(osVersion)")
        
        return context.joined(separator: "\n")
    }
}

// MARK: - AIAgent Callback Extension

extension AIAgent {
    func setCallbacks(
        onStream: @escaping (String) -> Void,
        onToolCall: @escaping ([AIAgentOutput.FunctionCall]) async -> Bool,
        onToolResult: @escaping (String, String) -> Void
    ) async {
        self.onStreamToken = onStream
        self.onToolCallRequested = onToolCall
        self.onToolCallResult = onToolResult
    }
}
