import SwiftUI

// MARK: - Editor View Model (State Machine)
open class EditorViewModel: ObservableObject {
    @Published public var text: String = ""
    @Published public var cursorPosition: Int = 0 {
        didSet {
            updateSelection()
        }
    }
    @Published private(set) public var mode: EditorModeState = InsertModeState()
    @Published public var selection: Range<Int>?
    public var desiredColumn: Int?

    // State for visual mode command counts.
    public var visualModeCount: Int = 0

    // The last action performed that can be repeated with the '.' command.
    private(set) public var lastAction: RepeatableAction?
    private(set) public var register: String = ""

    // Callbacks (optional)
    public var onQuit: (() -> Void)?
    public var onSubmit: (() -> Void)?

    // Internal command state machine (no UI dependency)
    public let commandSM = EditorCommandStateMachine()

    public init() {
        // Initial state is set directly.
    }

    // MARK: Repeatable actions
    public func setLastAction(_ action: RepeatableAction) {
        print("[EditorViewModel] Setting last action to: \(action)")
        self.lastAction = action
    }

    public func repeatLastAction() {
        guard let lastAction = lastAction else {
            print("[EditorViewModel] No last action to repeat.")
            return
        }
        print("[EditorViewModel] Repeating last action: \(lastAction)")
        // To repeat, we just feed the action back into the state machine.
        commandSM.executeAction(lastAction, editor: self)
    }

    // MARK: Mode switches
    public func switchToInsertMode() {
        print("[EditorViewModel] Switching to InsertModeState")
        clearSelection()
        visualModeCount = 0
        mode = InsertModeState()
    }
    public func switchToNormalMode() {
        print("[EditorViewModel] Switching to NormalModeState")
        clearSelection()
        visualModeCount = 0
        mode = NormalModeState()
    }

    public func switchToVisualMode() {
        print("[EditorViewModel] Switching to VisualModeState")
        visualModeCount = 0
        mode = VisualModeState(anchor: cursorPosition)
        updateSelection()
    }

    public func switchToVisualLineMode() {
        print("[EditorViewModel] Switching to VisualLineModeState")
        visualModeCount = 0
        mode = VisualLineModeState(anchor: cursorPosition)
        updateSelection()
    }

    // MARK: App-level intents
    public func requestQuit() {
        print("[EditorViewModel] Quit requested.")
        onQuit?()
    }
    public func requestSubmit() {
        print("[EditorViewModel] Submit requested.")
        onSubmit?()
    }

    // MARK: Key handling entry
    @discardableResult
    public func handleEvent(_ keyEvent: KeyEvent) -> Bool {
        mode.handleEvent(keyEvent, editor: self)
    }

    /// NormalModeState calls this to feed tokens into the command machine.
    public func handleToken(_ token: EditorCommandToken) {
        commandSM.handleToken(token, editor: self)
    }

    public func executeOperator(_ op: EditorOperator, range: Range<Int>) {
        switch op {
        case .delete: delete(range: range)
        case .yank: yank(range: range)
        case .change: change(range: range)
        case .lowercase: transform(range: range, to: .lowercase)
        case .uppercase: transform(range: range, to: .uppercase)
        case .swapCase: transform(range: range, to: .swapCase)
        }
    }

    //==================================================
    // MARK: - Cursor & Text Editing Helpers
    //==================================================

    public func clearSelection() {
        selection = nil
    }

    private func updateSelection() {
        if let visualMode = mode as? VisualModeState {
            let anchor = visualMode.anchor
            if cursorPosition < anchor {
                // Selection from cursor up to and including the anchor
                selection = cursorPosition..<(anchor + 1)
            } else {
                // Selection from anchor up to and including the cursor
                selection = anchor..<(cursorPosition + 1)
            }
        } else if let visualLineMode = mode as? VisualLineModeState {
            let textAsNSString = text as NSString
            let anchorRange = textAsNSString.lineRange(
                for: NSRange(location: visualLineMode.anchor, length: 0))
            let cursorLineRange = textAsNSString.lineRange(
                for: NSRange(location: cursorPosition, length: 0))

            let start = min(anchorRange.location, cursorLineRange.location)
            let end = max(anchorRange.upperBound, cursorLineRange.upperBound)

            selection = start..<end
        }
    }

