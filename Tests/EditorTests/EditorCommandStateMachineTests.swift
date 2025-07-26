// MARK: - Repeat Find Tests
extension EditorCommandStateMachineTests {
    func testRepeatFindForward() {
        editor.text = "one two one three"
        editor.cursorPosition = 0

        // Find the first 'o'
        stateMachine.handleToken(.prefix("f"), editor: editor)
        stateMachine.handleToken(.argument("o"), editor: editor)
        XCTAssertEqual(editor.cursorPosition, 0) // Stays put on first char

        // Repeat forward (;)
        stateMachine.handleToken(.repeatLastFindForward, editor: editor)
        XCTAssertEqual(editor.cursorPosition, 8) // Jumps to 'o' in "one"
    }

    func testRepeatFindBackward() {
        editor.text = "one two one three"
        editor.cursorPosition = 0

        // Find the first 'n'
        stateMachine.handleToken(.prefix("f"), editor: editor)
        stateMachine.handleToken(.argument("n"), editor: editor)
        XCTAssertEqual(editor.cursorPosition, 1)

        // Repeat forward (;)
        stateMachine.handleToken(.repeatLastFindForward, editor: editor)
        XCTAssertEqual(editor.cursorPosition, 9) // Jumps to 'n' in "one"

        // Repeat backward (,)
        stateMachine.handleToken(.repeatLastFindBackward, editor: editor)
        XCTAssertEqual(editor.cursorPosition, 1) // Jumps back to first 'n'
    }

    func testRepeatTill() {
        let realEditor = EditorViewModel()
        realEditor.text = "one-two-three"
        realEditor.cursorPosition = 0

        // dt-
        stateMachine.handleToken(.delete, editor: realEditor)
        stateMachine.handleToken(.prefix("t"), editor: realEditor)
        stateMachine.handleToken(.argument("-"), editor: realEditor)

        XCTAssertEqual(realEditor.text, "-two-three")
        XCTAssertEqual(realEditor.cursorPosition, 0)

        // d;
        stateMachine.handleToken(.delete, editor: realEditor)
        stateMachine.handleToken(.repeatLastFindForward, editor: realEditor)

        XCTAssertEqual(realEditor.text, "-three")
        XCTAssertEqual(realEditor.cursorPosition, 0)
    }
    
    func testRepeatFindBackwardAfterForwardFind() {
        editor.text = "one two one three"
        editor.cursorPosition = 0

        // Find 'n'
        stateMachine.handleToken(.prefix("f"), editor: editor)
        stateMachine.handleToken(.argument("n"), editor: editor)
        XCTAssertEqual(editor.cursorPosition, 1)

        // Find next 'n'
        stateMachine.handleToken(.repeatLastFindForward, editor: editor)
        XCTAssertEqual(editor.cursorPosition, 9)

        // Now, repeat backward with ','
        stateMachine.handleToken(.repeatLastFindBackward, editor: editor)
        XCTAssertEqual(editor.cursorPosition, 1)
    }

    func testRepeatFindForwardAfterBackwardFind() {
        editor.text = "one two one three"
        editor.cursorPosition = 12

        // Find 't' backward
        stateMachine.handleToken(.prefix("F"), editor: editor)
        stateMachine.handleToken(.argument("t"), editor: editor)
        XCTAssertEqual(editor.cursorPosition, 8)

        // Repeat backward with ';'
        stateMachine.handleToken(.repeatLastFindForward, editor: editor)
        XCTAssertEqual(editor.cursorPosition, 4)

        // Now, repeat forward with ','
        stateMachine.handleToken(.repeatLastFindBackward, editor: editor)
        XCTAssertEqual(editor.cursorPosition, 8)
    }
}