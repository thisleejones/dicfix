import SwiftUI
import AppKit

// Add the missing color definition
extension Color {
    static let magenta = Color(red: 1.0, green: 0.0, blue: 1.0)
}

struct ColorMapper {
    private static let colorMap: [String: Color] = [
        // Standard Colors
        "red": .red, "green": .green, "blue": .blue, "white": .white,
        "black": .black, "gray": .gray, "cyan": .cyan, "magenta": .magenta,
        "yellow": .yellow, "orange": .orange, "purple": .purple, "pink": .pink,
        // SwiftUI Semantic Colors
        "primary": .primary, "secondary": .secondary, "accentColor": .accentColor,
        // NSColor Semantic Colors
        "labelColor": Color(nsColor: .labelColor),
        "secondaryLabelColor": Color(nsColor: .secondaryLabelColor),
        "tertiaryLabelColor": Color(nsColor: .tertiaryLabelColor),
        "windowBackgroundColor": Color(nsColor: .windowBackgroundColor),
        "controlBackgroundColor": Color(nsColor: .controlBackgroundColor),
        "lightGray": Color(nsColor: .lightGray), "darkGray": Color(nsColor: .darkGray),
        // NSColor System Colors
        "systemRed": Color(nsColor: .systemRed), "systemGreen": Color(nsColor: .systemGreen),
        "systemBlue": Color(nsColor: .systemBlue),
        "systemOrange": Color(nsColor: .systemOrange),
        "systemYellow": Color(nsColor: .systemYellow),
        "systemPurple": Color(nsColor: .systemPurple),
        "systemPink": Color(nsColor: .systemPink), "systemTeal": Color(nsColor: .systemTeal),
        "systemIndigo": Color(nsColor: .systemIndigo),
        "systemGray": Color(nsColor: .systemGray),
    ]

    private static func color(forName name: String) -> Color? {
        return colorMap.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    // Utility to parse a 3 or 6 digit hex string
    private static func parseHex(_ hex: String) -> (Double, Double, Double)? {
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

    // Centralized color parsing logic
    static func parseColor(_ colorString: String, fallback: Color = .gray) -> Color {
        if colorString.hasPrefix("#") {
            let hex = String(colorString.dropFirst())
            if let (red, green, blue) = parseHex(hex) {
                return Color(red: red, green: green, blue: blue)
            }
        } else {
            if let namedColor = color(forName: colorString) {
                return namedColor
            }
        }
        // Fallback if parsing fails or color string is empty
        if !colorString.isEmpty {
            print("Invalid color '\(colorString)'. Falling back.")
        }
        return fallback
    }
}
