import SwiftUI

/// Layout picker popup for choosing between rich panel and integrated terminal modes
struct LayoutPickerView: View {
    @Binding var isPresented: Bool
    @Binding var useRichOverlays: Bool

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
                    description: "AI responses appear in a separate scrollable panel with syntax highlighting, copy buttons, and formatted code blocks.",
                    isSelected: useRichOverlays,
                    preview: { RichPanelPreview() }
                ) {
                    useRichOverlays = true
                    isPresented = false
                }

                // Integrated Terminal option
                LayoutOptionCard(
                    title: "Integrated Terminal",
                    description: "AI responses render directly in the terminal with basic ANSI markdown formatting. Scrolls naturally with terminal content.",
                    isSelected: !useRichOverlays,
                    preview: { IntegratedTerminalPreview() }
                ) {
                    useRichOverlays = false
                    isPresented = false
                }
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // AI input area at top
                HStack {
                    Text("list files modified in the past hour")
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                }
                .font(.system(size: 8, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(height: geometry.size.height * 0.13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.8))

                Divider()

                // Rich panel preview
                VStack(alignment: .leading, spacing: 4) {
                    // Header
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.blue)

                        Text("Ask")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.blue)

                        Spacer()

                        // Action icons
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.secondary)

                            Image(systemName: "xmark")
                                .font(.system(size: 6, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))

                    // Content preview
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Here's the command:")
                            .font(.system(size: 7))

                        // Code block preview
                        HStack(spacing: 4) {
                            Text("1")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("find . -mmin -60")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                        .padding(3)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(3)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)

                    Spacer(minLength: 0)
                }
                .frame(height: geometry.size.height * 0.38)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Terminal prompt at bottom (remaining space)
                HStack(spacing: 0) {
                    Text("$ ")
                        .foregroundColor(.green)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 6, height: 10)
                    Spacer()
                }
                .font(.system(size: 9, design: .monospaced))
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
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
        VStack(spacing: 0) {
            // AI input area at top
            HStack {
                Text("list files modified in the past hour")
                    .foregroundColor(.primary)
                Spacer()
            }
            .font(.system(size: 8, design: .monospaced))
            .padding(6)
            .background(Color.black.opacity(0.85))

            // Separator line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            // Terminal content
            VStack(alignment: .leading, spacing: 2) {
                Group {
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

                    Text("  find . -mmin -60")
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
        }
        .cornerRadius(6)
    }
}

// MARK: - Layout Button for Toolbar

struct LayoutPickerButton: View {
    @Binding var useRichOverlays: Bool
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
                useRichOverlays: $useRichOverlays
            )
        }
    }
}

// MARK: - Preview

#Preview {
    LayoutPickerView(
        isPresented: .constant(true),
        useRichOverlays: .constant(true)
    )
    .padding()
    .frame(width: 600, height: 400)
}
