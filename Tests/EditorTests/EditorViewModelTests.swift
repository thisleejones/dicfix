// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

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
                XCTAssertEqual(editor.cursorPosition, 4)  // "two"

                editor.moveCursorForwardByWord()
                XCTAssertEqual(editor.cursorPosition, 8)  // "three"

                editor.moveCursorForwardByWord()
                XCTAssertEqual(editor.cursorPosition, 13)  // end of line
        }

        func testMoveCursorBackwardByWord() {
                editor.text = "one two three"
                editor.cursorPosition = 13

                editor.moveCursorBackwardByWord()
                XCTAssertEqual(editor.cursorPosition, 8)  // "three"

                editor.moveCursorBackwardByWord()
                XCTAssertEqual(editor.cursorPosition, 4)  // "two"

                editor.moveCursorBackwardByWord()
                XCTAssertEqual(editor.cursorPosition, 0)  // "one"
        }

        func testMoveCursorToEndOfWord() {
                editor.text = "one two three"
                editor.cursorPosition = 0  // "o" of "one"

                editor.moveCursorToEndOfWord()
                XCTAssertEqual(editor.cursorPosition, 2)  // "e" of "one"

                editor.cursorPosition = 5  // "w" of "two"
                editor.moveCursorToEndOfWord()
                XCTAssertEqual(editor.cursorPosition, 6)  // "o" of "two"
        }

        // MARK: - Line Movement

        func testMoveCursorToEndOfLine() {
                // Test on a line with a newline character
                editor.text = "hello world\nnext line"
                editor.cursorPosition = 2  // "l" of "hello"

                editor.moveCursorToEndOfLine()

                // Should be on the 'd' of "world", which is index 10
                XCTAssertEqual(editor.cursorPosition, 10, "Failed on line with newline")

                // Test on the last line without a newline character
                editor.cursorPosition = 14  // "x" of "next"

                editor.moveCursorToEndOfLine()

                // Should be on the 'e' of "line", which is index 20
                XCTAssertEqual(editor.cursorPosition, 20, "Failed on line without newline")

                // Test on an empty line
                editor.text = "line 1\n\nline 3"
                editor.cursorPosition = 7  // The empty line

                editor.moveCursorToEndOfLine()

                // Should remain at the start of the empty line
                XCTAssertEqual(editor.cursorPosition, 7, "Failed on empty line")
        }

        func testMoveCursorToBeginningOfLine() {
                editor.text = "first line\n  second line"

                // Start in the middle of the second line
                editor.cursorPosition = 18  // "c" of "second"

                editor.moveCursorToBeginningOfLine()

                // Should be at the start of the second line (index 11)
                XCTAssertEqual(editor.cursorPosition, 11, "Failed to move to beginning of line")

                // Move to first line and test again
                editor.cursorPosition = 5  // " " of "first"
                editor.moveCursorToBeginningOfLine()
                XCTAssertEqual(
                        editor.cursorPosition, 0, "Failed to move to beginning of first line")
        }

        func testMoveCursorToScreenLineStartNonBlank() {
                // Text with leading spaces and tabs
                editor.text = "  line 1\n\t  line 2\nline 3"
                // Indices:
                // "  line 1" -> 0..7
                // \n -> 8
                // "\t  line 2" -> 9..17
                // \n -> 18
                // "line 3" -> 19..24

                // Test 1: Start in middle of a line with leading spaces
                editor.cursorPosition = 4  // on 'n' of 'line 1'
                editor.moveCursorToScreenLineStartNonBlank()
                XCTAssertEqual(editor.cursorPosition, 2, "Failed on line with leading spaces")

                // Test 2: Start at the end of a line with leading tab and spaces
                editor.cursorPosition = 17  // end of line 2
                editor.moveCursorToScreenLineStartNonBlank()
                // Should move to 'l' of "line 2". Index is 9 (start) + 1 (tab) + 2 (spaces) = 12
                XCTAssertEqual(
                        editor.cursorPosition, 12, "Failed on line with leading tab and spaces")

                // Test 3: Start on a line with no leading whitespace
                editor.cursorPosition = 22  // on 'e' of 'line 3'
                editor.moveCursorToScreenLineStartNonBlank()
                XCTAssertEqual(
                        editor.cursorPosition, 19, "Failed on line with no leading whitespace")

                // Test 4: On a line that is all whitespace
                editor.text = "line 1\n    \nline 3"
                // Indices:
                // "line 1" -> 0..5
                // \n -> 6
                // "    " -> 7..10
                // \n -> 11
                // "line 3" -> 12..17
                editor.cursorPosition = 9  // in the middle of the whitespace line
                editor.moveCursorToScreenLineStartNonBlank()
                // Should move to the beginning of that line
                XCTAssertEqual(editor.cursorPosition, 7, "Failed on a line with only whitespace")
        }

        func testGoToLine() {
                editor.text = "line 1\nline 2\nline 3" // 3 lines

                // Go to line 2
                editor.goToLine(2)
                XCTAssertEqual(editor.cursorPosition, 7, "Failed to go to line 2") // "line 1\n" is 7 chars

                // Go to line 3
                editor.goToLine(3)
                XCTAssertEqual(editor.cursorPosition, 14, "Failed to go to line 3") // "line 2\n" is 7 chars

                // Go to line 1
                editor.goToLine(1)
                XCTAssertEqual(editor.cursorPosition, 0, "Failed to go to line 1")

                // Go to a line number that is too high
                editor.goToLine(100)
                XCTAssertEqual(editor.cursorPosition, editor.text.count, "Failed to go to end of file for out-of-bounds line")

                // Go to last line via Int.max
                editor.goToLine(Int.max)
                XCTAssertEqual(editor.cursorPosition, editor.text.count, "Failed to go to end of file for Int.max")
        }

        // MARK: - Character Movement

        func testMoveCursorLeftAndRight() {
                editor.text = "abc"
                editor.cursorPosition = 1  // 'b'

                // Test 'l' - move right
                editor.moveCursorRight()
                XCTAssertEqual(editor.cursorPosition, 2, "Failed to move right")  // 'c'

                // Test 'l' at end of line
                editor.moveCursorRight()
                XCTAssertEqual(editor.cursorPosition, 2, "Should not move past end of line")

                // Test 'h' - move left
                editor.moveCursorLeft()
                XCTAssertEqual(editor.cursorPosition, 1, "Failed to move left")  // 'b'

                // Test 'h' at start of line
                editor.moveCursorLeft()
                XCTAssertEqual(editor.cursorPosition, 0, "Failed to move to start of line")  // 'a'

                editor.moveCursorLeft()
                XCTAssertEqual(editor.cursorPosition, 0, "Should not move past start of line")
        }

        // MARK: - Editing Tests

        func testOpenLineBelow() {
                editor.text = "line one"
                editor.cursorPosition = 4

                editor.openLineBelow()

                XCTAssertEqual(editor.text, "line one\n")
                XCTAssertEqual(editor.cursorPosition, 9)
                XCTAssert(editor.mode is InsertMode)
        }

        func testOpenLineBelowOnLastLineWithoutNewline() {                                   
                editor.text = "hello world"                                                      
                editor.cursorPosition = 5 // on 'o'                                              

                editor.openLineBelow()                                                           

                XCTAssertEqual(editor.text, "hello world\n")                                     
                XCTAssertEqual(editor.cursorPosition, 12) // Cursor should be on the new line    
                XCTAssertTrue(editor.mode is InsertMode, "Should be in insert mode")             
        }                                                                                    

        func testOpenLineBelowInEmptyFile() {                                                
                editor.text = ""                                                                 
                editor.cursorPosition = 0                                                        

                editor.openLineBelow()                                                           

                XCTAssertEqual(editor.text, "\n")                                                
                XCTAssertEqual(editor.cursorPosition, 1) // Cursor should be on the new line     
                XCTAssertTrue(editor.mode is InsertMode, "Should be in insert mode")             
        }                                                                                    

        func testOpenLineAbove() {
                editor.text = "line one"
                editor.cursorPosition = 4

                editor.openLineAbove()

                XCTAssertEqual(editor.text, "\nline one")
                XCTAssertEqual(editor.cursorPosition, 0)
                XCTAssert(editor.mode is InsertMode)
        }

        func testDeleteToEndOfLine() {
                editor.text = "one two three"
                editor.cursorPosition = 4  // "t" of "two"

                editor.deleteToEndOfLine()

                XCTAssertEqual(editor.text, "one ")
                XCTAssertEqual(editor.cursorPosition, 4)
                XCTAssertEqual(editor.register, "two three")
        }

        func testChangeToEndOfLine() {
                editor.text = "one two three"
                editor.cursorPosition = 4  // "t" of "two"

                editor.changeToEndOfLine()

                XCTAssertEqual(editor.text, "one ")
                XCTAssertEqual(editor.cursorPosition, 4)
                XCTAssertEqual(editor.register, "two three")
                XCTAssert(editor.mode is InsertMode, "Should be in insert mode")
        }

        func testCountedDeleteCharBackward() {
                editor.text = "abcdefg"
                editor.cursorPosition = 7  // End of the string

                // Simulate pressing '2' then 'X'
                editor.commandSM.handleToken(.digit(2), editor: editor)
                editor.commandSM.handleToken(.deleteCharBackward, editor: editor)

                XCTAssertEqual(editor.text, "abcde")
                XCTAssertEqual(editor.cursorPosition, 5)
        }

        // MARK: - Paste Tests

        func testPasteLinewiseAtEndOfFileWithoutNewline() {
                editor.text = "final line"  // No trailing newline
                editor.cursorPosition = 5
                editor.setRegister(to: "pasted line\n")

                editor.paste()

                XCTAssertEqual(editor.text, "final line\npasted line\n")
                // Cursor should be at the beginning of the pasted line's content
                XCTAssertEqual(editor.cursorPosition, 11)
        }

        func testPasteCharacterwise() {
                editor.text = "hello world"
                editor.cursorPosition = 5  // at the space
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
                editor.cursorPosition = 7  // on "g" of "long"

                // Move down to the short line
                editor.moveCursorDown()
                XCTAssertEqual(
                        editor.cursorPosition, 18, "Cursor should be at the end of the short line")  // end of "a short"

                // Move down to the long line again
                editor.moveCursorDown()
                XCTAssertEqual(
                        editor.cursorPosition, 27, "Cursor should return to the desired column")  // "n" of "longer"
        }

        func testColumnPreservationFromLastCharacterOfLine() {
                editor.text =
                        "1234567890\n"  // Line 1: len 11, content 10. Last char '0' is at index 9.
                        + "123\n"  // Line 2: len 4, content 3. Last char '3' is at index 14 (11+3).
                        + "12345"  // Line 3: len 5, content 5. Last char '5' is at index 20 (15+5).

                // 1. Start on the last character of the first line.
                editor.cursorPosition = 9  // on '0'

                // 2. Move down to the second line, which is shorter.
                editor.moveCursorDown()

                // The desired column is 9. The second line has content length 3.
                // The cursor should land on the last character '3', at index 11 + 2 = 13.
                XCTAssertEqual(
                        editor.cursorPosition, 13,
                        "Cursor should be on the last character of the shorter line."
                )

                // 3. Move down to the third line. It's longer than the second, but shorter than the desired column.
                editor.moveCursorDown()

                // The desired column is still 9. The third line has content length 5.
                // The cursor should land on the last character '5', at index 15 + 4 = 19.
                XCTAssertEqual(
                        editor.cursorPosition, 19,
                        "Cursor should be on the last character of the shorter line."
                )
        }

        // MARK: - Operator+Motion Tests

        func testChangeWord() {
                editor.text = "one two three"
                editor.cursorPosition = 4  // "t" of "two"

                let range = 4..<8  // "two "
                editor.change(range: range)

                XCTAssertEqual(editor.text, "one three")
                XCTAssertEqual(editor.register, "two ")
                XCTAssertEqual(editor.cursorPosition, 4)
                XCTAssert(editor.mode is InsertMode, "Should be in insert mode")
        }

        func testYankWord() {
                editor.text = "one two three"
                editor.cursorPosition = 0  // "o" of "one"

                let range = 0..<4  // "one "
                editor.yank(range: range)

                XCTAssertEqual(editor.text, "one two three")  // text unchanged
                XCTAssertEqual(editor.register, "one ")
                XCTAssertEqual(editor.cursorPosition, 0)  // cursor at start of yank
        }

        func testDeleteBackwardWordOverBlankLine() {
                editor.text = "abc\n\n  d"
                // Start cursor at 'd'
                editor.cursorPosition = 7

                // Get the range for the 'b' motion
                let startPosition = editor.cursorPosition
                editor.moveCursorBackwardByWord()
                let endPosition = editor.cursorPosition

                // The motion should land at the start of the blank line (index 4)
                XCTAssertEqual(endPosition, 4)

                // Now, perform the deletion over that range
                editor.cursorPosition = startPosition  // Reset cursor for deletion
                editor.delete(range: endPosition..<startPosition)

                XCTAssertEqual(editor.text, "abc\nd")
                XCTAssertEqual(editor.cursorPosition, 4)
        }

        func testForwardWordWithComplexWhitespace() {
                editor.text = "   but line is going to be this long."
                // Indices:
                // "   but" -> 0..5
                // " line" -> 6..10
                // " is" -> 11..13

                // Start at the beginning of "but"
                editor.cursorPosition = 3

                // Test 'w'
                editor.moveCursorForwardByWord()
                XCTAssertEqual(editor.cursorPosition, 7, "w from 'but' should land on 'line'")

                editor.moveCursorForwardByWord()
                XCTAssertEqual(editor.cursorPosition, 12, "w from 'line' should land on 'is'")

                editor.moveCursorForwardByWord()
                XCTAssertEqual(editor.cursorPosition, 15, "w from 'is' should land on 'going'")

                // Reset and test 'W'
                editor.cursorPosition = 3

                editor.moveCursorForwardByWord(isWORD: true)
                XCTAssertEqual(editor.cursorPosition, 7, "W from 'but' should land on 'line'")

                editor.moveCursorForwardByWord(isWORD: true)
                XCTAssertEqual(editor.cursorPosition, 12, "W from 'line' should land on 'is'")

                editor.moveCursorForwardByWord(isWORD: true)
                XCTAssertEqual(editor.cursorPosition, 15, "W from 'is' should land on 'going'")
        }

        func testBackwardWordWithComplexWhitespace() {
                editor.text = "   but line is going to be this long."
                // Indices:
                // "   but" -> 0..5
                // " line" -> 6..10
                // " is" -> 11..13

                // Start at the beginning of "going"
                editor.cursorPosition = 15

                // Test 'b'
                editor.moveCursorBackwardByWord()
                XCTAssertEqual(editor.cursorPosition, 12, "b from 'going' should land on 'is'")

                editor.moveCursorBackwardByWord()
                XCTAssertEqual(editor.cursorPosition, 7, "b from 'is' should land on 'line'")

                editor.moveCursorBackwardByWord()
                XCTAssertEqual(editor.cursorPosition, 3, "b from 'line' should land on 'but'")

                // Reset and test 'B'
                editor.cursorPosition = 15

                editor.moveCursorBackwardByWord(isWORD: true)
                XCTAssertEqual(editor.cursorPosition, 12, "B from 'going' should land on 'is'")

                editor.moveCursorBackwardByWord(isWORD: true)
                XCTAssertEqual(editor.cursorPosition, 7, "B from 'is' should land on 'line'")

                editor.moveCursorBackwardByWord(isWORD: true)
                XCTAssertEqual(editor.cursorPosition, 3, "B from 'line' should land on 'but'")
        }

        func testRepeatDeleteWord() {
                editor.text = "one two three"
                editor.cursorPosition = 0

                // Perform "dw"
                editor.handleToken(.delete)
                editor.handleToken(.wordForward)

                // Text should be "two three"
                XCTAssertEqual(editor.text, "two three")
                XCTAssertEqual(editor.cursorPosition, 0)

                // Now, repeat the action with "."
                editor.repeatLastAction()

                // Text should be "three"
                XCTAssertEqual(editor.text, "three")
                XCTAssertEqual(editor.cursorPosition, 0)
        }

        // MARK: - Character Search Tests
        func testMoveToCharacter() {
                editor.text = "one two three"
                editor.cursorPosition = 0  // "o"

                // Simulate "ft"
                editor.moveCursorToCharacter("t", forward: true, till: false)
                XCTAssertEqual(editor.cursorPosition, 4)  // "t" of "two"

                // Simulate "fe" from new position
                editor.moveCursorToCharacter("e", forward: true, till: false)
                XCTAssertEqual(editor.cursorPosition, 11)  // "e" of "three"

                // Test searching for a character that doesn't exist after the cursor
                let originalPosition = editor.cursorPosition
                editor.moveCursorToCharacter("z", forward: true, till: false)
                XCTAssertEqual(editor.cursorPosition, originalPosition)  // Cursor should not move
        }

        // MARK: - Visual Line Mode Tests

        func testVisualLineModeDelete() {
                editor.text = "line one\nline two\nline three"
                editor.cursorPosition = 0  // Start on line one

                // Enter Visual Line Mode ('V')
                editor.switchToVisualLineMode()
                XCTAssert(editor.mode is VisualLineMode)

                // Move down to select the second line ('j')
                editor.moveCursorDown()

                // The selection should now cover the first two lines.
                // Line 1: "line one\n" (0..<9)
                // Line 2: "line two\n" (9..<18)
                // Selection should be 0..<18
                XCTAssertEqual(editor.selection, 0..<18)

                // Apply the delete operator ('d')
                guard let selection = editor.selection else {
                        XCTFail("Selection should not be nil")
                        return
                }
                editor.delete(range: selection)
                editor.switchToNormalMode()

                // The first two lines should be deleted
                XCTAssertEqual(editor.text, "line three")
                // The register should contain the deleted lines
                XCTAssertEqual(editor.register, "line one\nline two\n")
                // Cursor should be at the beginning of the remaining text
                XCTAssertEqual(editor.cursorPosition, 0)
                // Mode should be back to normal
                XCTAssert(editor.mode is NormalMode)
        }

        func testVisualLineModeYank() {
                editor.text = "line one\nline two\nline three"
                editor.cursorPosition = 9  // Start on line two

                // Enter Visual Line Mode ('V')
                editor.switchToVisualLineMode()
                XCTAssert(editor.mode is VisualLineMode)

                // Move down to select the third line ('j')
                editor.moveCursorDown()

                // The selection should now cover lines two and three.
                // Line 2: "line two\n" (9..<18)
                // Line 3: "line three" (18..<28)
                // Selection should be 9..<28
                XCTAssertEqual(editor.selection, 9..<28)

                // Apply the yank operator ('y')
                guard let selection = editor.selection else {
                        XCTFail("Selection should not be nil")
                        return
                }
                editor.yank(range: selection)
                editor.switchToNormalMode()

                // The text should be unchanged
                XCTAssertEqual(editor.text, "line one\nline two\nline three")
                // The register should contain the yanked lines
                XCTAssertEqual(editor.register, "line two\nline three")
                // Cursor should be at the start of the selection
                XCTAssertEqual(editor.cursorPosition, 9)
                // Mode should be back to normal
                XCTAssert(editor.mode is NormalMode)
        }
}

// MARK: - Text Object Range Tests
extension EditorViewModelTests {
    func testInnerWordRange() {
        editor.text = "one two-three"
        
        // On a word
        var range = editor.range(for: .word, at: 1, inner: true)
        XCTAssertEqual(range, 0..<3)
        
        // On whitespace
        range = editor.range(for: .word, at: 3, inner: true)
        XCTAssertEqual(range, 3..<4)
        
        // On punctuation
        range = editor.range(for: .word, at: 7, inner: true)
        XCTAssertEqual(range, 7..<8)
    }

    func testInnerWORDRange() {
        editor.text = "one two-three"
        
        // On a word
        var range = editor.range(for: .WORD, at: 1, inner: true)
        XCTAssertEqual(range, 0..<3)
        
        // On whitespace
        range = editor.range(for: .WORD, at: 3, inner: true)
        XCTAssertEqual(range, 3..<4)
        
        // On punctuation, should select the whole WORD
        range = editor.range(for: .WORD, at: 7, inner: true)
        XCTAssertEqual(range, 4..<13)
    }
}
