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
        // print(
        //     "[InsertModeState] handleEvent for key code: \(keyEvent.key?.rawValue ?? keyEvent.keyCode)"
        // )

        // Escape leaves insert mode.
        if keyEvent.key == .escape {
            print("[InsertModeState] Detected Escape. Switching to Normal mode.")
            editor.switchToNormalMode()
            return true  // Event handled.
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

        // --- VIM MOTION KEYS ---
        // case .j where keyEvent.mods.isOnlyControl:
        //     Swift.print("[NormalModeState] Ctrl-j detected.")
        //     // Future: Add action for Ctrl-j (scroll forward through history)
        //     return true
        // case .j where keyEvent.mods.isUnmodified:
        //     editor.moveCursorDown()
        //     return true
        // case .k where keyEvent.mods.isOnlyControl:
        //     // Future: Add action for Ctrl-k (scroll back through history)
        //     Swift.print("[NormalModeState] Ctrl-k detected.")
        // case .j where keyEvent.mods.isUnmodified:
        //     editor.moveCursorUp()
        //     return true
        // case .h where keyEvent.mods.isUnmodified:
        //     editor.moveCursorLeft()
        //     return true
        // case .l where keyEvent.mods.isUnmodified:
        //     editor.moveCursorRight()
        //     return true

        // // --- VIM MOTION KEYS/WORD MOVEMENT ---
        // case .b where keyEvent.mods.isOnlyShift:
        //     editor.moveCursorBackwardByWord(isWORD: true)
        //     return true
        // case .b where keyEvent.mods.isUnmodified:
        //     editor.moveCursorBackwardByWord()
        //     return true
        // case .w where keyEvent.mods.isOnlyShift:
        //     editor.moveCursorForwardByWord(isWORD: true)
        //     return true
        // case .w where keyEvent.mods.isUnmodified:
        //     editor.moveCursorForwardByWord()
        //     return true

        // // --- VIM EDITING/MODE-SWITCH KEYS ---
        // case .i where keyEvent.mods.isOnlyShift:
        //     editor.moveCursorToBeginningOfLine()
        //     // TODO: should skip whitespace
        //     editor.switchToInsertMode()
        //     return true
        // case .i where keyEvent.mods.isUnmodified:
        //     editor.switchToInsertMode()
        //     return true

        // case .a where keyEvent.mods.isOnlyShift:
        //     editor.moveCursorToEndOfLine()
        //     editor.switchToInsertMode()
        //     return true
        // case .a where keyEvent.mods.isUnmodified:
        //     editor.moveCursorToNextCharacter()
        //     editor.switchToInsertMode()
        //     return true
        // default:
        //     break
        // }

        return true
    }
}