    public func moveCursorToEndOfLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))

        // Determine the end of the line's content, excluding the newline character.
        let endOfLine = lineRange.upperBound
        let contentEndPosition = (endOfLine > lineRange.location && textAsNSString.character(at: endOfLine - 1) == 10)
            ? endOfLine - 1
            : endOfLine

        // If the line is not empty, move the cursor to the last character of the content.
        if contentEndPosition > lineRange.location {
            cursorPosition = contentEndPosition - 1
        } else {
            // Otherwise, the line is empty, so the cursor stays at the beginning of the line.
            cursorPosition = lineRange.location
        }
    }

    public func moveCursorToNextCharacter() {
        if cursorPosition < text.count {
            cursorPosition += 1
        }
    }

    public func moveCursorToBeginningOfLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        cursorPosition = lineRange.location
    }

    public func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
        desiredColumn = nil
    }

    public func moveCursorRight() {
        if cursorPosition < text.count {
            cursorPosition += 1
        }
        desiredColumn = nil
    }

    public func moveCursorUp() {
        let textAsNSString = text as NSString
        let currentLineRange = textAsNSString.lineRange(
            for: NSRange(location: cursorPosition, length: 0))

        // Can't move up from the first line
        guard currentLineRange.location > 0 else { return }

        let previousLineRange = textAsNSString.lineRange(
            for: NSRange(location: currentLineRange.location - 1, length: 0))
        let column = desiredColumn ?? (cursorPosition - currentLineRange.location)
        if desiredColumn == nil {
            desiredColumn = column
        }

        let lineContentLength =
            previousLineRange.length > 0
                && textAsNSString.character(at: previousLineRange.upperBound - 1) == 10
            ? previousLineRange.length - 1 : previousLineRange.length
        let targetColumn = min(
            column, max(0, lineContentLength > 0 ? lineContentLength - 1 : lineContentLength))

        cursorPosition = previousLineRange.location + targetColumn
    }

    public func moveCursorDown() {
        let textAsNSString = text as NSString
        let currentLineRange = textAsNSString.lineRange(
            for: NSRange(location: cursorPosition, length: 0))

        // Can't move down from the last line
        guard currentLineRange.upperBound < textAsNSString.length else { return }

        let nextLineRange = textAsNSString.lineRange(
            for: NSRange(location: currentLineRange.upperBound, length: 0))
        let column = desiredColumn ?? (cursorPosition - currentLineRange.location)
        if desiredColumn == nil {
            desiredColumn = column
        }

        let lineContentLength =
            nextLineRange.length > 0
                && textAsNSString.character(at: nextLineRange.upperBound - 1) == 10
            ? nextLineRange.length - 1 : nextLineRange.length
        let targetColumn = min(
            column, max(0, lineContentLength > 0 ? lineContentLength - 1 : lineContentLength))
        print(
            "column: \(column), desiredColumn: \(String(describing: desiredColumn)), lineContentLength: \(lineContentLength), targetColumn: \(targetColumn)"
        )

        cursorPosition = nextLineRange.location + targetColumn
    }

    public func moveCursorScreenLineDown() {
        // TODO: Implement proper screen line (visual line) navigation.
        // For now, fallback to logical line navigation.
        moveCursorDown()
    }

    public func moveCursorScreenLineUp() {
        // TODO: Implement proper screen line (visual line) navigation.
        // For now, fallback to logical line navigation.
        moveCursorUp()
    }

    public func moveCursorToScreenLineStartNonBlank() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))

        var searchPosition = lineRange.location
        while searchPosition < lineRange.upperBound {
            // Using a simple character check for whitespace, which is more direct.
            let char = Character(UnicodeScalar(textAsNSString.character(at: searchPosition))!)
            if !char.isWhitespace || char.isNewline {
                // Found the first non-whitespace character or the newline terminator.
                // The newline check handles empty lines correctly.
                if char.isNewline {
                    cursorPosition = lineRange.location
                } else {
                    cursorPosition = searchPosition
                }
                return
            }
            searchPosition += 1
        }
        
        // If the loop completes, the line is empty or all whitespace.
        // Move to the beginning of the line.
        cursorPosition = lineRange.location
    }

    public func moveCursorToScreenLineEnd() {
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

        func canAdvance() -> Bool {
            if direction == .forward {
                return index < text.count
            } else {
                return index >= 0
            }
        }

        var currentType: CharType {
            guard canAdvance() else { return .whitespace }
            let char = text[index]
            if char.isWhitespace { return .whitespace }
            if char.isLetter || char.isNumber || char == "_" { return .word }
            return .punctuation
        }

        mutating func advance() {
            index += (direction == .forward ? 1 : -1)
        }
    }

    public func moveCursorForwardByWord(isWORD: Bool = false) {
        var scanner = TextScanner(text: text, index: cursorPosition, direction: .forward)
        if !scanner.canAdvance() { return }

        if isWORD {
            // WORD = run of non-whitespace
            if scanner.currentType != .whitespace {
                while scanner.canAdvance() && scanner.currentType != .whitespace {
                    scanner.advance()
                }
            } else {
                while scanner.canAdvance() && scanner.currentType == .whitespace {
                    scanner.advance()
                }
            }
            while scanner.canAdvance() && scanner.currentType == .whitespace { scanner.advance() }
            cursorPosition = scanner.index
            return
        }

        let startType = scanner.currentType

        if startType == .whitespace {
            // Jump to first non-space token
            while scanner.canAdvance() && scanner.currentType == .whitespace { scanner.advance() }
            cursorPosition = scanner.index
            return
        }

        // Consume current run (word or punctuation)
        while scanner.canAdvance() && scanner.currentType == startType { scanner.advance() }

        // If we just consumed a word, also skip the punctuation block right after it
        if startType == .word {
            while scanner.canAdvance() && scanner.currentType == .punctuation { scanner.advance() }
        }

        // Skip trailing whitespace to land at next token start
        while scanner.canAdvance() && scanner.currentType == .whitespace { scanner.advance() }

        cursorPosition = scanner.index
    }

    public func moveCursorToEndOfWord(isWORD: Bool = false) {
        var scanner = TextScanner(text: text, index: cursorPosition, direction: .forward)
        if !scanner.canAdvance() { return }

        // If cursor is not on whitespace, advance once to ensure we can find the *next* word end.
        if scanner.currentType != .whitespace {
            scanner.advance()
            if !scanner.canAdvance() { return }
        }

        // Skip any whitespace to find the beginning of the next word/WORD
        while scanner.canAdvance() && scanner.currentType == .whitespace {
            scanner.advance()
        }
        if !scanner.canAdvance() { return }

        let startType = scanner.currentType
        if isWORD {
            // A WORD is a sequence of non-whitespace characters.
            while scanner.canAdvance() && scanner.currentType != .whitespace {
                scanner.advance()
            }
        } else {
            // A word is a sequence of the same character type (word or punctuation).
            while scanner.canAdvance() && scanner.currentType == startType {
                scanner.advance()
            }
        }

        // The scanner is now one position past the end of the word.
        // To land on the last character, we move back one.
        let finalPosition = scanner.index - 1
        if finalPosition >= 0 {
            cursorPosition = finalPosition
        }
    }

    public func moveCursorBackwardByWord(isWORD: Bool = false) {
        if cursorPosition == 0 { return }

        // Special case for `{`-like behavior based on user feedback.
        // If the text between the cursor and the last blank line is all whitespace,
        // then `b` should behave like a paragraph motion.
        let textBeforeCursor = String(text[..<text.index(text.startIndex, offsetBy: cursorPosition)])
        if let blankLineRange = textBeforeCursor.range(of: "\n\n", options: .backwards) {
            let textAfterBlankLine = text[blankLineRange.upperBound..<text.index(text.startIndex, offsetBy: cursorPosition)]
            if textAfterBlankLine.allSatisfy({ $0.isWhitespace }) {
                // This is the scenario the user described. Move to the start of the blank line.
                // The position is the index of the second newline character.
                cursorPosition = text.distance(from: text.startIndex, to: text.index(after: blankLineRange.lowerBound))
                return
            }
        }

        // Standard 'b' motion logic
        var scanner = TextScanner(text: text, index: cursorPosition - 1, direction: .backward)

        // Skip whitespace first
        while scanner.canAdvance() && scanner.currentType == .whitespace { scanner.advance() }
        if !scanner.canAdvance() {
            cursorPosition = 0
            return
        }

        if isWORD {
            // WORD = run of non-whitespace
            while scanner.canAdvance() && scanner.currentType != .whitespace { scanner.advance() }
            cursorPosition = scanner.index + 1
            return
        }

        // If we land on punctuation, consume that block then continue into previous word
        if scanner.currentType == .punctuation {
            while scanner.canAdvance() && scanner.currentType == .punctuation { scanner.advance() }
        }

        // Now consume the word (or whatever block we're on) to its beginning
        let blockType = scanner.currentType
        while scanner.canAdvance() && scanner.currentType == blockType && blockType != .whitespace {
            scanner.advance()
        }

        cursorPosition = scanner.index + 1
    }

    public func moveCursorToBeginningOfFile() {
        cursorPosition = 0
    }

    public func moveCursorToEndOfFile() {
        cursorPosition = text.count
    }

    public func goToEndOfFile() {
        moveCursorToEndOfFile()
    }

    public func goToLine(_ line: Int) {
        print("Going to line: \(line)")
        // A count of 0 or 1 for 'G' goes to the first line.
        // 'gg' also results in a call to goToLine(1).
        if line <= 1 {
            moveCursorToBeginningOfFile()
        }
        // A count of Int.max signifies going to the last line.
        else if line == Int.max {
            moveCursorToEndOfFile()
        } else {
            // This is a placeholder for real line-based navigation.
            // For now, any other line number also goes to the end.
            // TODO: Implement mapping a line number to a cursor index.
            print("goToLine for specific number (\(line)) not yet implemented.")
            moveCursorToEndOfFile()
        }
    }

    public func selectLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))

        // Adjust the cursor to the end of the line selection, including the newline character.
        cursorPosition = lineRange.upperBound
    }

    public func openLineBelow() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        let insertPosition = lineRange.location + lineRange.length
        text.insert("\n", at: text.index(text.startIndex, offsetBy: insertPosition))
        cursorPosition = insertPosition
        switchToInsertMode()
    }

    public func openLineAbove() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        let insertPosition = lineRange.location
        text.insert("\n", at: text.index(text.startIndex, offsetBy: insertPosition))
        cursorPosition = insertPosition
        switchToInsertMode()
    }

    public func insertNewline() {
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.insert("\n", at: index)
        cursorPosition += 1
    }

    //==================================================
    // MARK: - Editing primitives (used by operators)
    //==================================================

    public func deleteToEndOfLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        let endOfLine = lineRange.location + lineRange.length

        // If the line ends with a newline, we want to preserve it for 'D'
        let rangeEnd =
            (endOfLine > lineRange.location && textAsNSString.character(at: endOfLine - 1) == 10)
            ? endOfLine - 1 : endOfLine

        let range = cursorPosition..<rangeEnd
        delete(range: range)
    }

    public func yankToEndOfLine() {
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        let endOfLine = lineRange.location + lineRange.length
        let rangeEnd =
            (endOfLine > lineRange.location && textAsNSString.character(at: endOfLine - 1) == 10)
            ? endOfLine - 1 : endOfLine

        let range = cursorPosition..<rangeEnd
        yank(range: range)
    }

    public func delete(range: Range<Int>) {
        print("Deleting range: \(range)")
        guard range.lowerBound >= 0,
            range.upperBound <= text.count,
            range.lowerBound < range.upperBound
        else {
            print("Deletion aborted: invalid range.")
            return
        }

        // Yank the text before deleting it
        let from = text.index(text.startIndex, offsetBy: range.lowerBound)
        let to = text.index(text.startIndex, offsetBy: range.upperBound)
        let yankedText = String(text[from..<to])
        setRegister(to: yankedText)

        text.removeSubrange(from..<to)
        cursorPosition = range.lowerBound
    }

    public func change(range: Range<Int>) {
        delete(range: range)
        switchToInsertMode()
    }

    public func yank(range: Range<Int>) {
        guard range.lowerBound >= 0,
            range.upperBound <= text.count,
            range.lowerBound < range.upperBound
        else {
            print("Yank aborted: invalid range.")
            return
        }
        let from = text.index(text.startIndex, offsetBy: range.lowerBound)
        let to = text.index(text.startIndex, offsetBy: range.upperBound)
        let yankedText = String(text[from..<to])
        setRegister(to: yankedText)

        // Move cursor to the start of the yanked text
        cursorPosition = range.lowerBound
    }

    public func paste() {
        guard !register.isEmpty else { return }

        // If the register contains a full line (ends with newline), paste it on the line below.
        if register.last == "\n" {
            let textAsNSString = text as NSString
            let lineRange = textAsNSString.lineRange(
                for: NSRange(location: cursorPosition, length: 0))
            let insertPosition = lineRange.upperBound
            let index = text.index(text.startIndex, offsetBy: insertPosition)

            // If we are pasting after a line that doesn't have a newline (i.e., the last line of the file),
            // we must first add a newline to place the pasted content on the line below.
            let needsLeadingNewline =
                insertPosition > 0 && textAsNSString.character(at: insertPosition - 1) != 10
            let contentToInsert = needsLeadingNewline ? "\n" + register : register

            text.insert(contentsOf: contentToInsert, at: index)

            // The cursor should move to the beginning of the *actual* pasted content.
            // If we prepended a newline, this is one character after the insertion point.
            cursorPosition = needsLeadingNewline ? insertPosition + 1 : insertPosition
        } else {
            // Otherwise, paste after the cursor.
            let insertPosition = cursorPosition + 1
            guard insertPosition <= text.count else {
                text.append(contentsOf: register)
                cursorPosition = text.count
                return
            }
            let index = text.index(text.startIndex, offsetBy: insertPosition)
            text.insert(contentsOf: register, at: index)
            cursorPosition = insertPosition + register.count - 1  // Move cursor to end of pasted text
        }
    }

    public func pasteBefore() {
        guard !register.isEmpty else { return }

        // If the register contains a full line, paste it on the line above.
        if register.last == "\n" {
            let textAsNSString = text as NSString
            let lineRange = textAsNSString.lineRange(
                for: NSRange(location: cursorPosition, length: 0))
            let insertPosition = lineRange.location
            let index = text.index(text.startIndex, offsetBy: insertPosition)
            text.insert(contentsOf: register, at: index)
            cursorPosition = insertPosition  // Move cursor to beginning of pasted line
        } else {
            // Otherwise, paste before the cursor.
            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            text.insert(contentsOf: register, at: index)
            cursorPosition = cursorPosition + register.count - 1  // Move cursor to end of pasted text
        }
    }

    public func setRegister(to value: String) {
        print("Yanking to register: \(value)")
        register = value
    }

    public func deleteCurrentCharacter() {
        guard cursorPosition < text.count else { return }
        let range = cursorPosition..<(cursorPosition + 1)
        delete(range: range)
    }

    public func deleteCharBackward() {
        guard cursorPosition > 0 else { return }
        let range = (cursorPosition - 1)..<cursorPosition
        delete(range: range)
    }

    public func changeToEndOfLine() {
        deleteToEndOfLine()
        switchToInsertMode()
    }

    public enum TransformationType {
        case lowercase
        case uppercase
        case swapCase
    }

    public func transform(range: Range<Int>, to type: TransformationType) {
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
