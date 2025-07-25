// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

import XCTest

@testable import Editor

// MARK: - Mock EditorViewModel

class MockEditorViewModel: EditorViewModel {
    var log: [String] = []

    override func switchToInsertMode() {
        log.append("switchToInsertMode")
        super.switchToInsertMode()
    }

    override func switchToNormalMode() {
        log.append("switchToNormalMode")
        super.switchToNormalMode()
    }

    override func moveCursorToNextCharacter() {
        log.append("moveCursorToNextCharacter")
        super.moveCursorToNextCharacter()
    }

    override func moveCursorLeft() {
        log.append("moveCursorLeft")
        super.moveCursorLeft()
    }

    override func moveCursorRight() {
        log.append("moveCursorRight")
        super.moveCursorRight()
    }

    override func moveCursorUp() {
        log.append("moveCursorUp")
        super.moveCursorUp()
    }

    override func moveCursorDown() {
        log.append("moveCursorDown")
        super.moveCursorDown()
    }

    override func moveCursorForwardByWord(isWORD: Bool = false) {
        log.append("moveCursorForwardByWord(isWORD: \(isWORD))")
        super.moveCursorForwardByWord(isWORD: isWORD)
    }

    override func moveCursorBackwardByWord(isWORD: Bool = false) {
        log.append("moveCursorBackwardByWord(isWORD: \(isWORD))")
        super.moveCursorBackwardByWord(isWORD: isWORD)
    }

    override func moveCursorToBeginningOfLine() {
        log.append("moveCursorToBeginningOfLine")
        super.moveCursorToBeginningOfLine()
    }

    override func goToLine(_ line: Int) {
        log.append("goToLine(\(line))")
        super.goToLine(line)
    }

    override func delete(range: Range<Int>) {
        log.append("delete(range: \(range))")
        super.delete(range: range)
    }

    override func yank(range: Range<Int>) {
        log.append("yank(range: \(range))")
        super.yank(range: range)
    }

    override func change(range: Range<Int>) {
        log.append("change(range: \(range))")
        super.change(range: range)
    }

    override func deleteToEndOfLine(count: Int) {
        log.append("deleteToEndOfLine(count: \(count))")
        super.deleteToEndOfLine(count: count)
    }

    override func yankToEndOfLine(count: Int) {
        log.append("yankToEndOfLine(count: \(count))")
        super.yankToEndOfLine(count: count)
    }

    override func changeToEndOfLine(count: Int) {
        log.append("changeToEndOfLine(count: \(count))")
        super.changeToEndOfLine(count: count)
    }

    override func deleteCurrentCharacter() {
        log.append("deleteCurrentCharacter")
        super.deleteCurrentCharacter()
    }

    override func deleteCharBackward() {
        log.append("deleteCharBackward")
        super.deleteCharBackward()
    }

    override func requestSubmit() {
        log.append("requestSubmit")
        super.requestSubmit()
    }

    override func requestQuit() {
        log.append("requestQuit")
        super.requestQuit()
    }

    override func paste() {
        log.append("paste()")
        super.paste()
    }

    override func pasteBefore() {
        log.append("pasteBefore()")
        super.pasteBefore()
    }

    override func transform(range: Range<Int>, to type: TransformationType) {
        log.append("transform(range: \(range), to: .\(type))")
        super.transform(range: range, to: type)
    }

    override func moveCursorToCharacter(_ character: Character, forward: Bool, till: Bool) {
        log.append("moveCursorToCharacter(\"\(character)\", forward: \(forward), till: \(till))")
        super.moveCursorToCharacter(character, forward: forward, till: till)
    }
}

// MARK: - State Machine Tests

class EditorCommandStateMachineTests: XCTestCase {
    var stateMachine: EditorCommandStateMachine!
    var editor: MockEditorViewModel!

    override func setUp() {
        super.setUp()
        stateMachine = EditorCommandStateMachine()
        editor = MockEditorViewModel()
        editor.text = "one two three\nfour five six"
        editor.cursorPosition = 0
    }

    // MARK: - Standalone Commands

    func testStandaloneCommands() {
        stateMachine.handleToken(.switchToInsertMode, editor: editor)
        XCTAssertEqual(editor.log.last, "switchToInsertMode")

        stateMachine.handleToken(.switchToInsertModeAndMove, editor: editor)
        XCTAssertTrue(editor.log.contains("moveCursorToNextCharacter"))
        XCTAssertTrue(editor.log.contains("switchToInsertMode"))

        stateMachine.handleToken(.deleteToEndOfLine, editor: editor)
        XCTAssertTrue(editor.log.last?.contains("delete") ?? false)

        stateMachine.handleToken(.deleteChar, editor: editor)
        XCTAssertTrue(editor.log.last?.contains("delete") ?? false)
    }

