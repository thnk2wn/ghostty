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

// Output block message for display as overlay
struct AgentOutputMessage: Identifiable {
    let id: UUID = UUID()
    let mode: AgentMode
    let query: String?
    let content: String?
    let commands: [String]?
    let isProcessing: Bool
}

@MainActor
class AgentPaneViewModel: ObservableObject {
    @Published var mode: AgentMode = .ask
    @Published var isProcessing: Bool = false
    @Published var pendingCommands: [String] = []
    @Published var selectedModel: String = "gpt-4o-mini"
    @Published var outputBlocks: [AgentOutputMessage] = []
    @Published var hasAPIKey: Bool = false

    private var bridge: AgentBridge?

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

    func executeCommands() {
        guard !pendingCommands.isEmpty else { return }
        
        let commandsToExecute = pendingCommands
        pendingCommands.removeAll()
        
        isProcessing = true
        
        var executedCount = 0
        let totalCommands = commandsToExecute.count
        
        func executeNext() {
            guard executedCount < totalCommands else {
                isProcessing = false
                return
            }
            
            let command = commandsToExecute[executedCount]
            executedCount += 1
            
            bridge?.executeCommand(command) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let cmdResult):
                    let message = AgentOutputMessage(
                        mode: .agent,
                        query: nil,
                        content: "Executed: `\(command)`\n\nOutput:\n```\n\(cmdResult.output)\(cmdResult.error)```\n\nExit code: \(cmdResult.exitCode)",
                        commands: nil,
                        isProcessing: false
                    )
                    self.outputBlocks.append(message)
                    
                case .failure(let error):
                    let message = AgentOutputMessage(
                        mode: .agent,
                        query: nil,
                        content: "Failed to execute: `\(command)`\n\nError: \(error.localizedDescription)",
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
    }
}
