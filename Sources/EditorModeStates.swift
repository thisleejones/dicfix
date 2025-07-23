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
