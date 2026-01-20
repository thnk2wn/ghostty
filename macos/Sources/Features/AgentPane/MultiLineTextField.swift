import SwiftUI
import AppKit

class ConstrainedScrollView: NSScrollView {
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 24)
    }
}

struct MultiLineTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var focused: FocusState<Bool>.Binding
    @Binding var height: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> ConstrainedScrollView {
        let scrollView = ConstrainedScrollView()
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 4, height: 2)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.isFieldEditor = true
        textView.usesFindBar = false
        textView.autoresizingMask = [.width]
        
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: ConstrainedScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        context.coordinator.updateText(textView.string)
        
        if textView.string != text {
            let selectedRange = textView.selectedRanges.first as? NSRange ?? NSRange(location: 0, length: 0)
            textView.string = text
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }
        
        DispatchQueue.main.async {
            if focused.wrappedValue && textView.window?.firstResponder != textView {
                textView.window?.makeFirstResponder(textView)
            }
        }
        
        context.coordinator.placeholder = placeholder
        
        // Calculate content height
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            let usedRect = layoutManager.usedRect(for: textContainer)
            let contentHeight = usedRect.height + textView.textContainerInset.height * 2 + 4
            let minHeight: CGFloat = 24
            let maxHeight: CGFloat = 120
            let newHeight = min(max(contentHeight, minHeight), maxHeight)
            
            if abs(newHeight - height) > 1 {
                DispatchQueue.main.async {
                    height = newHeight
                }
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultiLineTextField
        var placeholder: String = ""
        private var currentText: String = ""
        
        init(_ parent: MultiLineTextField) {
            self.parent = parent
            self.placeholder = parent.placeholder
        }
        
        func updateText(_ text: String) {
            currentText = text
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            if newText != currentText {
                currentText = newText
                parent.text = newText
                
                // Recalculate height
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                if let layoutManager = textView.layoutManager,
                   let textContainer = textView.textContainer {
                    let usedRect = layoutManager.usedRect(for: textContainer)
                    let contentHeight = usedRect.height + textView.textContainerInset.height * 2 + 4
                    let minHeight: CGFloat = 24
                    let maxHeight: CGFloat = 120
                    let newHeight = min(max(contentHeight, minHeight), maxHeight)
                    
                    if abs(newHeight - parent.height) > 1 {
                        parent.height = newHeight
                    }
                }
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                } else {
                    parent.onSubmit()
                    return true
                }
            }
            return false
        }
    }
}

struct MultiLineTextFieldWrapper: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    @FocusState.Binding var focused: Bool
    @Binding var height: CGFloat
    
    var body: some View {
        MultiLineTextField(
            text: $text,
            placeholder: placeholder,
            onSubmit: onSubmit,
            focused: $focused,
            height: $height
        )
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}
