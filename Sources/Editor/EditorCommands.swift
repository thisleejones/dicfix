import SwiftUI

// MARK: - State Machine Types

/// An enum representing a fully-formed, repeatable command.
public enum RepeatableAction {
    /// A standard operator + motion command, e.g., `dw`, `3yy`.
    case standard(op: EditorOperator, motion: EditorMotion, count: Int)
    /// A standalone command that is repeatable, e.g., `D`, `x`.
    case standalone(token: EditorCommandToken, count: Int)
}

/// Describes an action to be taken (e.g., delete, change).
public enum EditorOperator {
    case delete
    case change
    case yank
    case lowercase
    case uppercase
    case swapCase
}

/// A prefix that specifies whether to include whitespace or surrounding characters.
public enum TextObjectPrefix {
    case inner  // e.g., 'iw' for "inner word"
    case around  // e.g., 'aw' for "a word"
}

/// A selector for a region of text, like a word, sentence, or quoted string.
public enum TextObjectSelector {
    case word
    case WORD
    case paragraph
    case sentence
    case singleQuote
    case doubleQuote
    case backtick
    case parentheses
    case curlyBraces
    case squareBrackets
}

/// Describes a region of text to be affected by an operator.
public enum EditorMotion {
    case wordForward
    case WORDForward
    case wordBackward
    case WORDBackward
    case endOfWord
    case endOfWORD
    case charLeft
    case charRight
    case lineUp
    case lineDown
    case goToEndOfFile
    case goToStartOfLine  // For '0' and 'g0'
    case goToFirstLine  // For 'gg'
    case line  // Represents a line-wise motion, for 'dd', 'yy'
    case screenLineDown
    case screenLineUp
    case screenLineStartNonBlank
    case screenLineEnd
    case textObject(prefix: TextObjectPrefix, selector: TextObjectSelector)
}

/// The explicit state of the command state machine.
public enum EditorCommandState: CustomStringConvertible {
    case idle
    case waitingForMotion(operator: EditorOperator, count: Int)
    case waitingForOperator(count: Int)
    case waitingForSuffix(prefix: EditorCommandToken, count: Int)
    case waitingForTextObjectSelector(operator: EditorOperator, count: Int, prefix: TextObjectPrefix)

    public var description: String {
        switch self {
        case .idle:
            return "idle"
        case .waitingForMotion(let op, let count):
            return "waitingForMotion(operator: \(op), count: \(count))"
        case .waitingForOperator(let count):
            return "waitingForOperator(count: \(count))"
        case .waitingForSuffix(let prefix, let count):
            return "waitingForSuffix(prefix: \(prefix), count: \(count))"
        case .waitingForTextObjectSelector(let op, let count, let prefix):
            return "waitingForTextObjectSelector(operator: \(op), count: \(count), prefix: \(prefix))"
        }
    }
}

public enum EditorCommandToken: Equatable {
    // A token that starts a sequence, like 'g' in 'gg'
    case prefix(Character)

    // The character argument for a command like 'f'
    case argument(Character)

    // Numbers build counts
    case digit(Int)

    // Operators (act on a motion)
    case delete
    case yank
    case change
    case lowercase  // gu
    case uppercase  // gU
    case swapCase  // g~

    // Motions
    case wordForward  // w
    case WORDForward  // W
    case wordBackward  // b
    case WORDBackward  // B
    case endOfWord  // e
    case endOfWORD  // E
    case charLeft, charRight, lineUp, lineDown
    case goToFirstLine  // gg
    case goToEndOfFile  // G
    case goToStartOfLine  // 0
    case screenLineStartNonBlank  // ^
    case screenLineEnd  // $

    // Text Object Prefixes
    case inner  // i
    case around  // a

    // Standalone commands
    case switchToInsertMode
    case switchToInsertModeAndMove
    case switchToVisualMode
    case switchToVisualLineMode
    case openLineBelow
    case openLineAbove
    case deleteToEndOfLine  // D
    case yankToEndOfLine  // Y
    case deleteChar  // x
    case deleteCharBackward  // X
    case changeToEndOfLine  // C
    case repeatLastAction  // .
    case paste  // p
    case pasteBefore  // P
    case requestSubmit
    case requestQuit

    case escape
    case unknown(String)

