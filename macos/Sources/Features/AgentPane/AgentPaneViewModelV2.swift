import SwiftUI
import GhosttyKit

/// Updated AgentPaneViewModel using the new AIAgent framework
@MainActor
class AgentPaneViewModelV2: ObservableObject {
    @Published var mode: AgentMode = .ask
    @Published var isProcessing: Bool = false
    @Published var pendingToolCalls: [AIAgentOutput.FunctionCall] = []
    @Published var selectedModel: String = ""
    @Published var hasAPIKey: Bool = false
    @Published var useRichOverlays: Bool = true
    @Published var richBlocks: [RichAIBlock] = []
    @Published var errorMessage: String? = nil
    @Published var reasoningLevel: ReasoningLevel = .none
    
    // Compatibility: outputBlocks for views that check it
    var outputBlocks: [AgentOutputMessage] { [] }
    
    // Compatibility with existing views - maps tool calls to user-friendly descriptions
    var pendingCommands: [String] {
        pendingToolCalls.compactMap { call in
            formatToolCallForUser(call)
        }
    }
    
    /// Format a tool call as a user-friendly description
    private func formatToolCallForUser(_ call: AIAgentOutput.FunctionCall) -> String {
        switch call.name {
        case "execute_command":
            if let cmd = call.arguments["command"]?.stringValue {
                return cmd
            }
        case "shell_run":
            if let cmd = call.arguments["command"]?.stringValue {
                return "Run: \(cmd)"
            }
        case "file_read", "read_file":
            if let path = call.arguments["file"]?.stringValue ?? call.arguments["path"]?.stringValue {
                return "Read file: \(path)"
            }
        case "file_write", "write_file":
            if let path = call.arguments["file"]?.stringValue ?? call.arguments["path"]?.stringValue {
                return "Write to: \(path)"
            }
        case "file_delete":
            if let path = call.arguments["file"]?.stringValue {
                return "Delete: \(path)"
            }
        case "list_directory":
            if let path = call.arguments["path"]?.stringValue {
                return "List directory: \(path)"
            }
        case "search_files":
            if let dir = call.arguments["directory"]?.stringValue,
               let pattern = call.arguments["pattern"]?.stringValue {
                return "Search '\(pattern)' in \(dir)"
            }
        default:
            break
        }
        // Fallback - show tool name with brief args
        let argsPreview = call.arguments.keys.prefix(2).joined(separator: ", ")
        return "\(call.name)(\(argsPreview)...)"
    }
    
    /// Check if the currently selected model supports reasoning levels
    var selectedModelSupportsReasoning: Bool {
        guard let model = ModelRegistry.shared.model(byId: selectedModel) else {
            return false
        }
        return model.supportsReasoning
    }
    
    private var surface: Ghostty.SurfaceView?
    private var currentRichBlockId: UUID?
    private var toolApprovalContinuation: CheckedContinuation<Bool, Never>?
    
    var availableModels: [String] {
        return AgentConfig.availableModels()
    }
    
    var availableModelsForCurrentMode: [ModelInfo] {
        return AgentConfig.availableModels(forMode: mode)
    }
    
    var isConfigured: Bool {
        surface != nil
    }
    
    init() {
        loadConfig()
        checkAPIKeys()
    }
    
    func checkAPIKeys() {
        hasAPIKey = AgentConfig.hasAnyAPIKeyConfigured()
    }
    
    func configure(surface: Ghostty.SurfaceView) {
        self.surface = surface
    }
    
    // MARK: - Submit Input
    
    func submitInput(_ input: String) {
        guard !input.isEmpty else { return }
        
        errorMessage = nil
        
        // Get API key
        let provider = ModelFactory.providerForModel(selectedModel)
        guard let apiKey = AgentConfig.getAPIKey(for: provider), !apiKey.isEmpty else {
            errorMessage = "AI not configured. Click the settings banner above or select AI Settings from the model dropdown to add your API key."
            return
        }
        
        isProcessing = true
        
        // Create a rich block for output
        let blockId = startRichBlock(mode: mode, query: input, startRow: 0)
        
        Task {
            await runAgent(
                prompt: input,
                modelId: selectedModel,
                apiKey: apiKey,
                surface: surface, // Can be nil - tools that need it will fail gracefully
                blockId: blockId
            )
        }
        
        saveConfig()
    }
    
