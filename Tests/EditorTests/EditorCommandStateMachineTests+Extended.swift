
import XCTest

@testable import Editor

// MARK: - Text Object Tests (Extended)
extension EditorCommandStateMachineTests {
    func testDeleteInnerSingleQuotes() {
        editor.text = "one 'two three' four"
        editor.cursorPosition = 7  // on 'o' of 'two'

        // di'
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("'"), editor: editor)  // '''

        XCTAssertTrue(editor.log.contains("delete(range: 5..<14)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one '' four")
    }

    func testDeleteInnerBackticks() {
        editor.text = "one `two three` four"
        editor.cursorPosition = 7  // on 'o' of 'two'

        // di`
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("`"), editor: editor)  // '`'

        XCTAssertTrue(editor.log.contains("delete(range: 5..<14)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one `` four")
    }

    func testDeleteInnerCurlyBraces() {
        editor.text = "one {two three} four"
        editor.cursorPosition = 7  // on 'o' of 'two'

        // di{
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("{"), editor: editor)  // '{'

        XCTAssertTrue(editor.log.contains("delete(range: 5..<14)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one {} four")
    }

    func testDeleteInnerCurlyBracesWithB() {
        editor.text = "one {two three} four"
        editor.cursorPosition = 7  // on 'o' of 'two'

        // diB
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.inner, editor: editor)  // 'i'
        stateMachine.handleToken(.argument("B"), editor: editor)  // 'B'

        XCTAssertTrue(editor.log.contains("delete(range: 5..<14)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one {} four")
    }

    func testDeleteAroundCurlyBracesWithB() {
        editor.text = "one {two three} four"
        editor.cursorPosition = 7  // on 'o' of 'two'

        // daB
        stateMachine.handleToken(.delete, editor: editor)
        stateMachine.handleToken(.around, editor: editor) // 'a'
        stateMachine.handleToken(.argument("B"), editor: editor)  // 'B'

        XCTAssertTrue(editor.log.contains("delete(range: 3..<15)"), "Log was: \(editor.log)")
        XCTAssertEqual(editor.text, "one four")
    }
}
