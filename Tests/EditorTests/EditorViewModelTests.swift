import XCTest
@testable import Editor

class EditorViewModelTests: XCTestCase {
    var editor: EditorViewModel!

    override func setUp() {
        super.setUp()
        editor = EditorViewModel()
    }

    // MARK: - Word Movement Tests

    func testMoveCursorForwardByWord() {
        editor.text = "one two three"
        editor.cursorPosition = 0

        editor.moveCursorForwardByWord()
        XCTAssertEqual(editor.cursorPosition, 4) // "two"

        editor.moveCursorForwardByWord()
        XCTAssertEqual(editor.cursorPosition, 8) // "three"

        editor.moveCursorForwardByWord()
        XCTAssertEqual(editor.cursorPosition, 13) // end of line
    }

    func testMoveCursorBackwardByWord() {
        editor.text = "one two three"
        editor.cursorPosition = 13

        editor.moveCursorBackwardByWord()
        XCTAssertEqual(editor.cursorPosition, 8) // "three"

        editor.moveCursorBackwardByWord()
        XCTAssertEqual(editor.cursorPosition, 4) // "two"

        editor.moveCursorBackwardByWord()
        XCTAssertEqual(editor.cursorPosition, 0) // "one"
    }
    
    func testMoveCursorToEndOfWord() {
        editor.text = "one two three"
        editor.cursorPosition = 0 // "o" of "one"
        
        editor.moveCursorToEndOfWord()
        XCTAssertEqual(editor.cursorPosition, 2) // "e" of "one"
        
        editor.cursorPosition = 5 // "w" of "two"
        editor.moveCursorToEndOfWord()
        XCTAssertEqual(editor.cursorPosition, 6) // "o" of "two"
    }

    // MARK: - Line Movement
    
    func testMoveCursorToEndOfLine() {
        // Test on a line with a newline character
        editor.text = "hello world\nnext line"
        editor.cursorPosition = 2 // "l" of "hello"
        
        editor.moveCursorToEndOfLine()
        
        // Should be on the 'd' of "world", which is index 10
        XCTAssertEqual(editor.cursorPosition, 10, "Failed on line with newline")
        
        // Test on the last line without a newline character
        editor.cursorPosition = 14 // "x" of "next"
        
        editor.moveCursorToEndOfLine()
        
        // Should be on the 'e' of "line", which is index 20
        XCTAssertEqual(editor.cursorPosition, 20, "Failed on line without newline")
        
        // Test on an empty line
        editor.text = "line 1\n\nline 3"
        editor.cursorPosition = 7 // The empty line
        
        editor.moveCursorToEndOfLine()
        
        // Should remain at the start of the empty line
        XCTAssertEqual(editor.cursorPosition, 7, "Failed on empty line")
    }

    func testMoveCursorToBeginningOfLine() {
        editor.text = "first line\n  second line"
        
        // Start in the middle of the second line
        editor.cursorPosition = 18 // "c" of "second"
        
        editor.moveCursorToBeginningOfLine()
        
        // Should be at the start of the second line (index 11)
        XCTAssertEqual(editor.cursorPosition, 11, "Failed to move to beginning of line")
        
        // Move to first line and test again
        editor.cursorPosition = 5 // " " of "first"
        editor.moveCursorToBeginningOfLine()
        XCTAssertEqual(editor.cursorPosition, 0, "Failed to move to beginning of first line")
    }

    // MARK: - Editing Tests

    func testOpenLineBelow() {
        editor.text = "line one"
        editor.cursorPosition = 4
        
        editor.openLineBelow()
        
        XCTAssertEqual(editor.text, "line one\n")
        XCTAssertEqual(editor.cursorPosition, 8)
        XCTAssert(editor.mode is InsertModeState)
    }

    func testOpenLineAbove() {
        editor.text = "line one"
        editor.cursorPosition = 4
        
        editor.openLineAbove()
        
        XCTAssertEqual(editor.text, "\nline one")
        XCTAssertEqual(editor.cursorPosition, 0)
        XCTAssert(editor.mode is InsertModeState)
    }
    