    // MARK: - Motion Tests

    func testSimpleMotion() {
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertEqual(editor.log, ["moveCursorForwardByWord(isWORD: false)"])
    }

    func testCountedMotion() {
        stateMachine.handleToken(.digit(3), editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertEqual(
            editor.log,
            [
                "moveCursorForwardByWord(isWORD: false)",
                "moveCursorForwardByWord(isWORD: false)",
                "moveCursorForwardByWord(isWORD: false)",
            ])
    }

    func testMultiDigitCountedMotion() {
        stateMachine.handleToken(.digit(1), editor: editor)
        stateMachine.handleToken(.digit(2), editor: editor)
        stateMachine.handleToken(.lineDown, editor: editor)

        let expected = Array(repeating: "moveCursorDown", count: 12)
        XCTAssertEqual(editor.log, expected)
    }

    // MARK: - Operator + Motion Tests

    func testSimpleOperatorMotion() {
        editor.cursorPosition = 0
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)

        // The motion is executed first to find the range
        XCTAssertEqual(editor.log.first, "moveCursorForwardByWord(isWORD: false)")
        // Then the operation is performed on the range
        XCTAssertTrue(editor.log.contains("delete(range: 0..<4)"), "Log was: \(editor.log)")
    }

    func testCountedOperatorMotion() {
        editor.cursorPosition = 0
        stateMachine.handleToken(.digit(2), editor: editor)
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)

        XCTAssertEqual(
            editor.log,
            [
                "moveCursorForwardByWord(isWORD: false)",
                "moveCursorForwardByWord(isWORD: false)",
                "delete(range: 0..<8)",
            ])
    }

    // MARK: - Doubled Operator (Line-wise) Tests

    func testDoubledOperator() {
        editor.cursorPosition = 5  // middle of "one two three"
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.delete, editor: editor)

        // The motion is 'selectLine', then the operation is 'delete'
        XCTAssertTrue(editor.log.contains { $0.contains("delete") })
    }

    func testCountedDoubledOperator() {
        editor.cursorPosition = 0
        stateMachine.handleToken(.digit(2), editor: editor)
        stateMachine.handleToken(.yank, editor: editor)
        stateMachine.handleToken(.yank, editor: editor)

        // Should select 2 lines then yank
        XCTAssertTrue(editor.log.contains { $0.contains("yank") })
    }

    // MARK: - Prefix Command Tests

    func testGoToFirstLineCommand() {
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.prefix("g"), editor: editor)
        XCTAssertEqual(editor.log.last, "goToLine(1)")
    }

    func testGoToLineCommand() {
        stateMachine.handleToken(.digit(1), editor: editor)
        stateMachine.handleToken(.digit(0), editor: editor)
        stateMachine.handleToken(.goToEndOfFile, editor: editor)  // G
        XCTAssertEqual(editor.log.last, "goToLine(10)")
    }

    func testEscapeFromWaitingState() {
        // 1. Start a command that puts the state machine in a waiting state.
        stateMachine.handleToken(.delete, editor: editor)
        XCTAssert(
            stateMachine.state.description.contains("waitingForMotion"),
            "State should be waitingForMotion")

        // 2. Press escape to cancel the command.
        stateMachine.handleToken(.requestQuit, editor: editor)

        // 3. Verify the state is now idle and no action was taken.
        XCTAssert(stateMachine.state.description.contains("idle"), "State should be idle")
        XCTAssert(editor.log.isEmpty, "No editor actions should have been logged")

        // 4. Press escape again to quit.
        stateMachine.handleToken(.requestQuit, editor: editor)
        XCTAssertEqual(editor.log.last, "requestQuit")
    }

    // MARK: - State Reset and Invalid Commands

    func testInvalidSequenceResetsState() {
        // Start with a valid operator
        stateMachine.handleToken(.delete, editor: editor)
        // Follow with an invalid token for this state, e.g., 'p' for paste.
        stateMachine.handleToken(.paste, editor: editor)

        // The state machine should reset, and the standalone command should execute.
        XCTAssertEqual(editor.log, ["paste()"])

        // Now try a simple motion to ensure we are back in idle
        editor.log.removeAll()
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertEqual(editor.log, ["moveCursorForwardByWord(isWORD: false)"])
    }

    func testZeroAsMotion() {
        stateMachine.handleToken(.digit(0), editor: editor)
        XCTAssertEqual(editor.log.last, "moveCursorToBeginningOfLine")
    }

    func testZeroAsCount() {
        stateMachine.handleToken(.digit(1), editor: editor)
        stateMachine.handleToken(.digit(0), editor: editor)  // count is 10
        stateMachine.handleToken(.charLeft, editor: editor)
        XCTAssertEqual(editor.log.count, 10)
        XCTAssertEqual(editor.log.last, "moveCursorLeft")
    }

    func testFindCharacter() {
        editor.text = "one two three"
        editor.cursorPosition = 0

        // Simulate "ft"
        stateMachine.handleToken(.prefix("f"), editor: editor)
        stateMachine.handleToken(.argument("t"), editor: editor)

        XCTAssertEqual(editor.log.last, "moveCursorToCharacter(\"t\", forward: true, till: false)")
    }

    func testFindCharacterBackward() {
        editor.text = "one two three"
        editor.cursorPosition = 10  // "h" of "three"

        // Simulate "Ft"
        stateMachine.handleToken(.prefix("F"), editor: editor)
        stateMachine.handleToken(.argument("t"), editor: editor)

        XCTAssertEqual(editor.log.last, "moveCursorToCharacter(\"t\", forward: false, till: false)")
    }

    func testTillCharacterForward() {
        editor.text = "one two three"
        editor.cursorPosition = 0

        // Simulate "tt"
        stateMachine.handleToken(.prefix("t"), editor: editor)
        stateMachine.handleToken(.argument("t"), editor: editor)

        XCTAssertEqual(editor.log.last, "moveCursorToCharacter(\"t\", forward: true, till: true)")
    }

    func testTillCharacterBackward() {
        editor.text = "one two three"
        editor.cursorPosition = 10

        // Simulate "Tt"
        stateMachine.handleToken(.prefix("T"), editor: editor)
        stateMachine.handleToken(.argument("t"), editor: editor)

        XCTAssertEqual(editor.log.last, "moveCursorToCharacter(\"t\", forward: false, till: true)")
    }
}

