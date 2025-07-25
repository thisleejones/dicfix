# DicFix Editor Internals

This document provides a comprehensive guide to the architecture and design of the Vim-style modal editor component within DicFix.

> **Note:** The Vim editor is disabled by default. To enable it, set `"vimMode": true` in your `settings.json` file or use the `--vim-mode` command-line flag when running the application.

> [!WARNING]
> **Disclaimer: This is a new and rapidly evolving feature.**
> The Vim editing mode was not part of the original plan for this application and has been developed very quickly. While it is powerful, you should expect some bugs or rough edges. Please report any issues you find.

---

## 1. Key Handling and Architecture

The editor's key handling follows a clear, well-structured path, starting from the view and propagating down to the state-specific logic. This ensures a clean separation of concerns.

1.  **`EditorTextField` (`NSTextViewRepresentable`)**
    This is the entry point for all keyboard input. It intercepts `keyDown(with:)` events from AppKit. Instead of letting `NSTextView` handle them directly, it wraps the `NSEvent` into a custom `KeyEvent` and passes it to the view model. By returning `true`, it signals that the event has been handled, preventing the default text system from processing it—a crucial behavior for a modal editor.

2.  **`EditorViewModel`**
    The view model acts as the central hub for the editor's state and logic. Its `handleEvent` method delegates the event to the current mode object (e.g., `InsertMode` or `NormalMode`), following the State design pattern. It exposes a clean API for all text and cursor manipulations.

3.  **`EditorMode` (Protocol & Implementations)**
    This is where the core logic for each mode resides.
    -   **`InsertMode`:** This state is straightforward. It checks for the `Escape` key to switch back to Normal mode. For all other keys, it returns `false`, allowing the standard text input system to handle them.
    -   **`NormalMode`:** This is the heart of the Vim-like behavior. It consumes almost all key events to prevent text insertion. It uses a `switch` statement to map keys (`h`, `j`, `k`, `l`, `w`, `b`, `d`, `c`, etc.) to command tokens, which are then processed by the state machine.

4.  **`EditorCommandStateMachine`**
    For complex, multi-key commands (`dd`, `dw`, `ciw`), the `NormalMode` sends command "tokens" (like `.delete`, `.change`, `.wordForward`) to the state machine. The state machine's job is to assemble a complete, valid command (e.g., operator + motion) and then execute the final action (e.g., `editor.delete(range:)`) on the view model.

### Architectural Assessment

-   **Separation of Concerns:** The architecture cleanly separates responsibilities. The View captures raw input, the ViewModel manages state and exposes a clean API, the State objects encapsulate mode-specific logic, and the Command State Machine handles the complexity of multi-key command sequences.
-   **Extensibility:** The design is highly extensible. Adding new commands, motions, or operators is a matter of extending the relevant enums (`EditorCommandToken`, `EditorMotion`, `EditorOperator`) and updating the state machine logic.
-   **Clarity:** The control flow is logical and easy to follow, making it clear where to find specific functionality.

---

## 2. Supported Commands

The editor supports a wide range of Vim-style commands, including counts and text objects.

### Command Structures

| Format                               | Description                                      | Examples                               |
| ------------------------------------ | ------------------------------------------------ | -------------------------------------- |
| `(command)`                          | A single-key standalone command.                 | `i`, `a`, `D`, `C`, `x`, `p`             |
| `(motion)`                           | A single-key cursor movement.                    | `h`, `j`, `k`, `l`, `w`, `b`, `0`, `$`   |
| `(operator)(motion)`                 | An operator followed by a motion.                | `dw`, `c0`, `y$`                         |
| `(operator)(operator)`               | A doubled operator for line-wise actions.        | `dd`, `yy`, `cc`                         |
| `(prefix)(suffix)`                   | A two-key command starting with a prefix.        | `gg`, `g~`, `gu`, `gU`                   |
| `(operator)(prefix)(suffix)`         | An operator followed by a text object.           | `diw`, `caw`, `yi"`, `da{`              |
| `(operator)(prefix)(find_char)`      | An operator followed by a find/till command.     | `dtc`, `df"`, `ct;`                      |

