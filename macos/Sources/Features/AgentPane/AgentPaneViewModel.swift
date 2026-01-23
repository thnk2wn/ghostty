import SwiftUI
import GhosttyKit

enum AgentMode: String, CaseIterable, Identifiable {
    case agent = "Agent"
    case ask = "Ask"
    case plan = "Plan"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .agent: return "sparkles"
        case .ask: return "questionmark.circle"
        case .plan: return "list.clipboard"
        }
    }

    var description: String {
        switch self {
        case .agent: return "Autonomous agent that can execute commands"
        case .ask: return "Q&A assistant, no execution"
        case .plan: return "Create detailed plans without executing"
        }
    }

    var color: Color {
        switch self {
        case .agent: return .purple
        case .ask: return .blue
        case .plan: return .orange
        }
    }
}

// Output block message for display as overlay (legacy)
struct AgentOutputMessage: Identifiable {
    let id: UUID = UUID()
    let mode: AgentMode
    let query: String?
    let content: String?
    let commands: [String]?
    let isProcessing: Bool
}

// Rich AI block for inline overlay rendering
struct RichAIBlock: Identifiable {
    let id: UUID
    let mode: AgentMode
    let query: String?
    var content: String
    let startRow: Int
    var isStreaming: Bool
    var isCollapsed: Bool = false

    init(mode: AgentMode, query: String?, startRow: Int) {
        self.id = UUID()
        self.mode = mode
        self.query = query
        self.content = ""
        self.startRow = startRow
        self.isStreaming = true
    }
}

@MainActor
class AgentPaneViewModel: ObservableObject {
    @Published var mode: AgentMode = .ask
    @Published var isProcessing: Bool = false
    @Published var pendingCommands: [String] = []
    @Published var selectedModel: String = ""
    @Published var outputBlocks: [AgentOutputMessage] = []
    @Published var hasAPIKey: Bool = false
    @Published var useRichOverlays: Bool = true
    @Published var richBlocks: [RichAIBlock] = []
    @Published var reasoningLevel: ReasoningLevel = .none
    @Published var errorMessage: String? = nil

    private var bridge: AgentBridge?
    private var currentRichBlockId: UUID?

    var availableModels: [String] {
        return AgentConfig.availableModels()
    }

    /// Get available models for the current mode
    var availableModelsForCurrentMode: [ModelInfo] {
        return AgentConfig.availableModels(forMode: mode)
    }

    /// Check if the currently selected model supports reasoning levels
    var selectedModelSupportsReasoning: Bool {
        guard let model = ModelRegistry.shared.model(byId: selectedModel) else {
            return false
        }
        return model.supportsReasoning
    }

    init() {
        loadConfig()
        checkAPIKeys()
    }

    func checkAPIKeys() {
        // Check if any provider has a valid API key (for banner visibility)
        hasAPIKey = AgentConfig.hasAnyAPIKeyConfigured()
    }

    private func providerForModel(_ model: String) -> String {
        if model.contains("claude") {
            return "anthropic"
        } else if model.contains("llama") || model.contains("mistral") || model.contains("codellama") || model.contains("mixtral") {
            return "ollama"
        }
        return "openai"
    }

    func configure(surface: Ghostty.SurfaceView) {
        // Create or update the bridge with the surface
        if bridge == nil {
            self.bridge = AgentBridge(surface: surface, viewModel: self)
        }
    }
    
    var isConfigured: Bool {
        bridge != nil
    }

    func submitInput(_ input: String) {
        guard !input.isEmpty else { return }
        
        // Clear any previous error
        errorMessage = nil
        
        guard bridge != nil else {
            errorMessage = "Terminal not ready. Please wait a moment and try again."
            return
        }

        // Check if the selected model's provider has a valid API key
        let provider = providerForModel(selectedModel)
        guard AgentConfig.hasValidAPIKey(for: provider) else {
            errorMessage = "AI not configured. Click the settings banner above or select AI Settings from the model dropdown to add your API key."
            return
        }

        isProcessing = true

        bridge?.processInput(input, mode: mode, model: selectedModel) { [weak self] result in
            guard let self = self else { return }

            self.isProcessing = false

            switch result {
            case .success(let response):
                if let commands = response.commands, !commands.isEmpty && self.mode == .agent {
                    self.pendingCommands = commands
                }

            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }

        saveConfig()
    }

    private var lastExecutedCommands: [String] = []

    func executeCommands() {
        guard !pendingCommands.isEmpty else { return }

        let commandsToExecute = pendingCommands
        pendingCommands.removeAll()
        lastExecutedCommands = commandsToExecute

        isProcessing = true

        var executedCount = 0
        let totalCommands = commandsToExecute.count

        func executeNext() {
            guard executedCount < totalCommands else {
                // All commands executed - trigger continuation after delay
                self.scheduleAgentContinuation()
                return
            }

            let command = commandsToExecute[executedCount]
            executedCount += 1

            bridge?.executeCommand(command) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success:
                    // Command sent to terminal successfully
                    break

                case .failure(let error):
                    let message = AgentOutputMessage(
                        mode: .agent,
                        query: nil,
                        content: "❌ Failed to send command: `\(command)`\n\nError: \(error.localizedDescription)",
                        commands: nil,
                        isProcessing: false
                    )
                    self.outputBlocks.append(message)
                }

                executeNext()
            }
        }

        executeNext()
    }

    private func scheduleAgentContinuation() {
        // Wait for command output, then continue the agent loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.mode == .agent else {
                self?.isProcessing = false
                return
            }

            // Send continuation - assume success and continue unless user intervenes
            let commandSummary = self.lastExecutedCommands.count == 1
                ? "Command executed"
                : "\(self.lastExecutedCommands.count) commands executed"

            let continuationPrompt = """
            \(commandSummary). Continue with the next command to complete the task.
            If done, respond only: "Task complete."
            """

            self.submitContinuation(continuationPrompt)
        }
    }

    private func submitContinuation(_ prompt: String) {
        guard bridge != nil else {
            isProcessing = false
            return
        }

        bridge?.processInput(prompt, mode: mode, model: selectedModel) { [weak self] result in
            guard let self = self else { return }

            self.isProcessing = false

            switch result {
            case .success(let response):
                let responseBlock = AgentOutputMessage(
                    mode: self.mode,
                    query: nil,
                    content: response.content,
                    commands: response.commands,
                    isProcessing: false
                )
                self.outputBlocks.append(responseBlock)

                // If new commands, queue them for approval
                if let commands = response.commands, !commands.isEmpty && self.mode == .agent {
                    self.pendingCommands = commands
                }

            case .failure(let error):
                let errorBlock = AgentOutputMessage(
                    mode: self.mode,
                    query: nil,
                    content: "❌ Error: \(error.localizedDescription)",
                    commands: nil,
                    isProcessing: false
                )
                self.outputBlocks.append(errorBlock)
            }
        }
    }

    func rejectCommands() {
        let message = AgentOutputMessage(
            mode: .agent,
            query: nil,
            content: "❌ Commands rejected by user",
            commands: nil,
            isProcessing: false
        )
        outputBlocks.append(message)
        pendingCommands.removeAll()
    }

    func clearBlocks() {
        outputBlocks.removeAll()
        richBlocks.removeAll()
        currentRichBlockId = nil
        bridge?.clearHistory()
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
}