// MARK: - Yank/Paste Tests
extension EditorCommandStateMachineTests {
    // MARK: Y (Yank to End of Line)
    func testYankToEndOfLine() {
        // Test case 1: Yank from cursor to end of line (Y)
        editor.text = "one two three"
        editor.cursorPosition = 4 // on 't' of 'two'
        stateMachine.handleToken(.yankToEndOfLine, editor: editor)
        XCTAssertEqual(editor.register, "two three")
        XCTAssertEqual(editor.cursorPosition, 4, "Cursor should not move after Y")
        
        setUp() // Reset state for next test case

        // Test case 2: Yank multiple lines, from cursor on first line, then subsequent full lines (3Y)
        editor.text = "one two three\nfour five six\nseven eight nine"
        editor.cursorPosition = 4 // on 't' of 'two'
        stateMachine.handleToken(.digit(3), editor: editor)
        stateMachine.handleToken(.yankToEndOfLine, editor: editor)
        let expectedYank = "two three\nfour five six\nseven eight nine"
        XCTAssertEqual(editor.register, expectedYank)
        XCTAssertEqual(editor.cursorPosition, 4, "Cursor should not move after 3Y")
        
        setUp() // Reset state for next test case

        // Test case 3: Yank multiple lines with a short line in the middle (3Y)
        editor.text = "one two three\nfour\nseven eight nine"
        editor.cursorPosition = 4 // on 't' of 'two'
        stateMachine.handleToken(.digit(3), editor: editor)
        stateMachine.handleToken(.yankToEndOfLine, editor: editor)
        let expectedYankWithShortLine = "two three\nfour\nseven eight nine"
        XCTAssertEqual(editor.register, expectedYankWithShortLine)
        XCTAssertEqual(editor.cursorPosition, 4, "Cursor should not move")
    }

