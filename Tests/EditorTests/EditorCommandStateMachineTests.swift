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

    override func deleteToEndOfLine() {
        log.append("deleteToEndOfLine")
        super.deleteToEndOfLine()
    }

    override func yankToEndOfLine() {
        log.append("yankToEndOfLine")
        super.yankToEndOfLine()
    }

    override func changeToEndOfLine() {
        log.append("changeToEndOfLine")
        super.changeToEndOfLine()
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

    // MARK: - State Reset and Invalid Commands

    func testInvalidSequenceResetsState() {
        // Start with a valid operator
        stateMachine.handleToken(.delete, editor: editor)
        // Follow with an invalid token for this state
        stateMachine.handleToken(.switchToInsertMode, editor: editor)

        // The state machine should reset, and the standalone command should execute.
        XCTAssertEqual(editor.log, ["switchToInsertMode"])

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
    func testYankLineAndPasteAfter() {
        editor.text = "first line\nsecond line"
        editor.cursorPosition = 0  // On "first line"

        // Yank the first line ("yy")
        stateMachine.handleToken(.yank, editor: editor)
        stateMachine.handleToken(.yank, editor: editor)

        XCTAssertTrue(editor.log.contains { $0.contains("yank") })
        XCTAssertEqual(editor.register, "first line\n")

        // Move to the second line to paste after it
        editor.cursorPosition = 12  // On "second line"

        // Paste after ("p")
        stateMachine.handleToken(.paste, editor: editor)
        XCTAssertEqual(editor.log.last, "paste()")
        XCTAssertEqual(editor.text, "first line\nsecond line\nfirst line\n")
    }

    func testYankLineAndPasteBefore() {
        editor.text = "first line\nsecond line"
        editor.cursorPosition = 0  // On "first line"

        // Yank the first line ("yy")
        stateMachine.handleToken(.yank, editor: editor)
        stateMachine.handleToken(.yank, editor: editor)
        XCTAssertEqual(editor.register, "first line\n")

        // Move to the second line to paste before it
        editor.cursorPosition = 12  // On "second line"

        // Paste before ("P")
        stateMachine.handleToken(.pasteBefore, editor: editor)
        XCTAssertEqual(editor.log.last, "pasteBefore()")
        XCTAssertEqual(editor.text, "first line\nfirst line\nsecond line")
    }

    func testDeleteWordAndPaste() {
        editor.text = "one two three"
        editor.cursorPosition = 4  // Start of "two"

        // Delete a word ("dw")
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)

        // The register should contain the deleted word and the space.
        XCTAssertEqual(editor.register, "two ")
        XCTAssertEqual(editor.text, "one three")

        // Move cursor to the beginning
        editor.cursorPosition = 0

        // Paste after ("p")
        stateMachine.handleToken(.paste, editor: editor)
        XCTAssertEqual(editor.log.last, "paste()")
        // Note: paste after cursor inserts at position + 1
        XCTAssertEqual(editor.text, "otwo ne three")
    }

    func testYankLineAndPasteMultipleTimes() {
        editor.text = "line one\nline two"
        editor.cursorPosition = 0

        // Yank line ("yy")
        stateMachine.handleToken(.yank, editor: editor)
        stateMachine.handleToken(.yank, editor: editor)
        XCTAssertEqual(editor.register, "line one\n")

        // Paste 3 times ("3p")
        stateMachine.handleToken(.digit(3), editor: editor)
        stateMachine.handleToken(.paste, editor: editor)

        let pasteLog = editor.log.filter { $0 == "paste()" }
        XCTAssertEqual(pasteLog.count, 3, "Paste should have been called 3 times.")
        XCTAssertEqual(editor.text, "line one\nline one\nline one\nline one\nline two")
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
        XCTAssertTrue(editor.log.contains("transform(range: 4..<8, to: .swapCase)"), "Log was: \(editor.log)")
    }

    func testSwapCaseLine() {
        editor.text = "one tWo thRee\nFOUR five six"
        editor.cursorPosition = 0
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.swapCase, editor: editor)
        stateMachine.handleToken(.swapCase, editor: editor)  // g~~
        XCTAssertTrue(editor.log.contains("transform(range: 0..<13, to: .swapCase)"), "Log was: \(editor.log)")
    }

    // gu (lowercase)
    func testLowercaseWord() {
        editor.text = "one tWo thRee"
        editor.cursorPosition = 4  // on 't' of 'tWo'
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.lowercase, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertTrue(editor.log.contains("transform(range: 4..<8, to: .lowercase)"), "Log was: \(editor.log)")
    }

    func testLowercaseLine() {
        editor.text = "one tWo thRee\nFOUR five six"
        editor.cursorPosition = 14  // on 'F' of 'FOUR'
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.lowercase, editor: editor)
        stateMachine.handleToken(.lowercase, editor: editor)  // guu
        XCTAssertTrue(editor.log.contains("transform(range: 14..<27, to: .lowercase)"), "Log was: \(editor.log)")
    }

    // gU (uppercase)
    func testUppercaseWord() {
        editor.text = "one tWo thRee"
        editor.cursorPosition = 0
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)
        XCTAssertTrue(editor.log.contains("transform(range: 0..<4, to: .uppercase)"), "Log was: \(editor.log)")
    }

    func testUppercaseLine() {
        editor.text = "one tWo thRee\nFOUR five six"
        editor.cursorPosition = 0
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)  // gUU
        XCTAssertTrue(editor.log.contains("transform(range: 0..<13, to: .uppercase)"), "Log was: \(editor.log)")
    }

    func testCountedUppercaseWord() {
        editor.text = "one two three"
        editor.cursorPosition = 0
        stateMachine.handleToken(.digit(2), editor: editor)
        stateMachine.handleToken(.prefix("g"), editor: editor)
        stateMachine.handleToken(.uppercase, editor: editor)
        stateMachine.handleToken(.wordForward, editor: editor)  // 2gUw
        XCTAssertTrue(editor.log.contains("transform(range: 0..<8, to: .uppercase)"), "Log was: \(editor.log)")
    }
}
