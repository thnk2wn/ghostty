import SwiftUI

/// Layout picker popup for choosing between rich panel and integrated terminal modes
struct LayoutPickerView: View {
    @Binding var isPresented: Bool
    @Binding var useRichOverlays: Bool
    @Binding var dontShowAgain: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Choose AI Output Layout")
                .font(.headline)
                .padding(.top, 4)

            // Layout options
            HStack(spacing: 20) {
                // Rich Panel option
                LayoutOptionCard(
                    title: "Rich Panel",
                    description: "AI responses appear in a scrollable panel with syntax highlighting, copy buttons, and formatted code blocks.",
                    isSelected: useRichOverlays,
                    preview: { RichPanelPreview() }
                ) {
                    useRichOverlays = true
                    isPresented = false
                }

                // Integrated Terminal option
                LayoutOptionCard(
                    title: "Integrated Terminal",
                    description: "AI responses render directly in the terminal with ANSI formatting. Scrolls naturally with terminal content.",
                    isSelected: !useRichOverlays,
                    preview: { IntegratedTerminalPreview() }
                ) {
                    useRichOverlays = false
                    isPresented = false
                }
            }

            Divider()

            // Don't show again checkbox
            HStack {
                Toggle(isOn: $dontShowAgain) {
                    Text("Don't show this again")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Layout Option Card

struct LayoutOptionCard<Preview: View>: View {
    let title: String
    let description: String
    let isSelected: Bool
    @ViewBuilder let preview: () -> Preview
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Preview area
                preview()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )

                // Title with checkmark
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                }

                // Description
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 240)
            .background(isHovering ? Color.accentColor.opacity(0.05) : Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Rich Panel Preview

struct RichPanelPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            // Terminal area (small)
            HStack {
                Text("$ ")
                    .foregroundColor(.green)
                Text("ls -la")
                    .foregroundColor(.primary)
                Spacer()
            }
            .font(.system(size: 9, design: .monospaced))
            .padding(6)
            .background(Color.black.opacity(0.8))

            Divider()

            // Rich panel preview
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                    Text("Ask")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))

                // Content preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Here's the command:")
                        .font(.system(size: 8))

                    // Code block preview
                    HStack(spacing: 4) {
                        Text("1")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("ls -la /home")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
                }
                .padding(.horizontal, 6)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Integrated Terminal Preview

struct IntegratedTerminalPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Terminal content
            Group {
                HStack(spacing: 0) {
                    Text("$ ")
                        .foregroundColor(.green)
                    Text("ask \"how to list files\"")
                        .foregroundColor(.primary)
                }

                Text("")

                HStack(spacing: 0) {
                    Text("▸ ")
                        .foregroundColor(.blue)
                    Text("Here's the command:")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                Text("")

                Text("bash ────────────────────")
                    .foregroundColor(.gray)

                Text("  ls -la /home")
                    .foregroundColor(.gray.opacity(0.8))

                Text("────────────────────────")
                    .foregroundColor(.gray)

                Text("")

                HStack(spacing: 0) {
                    Text("$ ")
                        .foregroundColor(.green)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 6, height: 10)
                }
            }
            .font(.system(size: 8, design: .monospaced))

            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.85))
        .cornerRadius(6)
    }
}

// MARK: - Layout Button for Toolbar

struct LayoutPickerButton: View {
    @Binding var useRichOverlays: Bool
    @Binding var dontShowAgain: Bool
    @State private var showingPicker = false

    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack(spacing: 4) {
                Image(systemName: useRichOverlays ? "rectangle.split.1x2" : "terminal")
                    .font(.system(size: 11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(useRichOverlays ? "Rich Panel Layout" : "Integrated Terminal Layout")
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            LayoutPickerView(
                isPresented: $showingPicker,
                useRichOverlays: $useRichOverlays,
                dontShowAgain: $dontShowAgain
            )
        }
    }
}

// MARK: - Preview

#Preview {
    LayoutPickerView(
        isPresented: .constant(true),
        useRichOverlays: .constant(true),
        dontShowAgain: .constant(false)
    )
    .padding()
    .frame(width: 600, height: 400)
}