    var toOperator: EditorOperator? {
        switch self {
        case .delete: return .delete
        case .change: return .change
        case .yank: return .yank
        case .lowercase: return .lowercase
        case .uppercase: return .uppercase
        case .swapCase: return .swapCase
        default: return nil
        }
    }

    var toMotion: EditorMotion? {
        switch self {
        case .wordForward: return .wordForward
        case .WORDForward: return .WORDForward
        case .wordBackward: return .wordBackward
        case .WORDBackward: return .WORDBackward
        case .endOfWord: return .endOfWord
        case .endOfWORD: return .endOfWORD
        case .charLeft: return .charLeft
        case .charRight: return .charRight
        case .lineUp: return .lineUp
        case .lineDown: return .lineDown
        case .goToEndOfFile: return .goToEndOfFile
        case .goToStartOfLine: return .goToStartOfLine
        case .goToFirstLine: return .goToFirstLine
        case .screenLineStartNonBlank: return .screenLineStartNonBlank
        case .screenLineEnd: return .screenLineEnd
        default: return nil
        }
    }

    var toDigit: Int? {
        if case .digit(let d) = self { return d }
        return nil
    }

    static func from(keyEvent: KeyEvent, state: EditorCommandState) -> EditorCommandToken? {
        guard let k = keyEvent.key else { return nil }

        // If we are waiting for a suffix, some prefixes expect a character argument.
        if case .waitingForSuffix(let prefix, _) = state {
            // TODO: This is not ideal, review, it feels like this is more a state machine issue.
            if case .prefix(let pchar) = prefix, "fFtT".contains(pchar) {
                if let char = keyEvent.characters?.first {
                    return .argument(char)
                }
            }
        }

        // Digits (counts)
        if let chars = keyEvent.characters, chars.count == 1, let d = Int(chars) {
            if d >= 0 && d <= 9 {
                return .digit(d)
            }
        }

        // Control-modified keys
        if keyEvent.mods.isControl {
            switch k {
            case .j: return .openLineBelow
            default: break
            }
        }

        // Shift-modified keys that have their own meaning
        if keyEvent.mods.isShift {
            switch k {
            case .p: return .pasteBefore  // Shift-p is P
            case .v: return .switchToVisualLineMode
            case .o: return .openLineAbove
            case .d: return .deleteToEndOfLine
            case .y: return .yankToEndOfLine
            case .g: return .goToEndOfFile  // Shift-g is G
            case .x: return .deleteCharBackward  // Shift-x is X
            case .c: return .changeToEndOfLine  // Shift-c is C
            case .u: return .uppercase
            case .tilde: return .swapCase
            case .four: return .screenLineEnd
            case .six: return .screenLineStartNonBlank
            default: break  // fall through for other shift-keys
            }
        }

        switch k {
        // Operators
        case .d: return .delete
        case .y: return .yank
        case .c: return .change
        case .u: return .lowercase

        // Motions
        case .w: return keyEvent.mods.isOnlyShift ? .WORDForward : .wordForward
        case .b: return keyEvent.mods.isOnlyShift ? .WORDBackward : .wordBackward
        case .e: return keyEvent.mods.isOnlyShift ? .endOfWORD : .endOfWord
        case .h: return .charLeft
        case .l: return .charRight
        case .j: return .lineDown
        case .k: return .lineUp

        // Prefixes
        case .f: return keyEvent.mods.isOnlyShift ? .prefix("F") : .prefix("f")
        case .t: return keyEvent.mods.isOnlyShift ? .prefix("T") : .prefix("t")
        case .g: return .prefix("g")

        // Standalone Commands / Text Object Prefixes
        case .i:
            if case .waitingForMotion = state {
                return .inner
            }
            return .switchToInsertMode
        case .a:
            if case .waitingForMotion = state {
                return .around
            }
            return .switchToInsertModeAndMove
        case .o: return .openLineBelow
        case .v: return .switchToVisualMode
        case .x: return .deleteChar
        case .p: return .paste
        case .`repeat`: return .repeatLastAction
        case .enter, .keypadEnter: return .requestSubmit
        case .escape: return .requestQuit  // In normal mode, escape is for quitting.
        case .tilde: return .swapCase

        default:
            // If no other token matches, and we have a single character, treat it as an argument.
            if let char = keyEvent.characters?.first {
                return .argument(char)
            }
            return .unknown(keyEvent.characters ?? "")
        }
    }
}

