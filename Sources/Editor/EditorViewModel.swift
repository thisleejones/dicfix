// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

import SwiftUI

// MARK: - String extension for line-based calculations
extension String {
    public struct Line {
        public let content: String
        public let range: Range<Int>
    }

    public func currentLine(at cursorPosition: Int) -> Line {
        let textAsNSString = self as NSString
        let lineNSRange = textAsNSString.lineRange(
            for: NSRange(location: cursorPosition, length: 0))
        let lineRange = lineNSRange.location..<lineNSRange.upperBound
        let lineContent = textAsNSString.substring(with: lineNSRange)
        return Line(content: lineContent, range: lineRange)
    }
}

// MARK: - Editor View Model (State Machine)
open class EditorViewModel: ObservableObject {
    @Published public var text: String = ""
    @Published public var cursorPosition: Int = 0 {
        didSet {
            updateSelection()
        }
    }
    @Published private(set) public var mode: EditorMode = InsertMode()
    @Published public var selection: Range<Int>?
    public var desiredColumn: Int?

    // State for visual mode command counts.
    public var visualModeCount: Int = 0

    // The last action performed that can be repeated with the '.' command.
    private(set) public var lastAction: RepeatableAction?
    private(set) public var register: String = ""

    // Undo/Redo state
    private var undoStack: [(text: String, cursorPosition: Int)] = []
    private var redoStack: [(text: String, cursorPosition: Int)] = []

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
        mode = InsertMode()
    }

    public func switchToNormalMode() {
        print("[EditorViewModel] Switching to NormalModeState")
        clearSelection()
        visualModeCount = 0
        mode = NormalMode()
    }

    public func switchToVisualMode() {
        print("[EditorViewModel] Switching to VisualModeState")
        visualModeCount = 0
        mode = VisualMode(anchor: cursorPosition)
        updateSelection()
    }

    public func switchToVisualLineMode() {
        print("[EditorViewModel] Switching to VisualLineModeState")
        visualModeCount = 0
        mode = VisualLineMode(anchor: cursorPosition)
        updateSelection()
    }

    public func moveCursorAfterEndOfLine() {
        let line = text.currentLine(at: cursorPosition)
        var insertPosition = line.range.upperBound
        if !line.content.isEmpty && line.content.last == "\n" {
            insertPosition -= 1
        }
        cursorPosition = insertPosition
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
        if let visualMode = mode as? VisualMode {
            let anchor = visualMode.anchor
            if cursorPosition < anchor {
                // Selection from cursor up to and including the anchor
                selection = cursorPosition..<(anchor + 1)
            } else {
                // Selection from anchor up to and including the cursor
                selection = anchor..<(cursorPosition + 1)
            }
        } else if let visualLineMode = mode as? VisualLineMode {
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
        let contentEndPosition =
            (endOfLine > lineRange.location && textAsNSString.character(at: endOfLine - 1) == 10)
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
        let line = text.currentLine(at: cursorPosition)
        let endOfLineOffset = line.range.upperBound - 1
        if cursorPosition < endOfLineOffset {
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

    public func moveCursorToCharacter(_ character: Character, forward: Bool, till: Bool) {
        let line = text.currentLine(at: cursorPosition)
        let lineContent = Array(line.content)
        let cursorRelativePos = cursorPosition - line.range.lowerBound

        // Ensure the cursor is within the line's bounds before proceeding.
        guard cursorRelativePos < lineContent.count else {
            return
        }

        // Define the search range on the current line
        let searchRange: any Sequence<Int> =
            forward
            ? (cursorRelativePos + 1)..<lineContent.count
            : (0..<cursorRelativePos).reversed()

        var foundIndex: Int?

        // Find the first occurrence of the character in the search range
        for i in searchRange {
            if lineContent[i] == character {
                foundIndex = i
                break
            }
        }

        if let finalIndex = foundIndex {
            let offset = till ? (forward ? -1 : 1) : 0
            cursorPosition = line.range.lowerBound + finalIndex + offset
        }
    }

    public func range(for object: TextObjectSelector, at position: Int, inner: Bool) -> Range<Int>?
    {
        switch object {
        case .word, .WORD:
            return wordRange(at: position, isWORD: object == .WORD, inner: inner)
        case .singleQuote, .doubleQuote, .backtick:
            guard let delimiter = object.delimiter else { return nil }
            return findSurrounding(char: delimiter, at: position, inner: inner)
        case .parentheses, .curlyBraces, .squareBrackets:
            guard let delimiters = object.delimiters else { return nil }
            return findSurrounding(
                open: delimiters.open, close: delimiters.close, at: position, inner: inner)
        default:
            return nil
        }
    }

    private func wordRange(at position: Int, isWORD: Bool, inner: Bool) -> Range<Int>? {
        let textChars = Array(text)
        guard position < textChars.count else { return nil }

        let charAtPosition = textChars[position]
        let charactersToMatch: (Character) -> Bool

        if isWORD {
            if charAtPosition.isWhitespace {
                charactersToMatch = { $0.isWhitespace }
            } else {
                charactersToMatch = { !$0.isWhitespace }
            }
        } else {
            let isWordChar = { (c: Character) in c.isLetter || c.isNumber || c == "_" }
            if isWordChar(charAtPosition) {
                charactersToMatch = isWordChar
            } else if charAtPosition.isWhitespace {
                charactersToMatch = { $0.isWhitespace }
            } else {
                // For non-WORD, punctuation is its own block.
                charactersToMatch = { !isWordChar($0) && !$0.isWhitespace }
            }
        }

        // Find start of the block
        var start = position
        while start > 0 && charactersToMatch(textChars[start - 1]) {
            start -= 1
        }

        // Find end of the block
        var end = position
        while end < text.count - 1 && charactersToMatch(textChars[end + 1]) {
            end += 1
        }

        return start..<(end + 1)
    }

    private func findSurrounding(char: Character, at position: Int, inner: Bool) -> Range<Int>? {
        let textChars = Array(text)
        guard position < textChars.count else { return nil }

        // Find the opening delimiter
        var startIdx = -1
        for i in (0..<position).reversed() {
            if textChars[i] == char {
                startIdx = i
                break
            }
        }

        guard startIdx != -1 else { return nil }

        // Find the closing delimiter
        var endIdx = -1
        for i in (position..<textChars.count) {
            if textChars[i] == char {
                endIdx = i
                break
            }
        }

        guard endIdx != -1 else { return nil }

        if inner {
            return (startIdx + 1)..<endIdx
        } else {
            var start = startIdx
            var end = endIdx + 1

            // Prioritize consuming leading whitespace.
            while start > 0 && textChars[start - 1].isWhitespace {
                start -= 1
            }

            // If no leading whitespace was found, consume trailing whitespace.
            if start == startIdx {
                while end < textChars.count && textChars[end].isWhitespace {
                    end += 1
                }
            }
            return start..<end
        }
    }

    private func findSurrounding(open: Character, close: Character, at position: Int, inner: Bool)
        -> Range<Int>?
    {
        let textChars = Array(text)
        guard position < textChars.count else { return nil }

        var openParenIndex = -1
        var closeParenIndex = -1
        var balance = 0

        // Find the enclosing opening paren
        for i in (0...position).reversed() {
            if textChars[i] == close {
                balance += 1
            } else if textChars[i] == open {
                balance -= 1
                if balance < 0 {
                    openParenIndex = i
                    break
                }
            }
        }

        guard openParenIndex != -1 else { return nil }

        // Find the matching closing paren
        balance = 0
        for i in openParenIndex..<textChars.count {
            if textChars[i] == open {
                balance += 1
            } else if textChars[i] == close {
                balance -= 1
                if balance == 0 {
                    closeParenIndex = i
                    break
                }
            }
        }

        guard closeParenIndex != -1 else { return nil }

        if inner {
            return (openParenIndex + 1)..<closeParenIndex
        } else {
            var start = openParenIndex
            var end = closeParenIndex + 1

            // Prioritize consuming leading whitespace.
            while start > 0 && textChars[start - 1].isWhitespace {
                start -= 1
            }

            // If no leading whitespace was found, consume trailing whitespace.
            if start == openParenIndex {
                while end < textChars.count && textChars[end].isWhitespace {
                    end += 1
                }
            }
            return start..<end
        }
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

        let charType = scanner.currentType

        if isWORD {
            // For WORD, if we are on non-whitespace, skip it all.
            if charType != .whitespace {
                while scanner.canAdvance() && scanner.currentType != .whitespace {
                    scanner.advance()
                }
            }
            // Then, skip all subsequent whitespace to land on the start of the next WORD.
            while scanner.canAdvance() && scanner.currentType == .whitespace {
                scanner.advance()
            }
        } else {
            // For word, the logic is more complex.
            if charType == .word || charType == .punctuation {
                // 1. If on a word or punctuation, skip to the end of it.
                let currentType = scanner.currentType
                while scanner.canAdvance() && scanner.currentType == currentType {
                    scanner.advance()
                }
            }
            // 2. Then, skip any and all whitespace to land on the next word.
            while scanner.canAdvance() && scanner.currentType == .whitespace {
                scanner.advance()
            }
        }

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
        let textBeforeCursor = String(
            text[..<text.index(text.startIndex, offsetBy: cursorPosition)])
        if let blankLineRange = textBeforeCursor.range(of: "\n\n", options: .backwards) {
            let textAfterBlankLine = text[
                blankLineRange.upperBound..<text.index(text.startIndex, offsetBy: cursorPosition)]
            if textAfterBlankLine.allSatisfy({ $0.isWhitespace }) {
                // This is the scenario the user described. Move to the start of the blank line.
                // The position is the index of the second newline character.
                cursorPosition = text.distance(
                    from: text.startIndex, to: text.index(after: blankLineRange.lowerBound))
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

        if line <= 1 {
            moveCursorToBeginningOfFile()
            return
        }
        if line == Int.max {
            moveCursorToEndOfFile()
            return
        }

        let lines = text.components(separatedBy: .newlines)
        let targetLine = line - 1  // 0-indexed

        if targetLine < lines.count {
            // Calculate the character index for the start of the target line.
            var charIndex = 0
            for i in 0..<targetLine {
                charIndex += lines[i].count + 1  // +1 for the newline character
            }
            self.cursorPosition = charIndex
        } else {
            // Line number is out of bounds, go to the end of the file.
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
        saveUndoState()
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        
        // Always insert after the current line's content, before any existing newline.
        let endOfLine = lineRange.upperBound
        let hasNewline = !text.isEmpty && endOfLine > 0 && textAsNSString.character(at: endOfLine - 1) == 10
        let insertPosition = hasNewline ? endOfLine - 1 : endOfLine
        
        text.insert("\n", at: text.index(text.startIndex, offsetBy: insertPosition))
        cursorPosition = insertPosition + 1
        switchToInsertMode()
    }

    public func openLineAbove() {
        saveUndoState()
        let textAsNSString = text as NSString
        let lineRange = textAsNSString.lineRange(for: NSRange(location: cursorPosition, length: 0))
        let insertPosition = lineRange.location
        text.insert("\n", at: text.index(text.startIndex, offsetBy: insertPosition))
        cursorPosition = insertPosition
        switchToInsertMode()
    }

    public func splitLine() {
        saveUndoState()
        let splitIndex = text.index(text.startIndex, offsetBy: cursorPosition)
        let firstPart = String(text[..<splitIndex])
        let secondPart = String(text[splitIndex...])
        text = firstPart + "\n" + secondPart
        cursorPosition += 1
        switchToInsertMode()
    }

    public func insertNewline() {
        saveUndoState()
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.insert("\n", at: index)
        cursorPosition += 1
    }

    //==================================================
    // MARK: - Editing primitives (used by operators)
    //==================================================

    public func deleteToEndOfLine(count: Int = 1) {
        let firstLineInfo = text.currentLine(at: cursorPosition)

        // Calculate the end of the range for the first line.
        var endRange =
            firstLineInfo.range.upperBound - (firstLineInfo.content.hasSuffix("\n") ? 1 : 0)

        // If count > 1, extend the range to include subsequent full lines.
        if count > 1 {
            var currentLineStart = firstLineInfo.range.upperBound
            for i in 1..<count {
                if currentLineStart >= text.count { break }
                let nextLineInfo = text.currentLine(at: currentLineStart)
                // For all but the last line, we take the whole range.
                // For the last line, we take up to the content end.
                if i == count - 1 {
                    endRange =
                        nextLineInfo.range.upperBound
                        - (nextLineInfo.content.hasSuffix("\n") ? 1 : 0)
                } else {
                    endRange = nextLineInfo.range.upperBound
                }
                currentLineStart = nextLineInfo.range.upperBound
            }
        }

        let rangeToDelete = cursorPosition..<endRange
        delete(range: rangeToDelete)
    }

    public func yankToEndOfLine(count: Int = 1) {
        var rangesToYank: [Range<Int>] = []

        // 1. Handle the first line: from cursor to end of line content.
        let firstLineInfo = text.currentLine(at: cursorPosition)
        let firstLineContentEnd =
            firstLineInfo.range.upperBound - (firstLineInfo.content.hasSuffix("\n") ? 1 : 0)
        if cursorPosition < firstLineContentEnd {
            rangesToYank.append(cursorPosition..<firstLineContentEnd)
        }

        // 2. Handle subsequent full lines.
        if count > 1 {
            var currentLineStart = firstLineInfo.range.upperBound
            for _ in 1..<count {
                if currentLineStart >= text.count { break }

                let nextLineInfo = text.currentLine(at: currentLineStart)
                rangesToYank.append(nextLineInfo.range)
                currentLineStart = nextLineInfo.range.upperBound
            }
        }

        // 3. Join the text from the calculated ranges.
        let yankedText = rangesToYank.map { range -> String in
            let from = text.index(text.startIndex, offsetBy: range.lowerBound)
            let to = text.index(text.startIndex, offsetBy: range.upperBound)
            // Ensure we don't add an extra newline if the range already includes it.
            let content = String(text[from..<to])
            return content.hasSuffix("\n") ? String(content.dropLast()) : content
        }.joined(separator: "\n")

        setRegister(to: yankedText)

        // Per Vim behavior, the cursor does not move after a Y command.
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

        saveUndoState()

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
        saveUndoState()

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
        saveUndoState()
        saveUndoState()

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

    public func changeToEndOfLine(count: Int = 1) {
        deleteToEndOfLine(count: count)
        switchToInsertMode()
    }

    public enum TransformationType {
        case lowercase
        case uppercase
        case swapCase
    }

    public func transform(range: Range<Int>, to type: TransformationType) {
        saveUndoState()
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

    // MARK: - Undo/Redo Functionality
    
    private func saveUndoState() {
        let currentState = (text: text, cursorPosition: cursorPosition)
        undoStack.append(currentState)
        redoStack.removeAll() // A new action clears the redo stack
    }

    public func undo() {
        guard let lastState = undoStack.popLast() else { return }
        let currentState = (text: text, cursorPosition: cursorPosition)
        redoStack.append(currentState)
        
        text = lastState.text
        cursorPosition = lastState.cursorPosition
    }

    public func redo() {
        guard let nextState = redoStack.popLast() else { return }
        let currentState = (text: text, cursorPosition: cursorPosition)
        undoStack.append(currentState)
        
        text = nextState.text
        cursorPosition = nextState.cursorPosition
    }
}


// MARK: - Key Event Handling
extension EditorViewModel {
    public func insertCharacter(_ char: String) {
        saveUndoState()
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.insert(contentsOf: char, at: index)
        cursorPosition += char.count
    }

    public func appendCharacterAtEndOfLine(_ content: String) {
        // 1. Ensure this action can be undone.
        saveUndoState()

        // 2. Get information about the line the cursor is currently on.
        let line = text.currentLine(at: cursorPosition)

        // 3. Determine the precise insertion point.
        //    Start with the end of the line's range.
        var insertPosition = line.range.upperBound

        // 4. If the line ends with a newline, we must insert *before* it.
        if !line.content.isEmpty && line.content.last == "\n" {
            insertPosition -= 1
        }

        // 5. Perform the text insertion.
        let index = text.index(text.startIndex, offsetBy: insertPosition)
        text.insert(contentsOf: content, at: index)

        // 6. The cursor should be placed after the newly inserted content.
        cursorPosition = insertPosition + content.count
    }

    public func backspace() {
        guard cursorPosition > 0 else { return }
        saveUndoState()
        let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
        text.remove(at: index)
        cursorPosition -= 1
    }
}
