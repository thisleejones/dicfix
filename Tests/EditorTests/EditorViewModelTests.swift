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