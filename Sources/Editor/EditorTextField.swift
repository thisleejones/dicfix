import SwiftUI

// The NSViewRepresentable that wraps our InterceptingTextView.
public struct EditorTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    var viewModel: EditorViewModel
    var settings: EditorSettings
    var onSubmit: () -> Void

    // A custom NSTextView that correctly intercepts all key events.
    private class InterceptingTextView: NSTextView {
        var onKeyDown: ((NSEvent) -> Bool)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if onKeyDown?(event) == true {
                // If the event was handled by our custom logic, we stop.
                return
            }
            // Otherwise, allow default NSTextView behavior (e.g., typing).
            super.keyDown(with: event)
        }

        // Treat Enter as a submit action, not a newline.
        override func insertNewline(_ sender: Any?) {
            // This is handled by the coordinator's `textView(_:doCommandBy:)`.
            super.insertNewline(sender)
        }
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let textView = InterceptingTextView()
        textView.onKeyDown = context.coordinator.handleKeyDown

        // Configure to look like a borderless text field
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.font = NSFont(
            name: settings.fontName,
            size: CGFloat(settings.fontSize)
        )
        // Set the color for any new text that is typed.
        let textColor = NSColor(settings.textColor)
        textView.typingAttributes[.foregroundColor] = textColor
        textView.textColor = textColor
        textView.delegate = context.coordinator
        if let tc = textView.textContainer {
            tc.widthTracksTextView = true
            tc.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            tc.lineFragmentPadding = 0
        }
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = nsView.documentView as? InterceptingTextView else { return }

        let textColor = NSColor(settings.textColor)
        // Always ensure typing attributes are up-to-date.
        textView.typingAttributes[.foregroundColor] = textColor
        textView.textColor = textColor

        // Keep the sync, but don't gate the attribute fix behind it
        if textView.string != text {
            textView.string = text
        }
        
        // Handle selection display
        if let selection = viewModel.selection {
            let nsRange = NSRange(location: selection.lowerBound, length: selection.count)
            if textView.selectedRange != nsRange {
                textView.selectedRange = nsRange
            }
        } else {
            // If no selection, just update the cursor position
            if textView.selectedRange.location != cursorPosition
                || textView.selectedRange.length != 0
            {
                textView.selectedRange = NSRange(location: cursorPosition, length: 0)
            }
        }

        // Ensure the cursor is always visible after an update
        let cursorRange = NSRange(location: cursorPosition, length: 0)
        textView.scrollRangeToVisible(cursorRange)

        textView.insertionPointColor = viewModel.mode.insertionPointColor(
            settings: settings)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextField

        init(_ parent: EditorTextField) {
            self.parent = parent
        }

        // The single entry point for all key events.
        func handleKeyDown(event: NSEvent) -> Bool {
            let keyEvent = KeyEvent.from(event: event)
            return parent.viewModel.mode.handleEvent(keyEvent, editor: parent.viewModel)
        }

        // Delegate method for text changes.
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.cursorPosition = textView.selectedRange.location
        }

        // Delegate method for selection changes (mouse, arrow keys).
        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.cursorPosition = textView.selectedRange.location
        }

        // Delegate method for command keys (Enter, Escape, etc.).
        public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.viewModel.requestSubmit()
                return true
            }

            if let event = NSApp.currentEvent {
                return handleKeyDown(event: event)
            }

            return false
        }
    }
}
