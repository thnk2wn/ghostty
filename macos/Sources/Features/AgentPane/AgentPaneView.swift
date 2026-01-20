import SwiftUI
import Combine

struct AgentPaneView: View {
    @ObservedObject var viewModel: AgentPaneViewModel
    @State private var inputText: String = ""
    @State private var showModeInfo: Bool = false
    @State private var hasConfigured: Bool = false
    @State private var inputHeight: CGFloat = 24
    @FocusState private var inputFocused: Bool

    var surfaceView: Ghostty.SurfaceView?

    var body: some View {
        VStack(spacing: 0) {
            // API Key warning (shows if missing)
            if !viewModel.hasAPIKey {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Missing API key - Set OPENAI_API_KEY or ANTHROPIC_API_KEY environment variable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .frame(height: 30)
            }

            // Main control bar
            HStack(alignment: .center, spacing: 12) {
                // Mode selector with info button
                HStack(alignment: .center, spacing: 2) {
                    Picker("Mode", selection: $viewModel.mode) {
                        ForEach(AgentMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)

                    Button(action: { showModeInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showModeInfo) {
                        ModeInfoPopover()
                    }
                }
                .padding(.trailing, 4)

                // Layout picker button
                LayoutPickerButton(
                    useRichOverlays: Binding(
                        get: { viewModel.useRichOverlays },
                        set: { newValue in
                            viewModel.useRichOverlays = newValue
                            viewModel.saveConfig()
                        }
                    )
                )

                Spacer()

                // Model selector
                Menu {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Button(model) {
                            viewModel.selectedModel = model
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedModel)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)

                // Clear blocks button
                if !viewModel.outputBlocks.isEmpty || !viewModel.richBlocks.isEmpty {
                    Button(action: { viewModel.clearBlocks() }) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear output blocks")
                }
            }
            .frame(height: 40)
            .padding(.horizontal)
            .background(viewModel.mode.color.opacity(0.1))

            Divider()

            // Input area
            HStack(alignment: .bottom, spacing: 8) {
                MultiLineTextFieldWrapper(
                    text: $inputText,
                    placeholder: placeholderForMode(viewModel.mode),
                    onSubmit: submitInput,
                    focused: $inputFocused,
                    height: $inputHeight
                )
                .frame(height: inputHeight)

                Button(action: submitInput) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.mode.color)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || viewModel.isProcessing)
                .help("Send message (⏎)\nNew line (⇧⏎)")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            inputFocused = true
            tryConfigureSurface()
        }
        .onChange(of: surfaceView?.id) { _ in
            tryConfigureSurface()
        }
    }

    private func tryConfigureSurface() {
        guard !hasConfigured else { return }

        if let surface = surfaceView {
            viewModel.configure(surface: surface)
            hasConfigured = true
        }
    }

    private func submitInput() {
        guard !inputText.isEmpty else { return }
        viewModel.submitInput(inputText)
        inputText = ""
        inputHeight = 24
    }

    private func placeholderForMode(_ mode: AgentMode) -> String {
        switch mode {
        case .agent:
            return "Tell me what to do... (I can execute commands)"
        case .ask:
            return "Ask me anything about your terminal..."
        case .plan:
            return "What would you like me to plan?"
        }
    }
}

struct ModeInfoPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Agent Modes")
                .font(.headline)

            ForEach(AgentMode.allCases) { mode in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: mode.icon)
                        .foregroundColor(mode.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 350)
    }
}

/// Inline approval view that appears within the output panel
struct InlineApprovalView: View {
    let commands: [String]
    let onApprove: () -> Void
    let onReject: () -> Void

    private static let maxHeight: CGFloat = 150
    private static let maxCharactersPerCommand: Int = 1500

    private var displayCode: String {
        commands.map { command in
            if command.count > Self.maxCharactersPerCommand {
                return String(command.prefix(Self.maxCharactersPerCommand)) + "\n... (truncated)"
            }
            return command
        }.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14, weight: .medium))

                Text("Approval Required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)

                Spacer()

                HStack(spacing: 8) {
                    Button("Reject") {
                        onReject()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Approve") {
                        onApprove()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.08))

            // Code block
            ApprovalCodeBlockView(
                code: displayCode,
                maxHeight: Self.maxHeight
            )
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.98))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

struct ApprovalCodeBlockView: View {
    let code: String
    let maxHeight: CGFloat
    @State private var isHovering = false
    @State private var copied = false
    @State private var contentOverflows = false

    private var lines: [String] {
        code.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text("shell")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)

                Spacer()

                if contentOverflows {
                    Text("scroll for more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }

                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundColor(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || copied ? 1 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            // Code content with scroll and max height
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers column
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...max(lines.count, 1), id: \.self) { num in
                            Text("\(num)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.5))
                                .frame(height: 16)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

                    Divider()

                    // Code content with syntax highlighting
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(SyntaxHighlighter.highlight(line: line, language: "bash"))
                                .font(.system(size: 12, design: .monospaced))
                                .frame(height: 16, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .textSelection(.enabled)
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.onAppear {
                            contentOverflows = geometry.size.height > maxHeight
                        }
                        .onChange(of: code) { _ in
                            contentOverflows = geometry.size.height > maxHeight
                        }
                    }
                )
            }
            .frame(maxHeight: maxHeight)
            .background(Color(NSColor.textBackgroundColor).opacity(0.3))
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

#Preview {
    AgentPaneView(viewModel: AgentPaneViewModel())
        .frame(width: 600, height: 400)
}
