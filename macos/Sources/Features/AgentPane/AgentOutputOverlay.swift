import SwiftUI

/// Overlay that displays AI agent output blocks on top of the terminal
struct AgentOutputOverlay: View {
    @ObservedObject var viewModel: AgentPaneViewModel

    var body: some View {
        if !viewModel.outputBlocks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Spacer()

                // Display blocks from bottom up (most recent at bottom)
                ForEach(viewModel.outputBlocks.suffix(3)) { block in
                    AgentOutputBlock(message: block)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 8)
            .allowsHitTesting(true)
        }
    }
}
