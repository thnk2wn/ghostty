import Foundation
import GhosttyKit

/// Bridge between Swift UI and Zig agent backend
class AgentBridge {
    private let surface: Ghostty.SurfaceView
    private weak var viewModel: AgentPaneViewModel?
    private var agent: ghostty_agent_t?

    init(surface: Ghostty.SurfaceView, viewModel: AgentPaneViewModel) {
        self.surface = surface
        self.viewModel = viewModel

        // Initialize agent from Zig backend
        // Note: This will fail until the C API is fully wired up
    }

    deinit {
        if let agent = agent {
            ghostty_agent_free(agent)
        }
    }

    /// Send input to the agent backend
    /// Output will appear as styled overlay blocks
    func processInput(_ input: String, mode: AgentMode, model: String, completion: @escaping (Result<AgentResponse, Error>) -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            // If agent is initialized, use it
            if let agent = self.agent {
                let inputData = input.utf8CString
                let success = inputData.withUnsafeBufferPointer { buffer in
                    ghostty_agent_process_input(agent, buffer.baseAddress!, input.utf8.count)
                }

                if !success {
                    DispatchQueue.main.async {
                        completion(.failure(AgentError.processingFailed))
                    }
                    return
                }
            } else {
                // Fallback: Simulate response
                self.simulateResponse(input: input, mode: mode, completion: completion)
            }
        }
    }

    private func simulateResponse(input: String, mode: AgentMode, completion: @escaping (Result<AgentResponse, Error>) -> Void) {
        // Simulate processing time
        Thread.sleep(forTimeInterval: 1.0)

        // Create simple block with full-width bars
        let modeLabel = mode == .agent ? "AGENT" : mode == .ask ? "ASK" : "PLAN"
        let bgColor = mode == .agent ? "45" : mode == .ask ? "44" : "43" // Magenta, Blue, Yellow bg
        
        // Build block line by line with explicit structure
        var lines: [String] = []
        lines.append("")
        lines.append("\u{001B}[\(bgColor);97m \(modeLabel) \u{001B}[K\u{001B}[0m")
        lines.append("")
        lines.append("\u{001B}[1mQuery:\u{001B}[0m \(input)")
        lines.append("")
        lines.append("This is a simulated response.")
        lines.append("")
        lines.append("To complete:")
        lines.append("• Implement HTTP client")
        lines.append("• Wire up Zig backend")
        lines.append("• Add command execution")
        lines.append("")
        lines.append("\u{001B}[\(bgColor)m \u{001B}[K\u{001B}[0m")
        lines.append("")
        
        let blockOutput = lines.joined(separator: "\r\n")

        // Write to terminal output (not input)
        writeToTerminalOutput(blockOutput)

        let responseText = "AI response (see terminal)"
        let response = AgentResponse(
            content: responseText,
            reasoning: nil,
            commands: mode == .agent ? ["echo 'Example command'"] : nil
        )

        DispatchQueue.main.async {
            completion(.success(response))
        }
    }

    private func writeToTerminalOutput(_ text: String) {
        Task { @MainActor in
            guard let surface = self.surface.surface else { return }

            let len = text.utf8CString.count
            guard len > 0 else { return }

            text.withCString { ptr in
                _ = ghostty_agent_write_output(surface, ptr, Int(len - 1))
            }
        }
    }

    struct AgentResponse {
        let content: String
        let reasoning: String?
        let commands: [String]?
    }

    enum AgentError: Error {
        case notInitialized
        case invalidApiKey
        case networkError
        case providerError(String)
        case processingFailed
    }
}
