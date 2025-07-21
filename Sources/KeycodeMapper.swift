import CoreGraphics
import Foundation

struct KeycodeMapper {
    private static let keyMap: [String: CGKeyCode] = [
        "F1": 122,
        "F2": 120,
        "F3": 99,
        "F4": 118,
        "F5": 96,
        "F6": 97,
        "F7": 98,
        "F8": 100,
        "F9": 101,
        "F10": 109,
        "F11": 103,
        "F12": 111,
        "F13": 105,
        "F14": 107,
        "F15": 113,
        "F16": 106,
        "F17": 64,
        "F18": 79,
        "F19": 80,
        "F20": 90,  // Add more mappings as needed
        "'": 39,  // Apostrophe
        "Control": 59,
        "Option": 58,
        "Command": 55,
        "Shift": 56,
        "LeftShift": 56,
        "RightShift": 60,
        "CapsLock": 57,
    ]

    static func keyCode(for name: String) -> CGKeyCode? {
        return keyMap.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
