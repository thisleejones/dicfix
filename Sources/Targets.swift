import AppKit
import Foundation

// MARK: - Protocol

protocol Target {
    func send(text: String)
}

// MARK: - Implementations

class ClipboardTarget: Target {
    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

class KeystrokeTarget: Target {
    func send(text: String) {
        guard !text.isEmpty else { return }
        // This target is not fully implemented.
    }
}

class StdoutTarget: Target {
    func send(text: String) {
        print(text)
    }
}

class PasteTarget: Target {
    func send(text: String) {
        // 1. Copy text to the clipboard.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 2. Execute a delayed paste command using a detached shell process.
        let script = "tell application \"System Events\" to keystroke \"v\" using command down"
        let command = "(sleep 0.2 && /usr/bin/osascript -e '\(script)') &"

        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", command]

        do {
            try process.run()
        } catch {
            print("Failed to launch paste command: \(error)")
        }
    }
}


// MARK: - Helper for Keystroke

func type(text: String) {
    let source = CGEventSource(stateID: .hidSystemState)
    for character in text.utf16 {
        if let event = CGEvent(
            keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character])
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
        if let event = CGEvent(
            keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character])
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
