import SwiftUI

/// A Warp-style output block that appears in the terminal
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
