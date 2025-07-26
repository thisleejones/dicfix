// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

import XCTest

@testable import Editor

// MARK: - Undo/Redo Tests
class EditorCommandStateMachineUndoRedoTests: XCTestCase {
    var stateMachine: EditorCommandStateMachine!
    var editor: MockEditorViewModel!

    override func setUp() {
        super.setUp()
        stateMachine = EditorCommandStateMachine()
        editor = MockEditorViewModel()
        editor.text = "initial text"
        editor.cursorPosition = 0
    }

    func testUndoTokenInIdleState() {
        stateMachine.handleToken(.undo, editor: editor)
        XCTAssertEqual(editor.log.last, "undo")
    }

    func testRedoTokenInIdleState() {
        stateMachine.handleToken(.redo, editor: editor)
        XCTAssertEqual(editor.log.last, "redo")
    }

    func testUndoRedoSequence() {
        // Perform an action
        editor.text = "new text"
        editor.cursorPosition = 4
        
        // Undo the action
        stateMachine.handleToken(.undo, editor: editor)
        XCTAssertEqual(editor.log.last, "undo")
        
        // Redo the action
        stateMachine.handleToken(.redo, editor: editor)
        XCTAssertEqual(editor.log.last, "redo")
    }
}