import SwiftUI

// MARK: - Editor View Model (State Machine)
class EditorViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var cursorPosition: Int = 0
    @Published private(set) var mode: EditorModeState = InsertModeState()

    // Callbacks (optional)
    var onQuit: (() -> Void)?
    var onSubmit: (() -> Void)?

    // Internal command state machine (no UI dependency)
    private let commandSM = EditorCommandStateMachine()

    init() {
        // Initial state is set directly.
    }

    // MARK: Mode switches
    func switchToInsertMode() {
        print("[EditorViewModel] Switching to InsertModeState")
        mode = InsertModeState()
    }
    func switchToNormalMode() {
        print("[EditorViewModel] Switching to NormalModeState")
        mode = NormalModeState()
    }

    // MARK: App-level intents
    func requestQuit() {
        print("[EditorViewModel] Quit requested.")
        onQuit?()
    }
    func requestSubmit() {
        print("[EditorViewModel] Submit requested.")
        onSubmit?()
    }

    // MARK: Key handling entry
    @discardableResult
    func handleEvent(_ keyEvent: KeyEvent) -> Bool {
        mode.handleEvent(keyEvent, editor: self)
    }

    /// NormalModeState calls this to feed tokens into the command machine.
    func handleToken(_ token: EditorCommandToken) {
        commandSM.handleToken(token, editor: self)
    }

    //==================================================
    // MARK: - Cursor & Text Editing Helpers
    //==================================================

    func moveCursorToEndOfLine() {
        cursorPosition = text.count
    }

    func moveCursorToNextCharacter() {
        if cursorPosition < text.count {
            cursorPosition += 1
        }
    }

    func moveCursorToBeginningOfLine() {
        // TODO: find start of current visual line.
        cursorPosition = 0
    }

    func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
    }

    func moveCursorRight() {
        if cursorPosition < text.count {
            cursorPosition += 1
        }
    }

    func moveCursorUp() {
        // TODO: line math
    }

    func moveCursorDown() {
        // TODO: line math
    }

    func moveCursorScreenLineDown() {
        // TODO: Implement proper screen line (visual line) navigation.
        // For now, fallback to logical line navigation.
        moveCursorDown()
    }

    func moveCursorScreenLineUp() {
        // TODO: Implement proper screen line (visual line) navigation.
        // For now, fallback to logical line navigation.
        moveCursorUp()
    }

    func moveCursorToScreenLineStartNonBlank() {
        // TODO: Implement proper screen line (visual line) navigation.
        // For now, fallback to logical line navigation.
        moveCursorToBeginningOfLine() // Simplified
    }

    func moveCursorToScreenLineEnd() {
        // TODO: Implement proper screen line (visual line) navigation.
        // For now, fallback to logical line navigation.
        moveCursorToEndOfLine()
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

        if isWORD {
            // WORD = run of non-whitespace
            if scanner.currentType != .whitespace {
                while !scanner.isAtEnd && scanner.currentType != .whitespace { scanner.advance() }
            } else {
                while !scanner.isAtEnd && scanner.currentType == .whitespace { scanner.advance() }
            }
            while !scanner.isAtEnd && scanner.currentType == .whitespace { scanner.advance() }
            cursorPosition = scanner.index
            return
        }

        let startType = scanner.currentType

        if startType == .whitespace {
            // Jump to first non-space token
            while !scanner.isAtEnd && scanner.currentType == .whitespace { scanner.advance() }
            cursorPosition = scanner.index
            return
        }

        // Consume current run (word or punctuation)
        while !scanner.isAtEnd && scanner.currentType == startType { scanner.advance() }

        // If we just consumed a word, also skip the punctuation block right after it
        if startType == .word {
            while !scanner.isAtEnd && scanner.currentType == .punctuation { scanner.advance() }
        }

        // Skip trailing whitespace to land at next token start
        while !scanner.isAtEnd && scanner.currentType == .whitespace { scanner.advance() }

        cursorPosition = scanner.index
    }

    func moveCursorBackwardByWord(isWORD: Bool = false) {
        if cursorPosition == 0 { return }
        var scanner = TextScanner(text: text, index: cursorPosition - 1, direction: .backward)

        // Skip whitespace first
        while !scanner.isAtEnd && scanner.currentType == .whitespace { scanner.advance() }
        if scanner.isAtEnd {
            cursorPosition = 0
            return
        }

        if isWORD {
            // WORD = run of non-whitespace
            while !scanner.isAtEnd && scanner.currentType != .whitespace { scanner.advance() }
            cursorPosition = scanner.index + 1
            return
        }

        // If we land on punctuation, consume that block then continue into previous word
        if scanner.currentType == .punctuation {
            while !scanner.isAtEnd && scanner.currentType == .punctuation { scanner.advance() }
        }

        // Now consume the word (or whatever block we're on) to its beginning
        let blockType = scanner.currentType
        while !scanner.isAtEnd && scanner.currentType == blockType && blockType != .whitespace {
            scanner.advance()
        }

        cursorPosition = scanner.index + 1
    }

    func moveCursorToBeginningOfFile() {
        cursorPosition = 0
    }

    func moveCursorToEndOfFile() {
        cursorPosition = text.count
    }

    func goToEndOfFile() {
        moveCursorToEndOfFile()
    }

    func goToLine(_ line: Int) {
        print("Going to line: \(line)")
        // A count of 0 or 1 for 'G' goes to the first line.
        // 'gg' also results in a call to goToLine(1).
        if line <= 1 {
            moveCursorToBeginningOfFile()
        } 
        // A count of Int.max signifies going to the last line.
        else if line == Int.max {
            moveCursorToEndOfFile()
        }
        else {
            // This is a placeholder for real line-based navigation.
            // For now, any other line number also goes to the end.
            // TODO: Implement mapping a line number to a cursor index.
            print("goToLine for specific number (\(line)) not yet implemented.")
            moveCursorToEndOfFile()
        }
    }

    func selectLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        
        // Adjust the cursor to the end of the line selection
        cursorPosition = lineRange.location + lineRange.length
    }

    //==================================================
    // MARK: - Editing primitives (used by operators)
    //==================================================

    func deleteToEndOfLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        let endOfLine = lineRange.location + lineRange.length
        
        // If the line ends with a newline, we want to preserve it for 'D'
        let rangeEnd = (endOfLine > lineRange.location && textAsNSString.character(at: endOfLine - 1) == 10) ? endOfLine - 1 : endOfLine
        
        let range = cursorPosition..<rangeEnd
        delete(range: range)
    }

    func yankToEndOfLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        let endOfLine = lineRange.location + lineRange.length
        let rangeEnd = (endOfLine > lineRange.location && textAsNSString.character(at: endOfLine - 1) == 10) ? endOfLine - 1 : endOfLine
        
        let range = cursorPosition..<rangeEnd
        yank(range: range)
    }

    func delete(range: Range<Int>) {
        print("Deleting range: \(range)")
        guard range.lowerBound >= 0,
            range.upperBound <= text.count,
            range.lowerBound < range.upperBound
        else { 
            print("Deletion aborted: invalid range.")
            return 
        }
        let from = text.index(text.startIndex, offsetBy: range.lowerBound)
        let to = text.index(text.startIndex, offsetBy: range.upperBound)
        text.removeSubrange(from..<to)
        cursorPosition = range.lowerBound
    }

    func change(range: Range<Int>) {
        delete(range: range)
        switchToInsertMode()
    }

    func yank(range: Range<Int>) {
        // TODO: registers/clipboard
        cursorPosition = range.lowerBound
    }

    func deleteCurrentCharacter() {
        guard cursorPosition < text.count else { return }
        let range = cursorPosition..<(cursorPosition + 1)
        delete(range: range)
    }

    func deleteCharBackward() {
        guard cursorPosition > 0 else { return }
        let range = (cursorPosition - 1)..<cursorPosition
        delete(range: range)
        moveCursorLeft()
    }

    func changeToEndOfLine() {
        deleteToEndOfLine()
        switchToInsertMode()
    }

    enum TransformationType {
        case lowercase
        case uppercase
        case swapCase
    }

    func transform(range: Range<Int>, to type: TransformationType) {
        guard range.lowerBound >= 0,
              range.upperBound <= text.count,
              range.lowerBound < range.upperBound
        else {
            print("Transformation aborted: invalid range.")
            return
        }

        let start = text.index(text.startIndex, offsetBy: range.lowerBound)
        let end = text.index(text.startIndex, offsetBy: range.upperBound)
        let subrange = text[start..<end]

        let transformedText: String
        switch type {
        case .lowercase:
            transformedText = subrange.lowercased()
        case .uppercase:
            transformedText = subrange.uppercased()
        case .swapCase:
            transformedText = subrange.map {
                $0.isUppercase ? $0.lowercased() : $0.uppercased()
            }.joined()
        }

        text.replaceSubrange(start..<end, with: transformedText)
        cursorPosition = range.lowerBound
    }
}