public final class EditorCommandStateMachine {
    public private(set) var state: EditorCommandState = .idle

    public init() {}

    public func handleToken(_ token: EditorCommandToken, editor: EditorViewModel) {
        print("[State: \(state)] received token: \(token)")
        switch state {
        case .idle:
            handleTokenInIdleState(token, editor: editor)
        case .waitingForOperator(let count):
            handleTokenInWaitingForOperatorState(token, count: count, editor: editor)
        case .waitingForMotion(let op, let count):
            handleTokenInWaitingForMotionState(token, op: op, count: count, editor: editor)
        case .waitingForSuffix(let prefix, let count):
            handleTokenInWaitingForSuffixState(token, prefix: prefix, count: count, editor: editor)
        case .waitingForTextObjectSelector(let op, let count, let prefix):
            handleTokenInWaitingForTextObjectSelectorState(
                token, op: op, count: count, prefix: prefix, editor: editor)
        }
        print("           -> new state: \(state)")
    }

    private func handleTokenInIdleState(_ token: EditorCommandToken, editor: EditorViewModel) {
        if let op = token.toOperator {
            state = .waitingForMotion(operator: op, count: 1)
        } else if let digit = token.toDigit {
            if digit == 0 {
                // '0' is a motion if it's the first key.
                executeMotion(.goToStartOfLine, count: 1, editor: editor)
            } else {
                state = .waitingForOperator(count: digit)
            }
        } else if let motion = token.toMotion {
            if case .goToEndOfFile = motion {
                // 'G' with no count goes to the last line.
                editor.goToLine(Int.max)
            } else {
                executeMotion(motion, count: 1, editor: editor)
            }
        } else if case .prefix = token {
            state = .waitingForSuffix(prefix: token, count: 1)
        } else {
            // Handle standalone commands that execute immediately.
            switch token {
            case .switchToInsertMode:
                editor.switchToInsertMode()
            case .switchToInsertModeAndMove:
                editor.moveCursorToNextCharacter()
                editor.switchToInsertMode()
            case .switchToVisualMode:
                editor.switchToVisualMode()
            case .switchToVisualLineMode:
                editor.switchToVisualLineMode()
            case .openLineBelow:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .openLineAbove:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .repeatLastAction:
                editor.repeatLastAction()
            case .deleteToEndOfLine:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .yankToEndOfLine:
                // In Vim, Y is a synonym for yy, which yanks the whole line.
                execute(op: .yank, motion: .line, count: 1, editor: editor)
            case .deleteChar:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .deleteCharBackward:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .changeToEndOfLine:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .paste:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .pasteBefore:
                executeAction(.standalone(token: token, count: 1), editor: editor)
            case .requestSubmit:
                editor.requestSubmit()
            case .requestQuit:
                editor.requestQuit()
            default:
                // Any other token is ignored in idle state.
                break
            }
            // Standalone commands do not change the command state, they are handled by the editor.
            // The state remains .idle.
        }
    }

    private func handleTokenInWaitingForSuffixState(
        _ token: EditorCommandToken, prefix: EditorCommandToken, count: Int, editor: EditorViewModel
    ) {
        var handled = false
        switch prefix {
        case .prefix("f"):
            if case .argument(let char) = token {
                for _ in 0..<count {
                    editor.moveCursorToCharacter(char, forward: true, till: false)
                }
                handled = true
            }
        case .prefix("F"):
            if case .argument(let char) = token {
                for _ in 0..<count {
                    editor.moveCursorToCharacter(char, forward: false, till: false)
                }
                handled = true
            }
        case .prefix("t"):
            if case .argument(let char) = token {
                for _ in 0..<count {
                    editor.moveCursorToCharacter(char, forward: true, till: true)
                }
                handled = true
            }
        case .prefix("T"):
            if case .argument(let char) = token {
                for _ in 0..<count {
                    editor.moveCursorToCharacter(char, forward: false, till: true)
                }
                handled = true
            }
        case .prefix("g"):
            if case .prefix("g") = prefix, token == .prefix("g") {  // gg
                executeMotion(.goToFirstLine, count: count, editor: editor)
                handled = true
            } else if case .digit(0) = token {  // g0
                executeMotion(.goToStartOfLine, count: count, editor: editor)
                handled = true
            } else if let op = token.toOperator {  // gu, g~, gU etc.
                state = .waitingForMotion(operator: op, count: count)
                return  // Do not reset state to idle yet
            } else if token == .lineDown {  // gj
                executeMotion(.screenLineDown, count: count, editor: editor)
                handled = true
            } else if token == .lineUp {  // gk
                executeMotion(.screenLineUp, count: count, editor: editor)
                handled = true
            } else if token == .screenLineStartNonBlank {  // g^
                executeMotion(.screenLineStartNonBlank, count: count, editor: editor)
                handled = true
            } else if token == .screenLineEnd {  // g$
                executeMotion(.screenLineEnd, count: count, editor: editor)
                handled = true
            }
        default:
            break  // Other prefixes are not yet supported.
        }

        state = .idle
        if !handled {
            handleToken(token, editor: editor)
        }
    }