    private func runAgent(
        prompt: String,
        modelId: String,
        apiKey: String,
        surface: Ghostty.SurfaceView?,
        blockId: UUID
    ) async {
        AIAgentLogger.info("Starting agent run: model=\(modelId), mode=\(mode.rawValue)")
        let startTime = Date()
        
        // Create the model
        guard let model = ModelFactory.create(modelId: modelId, apiKey: apiKey) else {
            AIAgentLogger.error("Failed to create model: \(modelId)")
            errorMessage = "Unknown model: \(modelId)"
            endRichBlock(blockId: blockId)
            isProcessing = false
            return
        }
        
        // Create modular tools
        var tools: [AITool] = [
            FileIOTool(),
            DateTimeTool(),
            FetchTool(),
            ShellTool()
        ]
        
        // Only add terminal tools if we have a surface
        if let surface = surface {
            tools.insert(TerminalTools(surface: surface), at: 0)
            AIAgentLogger.debug("Terminal tools enabled")
        } else {
            AIAgentLogger.debug("No surface - terminal tools disabled")
        }
        
        AIAgentLogger.debug("Registered \(tools.count) tool providers")
        
        // Map mode
        let agentMode: AIAgentMode
        switch mode {
        case .agent: agentMode = .agent
        case .ask: agentMode = .ask
        case .plan: agentMode = .plan
        }
        
        // Build system prompt
        let systemPrompt = buildSystemPrompt()
        
        // Create agent
        let agent = AIAgent(
            model: model,
            tools: tools,
            systemPrompt: systemPrompt,
            mode: agentMode,
            configuration: .init(
                maxToolIterations: 10,
                toolIterationDelay: .milliseconds(500),
                autoExecuteTools: false
            )
        )
        
        // Set up streaming callback
        await agent.setCallbacks(
            onStream: { [weak self] token in
                Task { @MainActor in
                    self?.appendToRichBlock(blockId: blockId, text: token)
                }
            },
            onToolCall: { [weak self] calls in
                guard let self = self else { return false }
                
                // Auto-approve safe read-only tools
                let safeTools = Set(["fetch", "fetch_json", "fetch_headers", "get_current_datetime", 
                                     "datetime_now", "datetime_format", "datetime_parse",
                                     "generate_uuid", "base64_encode", "base64_decode", "json_format",
                                     "file_exists", "get_current_directory"])
                let allSafe = calls.allSatisfy { safeTools.contains($0.name) }
                
                if allSafe {
                    // Show a brief status message for auto-approved tools
                    Task { @MainActor in
                        let toolNames = calls.map { $0.name }.joined(separator: ", ")
                        self.appendToRichBlock(blockId: blockId, text: "\n\n*Using \(toolNames)...*\n")
                    }
                    return true
                }
                
                return await self.requestToolApproval(calls: calls)
            },
            onToolResult: { name, result in
                // Tool results are internal context for the AI - don't show raw output to user
                AIAgentLogger.tools.info("Tool '\(name)' returned \(result.count) characters")
            }
        )
        
        // Run the agent
        do {
            AIAgentLogger.info("Running agent with prompt: \(prompt.prefix(100))...")
            let context = gatherContext()
            let outputs = try await agent.run(prompt: prompt, context: context)
            
            let elapsed = Date().timeIntervalSince(startTime)
            AIAgentLogger.info("Agent completed successfully in \(String(format: "%.2f", elapsed))s with \(outputs.count) outputs")
            
            // If we got text output that wasn't streamed, add it
            let finalText = outputs.allTexts.joined(separator: "\n")
            if let block = richBlocks.first(where: { $0.id == blockId }),
               block.content.isEmpty && !finalText.isEmpty {
                appendToRichBlock(blockId: blockId, text: finalText)
            }
        } catch let error as AIModelError {
            let elapsed = Date().timeIntervalSince(startTime)
            AIAgentLogger.error("Agent failed after \(String(format: "%.2f", elapsed))s: \(error.localizedDescription)")
            appendToRichBlock(blockId: blockId, text: "\n\n**Error:** \(error.localizedDescription)")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            AIAgentLogger.error("Agent failed after \(String(format: "%.2f", elapsed))s: \(error.localizedDescription)")
            appendToRichBlock(blockId: blockId, text: "\n\n**Error:** \(error.localizedDescription)")
        }
        
        endRichBlock(blockId: blockId)
        isProcessing = false
    }
    
    // MARK: - Tool Approval
    
