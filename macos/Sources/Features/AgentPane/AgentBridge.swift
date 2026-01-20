import Foundation
import GhosttyKit

/// Bridge between Swift UI and Zig agent backend
class AgentBridge {
    private let surface: Ghostty.SurfaceView
    private weak var viewModel: AgentPaneViewModel?
    private var agent: ghostty_agent_t?
    private let aiClient = AIClient()
    private let markdownRenderer = MarkdownTerminalRenderer()

    // Rich overlay state
    private var currentRichBlockId: UUID?
    private var isUsingRichOverlays: Bool = true

    // Conversation history for maintaining context
    private var conversationHistory: [AIMessage] = []
    private var originalTask: String?

    init(surface: Ghostty.SurfaceView, viewModel: AgentPaneViewModel) {
        self.surface = surface
        self.viewModel = viewModel
    }

    /// Clear conversation history (call when starting a new task)
    func clearHistory() {
        conversationHistory.removeAll()
        originalTask = nil
    }

    deinit {
        if let agent = agent {
            ghostty_agent_free(agent)
        }
    }

    /// Send input to the agent backend with real AI processing
    func processInput(_ input: String, mode: AgentMode, model: String, completion: @escaping (Result<AgentResponse, Error>) -> Void) {
        Task {
            do {
                let context = await self.gatherTerminalContext()
                let systemPrompt = AIPrompts.systemPrompt(for: mode, terminalContext: context)

                // Track original task for context
                if originalTask == nil {
                    originalTask = input
                }

                // Build messages with conversation history
                var messages = [AIMessage(role: "system", content: systemPrompt)]
                messages.append(contentsOf: conversationHistory)
                messages.append(AIMessage(role: "user", content: input))

                // Add the user message to history
                conversationHistory.append(AIMessage(role: "user", content: input))

                let request = AIRequest(
                    messages: messages,
                    model: model,
                    stream: true,
                    temperature: 0.7
                )

                await MainActor.run {
                    self.startOutputBlock(mode: mode, query: input)
                }

                var accumulatedContent = ""

                self.aiClient.sendRequest(request, streamHandler: { [weak self] chunk in
                    guard let self = self else { return }
                    accumulatedContent += chunk

                    Task { @MainActor in
                        self.appendToCurrentBlock(chunk)
                    }
                }, completion: { [weak self] result in
                    guard let self = self else { return }

                    Task { @MainActor in
                        switch result {
                        case .success(let response):
                            let finalContent = response.content.isEmpty ? accumulatedContent : response.content

                            await self.endOutputBlock()

                            // Add assistant response to history
                            self.conversationHistory.append(AIMessage(role: "assistant", content: finalContent))

                            // Keep history manageable (last 10 exchanges)
                            if self.conversationHistory.count > 20 {
                                self.conversationHistory.removeFirst(2)
                            }

                            let commands: [String]?
                            if mode == .agent {
                                commands = self.extractCommands(from: finalContent)
                            } else {
                                commands = nil
                            }

                            let agentResponse = AgentResponse(
                                content: finalContent,
                                reasoning: nil,
                                commands: commands
                            )
                            completion(.success(agentResponse))

                        case .failure(let error):
                            await self.endOutputBlock()
                            let errorMessage = "\n\n❌ Error: \(error.localizedDescription)"
                            self.appendToCurrentBlock(errorMessage)
                            completion(.failure(error))
                        }
                    }
                })

            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private func gatherTerminalContext() async -> TerminalContext? {
        return await MainActor.run {
            guard let surface = self.surface.surface else { return nil }

            let cwd = self.getCurrentWorkingDirectory()
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

            return TerminalContext(
                workingDirectory: cwd,
                shell: shell,
                recentCommands: [],
                visibleOutput: nil
            )
        }
    }

    private func getCurrentWorkingDirectory() -> String? {
        return FileManager.default.currentDirectoryPath
    }

    private func extractCommands(from content: String) -> [String] {
        var commands: [String] = []
        let pattern = "```(?:bash|sh|shell)\\s*\\n([^`]+)```"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return commands
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

        for match in matches {
            if match.numberOfRanges > 1 {
                let commandRange = match.range(at: 1)
                let commandBlock = nsContent.substring(with: commandRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Keep the entire code block as a single command
                // This preserves multi-line commands, line continuations, and JSON arguments
                if !commandBlock.isEmpty && !commandBlock.hasPrefix("#") {
                    commands.append(commandBlock)
                }
            }
        }

        return commands
    }

    /// Execute a command by sending it to the terminal as user input
    /// This sends the command to the actual terminal PTY, so it runs in the shell
    func executeCommand(_ command: String, completion: @escaping (Result<CommandResult, Error>) -> Void) {
        Task { @MainActor in
            guard let surface = self.surface.surface else {
                completion(.failure(AgentError.processingFailed))
                return
            }

            // Show what we're about to execute
            self.appendToCurrentBlock("\n\n**Executing:** `\(command)`\n")

            // Send the command to the terminal with carriage return to execute it
            // Use \r (carriage return) not \n (newline) - this is what Enter key sends
            let commandWithCR = command + "\r"
            let success = commandWithCR.withCString { ptr in
                ghostty_agent_send_input(surface, ptr, commandWithCR.utf8.count)
            }

            if success {
                // Command was sent successfully
                // For now, we report success immediately since the command is running in the terminal
                // The user can see the output directly in the terminal
                let result = CommandResult(
                    output: "Command sent to terminal. Output visible in terminal below.",
                    error: "",
                    exitCode: 0
                )
                completion(.success(result))
            } else {
                completion(.failure(AgentError.processingFailed))
            }
        }
    }

    private var currentBlockId: UInt32 = 0
    private var hasWrittenResponseHeader = false
    private var spinnerTimer: Timer?
    private var spinnerFrame = 0
    private static let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private static let thinkingMessages = [
        "Thinking",
        "Analyzing query",
        "Processing",
        "Generating response"
    ]

    @MainActor
    private func startOutputBlock(mode: AgentMode, query: String) {
        // Capture the setting at the start of the block
        self.isUsingRichOverlays = viewModel?.useRichOverlays ?? AgentConfig.load().useRichOverlays

        if isUsingRichOverlays {
            // Rich overlay path: create a RichAIBlock
            guard let surface = self.surface.surface else { return }
            let startRow = Int(ghostty_agent_get_cursor_row(surface))
            let blockId = viewModel?.startRichBlock(mode: mode, query: query, startRow: startRow)
            self.currentRichBlockId = blockId
        } else {
            // Terminal output path: write ANSI to terminal
            guard let surface = self.surface.surface else { return }

            let modeInt: Int32 = mode == .agent ? 0 : mode == .ask ? 1 : 2

            let blockId = ghostty_agent_start_block(surface, modeInt)
            guard blockId > 0 else { return }

            self.currentBlockId = blockId
            self.hasWrittenResponseHeader = false
            self.spinnerFrame = 0

            let topBorderRow = ghostty_agent_get_cursor_row(surface)
            let spacesLine = String(repeating: " ", count: 80)

            self.writeToTerminalOutput("\r\n\(spacesLine)")
            ghostty_agent_mark_row(surface, topBorderRow + 1, blockId, true)

            self.writeToTerminalOutput("\r\n")

            let modeIcon = mode == .agent ? "✨" : mode == .ask ? "❓" : "📋"
            self.writeToTerminalOutput("\(modeIcon) \u{001B}[1m\(mode.rawValue) Mode\u{001B}[0m\r\n\r\n")
            self.writeToTerminalOutput("\u{001B}[1mQuery:\u{001B}[0m \(query)\r\n\r\n")

            startSpinner()
        }
    }

    @MainActor
    private func startSpinner() {
        writeSpinnerFrame()

        spinnerTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSpinner()
            }
        }
    }

    @MainActor
    private func updateSpinner() {
        guard currentBlockId > 0, !hasWrittenResponseHeader else {
            stopSpinner()
            return
        }
        spinnerFrame = (spinnerFrame + 1) % Self.spinnerFrames.count
        writeSpinnerFrame()
    }

    @MainActor
    private func writeSpinnerFrame() {
        let spinner = Self.spinnerFrames[spinnerFrame]
        let messageIndex = (spinnerFrame / 10) % Self.thinkingMessages.count
        let message = Self.thinkingMessages[messageIndex]
        let dots = String(repeating: ".", count: (spinnerFrame / 3) % 4)

        // Move to start of line, clear it, write spinner
        self.writeToTerminalOutput("\r\u{001B}[2K\u{001B}[36m\(spinner)\u{001B}[0m \u{001B}[2m\(message)\(dots)\u{001B}[0m")
    }

    @MainActor
    private func stopSpinner() {
        spinnerTimer?.invalidate()
        spinnerTimer = nil
    }

    @MainActor
    private func appendToCurrentBlock(_ text: String) {
        if isUsingRichOverlays {
            // Rich overlay path: append raw markdown to the block
            guard let blockId = currentRichBlockId else { return }
            viewModel?.appendToRichBlock(blockId: blockId, text: text)
        } else {
            // Terminal output path: convert to ANSI
            guard currentBlockId > 0 else { return }

            if !hasWrittenResponseHeader {
                stopSpinner()
                // Clear spinner line, then write response header
                self.writeToTerminalOutput("\r\u{001B}[2K\u{001B}[1mResponse:\u{001B}[0m\r\n")
                hasWrittenResponseHeader = true
                markdownRenderer.reset()
            }

            let ansiOutput = markdownRenderer.append(text)
            self.writeToTerminalOutput(ansiOutput)
        }
    }

    @MainActor
    private func endOutputBlock() async {
        if isUsingRichOverlays {
            // Rich overlay path: mark block as complete
            guard let blockId = currentRichBlockId else { return }
            viewModel?.endRichBlock(blockId: blockId)
            currentRichBlockId = nil
        } else {
            // Terminal output path: close the terminal block
            guard let surface = self.surface.surface else { return }
            guard currentBlockId > 0 else { return }

            stopSpinner()

            // Flush any remaining markdown content
            let remaining = markdownRenderer.flush()
            if !remaining.isEmpty {
                self.writeToTerminalOutput(remaining)
            }

            let bottomBorderRow = ghostty_agent_get_cursor_row(surface)
            let spacesLine = String(repeating: " ", count: 80)

            self.writeToTerminalOutput("\r\n\r\n\(spacesLine)")
            ghostty_agent_mark_row(surface, bottomBorderRow + 1, currentBlockId, false)

            self.writeToTerminalOutput("\r\n")

            ghostty_agent_end_block(surface, currentBlockId)
            currentBlockId = 0
        }
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

// Response structures
struct AgentResponse {
    let content: String
    let reasoning: String?
    let commands: [String]?
}

struct CommandResult {
    let output: String
    let error: String
    let exitCode: Int
}

// Error types
enum AgentError: Error {
    case processingFailed
    case invalidInput
    case missingAPIKey
}
