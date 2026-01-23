import SwiftUI
import AppKit

/// A Warp-style output block that appears in the terminal (legacy version)
struct AgentOutputBlock: View {
    let message: AgentOutputMessage
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                // Mode icon
                Image(systemName: message.mode.iconName)
                    .foregroundColor(message.mode.color)
                    .font(.system(size: 14, weight: .medium))

                Text(message.mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(message.mode.color)

                if message.isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }

                Spacer()

                // Collapse/expand button (only if not processing)
                if !message.isProcessing {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(message.mode.color.opacity(0.08))

            // Content
            if isExpanded && !message.isProcessing {
                VStack(alignment: .leading, spacing: 12) {
                    if let query = message.query {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(query)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                        Divider()
                            .padding(.horizontal, 12)
                    }

                    if let content = message.content {
                        Text(content)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .padding(.horizontal, 12)
                    }

                    if let commands = message.commands, !commands.isEmpty {
                        Divider()
                            .padding(.horizontal, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Commands:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)

                            ForEach(Array(commands.enumerated()), id: \.offset) { _, cmd in
                                HStack(spacing: 8) {
                                    Image(systemName: "terminal")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(cmd)
                                        .font(.system(size: 12, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.98))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(message.mode.color.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Rich AI Block View

/// Rich block view with full markdown rendering
struct RichAIBlockView: View {
    let block: RichAIBlock
    var onCollapse: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var copied = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Image(systemName: block.mode.iconName)
                    .foregroundColor(block.mode.color)
                    .font(.system(size: 14, weight: .medium))

                Text(block.mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(block.mode.color)

                if block.isStreaming {
                    StreamingIndicator()
                }

                Spacer()

                // Action buttons (visible on hover or always on touch)
                HStack(spacing: 4) {
                    // Copy all button
                    Button(action: copyAllContent) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(copied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy response")

                    // Collapse button
                    Button(action: { onCollapse?() }) {
                        Image(systemName: block.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(block.isCollapsed ? "Expand" : "Collapse")

                    // Dismiss button
                    if let onDismiss = onDismiss {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Dismiss")
                    }
                }
                .opacity(isHovering ? 1 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(block.mode.color.opacity(0.08))

            // Content
            if !block.isCollapsed {
                VStack(alignment: .leading, spacing: 12) {
                    // Query (if present)
                    if let query = block.query {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(query)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                        Divider()
                            .padding(.horizontal, 12)
                    }

                    // Content - use simple text during streaming for performance
                    if !block.content.isEmpty {
                        if block.isStreaming {
                            // Fast plain text rendering during streaming
                            Text(block.content)
                                .font(.system(size: 13, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                        } else {
                            // Rich markdown rendering when complete
                            RichMarkdownView(content: block.content, showLineNumbers: true)
                                .padding(.horizontal, 12)
                        }
                    } else if block.isStreaming {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Generating response...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.98))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(block.mode.color.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func copyAllContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(block.content, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

// MARK: - Streaming Indicator

struct StreamingIndicator: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .opacity(index <= dotCount ? 1 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

extension AgentMode {
    var iconName: String {
        switch self {
        case .agent: return "cpu"
        case .ask: return "bubble.left.fill"
        case .plan: return "list.bullet.rectangle"
        }
    }

    var displayName: String {
        switch self {
        case .agent: return "Agent"
        case .ask: return "Ask"
        case .plan: return "Plan"
        }
    }
}