    private func requestToolApproval(calls: [AIAgentOutput.FunctionCall]) async -> Bool {
        await MainActor.run {
            self.pendingToolCalls = calls
        }
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.toolApprovalContinuation = continuation
            }
        }
    }
    
    func approveToolCalls() {
        toolApprovalContinuation?.resume(returning: true)
        toolApprovalContinuation = nil
        pendingToolCalls = []
    }
    
    func rejectToolCalls() {
        toolApprovalContinuation?.resume(returning: false)
        toolApprovalContinuation = nil
        pendingToolCalls = []
        
        if let blockId = currentRichBlockId {
            appendToRichBlock(blockId: blockId, text: "\n\n**Tool calls rejected by user**")
        }
    }
    
    // Compatibility aliases for existing views
    func executeCommands() {
        approveToolCalls()
    }
    
    func rejectCommands() {
        rejectToolCalls()
    }
    
    // MARK: - Rich Block Management
    
    func startRichBlock(mode: AgentMode, query: String?, startRow: Int) -> UUID {
        let block = RichAIBlock(mode: mode, query: query, startRow: startRow)
        richBlocks.append(block)
        currentRichBlockId = block.id
        return block.id
    }
    
    func appendToRichBlock(blockId: UUID, text: String) {
        guard let index = richBlocks.firstIndex(where: { $0.id == blockId }) else { return }
        richBlocks[index].content += text
    }
    
    func endRichBlock(blockId: UUID) {
        guard let index = richBlocks.firstIndex(where: { $0.id == blockId }) else { return }
        richBlocks[index].isStreaming = false
        if currentRichBlockId == blockId {
            currentRichBlockId = nil
        }
    }
    
    func toggleRichBlockCollapsed(blockId: UUID) {
        guard let index = richBlocks.firstIndex(where: { $0.id == blockId }) else { return }
        richBlocks[index].isCollapsed.toggle()
    }
    
    func removeRichBlock(blockId: UUID) {
        richBlocks.removeAll { $0.id == blockId }
    }
    
    func clearBlocks() {
        richBlocks.removeAll()
        currentRichBlockId = nil
    }
    
    // MARK: - Helpers
    
    private func buildSystemPrompt() -> String {
        var prompt = """
        You are an AI assistant integrated into Ghostty, a terminal emulator.
        The user is working in a terminal environment on macOS.
        """
        
        switch mode {
        case .agent:
            prompt += """
            
            You have access to tools that can:
            - Execute shell commands (execute_command)
            - Read files (read_file)
            - Write files (write_file)
            - List directories (list_directory)
            - Get the current directory (get_current_directory)
            - Search for files (search_files)
            
            When you need to perform an action, use the appropriate tool.
            Always explain what you're about to do before using a tool.
            Be careful with destructive operations.
            """
        case .ask:
            prompt += """
            
            You can answer questions and provide guidance, but cannot execute commands.
            Suggest commands the user can run, but you cannot execute them directly.
            """
        case .plan:
            prompt += """
            
            Create detailed plans and step-by-step instructions.
            Do not execute anything - only describe what should be done.
            """
        }
        
        return prompt
    }
    
    private func gatherContext() -> String {
        var context: [String] = []
        
        let cwd = FileManager.default.currentDirectoryPath
        context.append("Current directory: \(cwd)")
        
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            context.append("Shell: \(shell)")
        }
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        context.append("OS: macOS \(osVersion)")
        
        return context.joined(separator: "\n")
    }
}

// MARK: - Config Loading (Reuse existing)

extension AgentPaneViewModelV2 {
    func loadConfig() {
        #if os(macOS)
        let ghosttyConfig = (NSApplication.shared.delegate as? AppDelegate)?.ghostty.config
        let config = AgentConfig.load(from: ghosttyConfig)
        #else
        let config = AgentConfig.load()
        #endif
        
        self.mode = config.mode
        self.useRichOverlays = config.useRichOverlays
        
        let availableForMode = AgentConfig.availableModels(forMode: self.mode)
        let registry = ModelRegistry.shared
        let modeDefault = registry.defaultModel(forMode: self.mode)
        
        if !modeDefault.isEmpty && availableForMode.contains(where: { $0.id == modeDefault }) {
            self.selectedModel = modeDefault
        } else if let firstAvailable = availableForMode.first {
            self.selectedModel = firstAvailable.id
        } else {
            self.selectedModel = "gpt-4o"
        }
    }
    
    func saveConfig() {
        UserDefaults.standard.set(useRichOverlays, forKey: "agentUseRichOverlays")
    }
    
    func updateModelForMode() {
        let availableForMode = AgentConfig.availableModels(forMode: self.mode)
        
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