### Counts

Counts can be prepended to most commands to repeat them.

-   **Count + Motion:** `3w` (move 3 words forward)
-   **Count + Operator + Motion:** `2dw` (delete 2 words)
-   **Count + Doubled Operator:** `4dd` (delete 4 lines)

### Supported Operators

-   `d`: **Delete**
-   `c`: **Change** (delete and enter insert mode)
-   `y`: **Yank** (copy)
-   `g~`: **Swap Case**
-   `gu`: **Lowercase**
-   `gU`: **Uppercase**

### Supported Text Objects

Text objects are used with operators to act on specific regions of text. They are triggered by a prefix (`i` for "inner" or `a` for "around").

| Selector(s) | Description                               | Example (Delete Inner) | Example (Delete Around) |
| ----------- | ----------------------------------------- | ---------------------- | ----------------------- |
| `w`, `W`    | word / WORD                               | `diw`                  | `daw`                   |
| `"`         | double quotes                             | `di"`                  | `da"`                   |
| `'`         | single quotes                             | `di'`                  | `da'`                   |
| `` ` ``     | backticks                                 | `di``                  | `da``                   |
| `(`, `)`, `b` | parentheses                               | `dib`                  | `dab`                   |
| `{`, `}`, `B` | curly braces                              | `diB`                  | `daB`                   |
| `[`, `]`    | square brackets                           | `di[`                  | `da[`                   |

### The Repeat (`.`) Command

The editor supports repeating the last change using the `.` command. The implementation relies on storing the last command in the `EditorViewModel` as a `RepeatableAction`.

-   **Supported Repeatable Commands:**
    -   All standard `operator + motion` commands (`dw`, `ciw`, `3dd`, etc.).
    -   Standalone change commands: `D`, `C`, `x`, `X`, `o`, `O`, `p`, `P`.
-   **Known Gaps:**
    -   `Y` (yank to end of line) is currently a synonym for `yy` and is repeatable as such, but it is not its own distinct repeatable action.

---

## 3. How to Add a New Command

This guide provides a step-by-step process for adding new commands to the editor, ensuring consistency with the existing architecture.

### Adding a Simple Motion

1.  **`EditorCommands.swift`**:
    -   Add a case to `EditorMotion`: `.newMotion`.
    -   Add a case to `EditorCommandToken`: `.newMotion`.
    -   Map the token to the motion in the `toMotion` computed property.
    -   Update `from(keyEvent:state:)` to create the token from the desired key press.
2.  **`EditorViewModel.swift`**: Implement the cursor logic in a new method (e.g., `moveWithNewMotion()`).
3.  **`EditorCommands.swift`**: In `executeMotion`, call the new view model method for your motion case.

### Adding an Operator

1.  **`EditorCommands.swift`**:
    -   Add a case to `EditorOperator`: `.newOperator`.
    -   Add a case to `EditorCommandToken`: `.newOperator`.
    -   Map the token in the `toOperator` computed property.
    -   Update `from(keyEvent:state:)` to create the token.
2.  **`EditorViewModel.swift`**: Implement the action (e.g., `newOperator(range: Range<Int>)`).
3.  **`EditorCommands.swift`**: In the `execute` method, call the new view model method for your operator case.

### Adding a `g`-prefixed Command

1.  **`EditorCommands.swift`**:
    -   Add a new operator case to `EditorOperator` (e.g., `.gCommand`).
    -   Add a new token case to `EditorCommandToken` (e.g., `.gCommand`).
    -   Map the token in `toOperator`.
    -   Update `from(keyEvent:state:)` to handle the key combination (e.g., `Shift + key`).
    -   In `handleTokenInWaitingForSuffixState`, ensure the `case .prefix("g")` block correctly transitions to `waitingForMotion` with your new operator.
2.  **`EditorViewModel.swift`**: Add the execution logic, likely using the existing `transform` method if it's a case change.
3.  **`EditorCommands.swift`**: Update the `execute` method to call the appropriate view model method.
