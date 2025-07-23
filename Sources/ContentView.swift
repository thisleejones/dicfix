import AppKit
import SwiftUI
import Editor

struct ContentView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var text = ""
    let target: Target

    @State private var hasTriggeredDictation = false
    @FocusState private var isMainFieldFocused: Bool

    init(target: Target) {
        self.target = target
    }

    // Custom binding to filter out newlines
    private var textBinding: Binding<String> {
        Binding<String>(
            get: { self.text },
            set: {
                self.text = $0.components(separatedBy: .newlines).joined()
            }
        )
    }

    // Helper to select the correct font
    private var appFont: Font {
        let settings = settingsManager.settings
        if NSFont(name: settings.fontName, size: settings.fontSize) != nil {
            return .custom(settings.fontName, size: settings.fontSize)
        } else {
            print("Font '\(settings.fontName)' not found. Falling back to system monospaced font.")
            return .system(size: settings.fontSize, design: .monospaced)
        }
    }

    // Color properties with fallback logic
    private var promptBodyColor: Color {
        ColorMapper.parseColor(settingsManager.settings.promptBodyColor, fallback: .gray)
    }

    private var promptPrefixColor: Color {
        ColorMapper.parseColor(
            settingsManager.settings.promptPrefixColor, fallback: promptBodyColor)
    }

    private var promptSuffixColor: Color {
        ColorMapper.parseColor(
            settingsManager.settings.promptSuffixColor, fallback: promptBodyColor)
    }

    private var textColor: Color {
        ColorMapper.parseColor(settingsManager.settings.textColor, fallback: .white)
    }

    private var placeholderColor: Color {
        ColorMapper.parseColor(settingsManager.settings.placeholderColor, fallback: .gray)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Prompt composed of three parts
            HStack(spacing: 0) {
                Text(settingsManager.settings.promptPrefix)
                    .foregroundColor(promptPrefixColor)
                Text(settingsManager.settings.promptBody)
                    .foregroundColor(promptBodyColor)
                Text(settingsManager.settings.promptSuffix)
                    .foregroundColor(promptSuffixColor)
            }
            .font(appFont)
            .padding(.leading, 12)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(settingsManager.settings.placeholder)
                        .foregroundColor(placeholderColor)
                        .font(appFont)
                        .padding(.leading, 4)  // Align with TextField's internal padding
                }

                if settingsManager.settings.vimMode {
                    let editorSettings = Editor.EditorSettings(
                        textColor: textColor,
                        fontName: settingsManager.settings.fontName,
                        fontSize: settingsManager.settings.fontSize
                    )
                    Editor.EditorView(
                        text: textBinding,
                        settings: editorSettings,
                        onSubmit: submit,
                        onQuit: {
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.isTerminating = true
                            }
                            NSApp.terminate(nil)
                        }
                    )
                    .accessibilityIdentifier("mainField")
                    .focused($isMainFieldFocused)
                } else {
                    TextField("", text: textBinding, onCommit: submit)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(appFont)
                        .foregroundColor(textColor)
                        .accessibilityIdentifier("mainField")
                        .focused($isMainFieldFocused)
                        .onExitCommand {
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.isTerminating = true
                            }
                            NSApp.terminate(nil)
                        }
                }
            }
            .onChange(of: isMainFieldFocused) { isFocused in
                if isFocused && !hasTriggeredDictation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if isMainFieldFocused && !hasTriggeredDictation {
                            hasTriggeredDictation = true
                            invokeDictation()
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .background(Color.black.opacity(settingsManager.settings.opacity))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.7), lineWidth: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // .onExitCommand {
        //     if let appDelegate = NSApp.delegate as? AppDelegate {
        //         appDelegate.isTerminating = true
        //     }
        //     NSApp.terminate(nil)
        // }
    }

    private func submit() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.isTerminating = true
        }
        appendToHistory(text)
        target.send(text: text)
        NSApp.terminate(nil)
    }

    private func appendToHistory(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let timestamp = Int(Date().timeIntervalSince1970)
        let historyLine = ": \(timestamp);\(command)\n"

        let url = SettingsManager.historyUrl
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let fileHandle = try FileHandle(forWritingTo: url)
                fileHandle.seekToEndOfFile()
                fileHandle.write(historyLine.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try historyLine.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to write to history: \(error.localizedDescription)")
        }
    }

    func invokeDictation() {
        let settings = settingsManager.settings
        let key = settings.dictationKey
        let mods = settings.dictationKeyMods
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let delay = settings.dictationKeyDelayInterval

        let script: String
        var usingClause = ""

        if !mods.isEmpty {
            let modifiers = mods.map { "\($0) down" }.joined(separator: ", ")
            usingClause = " using {\(modifiers)}"
        }

        // Sanitize the key to prevent command injection.
        // We only allow F-keys to be executed as key codes.
        if let keyCode = KeycodeMapper.keyCode(for: key) {
            script = "tell application \"System Events\" to key code \(keyCode)\(usingClause)"
        } else {
            // For any other key, we treat it as a literal string to be typed.
            // We must escape it to prevent injection.
            let escapedKey = key.replacingOccurrences(of: "\"", with: "\\\"")
            script = "tell application \"System Events\" to keystroke \"\(escapedKey)\"\(usingClause)"
        }

        let execution = {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("Error invoking dictation: \(error)")
                    // Display a user-facing alert on the main thread
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Error Invoking Dictation"
                        alert.informativeText = "Failed to trigger the dictation key. Please check your settings.\n\nDetails: \(error)"
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                execution()
            }
        } else {
            execution()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(target: ClipboardTarget())
            .environmentObject(SettingsManager.shared)
    }
}
