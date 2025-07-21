import AppKit
import SwiftUI

// Add the missing color definition
extension Color {
    static let magenta = Color(red: 1.0, green: 0.0, blue: 1.0)
}

struct ContentView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var text = ""
    let target: Target

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

    // Centralized color parsing logic
    private func parseColor(_ colorString: String, fallback: Color = .gray) -> Color {
        if colorString.hasPrefix("#") {
            let hex = String(colorString.dropFirst())
            if let (red, green, blue) = parseHex(hex) {
                return Color(red: red, green: green, blue: blue)
            }
        } else {
            if let namedColor = getNamedColor(colorString) {
                return namedColor
            }
        }
        // Fallback if parsing fails or color string is empty
        if !colorString.isEmpty {
            print("Invalid color '\(colorString)'. Falling back.")
        }
        return fallback
    }

    // Helper to handle named colors
    private func getNamedColor(_ name: String) -> Color? {
        let colorMap: [String: Color] = [
            // Standard Colors
            "red": .red, "green": .green, "blue": .blue, "white": .white,
            "black": .black, "gray": .gray, "cyan": .cyan, "magenta": .magenta,
            "yellow": .yellow, "orange": .orange, "purple": .purple, "pink": .pink,
            // SwiftUI Semantic Colors
            "primary": .primary, "secondary": .secondary, "accentcolor": .accentColor,
            // NSColor Semantic Colors
            "labelcolor": Color(nsColor: .labelColor),
            "secondarylabelcolor": Color(nsColor: .secondaryLabelColor),
            "tertiarylabelcolor": Color(nsColor: .tertiaryLabelColor),
            "windowbackgroundcolor": Color(nsColor: .windowBackgroundColor),
            "controlbackgroundcolor": Color(nsColor: .controlBackgroundColor),
            "lightgray": Color(nsColor: .lightGray), "darkgray": Color(nsColor: .darkGray),
            // NSColor System Colors
            "systemred": Color(nsColor: .systemRed), "systemgreen": Color(nsColor: .systemGreen),
            "systemblue": Color(nsColor: .systemBlue),
            "systemorange": Color(nsColor: .systemOrange),
            "systemyellow": Color(nsColor: .systemYellow),
            "systempurple": Color(nsColor: .systemPurple),
            "systempink": Color(nsColor: .systemPink), "systemteal": Color(nsColor: .systemTeal),
            "systemindigo": Color(nsColor: .systemIndigo),
            "systemgray": Color(nsColor: .systemGray),
        ]
        return colorMap[name.lowercased()]
    }

    // Utility to parse a 3 or 6 digit hex string
    private func parseHex(_ hex: String) -> (Double, Double, Double)? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red: Double
        let green: Double
        let blue: Double
        if hexSanitized.count == 6 {
            red = Double((rgb & 0xFF0000) >> 16) / 255.0
            green = Double((rgb & 0x00FF00) >> 8) / 255.0
            blue = Double(rgb & 0x0000FF) / 255.0
        } else if hexSanitized.count == 3 {
            let redShort = Double((rgb & 0xF00) >> 8)
            let greenShort = Double((rgb & 0x0F0) >> 4)
            let blueShort = Double(rgb & 0x00F)
            red = (redShort * 16 + redShort) / 255.0
            green = (greenShort * 16 + greenShort) / 255.0
            blue = (blueShort * 16 + blueShort) / 255.0
        } else {
            return nil
        }
        return (red, green, blue)
    }

    // Color properties with fallback logic
    private var promptBodyColor: Color {
        parseColor(settingsManager.settings.promptBodyColor, fallback: .gray)
    }

    private var promptPrefixColor: Color {
        parseColor(settingsManager.settings.promptPrefixColor, fallback: promptBodyColor)
    }

    private var promptSuffixColor: Color {
        parseColor(settingsManager.settings.promptSuffixColor, fallback: promptBodyColor)
    }

    private var textColor: Color {
        parseColor(settingsManager.settings.textColor, fallback: .white)
    }

    private var placeholderColor: Color {
        parseColor(settingsManager.settings.placeholderColor, fallback: .gray)
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
                TextField("", text: textBinding)
                    .lineLimit(1)
                    .accessibilityIdentifier("mainField")
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(textColor)
                    .accentColor(textColor)
                    .font(appFont)
            }
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .background(Color.black.opacity(settingsManager.settings.opacity))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.7), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onSubmit {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.isTerminating = true
            }
            appendToHistory(text)
            target.send(text: text)
            NSApp.terminate(nil)
        }
        .onExitCommand {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.isTerminating = true
            }
            NSApp.terminate(nil)
        }
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(target: ClipboardTarget())
            .environmentObject(SettingsManager.shared)
    }
}
