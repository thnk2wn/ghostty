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
    @Published var selectedModel: String = "gpt-4o-mini"
    @Published var outputBlocks: [AgentOutputMessage] = []
    @Published var hasAPIKey: Bool = false
    @Published var useRichOverlays: Bool = true
    @Published var hideLayoutPicker: Bool = false
    @Published var richBlocks: [RichAIBlock] = []

    private var bridge: AgentBridge?
    private var currentRichBlockId: UUID?

    var availableModels: [String] {
        return AgentConfig.availableModels()
    }

    init() {
        loadConfig()
        checkAPIKeys()
    }

    private func checkAPIKeys() {
        hasAPIKey = AgentConfig.hasValidAPIKey(for: selectedModel)
    }

    func configure(surface: Ghostty.SurfaceView) {
        // Only configure once
        guard bridge == nil else { return }
        self.bridge = AgentBridge(surface: surface, viewModel: self)
    }

    func submitInput(_ input: String) {
        guard !input.isEmpty else { return }
        guard bridge != nil else { return }

        checkAPIKeys()
        guard hasAPIKey else {
            let errorBlock = AgentOutputMessage(
                mode: mode,
                query: input,
                content: "❌ Missing API key. Please set the appropriate environment variable:\n\n```bash\nexport OPENAI_API_KEY=\"your-key\"\n# or\nexport ANTHROPIC_API_KEY=\"your-key\"\n```\n\nThen restart Ghostty.",
                commands: nil,
                isProcessing: false
            )
            outputBlocks.append(errorBlock)
            return
        }

        isProcessing = true

        let processingBlock = AgentOutputMessage(
            mode: mode,
            query: input,
            content: nil,
            commands: nil,
            isProcessing: true
        )
        outputBlocks.append(processingBlock)

        bridge?.processInput(input, mode: mode, model: selectedModel) { [weak self] result in
            guard let self = self else { return }

            self.isProcessing = false

            self.outputBlocks.removeAll { $0.id == processingBlock.id }

            switch result {
            case .success(let response):
                let responseBlock = AgentOutputMessage(
                    mode: self.mode,
                    query: input,
                    content: response.content,
                    commands: response.commands,
                    isProcessing: false
                )
                self.outputBlocks.append(responseBlock)

                if let commands = response.commands, !commands.isEmpty && self.mode == .agent {
                    self.pendingCommands = commands
                }

            case .failure(let error):
                let errorBlock = AgentOutputMessage(
                    mode: self.mode,
                    query: input,
                    content: "❌ Error: \(error.localizedDescription)",
                    commands: nil,
                    isProcessing: false
                )
                self.outputBlocks.append(errorBlock)
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