    func testDeleteToEndOfLine() {
        editor.text = "one two three"
        editor.cursorPosition = 4 // "t" of "two"
        
        editor.deleteToEndOfLine()
        
        XCTAssertEqual(editor.text, "one ")
        XCTAssertEqual(editor.cursorPosition, 4)
        XCTAssertEqual(editor.register, "two three")
    }

    func testCountedDeleteCharBackward() {
        editor.text = "abcdefg"
        editor.cursorPosition = 7 // End of the string

        // Simulate pressing '2' then 'X'
        editor.commandSM.handleToken(.digit(2), editor: editor)
        editor.commandSM.handleToken(.deleteCharBackward, editor: editor)

        XCTAssertEqual(editor.text, "abcde")
        XCTAssertEqual(editor.cursorPosition, 5)
    }
    
    // MARK: - Paste Tests
    
    func testPasteLinewiseAtEndOfFileWithoutNewline() {
        editor.text = "final line" // No trailing newline
        editor.cursorPosition = 5
        editor.setRegister(to: "pasted line\n")
        
        editor.paste()
        
        XCTAssertEqual(editor.text, "final line\npasted line\n")
        // Cursor should be at the beginning of the pasted line's content
        XCTAssertEqual(editor.cursorPosition, 11)
    }

    func testPasteCharacterwise() {
        editor.text = "hello world"
        editor.cursorPosition = 5 // at the space
        editor.setRegister(to: " cruel")

        editor.paste()

        // Vim's `p` pastes *after* the cursor.
        // Pasting " cruel" after the space at index 5 results in "hello  cruelworld".
        // The cursor lands on the last character of the pasted text.
        XCTAssertEqual(editor.text, "hello  cruelworld")
        XCTAssertEqual(editor.cursorPosition, 11)
    }

    // MARK: - Column Preservation
    
    func testColumnPreservation() {
        editor.text = "a long line\na short\nan even longer line"
        editor.cursorPosition = 7 // on "g" of "long"
        
        // Move down to the short line
        editor.moveCursorDown()
        XCTAssertEqual(editor.cursorPosition, 18, "Cursor should be at the end of the short line") // end of "a short"
        
        // Move down to the long line again
        editor.moveCursorDown()
        XCTAssertEqual(editor.cursorPosition, 27, "Cursor should return to the desired column") // "n" of "longer"
    }

    func testColumnPreservationFromLastCharacterOfLine() {
        editor.text = "1234567890\n" + // Line 1: len 11, content 10. Last char '0' is at index 9.
                      "123\n" +        // Line 2: len 4, content 3. Last char '3' is at index 14 (11+3).
                      "12345"          // Line 3: len 5, content 5. Last char '5' is at index 20 (15+5).

        // 1. Start on the last character of the first line.
        editor.cursorPosition = 9 // on '0'
        
        // 2. Move down to the second line, which is shorter.
        editor.moveCursorDown()
        
        // The desired column is 9. The second line has content length 3.
        // The cursor should land on the last character '3', at index 11 + 2 = 13.
        XCTAssertEqual(editor.cursorPosition, 13, "Cursor should be on the last character of the shorter line.")
        
        // 3. Move down to the third line. It's longer than the second, but shorter than the desired column.
        editor.moveCursorDown()
        
        // The desired column is still 9. The third line has content length 5.
        // The cursor should land on the last character '5', at index 15 + 4 = 19.
        XCTAssertEqual(editor.cursorPosition, 19, "Cursor should be on the last character of the shorter line.")
    }
    
    // MARK: - Operator+Motion Tests
    
    func testChangeWord() {
        editor.text = "one two three"
        editor.cursorPosition = 4 // "t" of "two"
        
        let range = 4..<8 // "two "
        editor.change(range: range)
        
        XCTAssertEqual(editor.text, "one three")
        XCTAssertEqual(editor.register, "two ")
        XCTAssertEqual(editor.cursorPosition, 4)
        XCTAssert(editor.mode is InsertModeState, "Should be in insert mode")
    }
    
    func testYankWord() {
        editor.text = "one two three"
        editor.cursorPosition = 0 // "o" of "one"
        
        let range = 0..<4 // "one "
        editor.yank(range: range)
        
        XCTAssertEqual(editor.text, "one two three") // text unchanged
        XCTAssertEqual(editor.register, "one ")
        XCTAssertEqual(editor.cursorPosition, 0) // cursor at start of yank
    }
}