    // MARK: yy (Yank Line)
    func testYankLinewise() {
        // Test case 1: Yank a single entire line (yy)
        editor.text = "one two three\nfour five six"
        editor.cursorPosition = 5 // on 't' of 'two'
        stateMachine.handleToken(.yank, editor: editor)
        stateMachine.handleToken(.yank, editor: editor)
        XCTAssertEqual(editor.register, "one two three\n")
        XCTAssertEqual(editor.cursorPosition, 0, "Cursor should move to beginning of the line after yy")

        setUp() // Reset state for next test case

        // Test case 2: Yank multiple entire lines (3yy)
        editor.text = "one\ntwo\nthree\nfour"
        editor.cursorPosition = 4 // on 't' of 'two'
        stateMachine.handleToken(.digit(3), editor: editor)
        stateMachine.handleToken(.yank, editor: editor)
        stateMachine.handleToken(.yank, editor: editor)
        XCTAssertEqual(editor.register, "two\nthree\nfour")
        XCTAssertEqual(editor.cursorPosition, 4, "Cursor should move to beginning of the first yanked line")
    }

    // MARK: Paste
    func testPasteAfter() {
        editor.text = "first line\nsecond line"
        editor.cursorPosition = 0
        editor.setRegister(to: "pasted text")

        // p
        stateMachine.handleToken(.paste, editor: editor)
        XCTAssertEqual(editor.text, "fpasted textirst line\nsecond line")
    }

    func testPasteBefore() {
        editor.text = "first line\nsecond line"
        editor.cursorPosition = 0
        editor.setRegister(to: "pasted text")

        // P
        stateMachine.handleToken(.pasteBefore, editor: editor)
        XCTAssertEqual(editor.text, "pasted textfirst line\nsecond line")
    }
}

// MARK: - Transformation (g~, gu, gU) Tests
extension EditorCommandStateMachineTests {
    // g~ (swap case)
    func testSwapCaseWord() {
        editor.text = "one tWo thRee"
        editor.cursorPosition = 4  // on 't' of 'tWo'
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.swapCase, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertTrue(
            editor.log.contains("transform(range: 4..<8, to: .swapCase)"), "Log was: \(editor.log)")
    }

    func testSwapCaseLine() {
        editor.text = "one tWo thRee\nFOUR five six"
        editor.cursorPosition = 0
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.swapCase, editor: editor)
        stateMachine.handleToken(.swapCase, editor: editor)  // g~~
        XCTAssertTrue(
            editor.log.contains("transform(range: 0..<13, to: .swapCase)"), "Log was: \(editor.log)"
        )
    }

    // gu (lowercase)
    func testLowercaseWord() {
        editor.text = "one tWo thRee"
        editor.cursorPosition = 4  // on 't' of 'tWo'
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.lowercase, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertTrue(
            editor.log.contains("transform(range: 4..<8, to: .lowercase)"), "Log was: \(editor.log)"
        )
    }

    func testLowercaseLine() {
        editor.text = "one tWo thRee\nFOUR five six"
        editor.cursorPosition = 14  // on 'F' of 'FOUR'
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.lowercase, editor: editor)
        stateMachine.handleToken(.lowercase, editor: editor)  // guu
        XCTAssertTrue(
            editor.log.contains("transform(range: 14..<27, to: .lowercase)"),
            "Log was: \(editor.log)")
    }

    // gU (uppercase)
    func testUppercaseWord() {
        editor.text = "one tWo thRee"
        editor.cursorPosition = 0
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertTrue(
            editor.log.contains("transform(range: 0..<4, to: .uppercase)"), "Log was: \(editor.log)"
        )
    }

    func testUppercaseLine() {
        editor.text = "one tWo thRee\nFOUR five six"
        editor.cursorPosition = 0
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)  // gUU
        XCTAssertTrue(
            editor.log.contains("transform(range: 0..<13, to: .uppercase)"),
            "Log was: \(editor.log)")
    }

    func testCountedUppercaseWord() {
        editor.text = "one two three"
        editor.cursorPosition = 0
        stateMachine.handleToken(.digit(2), editor: editor)
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)  // 2gUw
        XCTAssertTrue(
            editor.log.contains("transform(range: 0..<8, to: .uppercase)"), "Log was: \(editor.log)"
        )
    }
}

// MARK: - Text Object Tests
extension EditorCommandStateMachineTests {
    func testDeleteInnerWord() {
        editor.text = "one two three"
        editor.cursorPosition = 5  // on 'w' of 'two'

        // diw
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("w"), editor: editor)  // 'w'

        XCTAssertTrue(editor.log.contains("delete(range: 4..<7)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one  three")
    }

    func testDeleteInnerWordOnWhitespace() {
        editor.text = "one two three"
        editor.cursorPosition = 3  // on space after "one"

        // diw
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("w"), editor: editor)  // 'w'

