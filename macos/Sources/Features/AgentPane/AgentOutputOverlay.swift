import SwiftUI

/// Bottom panel that displays AI agent output blocks
/// Positioned below the terminal, not overlaying it
struct AgentOutputOverlay: View {
    @ObservedObject var viewModel: AgentPaneViewModel
    var surfaceView: Ghostty.SurfaceView?

    // Resizing state - stored in view model for persistence
    @State private var panelHeight: CGFloat = 300
    @State private var isDragging: Bool = false
    @State private var dragStartHeight: CGFloat = 0

    private let minPanelHeight: CGFloat = 100
    private let maxPanelHeight: CGFloat = 600

    var body: some View {
        if viewModel.useRichOverlays && !viewModel.richBlocks.isEmpty {
            richBlocksPanel
        }
    }

    // MARK: - Rich Blocks Panel (bottom drawer)

    @ViewBuilder
    private var richBlocksPanel: some View {
        VStack(spacing: 0) {
            // Draggable splitter handle
            splitterHandle

            // Scrollable content
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.richBlocks) { block in
                            RichAIBlockView(
                                block: block,
                                onCollapse: { viewModel.toggleRichBlockCollapsed(blockId: block.id) },
                                onDismiss: { viewModel.removeRichBlock(blockId: block.id) }
                            )
                            .id(block.id)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.richBlocks.last?.content) { _ in
                    if let lastBlock = viewModel.richBlocks.last {
                        scrollProxy.scrollTo(lastBlock.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Splitter Handle

    private var splitterHandle: some View {
        VStack(spacing: 0) {
            // Drag handle area
            ZStack {
                Rectangle()
                    .fill(isDragging ? Color.accentColor.opacity(0.1) : Color(NSColor.windowBackgroundColor))

                Capsule()
                    .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 4)
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartHeight = panelHeight
                        }
                        // Dragging up (negative translation) increases panel height
                        let newHeight = dragStartHeight - value.translation.height
                        panelHeight = min(max(newHeight, minPanelHeight), maxPanelHeight)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }

            Rectangle()
                .fill(isDragging ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
    }
}
