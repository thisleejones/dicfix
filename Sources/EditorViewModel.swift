import SwiftUI

// MARK: - Editor View Model (State Machine)
class EditorViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var cursorPosition: Int = 0
    @Published private(set) var mode: EditorModeState = InsertModeState()
    var onQuit: (() -> Void)?
    var onSubmit: (() -> Void)?

    init() {
        // Initial state is set directly.
    }
    func switchToInsertMode() {
        print("[EditorViewModel] Switching to InsertModeState")
        mode = InsertModeState()
    }
    func switchToNormalMode() {
        print("[EditorViewModel] Switching to NormalModeState")
        mode = NormalModeState()
    }
    func requestQuit() {
        print("[EditorViewModel] Quit requested.")
        onQuit?()
    }
    func requestSubmit() {
        print("[EditorViewModel] Submit requested.")
        onSubmit?()
    }

    func moveCursorToEndOfLine() {
        cursorPosition = text.count
    }

    func moveCursorToNextCharacter() {
        if cursorPosition < text.count {
            cursorPosition += 1
        }
    }

    func moveCursorToBeginningOfLine() {
        // For now, this is a simple stub.
        // A real implementation would need to find the start of the current line.
        cursorPosition = 0
        print("[EditorViewModel] moveCursorToBeginningOfLine")
    }

    func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
        print("[EditorViewModel] moveCursorLeft")
    }

    func moveCursorRight() {
        if cursorPosition < text.count {
            cursorPosition += 1
        }
        print("[EditorViewModel] moveCursorRight")
    }

    func moveCursorUp() {
        // Stub - requires line analysis
        print("[EditorViewModel] moveCursorUp")
    }

    func moveCursorDown() {
        // Stub - requires line analysis
        print("[EditorViewModel] moveCursorDown")
    }

    // MARK: - Word Movement Logic

    private struct TextScanner {
        enum CharType { case word, punctuation, whitespace }
        enum Direction { case forward, backward }

        private let text: [Character]
        private let direction: Direction
        private(set) var index: Int

        init(text: String, index: Int, direction: Direction) {
            self.text = Array(text)
            self.index = index
            self.direction = direction
        }

        var isAtEnd: Bool {
            direction == .forward ? index >= text.count : index < 0
        }

        var currentType: CharType {
            guard !isAtEnd else { return .whitespace }
            let char = text[index]
            if char.isWhitespace { return .whitespace }
            if char.isLetter || char.isNumber || char == "_" { return .word }
            return .punctuation
        }

        mutating func advance() {
            index += (direction == .forward ? 1 : -1)
        }
    }

    func moveCursorForwardByWord(isWORD: Bool = false) {
        var scanner = TextScanner(text: text, index: cursorPosition, direction: .forward)
        if scanner.isAtEnd { return }

        // If starting on whitespace, find the next non-whitespace character.
        if scanner.currentType == .whitespace {
            while !scanner.isAtEnd && scanner.currentType == .whitespace {
                scanner.advance()
            }
        } else {
            // Otherwise, skip the current group of characters...
            let initialType = scanner.currentType
            if isWORD {
                // For WORD, skip all non-whitespace characters
                while !scanner.isAtEnd && scanner.currentType != .whitespace {
                    scanner.advance()
                }
            } else {
                // For word or punctuation, skip the current block of same-type characters
                while !scanner.isAtEnd && scanner.currentType == initialType {
                    scanner.advance()
                }
            }
            // ...and then skip any subsequent whitespace to find the beginning of the next word.
            while !scanner.isAtEnd && scanner.currentType == .whitespace {
                scanner.advance()
            }
        }
        
        cursorPosition = scanner.index
    }

    func moveCursorBackwardByWord(isWORD: Bool = false) {
        if cursorPosition == 0 { return }
        var scanner = TextScanner(text: text, index: cursorPosition - 1, direction: .backward)

        // Skip initial whitespace
        while !scanner.isAtEnd && scanner.currentType == .whitespace {
            scanner.advance()
        }
        if scanner.isAtEnd {
            cursorPosition = 0
            return
        }

        // Skip the current group of characters
        let initialType = scanner.currentType
        if isWORD {
            // For WORD, skip all non-whitespace characters
            while !scanner.isAtEnd && scanner.currentType != .whitespace {
                scanner.advance()
            }
        } else {
            // For word or punctuation, skip the current block of same-type characters
            while !scanner.isAtEnd && scanner.currentType == initialType {
                scanner.advance()
            }
        }
        
        cursorPosition = scanner.index + 1
    }
}