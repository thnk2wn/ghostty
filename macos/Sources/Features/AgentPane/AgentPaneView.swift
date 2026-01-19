import SwiftUI
import Combine

struct AgentPaneView: View {
    @ObservedObject var viewModel: AgentPaneViewModel
    @State private var inputText: String = ""
    @State private var showModeInfo: Bool = false
    @State private var hasConfigured: Bool = false
    @FocusState private var inputFocused: Bool

    var surfaceView: Ghostty.SurfaceView?

    var body: some View {
        VStack(spacing: 0) {
            // Processing indicator (shows at top when thinking)
            if viewModel.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Thinking...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(viewModel.mode.color.opacity(0.05))
            }

            // Approval dialog (shows at top when commands need approval)
            if !viewModel.pendingCommands.isEmpty {
                ApprovalView(
                    commands: viewModel.pendingCommands,
                    onApprove: { viewModel.executeCommands() },
                    onReject: { viewModel.rejectCommands() }
                )
                .padding(.horizontal)
                .padding(.top, 6)
            }

            // Main control bar
            HStack(spacing: 12) {
                // Mode selector
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
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showModeInfo) {
                    ModeInfoPopover()
                }

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
                if !viewModel.outputBlocks.isEmpty {
                    Button(action: { viewModel.clearBlocks() }) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear output blocks")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(viewModel.mode.color.opacity(0.1))

            Divider()

            // Input area
            HStack(spacing: 8) {
                TextField(placeholderForMode(viewModel.mode), text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit {
                        submitInput()
                    }

                Button(action: submitInput) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.mode.color)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || viewModel.isProcessing)
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(height: viewModel.pendingCommands.isEmpty ? 80 : 180)
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

struct ApprovalView: View {
    let commands: [String]
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Approval Required")
                    .font(.headline)
            }

            Text("The agent wants to execute the following commands:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(commands, id: \.self) { command in
                    Text(command)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                Button("Reject", role: .cancel) {
                    onReject()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Approve") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 2)
        )
    }
}

#Preview {
    AgentPaneView(viewModel: AgentPaneViewModel())
        .frame(width: 600, height: 400)
}
