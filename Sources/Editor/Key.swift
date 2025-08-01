// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

import AppKit
import Carbon.HIToolbox.Events
import CoreGraphics

// A struct to represent a key press event, containing both the
// case-insensitive key code and the case-sensitive characters.
public struct KeyEvent {
    let keyCode: CGKeyCode
    let key: Key?
    let characters: String?
    let modifierFlags: NSEvent.ModifierFlags
    let mods: Modifiers

    // Factory method to create a KeyEvent from an NSEvent.
    public static func from(event: NSEvent) -> KeyEvent {
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
public struct Modifiers {
    let flags: NSEvent.ModifierFlags

    let isShift: Bool
    let isControl: Bool
    let isOption: Bool  // Also known as the "Alt" key
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

    public init(flags: NSEvent.ModifierFlags) {
        self.flags = flags
        self.isShift = flags.contains(.shift)
        self.isControl = flags.contains(.control)
        self.isOption = flags.contains(.option)
        self.isCommand = flags.contains(.command)
    }
}

// An enum to provide meaningful names for CGKeyCode values.
// This makes key handling code much more readable and avoids "magic numbers".
public enum Key: CGKeyCode {
    // -- Numbers --
    case zero = 29
    case one = 18
    case two = 19
    case three = 20
    case four = 21
    case five = 23
    case six = 22
    case seven = 26
    case eight = 28
    case nine = 25

    // -- Editing Keys --
    case a = 0
    case i = 34
    case o = 31
    case p = 35

    // Motion Keys
    case h = 4
    case j = 38
    case k = 40
    case l = 37
    case g = 5
    case m = 46
    case n = 45

    case b = 11
    case w = 13
    case e = 14
    case f = 3
    case r = 15
    case t = 17
    case q = 12
    case s = 1
    case z = 6

    // Editing Keys
    case d = 2
    case y = 16
    case c = 8
    case x = 7
    case u = 32
    case tilde = 50
    case v = 9

    // Action Keys
    case escape = 53
    case enter = 36
    case keypadEnter = 76
    case `repeat` = 47  // '.' key
    case semicolon = 41
    case comma = 43
}

// 1) NormalizedKey distinguishes w vs W, b vs B, etc.
public enum NormalizedKey {
    case w, W, b, B
    case h, j, k, l
    case d, y, c
    case esc, enter
    case digit(Int)
    case other(String)

    static func from(_ e: KeyEvent) -> NormalizedKey? {
        guard let k = e.key else { return nil }

        // digits (for counts)
        if let s = e.characters, s.count == 1, let n = Int(s) {
            return .digit(n)
        }

        switch k {
        case .w: return e.mods.isOnlyShift ? .W : .w
        case .b: return e.mods.isOnlyShift ? .B : .b
        case .h: return .h
        case .j: return .j
        case .k: return .k
        case .l: return .l
        case .d: return .d
        case .y: return .y
        case .c: return .c
        case .escape: return .esc
        case .enter, .keypadEnter: return .enter
        default:
            return .other(e.characters ?? "")
        }
    }
}