        XCTAssertTrue(editor.log.contains("delete(range: 3..<4)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "onetwo three")
    }

    func testDeleteInnerWORD() {
        editor.text = "one-two-three four"
        editor.cursorPosition = 5  // on 'w' of 'two'

        // diW
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("W"), editor: editor)  // 'W'

        XCTAssertTrue(editor.log.contains("delete(range: 0..<13)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, " four")
    }

    func testDeleteInnerDoubleQuotes() {
        editor.text = "one \"two three\" four"
        editor.cursorPosition = 7  // on 'o' of 'two'

        // di\"
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("\""), editor: editor)  // '"'

        XCTAssertTrue(editor.log.contains("delete(range: 5..<14)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one \"\" four")
    }

    func testDeleteInnerParentheses() {
        editor.text = "one (two (three)) four"
        editor.cursorPosition = 13  // on 'h' of 'three'

        // dib
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("b"), editor: editor)  // 'b'

        XCTAssertTrue(editor.log.contains("delete(range: 10..<15)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one (two ()) four")
    }
}

// MARK: - Deletion and Change Tests
extension EditorCommandStateMachineTests {
    func testDeleteToEndOfLine_Counted() {
        editor.text = "one two\nthree four\nfive six"
        editor.cursorPosition = 4 // on 't' of 'two'

        // 2D
        stateMachine.handleToken(.digit(2), editor: editor)
        stateMachine.handleToken(.deleteToEndOfLine, editor: editor)

        XCTAssertEqual(editor.text, "one \nfive six")
        XCTAssertEqual(editor.cursorPosition, 4)
    }

    func testChangeToEndOfLine_Counted() {
        editor.text = "one two\nthree four\nfive six"
        editor.cursorPosition = 4 // on 't' of 'two'

        // 2C
        stateMachine.handleToken(.digit(2), editor: editor)
        stateMachine.handleToken(.changeToEndOfLine, editor: editor)

        XCTAssertEqual(editor.text, "one \nfive six")
        XCTAssertEqual(editor.cursorPosition, 4)
        XCTAssertTrue(editor.log.contains("switchToInsertMode"), "Should switch to insert mode after C")
    }
}

// MARK: - Operator + Find/To Tests
extension EditorCommandStateMachineTests {
    func testDeleteTillChar() {
        editor.text = "one two three"
        editor.cursorPosition = 0 // on 'o'

        // dt' '
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.prefix("t"), editor: editor)
        stateMachine.handleToken(.argument(" "), editor: editor)

        XCTAssertTrue(editor.log.contains("delete(range: 0..<3)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, " two three")
        XCTAssertEqual(editor.cursorPosition, 0)
    }

    func testDeleteFindChar() {
        editor.text = "one two three"
        editor.cursorPosition = 0 // on 'o'

        // df' '
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.prefix("f"), editor: editor)
        stateMachine.handleToken(.argument(" "), editor: editor)

        XCTAssertTrue(editor.log.contains("delete(range: 0..<4)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "two three")
        XCTAssertEqual(editor.cursorPosition, 0)
    }

    func testYankFindChar() {
        editor.text = "one two three"
        editor.cursorPosition = 0 // on 'o'

        // yf' '
        stateMachine.handleToken(.yank, editor: editor)
        stateMachine.handleToken(.prefix("f"), editor: editor)
        stateMachine.handleToken(.argument(" "), editor: editor)

        XCTAssertTrue(editor.log.contains("yank(range: 0..<4)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.register, "one ")
        XCTAssertEqual(editor.text, "one two three") // Yank shouldn't change text
        XCTAssertEqual(editor.cursorPosition, 0)
    }

    func testChangeTillChar() {
        editor.text = "one two three"
        editor.cursorPosition = 4 // on 't' of 'two'

        // ct'h'
        stateMachine.handleToken(.change, editor: editor)
        stateMachine.handleToken(.prefix("t"), editor: editor)
        stateMachine.handleToken(.argument("h"), editor: editor)

        XCTAssertTrue(editor.log.contains("change(range: 4..<9)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one hree")
        XCTAssertEqual(editor.cursorPosition, 4)
        XCTAssertTrue(editor.log.contains("switchToInsertMode"), "Should switch to insert mode")
    }
    
    func testDeleteFindCharBackward() {
        editor.text = "one two three"
        editor.cursorPosition = 12 // on 'e' of 'three'

        // dF' '
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.prefix("F"), editor: editor)
        stateMachine.handleToken(.argument(" "), editor: editor)

        XCTAssertTrue(editor.log.contains("delete(range: 7..<13)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one two")
        XCTAssertEqual(editor.cursorPosition, 7)
    }
}