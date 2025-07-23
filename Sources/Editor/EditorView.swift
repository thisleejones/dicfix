import SwiftUI

// MARK: - Editor View (The main view for the editor)
public struct EditorView: View {
    @StateObject private var viewModel = EditorViewModel()
    @Binding public var text: String
    public var settings: EditorSettings
    public var onSubmit: () -> Void
    public var onQuit: () -> Void

    public init(text: Binding<String>, settings: EditorSettings, onSubmit: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self._text = text
        self.settings = settings
        self.onSubmit = onSubmit
        self.onQuit = onQuit
    }

    public var body: some View {
        EditorTextField(
            text: $viewModel.text,
            cursorPosition: $viewModel.cursorPosition,
            viewModel: viewModel,
            settings: settings,
            onSubmit: onSubmit
        )
        .frame(height: CGFloat(settings.fontSize * 8) * 1.2)
        .onChange(of: viewModel.text) { newText in
            self.text = newText
        }
        .onAppear {
            viewModel.text = self.text
            viewModel.onQuit = {
                print("[EditorView] Quit action received.")
                self.onQuit()
            }
            viewModel.onSubmit = {
                print("[EditorView] Submit action received.")
                self.onSubmit()
            }
        }
    }
}

