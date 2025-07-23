import Foundation
import SwiftUI

public struct EditorSettings {
    public let textColor: Color
    public let fontName: String
    public let fontSize: CGFloat

    public init(textColor: Color, fontName: String, fontSize: CGFloat) {
        self.textColor = textColor
        self.fontName = fontName
        self.fontSize = fontSize
    }
}

// MARK: - Editor State Protocol
public protocol EditorModeState {
    var name: String { get }
    func insertionPointColor(settings: EditorSettings) -> NSColor

    /// Return true if the event is fully handled (prevent default text insertion), false to let the OS handle it.
    func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool
}

// MARK: - Insert Mode State
public struct InsertModeState: EditorModeState {
    public let name = "INSERT"

    public init() {}

    public func insertionPointColor(settings: EditorSettings) -> NSColor {
        return NSColor(settings.textColor)
    }

    public func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
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
public struct NormalModeState: EditorModeState {
    public let name = "NORMAL"

    public init() {}

    public func insertionPointColor(settings: EditorSettings) -> NSColor {
        return .clear
    }

    public func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
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
public struct VisualModeState: EditorModeState {
    public let name = "VISUAL"
    public let anchor: Int

    public init(anchor: Int) {
        self.anchor = anchor
    }

    public func insertionPointColor(settings: EditorSettings) -> NSColor {
        return .clear
    }

    public func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
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
public struct VisualLineModeState: EditorModeState {
    public let name = "VISUAL LINE"
    public let anchor: Int

    public init(anchor: Int) {
        self.anchor = anchor
    }

    public func insertionPointColor(settings: EditorSettings) -> NSColor {
        return .clear
    }

    public func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
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