    private func handleTokenInWaitingForOperatorState(
        _ token: EditorCommandToken, count: Int, editor: EditorViewModel
    ) {
        if let op = token.toOperator {
            state = .waitingForMotion(operator: op, count: count)
        } else if let digit = token.toDigit {
            let newCount = count * 10 + digit
            state = .waitingForOperator(count: newCount)
        } else if let motion = token.toMotion {
            // This is a pure motion with a count, like "3w" or "1G". Execute it immediately.
            executeMotion(motion, count: count, editor: editor)
            state = .idle
        } else if case .prefix = token {
            state = .waitingForSuffix(prefix: token, count: count)
        } else if token == .yankToEndOfLine {
            execute(op: .yank, motion: .line, count: count, editor: editor)
            state = .idle
        } else if token == .deleteChar {
            executeAction(.standalone(token: token, count: count), editor: editor)
            state = .idle
        } else if token == .deleteCharBackward {
            executeAction(.standalone(token: token, count: count), editor: editor)
            state = .idle
        } else if token == .paste {
            executeAction(.standalone(token: token, count: count), editor: editor)
            state = .idle
        } else if token == .pasteBefore {
            executeAction(.standalone(token: token, count: count), editor: editor)
            state = .idle
        } else {
            // Invalid sequence. Reset and re-process.
            state = .idle
            handleToken(token, editor: editor)
        }
    }

    private func handleTokenInWaitingForMotionState(
        _ token: EditorCommandToken, op: EditorOperator, count: Int, editor: EditorViewModel
    ) {
        if let motion = token.toMotion {
            execute(op: op, motion: motion, count: count, editor: editor)
            // execute() resets state to idle
        } else if let secondOpToken = token.toOperator, secondOpToken == op {
            // Handle doubled operators like 'dd', 'yy' as line-wise operations.
            execute(op: op, motion: .line, count: count, editor: editor)
        } else if token == .inner {  // 'i'
            state = .waitingForTextObjectSelector(operator: op, count: count, prefix: .inner)
        } else if token == .around {  // 'a'
            state = .waitingForTextObjectSelector(operator: op, count: count, prefix: .around)
        } else {
            // Invalid token in this state. Reset and re-process.
            state = .idle
            handleToken(token, editor: editor)
        }
    }

    private func handleTokenInWaitingForTextObjectSelectorState(
        _ token: EditorCommandToken, op: EditorOperator, count: Int, prefix: TextObjectPrefix,
        editor: EditorViewModel
    ) {
        var selector: TextObjectSelector?
        switch token {
        case .wordForward:
            selector = .word
        default:
            break
        }

        if let selector = selector {
            let motion = EditorMotion.textObject(prefix: prefix, selector: selector)
            execute(op: op, motion: motion, count: count, editor: editor)
        } else {
            // Invalid sequence. Reset.
            state = .idle
            handleToken(token, editor: editor)
        }
    }

