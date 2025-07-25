// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

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

    var delimiter: Character? {
        switch self {
        case .singleQuote: return "'"
        case .doubleQuote: return "\""
        case .backtick: return "`"
        default: return nil
        }
    }

    var delimiters: (open: Character, close: Character)? {
        switch self {
        case .parentheses: return ("(", ")")
        case .curlyBraces: return ("{", "}")
        case .squareBrackets: return ("[", "]")
        default: return nil
        }
    }
}

/// Describes a region of text to be affected by an operator.
public enum EditorMotion {
    case findCharacter(char: Character, forward: Bool, till: Bool)
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
    case waitingForSuffix(operator: EditorOperator?, prefix: EditorCommandToken, count: Int)
    case waitingForTextObjectSelector(
        operator: EditorOperator, count: Int, prefix: TextObjectPrefix)

    public var description: String {
        switch self {
        case .idle:
            return "idle"
        case .waitingForMotion(let op, let count):
            return "waitingForMotion(operator: \(op), count: \(count))"
        case .waitingForOperator(let count):
            return "waitingForOperator(count: \(count))"
        case .waitingForSuffix(let op, let prefix, let count):
            let opString = op != nil ? "operator: \(op!), " : ""
            return "waitingForSuffix(\(opString)prefix: \(prefix), count: \(count))"
        case .waitingForTextObjectSelector(let op, let count, let prefix):
            return
                "waitingForTextObjectSelector(operator: \(op), count: \(count), prefix: \(prefix))"
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

        // If we are waiting for a text object selector, many keys become arguments.
        if case .waitingForTextObjectSelector = state {
            if let char = keyEvent.characters?.first {
                let validSelectors = "wWbB\"'`()[]{}ps"  // p=paragraph, s=sentence
                if validSelectors.contains(char) {
                    return .argument(char)
                }
            }
        }

        // If we are waiting for a suffix, some prefixes expect a character argument.
        if case .waitingForSuffix(_, let prefix, _) = state {
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

        // If escape is pressed in any non-idle state, reset to idle.
        if token == .requestQuit, case .idle = state {
            editor.requestQuit()
            return
        } else if token == .requestQuit {
            state = .idle
            return
        }

        switch state {
        case .idle:
            handleTokenInIdleState(token, editor: editor)
        case .waitingForOperator(let count):
            handleTokenInWaitingForOperatorState(token, count: count, editor: editor)
        case .waitingForMotion(let op, let count):
            handleTokenInWaitingForMotionState(token, op: op, count: count, editor: editor)
        case .waitingForSuffix(let op, let prefix, let count):
            handleTokenInWaitingForSuffixState(token, op: op, prefix: prefix, count: count, editor: editor)
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
            state = .waitingForSuffix(operator: nil, prefix: token, count: 1)
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
    _ token: EditorCommandToken, op: EditorOperator?, prefix: EditorCommandToken, count: Int,
    editor: EditorViewModel
) {
    var handled = false
    var motion: EditorMotion?

    switch prefix {
    case .prefix("f"):
        if case .argument(let char) = token { motion = .findCharacter(char: char, forward: true, till: false) }
    case .prefix("F"):
        if case .argument(let char) = token { motion = .findCharacter(char: char, forward: false, till: false) }
    case .prefix("t"):
        if case .argument(let char) = token { motion = .findCharacter(char: char, forward: true, till: true) }
    case .prefix("T"):
        if case .argument(let char) = token { motion = .findCharacter(char: char, forward: false, till: true) }
    case .prefix("g"):
        if case .prefix("g") = prefix, token == .prefix("g") { motion = .goToFirstLine }
        else if case .digit(0) = token { motion = .goToStartOfLine }
        else if let newOp = token.toOperator {
            state = .waitingForMotion(operator: newOp, count: count)
            return
        }
        else if token == .lineDown { motion = .screenLineDown }
        else if token == .lineUp { motion = .screenLineUp }
        else if token == .screenLineStartNonBlank { motion = .screenLineStartNonBlank }
        else if token == .screenLineEnd { motion = .screenLineEnd }
    default:
        break
    }

    if let motion = motion {
        if let op = op {
            // Operator-motion command, e.g., dtc
            execute(op: op, motion: motion, count: count, editor: editor)
        } else {
            // Standalone motion, e.g., fc
            executeMotion(motion, count: count, editor: editor)
        }
        handled = true
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
            state = .waitingForSuffix(operator: nil, prefix: token, count: count)
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
        } else if case .prefix = token {
            state = .waitingForSuffix(operator: op, prefix: token, count: count)
        }
        else {
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
        if case .argument(let char) = token {
            switch char {
            case "w": selector = .word
            case "W": selector = .WORD
            case "\"": selector = .doubleQuote
            case "'": selector = .singleQuote
            case "`": selector = .backtick
            case "(": selector = .parentheses
            case ")": selector = .parentheses
            case "b": selector = .parentheses
            case "{": selector = .curlyBraces
            case "}": selector = .curlyBraces
            case "B": selector = .curlyBraces
            case "[": selector = .squareBrackets
            case "]": selector = .squareBrackets
            default: break
            }
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
            case .findCharacter(let char, let forward, let till):
                editor.moveCursorToCharacter(char, forward: forward, till: till)
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
                // A text object is not a standalone motion. It only makes sense with an operator.
                // If we get here, it's a no-op.
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

        // For text objects, the range is calculated without moving the cursor.
        if case .textObject(let prefix, let selector) = motion {
            if let range = editor.range(for: selector, at: startPos, inner: prefix == .inner) {
                return range
            }
            return startPos..<startPos  // No range found
        }

        // For all other motions, we execute them to find the end position.
        executeMotion(motion, count: count, editor: editor)
        let endPos = editor.cursorPosition

        // IMPORTANT: getRange should not have the side effect of permanently moving the cursor.
        // The final cursor position is determined by the operator (.delete, .change, etc.)
        // which is called later in the `execute` function. So, we restore the original position.
        editor.cursorPosition = startPos

        // Now, calculate the range based on the motion type and start/end positions.
        switch motion {
        case .findCharacter(_, let forward, let till):
            if forward {
                return startPos ..< endPos + 1
            } else { // backward
                let inclusive = !till // 'F' is inclusive, 'T' is exclusive
                let lowerBound = endPos + (inclusive ? 0 : 1)
                return lowerBound ..< startPos + 1
            }

        case .line:
            // The `executeMotion` for .line doesn't move the cursor, it just selects.
            // We need to calculate the range manually.
            let textAsNSString = editor.text as NSString
            var lineNSRange = textAsNSString.lineRange(for: NSRange(location: startPos, length: 0))

            if count > 1 {
                var endOfLine = lineNSRange.upperBound
                for _ in 1..<count {
                    if endOfLine >= editor.text.count { break }
                    let nextLineRange = textAsNSString.lineRange(for: NSRange(location: endOfLine, length: 0))
                    endOfLine = nextLineRange.upperBound
                }
                lineNSRange.length = endOfLine - lineNSRange.location
            }

            // For transformations, exclude the trailing newline. For others, include it.
            let isTransform = op == .lowercase || op == .uppercase || op == .swapCase
            if isTransform {
                if lineNSRange.length > 0 && textAsNSString.character(at: lineNSRange.upperBound - 1) == 10 {
                    return lineNSRange.location..<(lineNSRange.upperBound - 1)
                }
            }
            return lineNSRange.location..<lineNSRange.upperBound

        default:
            // Default handling for simple motions like w, b, h, j, k, l, etc.
            return startPos <= endPos ? startPos..<endPos : endPos..<startPos
        }
    }

    private func execute(
        op: EditorOperator, motion: EditorMotion, count: Int, editor: EditorViewModel
    ) {
        print("Executing: \(op) on \(motion) for \(count) time(s)")
        editor.setLastAction(.standard(op: op, motion: motion, count: count))

        let range = getRange(op: op, motion: motion, count: count, editor: editor)

        // The cursor position after the action depends on the operator.
        let finalCursorPos: Int
        switch op {
        case .delete:
            finalCursorPos = range.lowerBound
        case .yank:
            finalCursorPos = editor.cursorPosition // Yank should not move the cursor
        case .change:
            finalCursorPos = range.lowerBound
        default:
            finalCursorPos = range.lowerBound
        }

        switch op {
        case .delete: editor.delete(range: range)
        case .yank: editor.yank(range: range)
        case .change: editor.change(range: range)
        case .lowercase: editor.transform(range: range, to: .lowercase)
        case .uppercase: editor.transform(range: range, to: .uppercase)
        case .swapCase: editor.transform(range: range, to: .swapCase)
        }

        // After the action, place the cursor at the correct position.
        // Note: `change` handles its own cursor positioning and mode switching.
        if op != .change {
            editor.cursorPosition = finalCursorPos
        }
        


        state = .idle
    }
}
