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
        // Run simulation on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let surface = self.surface.surface else { return }
            
            let modeInt: Int32 = mode == .agent ? 0 : mode == .ask ? 1 : 2
            
            // Create block and get starting row
            let blockId = ghostty_agent_start_block(surface, modeInt)
            guard blockId > 0 else {
                completion(.failure(AgentError.processingFailed))
                return
            }
            
            // Get row position before top border
            let topBorderRow = ghostty_agent_get_cursor_row(surface)
            
            // Write ONLY spaces - the renderer will draw the underline
            let spacesLine = String(repeating: " ", count: 80)
            self.writeToTerminalOutput("\r\n\(spacesLine)")
            
            // Mark the border row - renderer will add underline
            ghostty_agent_mark_row(surface, topBorderRow + 1, blockId, true)
            
            // Move to content
            self.writeToTerminalOutput("\r\n\r\nQuery: \(input)\r\n\r\n")
            self.writeToTerminalOutput("This is a test AI response!\r\n\r\n")
            
            // Get row position before bottom border
            let bottomBorderRow = ghostty_agent_get_cursor_row(surface)
            
            // Write ONLY spaces for bottom border
            self.writeToTerminalOutput("\r\n\(spacesLine)")
            
            // Mark the border row - renderer will add underline
            ghostty_agent_mark_row(surface, bottomBorderRow + 1, blockId, false)
            
            // Move cursor past the border
            self.writeToTerminalOutput("\r\n")
            
            // Send empty command to trigger shell prompt redraw
            self.writeToTerminalOutput("\r")
            self.endAIBlock(blockId: blockId)
            print("📍 Marked row \(bottomBorderRow) as BOTTOM border")
            
            completion(.success(AgentResponse(
                content: "Test response",
                reasoning: nil,
                commands: nil
            )))
        }
    }

    private func simulateResponse(input: String, mode: AgentMode, completion: @escaping (Result<AgentResponse, Error>) -> Void) {
        // Simulate processing time
        Thread.sleep(forTimeInterval: 1.0)

        // All terminal operations must be synchronous and on the calling thread
        DispatchQueue.main.sync {
            // DEBUG: Write a visible message first
            writeToTerminalOutput("\r\n=== AI BLOCK TEST START ===\r\n")

            // Create empty line for top border and mark it
            writeToTerminalOutput(" ") // Write a space to create the row
            let modeInt: Int32 = mode == .agent ? 0 : mode == .ask ? 1 : 2
            let blockId = startAIBlock(modeInt: modeInt) // Mark this row as top border
            writeToTerminalOutput(" [TOP BORDER ROW - ID:\(blockId)]")

            if blockId == 0 {
                writeToTerminalOutput("\r\n❌ FAILED TO CREATE BLOCK!\r\n")
                return
            }

            // Move to next line after top border
            writeToTerminalOutput("\r\n")

            // Build block content
            var lines: [String] = []
            lines.append("")
            lines.append("\u{001B}[1mQuery:\u{001B}[0m \(input)")
            lines.append("")
            lines.append("This is a simulated response with native AI blocks!")
            lines.append("")
            lines.append("Features:")
            lines.append("  • Native terminal integration")
            lines.append("  • Scrolls with terminal")
            lines.append("  • Custom rendering ready")
            lines.append("")

            let blockOutput = lines.joined(separator: "\r\n")

            // Write block content to terminal
            writeToTerminalOutput(blockOutput)

            // Create empty line for bottom border
            writeToTerminalOutput("\r\n ")
            writeToTerminalOutput("[BOTTOM BORDER ROW]")

            // Mark current row as bottom border
            endAIBlock(blockId: blockId)

            // Move past the bottom border
            writeToTerminalOutput("\r\n=== AI BLOCK TEST END ===\r\n")
        }

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

    private func startAIBlock(modeInt: Int32) -> UInt32 {
        // Synchronous call needed for block creation
        guard let surface = self.surface.surface else {
            print("❌ No surface available for startAIBlock")
            return 0
        }
        let blockId = ghostty_agent_start_block(surface, modeInt)
        print("✅ Started AI block with ID: \(blockId), mode: \(modeInt)")
        return blockId
    }

    private func endAIBlock(blockId: UInt32) {
        // Synchronous call needed for proper sequencing
        guard let surface = self.surface.surface else {
            print("❌ No surface available for endAIBlock")
            return
        }
        ghostty_agent_end_block(surface, blockId)
        print("✅ Ended AI block with ID: \(blockId)")
    }

    private func writeToTerminalOutput(_ text: String) {
        // Synchronous write needed for proper sequencing
        guard let surface = self.surface.surface else { return }

        let len = text.utf8CString.count
        guard len > 0 else { return }

        text.withCString { ptr in
            _ = ghostty_agent_write_output(surface, ptr, Int(len - 1))
        }
    }
}

// Response structure
struct AgentResponse {
    let content: String
    let reasoning: String?
    let commands: [String]?
}

// Error types
enum AgentError: Error {
    case processingFailed
    case invalidInput
}