    public func executeMotion(_ motion: EditorMotion, count: Int, editor: EditorViewModel) {
        // Special handling for motions that use count as a line number.
        if case .goToEndOfFile = motion {
            editor.goToLine(count)
            return
        }

        for _ in 0..<count {
            switch motion {
            case .wordForward: editor.moveCursorForwardByWord(isWORD: false)
            case .WORDForward: editor.moveCursorForwardByWord(isWORD: true)
            case .wordBackward: editor.moveCursorBackwardByWord(isWORD: false)
            case .WORDBackward: editor.moveCursorBackwardByWord(isWORD: true)
            case .endOfWord: editor.moveCursorToEndOfWord(isWORD: false)
            case .endOfWORD: editor.moveCursorToEndOfWord(isWORD: true)
            case .charLeft: editor.moveCursorLeft()
            case .charRight: editor.moveCursorRight()
            case .lineUp: editor.moveCursorUp()
            case .lineDown: editor.moveCursorDown()
            case .goToStartOfLine: editor.moveCursorToBeginningOfLine()
            case .goToFirstLine: editor.goToLine(1)
            case .screenLineDown: editor.moveCursorScreenLineDown()
            case .screenLineUp: editor.moveCursorScreenLineUp()
            case .screenLineStartNonBlank: editor.moveCursorToScreenLineStartNonBlank()
            case .screenLineEnd: editor.moveCursorToScreenLineEnd()
            case .line: editor.selectLine()
            case .goToEndOfFile: break  // Already handled above'
            case .textObject(_, _):
                // TODO: AI, implemenet this!
                break
            }
        }
    }

    public func executeAction(_ action: RepeatableAction, editor: EditorViewModel) {
        editor.setLastAction(action)
        switch action {
        case .standard(let op, let motion, let count):
            execute(op: op, motion: motion, count: count, editor: editor)
        case .standalone(let token, let count):
            // We only support a limited set of repeatable standalone commands.
            for _ in 0..<count {
                switch token {
                case .deleteToEndOfLine:
                    editor.deleteToEndOfLine()
                case .changeToEndOfLine:
                    editor.changeToEndOfLine()
                case .deleteChar:
                    editor.deleteCurrentCharacter()
                case .deleteCharBackward:
                    editor.deleteCharBackward()
                case .openLineBelow:
                    editor.openLineBelow()
                case .openLineAbove:
                    editor.openLineAbove()
                case .paste:
                    editor.paste()
                case .pasteBefore:
                    editor.pasteBefore()
                default:
                    print("[EditorCommandStateMachine] Non-repeatable standalone action: \(token)")
                }
            }
        }
    }

    private func getRange(
        op: EditorOperator, motion: EditorMotion, count: Int, editor: EditorViewModel
    ) -> Range<Int> {
        let startPos = editor.cursorPosition

        if case .textObject(let prefix, let selector) = motion {
            if selector == .word {
                if prefix == .inner {
                    if let range = editor.innerWordRange(at: editor.cursorPosition) {
                        return range
                    }
                }
            }
            return editor.cursorPosition..<editor.cursorPosition  // No range found
        }

        executeMotion(motion, count: count, editor: editor)
        let endPos = editor.cursorPosition

        if case .line = motion {
            let textAsNSString = editor.text as NSString
            var lineNSRange = textAsNSString.lineRange(for: NSRange(location: startPos, length: 0))

            if count > 1 {
                var endOfLine = lineNSRange.upperBound
                for _ in 1..<count {
                    if endOfLine >= editor.text.count { break }
                    let nextLineRange = textAsNSString.lineRange(
                        for: NSRange(location: endOfLine, length: 0))
                    endOfLine = nextLineRange.upperBound
                }
                lineNSRange.length = endOfLine - lineNSRange.location
            }

            // For transformations, exclude the trailing newline. For others, include it.
            let isTransform = op == .lowercase || op == .uppercase || op == .swapCase
            if isTransform {
                if lineNSRange.length > 0
                    && textAsNSString.character(at: lineNSRange.upperBound - 1) == 10
                {
                    return lineNSRange.location..<(lineNSRange.upperBound - 1)
                }
            }
            return lineNSRange.location..<lineNSRange.upperBound
        } else {
            return startPos <= endPos ? startPos..<endPos : endPos..<startPos
        }
    }

    private func execute(
        op: EditorOperator, motion: EditorMotion, count: Int, editor: EditorViewModel
    ) {
        print("Executing: \(op) on \(motion) for \(count) time(s)")
        editor.setLastAction(.standard(op: op, motion: motion, count: count))

        let range = getRange(op: op, motion: motion, count: count, editor: editor)

        switch op {
        case .delete: editor.delete(range: range)
        case .yank: editor.yank(range: range)
        case .change: editor.change(range: range)
        case .lowercase: editor.transform(range: range, to: .lowercase)
        case .uppercase: editor.transform(range: range, to: .uppercase)
        case .swapCase: editor.transform(range: range, to: .swapCase)
        }

        state = .idle
    }
}
