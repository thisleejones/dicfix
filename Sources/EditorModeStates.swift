import SwiftUI

// MARK: - Editor State Protocol
protocol EditorModeState {
    var name: String { get }
    func insertionPointColor(settings: AppSettings) -> NSColor
    // The one and only function for handling key press events.
    func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool
}

// MARK: - Insert Mode State
struct InsertModeState: EditorModeState {
    let name = "INSERT"

    func insertionPointColor(settings: AppSettings) -> NSColor {
        return NSColor(ColorMapper.parseColor(settings.textColor))
    }

    func handleEvent(_ keyEvent: KeyEvent, editor: EditorViewModel) -> Bool {
        print(
            "[InsertModeState] handleEvent for key code: \(keyEvent.key?.rawValue ?? keyEvent.keyCode)"
        )

        if keyEvent.key == .escape {
            print("[InsertModeState] Detected Escape. Switching to Normal mode.")
            editor.switchToNormalMode()
            return true  // Event handled.
        }

        print("[InsertModeState] Event not handled. Allowing default behavior.")
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
        // Use the new `mods` helper for cleaner logging and checks
        // let charsForPrint =
        //     keyEvent.characters?.replacingOccurrences(of: "\n", with: "<newline>")
        //     .replacingOccurrences(of: "\r", with: "<return>") ?? "nil"
        // print(
        //     "[NormalModeState] handleEvent: key=\(keyEvent.key?.rawValue ?? 0), keyCode=\(keyEvent.keyCode), mods: shift=\(keyEvent.mods.isShift), ctrl=\(keyEvent.mods.isControl), opt=\(keyEvent.mods.isOption), cmd=\(keyEvent.mods.isCommand), chars=\(charsForPrint)"
        // )

        if let key = keyEvent.key {
            switch key {
            case .escape:
                print("[NormalModeState] Escape pressed.")
                editor.requestQuit()
                return true

            case .enter, .keypadEnter:
                print("[NormalModeState] Enter pressed.")
                editor.requestSubmit()
                return true

            // --- VIM MOTION KEYS ---
            case .j:
                if keyEvent.mods.isOnlyControl {
                    print("[NormalModeState] Ctrl-j detected.")
                    // Future: Add action for Ctrl-j
                } else if keyEvent.mods.isUnmodified {
                    editor.moveCursorDown()
                }
                return true
            case .k:
                if keyEvent.mods.isOnlyControl {
                    print("[NormalModeState] Ctrl-k detected.")
                } else if keyEvent.mods.isUnmodified {
                    editor.moveCursorUp()
                }
                return true
            case .h:
                if keyEvent.mods.isUnmodified {
                    editor.moveCursorLeft()
                }
                return true
            case .l:
                if keyEvent.mods.isUnmodified {
                    editor.moveCursorRight()
                }
                return true
            case .b:
                if keyEvent.mods.isOnlyShift {
                    editor.moveCursorBackwardByWord(isWORD: true)
                } else if keyEvent.mods.isUnmodified {
                    editor.moveCursorBackwardByWord()
                }
                return true
            case .w:
                if keyEvent.mods.isOnlyShift {
                    editor.moveCursorForwardByWord(isWORD: true)
                } else if keyEvent.mods.isUnmodified {
                    editor.moveCursorForwardByWord()
                }
                return true

            // --- VIM EDITING/MODE-SWITCH KEYS ---
            case .i:
                if keyEvent.characters == "I" {
                    print(
                        "[NormalModeState] 'I' detected. Switching to insert mode at start of line."
                    )
                    editor.moveCursorToBeginningOfLine()
                    editor.switchToInsertMode()
                } else {
                    print("[NormalModeState] 'i' detected. Switching to insert mode.")
                    editor.switchToInsertMode()
                }
                return true

            case .a:
                if keyEvent.characters == "A" {
                    print(
                        "[NormalModeState] 'A' detected. Switching to insert mode at end of line.")
                    editor.moveCursorToEndOfLine()
                    editor.switchToInsertMode()
                } else {
                    print("[NormalModeState] 'a' detected. Switching to insert mode after cursor.")
                    editor.moveCursorToNextCharacter()
                    editor.switchToInsertMode()
                }
                return true
            }
        }

        // If we fall through, it means no key-based command was handled.
        // We still consume the event to prevent typing in normal mode.
        print("[NormalModeState] Event not handled by any rule.")
        return true
    }
}
