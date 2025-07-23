import Foundation
import SwiftUI

// MARK: - Editor State Protocol
protocol EditorModeState {
    var name: String { get }
    func insertionPointColor(settings: AppSettings) -> NSColor

    /// Return true if the event is fully handled (prevent default text insertion), false to let the OS handle it.
    func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool
}

// MARK: - Insert Mode State
struct InsertModeState: EditorModeState {
    let name = "INSERT"

    func insertionPointColor(settings: AppSettings) -> NSColor {
        return NSColor(ColorMapper.parseColor(settings.textColor))
    }

    func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
        // Escape leaves insert mode.
        if keyEvent.key == .escape {
            print("[InsertModeState] Detected Escape. Switching to Normal mode.")
            editor.switchToNormalMode()
            return true  // Event handled.
        }

        if keyEvent.mods.isControl, keyEvent.key == .j {
            editor.insertNewline()
            return true
        }

        // Let system insert characters in Insert mode.
        return false
    }
}

// MARK: - Normal Mode State
struct NormalModeState: EditorModeState {
    let name = "NORMAL"

    func insertionPointColor(settings: AppSettings) -> NSColor {
        return .clear
    }

    func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
        // In Normal mode, we translate the KeyEvent to a EditorCommandToken
        // and feed it to the state machine. We always return true to prevent
        // the default system behavior (e.g., inserting a 'j' character).
        if let token = EditorCommandToken.from(keyEvent: keyEvent) {
            editor.handleToken(token)
        }

        return true
    }
}

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

// MARK: - Visual Line Mode State
struct VisualLineModeState: EditorModeState {
    let name = "VISUAL LINE"
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
        if let motion = token.toMotion {
            // In visual line mode, most motions are line-wise
            let lineWiseMotions: [EditorMotion] = [
                .lineUp, .lineDown, .goToEndOfFile, .goToStartOfLine,
            ]
            if lineWiseMotions.contains(motion) {
                editor.commandSM.executeMotion(motion, count: 1, editor: editor)
            }
        } else if let op = token.toOperator {
            if let selectionRange = editor.selection {
                editor.executeOperator(op, range: selectionRange)
            }
            editor.switchToNormalMode()
        }
    }
}
