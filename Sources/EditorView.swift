import SwiftUI

// MARK: - Editor View (The main view for the editor)
struct EditorView: View {
    @StateObject private var viewModel = EditorViewModel()
    @Binding var text: String
    var onSubmit: () -> Void
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        EditorTextField(
            text: $viewModel.text,
            cursorPosition: $viewModel.cursorPosition,
            viewModel: viewModel, // Pass the viewModel to the text field
            onSubmit: onSubmit
        )
        .frame(height: CGFloat(settingsManager.settings.fontSize * 8) * 1.2)
        .onChange(of: viewModel.text) { newText in
            self.text = newText
        }
        .onAppear {
            viewModel.text = self.text
            viewModel.onQuit = {
                print("[EditorView] Quit action received. Terminating.")
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.isTerminating = true
                }
                NSApp.terminate(nil)
            }
            viewModel.onSubmit = {
                print("[EditorView] Submit action received. Terminating.")
                self.onSubmit()
            }
        }
    }
}

