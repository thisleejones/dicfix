import Foundation
import SwiftUI

// MARK: - Visual Mode State
struct VisualModeState: EditorModeState {
    let name = "VISUAL"
    let anchor: Int

    init(anchor: Int) {
        self.anchor = anchor
    }

    func insertionPointColor(settings: AppSettings) -> NSColor {
        return .clear
    }

    func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
        if keyEvent.key == .escape {
            editor.clearSelection()
            editor.switchToNormalMode()
            return true
        }

        if let token = EditorCommandToken.from(keyEvent: keyEvent) {
            handleToken(token, editor: editor)
        }

        return true
    }

    private func handleToken(_ token: EditorCommandToken, editor: EditorViewModel) {
        if let digit = token.toDigit {
            if digit == 0 && editor.visualModeCount == 0 {
                // '0' is a motion, not the start of a count.
                editor.commandSM.executeMotion(.goToStartOfLine, count: 1, editor: editor)
            } else {
                editor.visualModeCount = (editor.visualModeCount * 10) + digit
            }
            return
        }

        if let motion = token.toMotion {
            let executionCount = editor.visualModeCount > 0 ? editor.visualModeCount : 1
            editor.commandSM.executeMotion(motion, count: executionCount, editor: editor)
        } else if let op = token.toOperator {
            if let selectionRange = editor.selection {
                editor.executeOperator(op, range: selectionRange)
            }
            editor.switchToNormalMode()
        }
        
        // Reset count after a non-digit key is pressed.
        editor.visualModeCount = 0
    }
}
