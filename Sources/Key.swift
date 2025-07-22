import AppKit
import Carbon.HIToolbox.Events
import CoreGraphics

// A struct to represent a key press event, containing both the
// case-insensitive key code and the case-sensitive characters.
struct KeyEvent {
    let keyCode: CGKeyCode
    let key: Key?
    let characters: String?
    let modifierFlags: NSEvent.ModifierFlags
    let mods: Modifiers

    // Factory method to create a KeyEvent from an NSEvent.
    static func from(event: NSEvent) -> KeyEvent {
        return KeyEvent(
            keyCode: event.keyCode,
            key: Key(rawValue: event.keyCode),
            characters: event.characters,
            modifierFlags: event.modifierFlags,
            mods: Modifiers(flags: event.modifierFlags)
        )
    }
}

// A helper struct to make querying modifier flags easy and readable.
struct Modifiers {
    let flags: NSEvent.ModifierFlags

    let isShift: Bool
    let isControl: Bool
    let isOption: Bool // Also known as the "Alt" key
    let isCommand: Bool

    // Check if no modifiers are pressed.
    var isUnmodified: Bool {
        return flags.intersection(.deviceIndependentFlagsMask).isEmpty
    }

    // Check if *only* a single modifier is pressed, and no others.
    var isOnlyShift: Bool { flags.intersection(.deviceIndependentFlagsMask) == .shift }
    var isOnlyControl: Bool { flags.intersection(.deviceIndependentFlagsMask) == .control }
    var isOnlyOption: Bool { flags.intersection(.deviceIndependentFlagsMask) == .option }
    var isOnlyCommand: Bool { flags.intersection(.deviceIndependentFlagsMask) == .command }

    init(flags: NSEvent.ModifierFlags) {
        self.flags = flags
        self.isShift = flags.contains(.shift)
        self.isControl = flags.contains(.control)
        self.isOption = flags.contains(.option)
        self.isCommand = flags.contains(.command)
    }
}

// An enum to provide meaningful names for CGKeyCode values.
// This makes key handling code much more readable and avoids "magic numbers".
enum Key: CGKeyCode {
    // Editing Keys
    case a = 0
    case i = 34

    // Motion Keys
    case h = 4
    case j = 38
    case k = 40
    case l = 37

    case b = 11
    case w = 13

    // Action Keys
    case escape = 53
    case enter = 36
    case keypadEnter = 76
}
