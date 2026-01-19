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

    private var bridge: AgentBridge?

    let availableModels: [String] = [
        "gpt-4o",
        "gpt-4o-mini",
        "o1-preview",
        "o1-mini",
        "gpt-5.2",
        "gpt-5.2-codex",
        "claude-3-5-sonnet-latest",
        "claude-3-opus-latest",
        "llama3",
        "codellama"
    ]

    func configure(surface: Ghostty.SurfaceView) {
        // Only configure once
        guard bridge == nil else { return }
        self.bridge = AgentBridge(surface: surface, viewModel: self)
    }

    func submitInput(_ input: String) {
        guard !input.isEmpty else { return }
        guard bridge != nil else { return }

        isProcessing = true

        // Add processing block
        let processingBlock = AgentOutputMessage(
            mode: mode,
            query: input,
            content: nil,
            commands: nil,
            isProcessing: true
        )
        outputBlocks.append(processingBlock)

        // Process through agent
        bridge?.processInput(input, mode: mode, model: selectedModel) { [weak self] result in
            guard let self = self else { return }

            self.isProcessing = false

            // Remove processing block
            self.outputBlocks.removeAll { $0.id == processingBlock.id }

            switch result {
            case .success(let response):
                // Add response block
                let responseBlock = AgentOutputMessage(
                    mode: self.mode,
                    query: input,
                    content: response.content,
                    commands: response.commands,
                    isProcessing: false
                )
                self.outputBlocks.append(responseBlock)

                // If there are commands and we need approval
                if let commands = response.commands, !commands.isEmpty && self.mode == .agent {
                    self.pendingCommands = commands
                }

            case .failure(let error):
                let errorBlock = AgentOutputMessage(
                    mode: self.mode,
                    query: input,
                    content: "Error: \(error.localizedDescription)",
                    commands: nil,
                    isProcessing: false
                )
                self.outputBlocks.append(errorBlock)
            }
        }
    }

    func executeCommands() {
        // TODO: Execute command via bridge
        pendingCommands.removeAll()
    }

    func rejectCommands() {
        pendingCommands.removeAll()
    }

    func clearBlocks() {
        outputBlocks.removeAll()
    }
}
