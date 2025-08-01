// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

import XCTest
@testable import dicfix

class SettingsTests: XCTestCase {

    var temporaryDirectory: URL!
    var appDelegate: AppDelegate!
    var mockApp: NSApplication!

    override func setUp() {
        super.setUp()

        // 1. Create a temporary directory for test artifacts.
        temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }

        // 2. Set the test-specific support directory.
        SettingsManager.testSupportDirectory = temporaryDirectory

        // 3. Create a mock application instance and our app delegate.
        mockApp = NSApplication.shared
        appDelegate = AppDelegate()
        mockApp.delegate = appDelegate

        // 4. Create a temporary settings file for a known state.
        var settings = AppSettings.defaultSettings()
        settings.target = "paste"
        settings.placeholder = "initial placeholder"
        settings.placeholderColor = "red"
        appDelegate.settingsManager.settings = settings
        appDelegate.settingsManager.save()
    }

    override func tearDown() {
        super.tearDown()
        // 1. Remove the temporary directory and all its contents.
        if let temporaryDirectory = temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        
        // 2. Reset the test support directory to nil.
        SettingsManager.testSupportDirectory = nil
    }

    func testTargetFromSettings() {
        // Test that the target is read correctly from the settings file.
        let target = appDelegate.getTarget()
        XCTAssert(target is PasteTarget, "Target should be PasteTarget from settings file, but was \(type(of: target))")

        // Test that a command-line argument overrides the setting.
        appDelegate.commandLineArguments = ["/path/to/app", "--target", "stdout"]
        let overriddenTarget = appDelegate.getTarget()
        XCTAssert(overriddenTarget is StdoutTarget, "Target should be StdoutTarget from command-line argument, but was \(type(of: overriddenTarget))")
    }

    func testPlaceholderSettingsAreOverriddenByCommandLine() {
        // 1. Set the command-line arguments for the test.
        appDelegate.commandLineArguments = [
            "/path/to/app",
            "--placeholder", "new placeholder",
            "--placeholder-color", "blue"
        ]

        // 2. Trigger applicationDidFinishLaunching to parse the arguments.
        // We send a dummy notification.
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // 3. Check that the settings have been updated.
        let updatedSettings = appDelegate.settingsManager.settings
        XCTAssertEqual(updatedSettings.placeholder, "new placeholder", "Placeholder should be updated by command-line argument")
        XCTAssertEqual(updatedSettings.placeholderColor, "blue", "Placeholder color should be updated by command-line argument")
    }

    func testDictationKeySettingIsOverriddenByCommandLine() {
        // 1. Set the command-line arguments for the test.
        appDelegate.commandLineArguments = [
            "/path/to/app",
            "--dictation-key", "F12"
        ]

        // 2. Trigger applicationDidFinishLaunching to parse the arguments.
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // 3. Check that the settings have been updated.
        let updatedSettings = appDelegate.settingsManager.settings
        XCTAssertEqual(updatedSettings.dictationKey, "F12", "Dictation key should be updated by command-line argument")
    }

    func testDictationKeyModsAndDelayAreOverriddenByCommandLine() {
        // 1. Set the command-line arguments for the test.
        appDelegate.commandLineArguments = [
            "/path/to/app",
            "--dictation-key-mods", "Command|Shift",
            "--dictation-key-delay", "500ms"
        ]

        // 2. Trigger applicationDidFinishLaunching to parse the arguments.
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // 3. Check that the settings have been updated.
        let updatedSettings = appDelegate.settingsManager.settings
        XCTAssertEqual(updatedSettings.dictationKeyMods, "Command|Shift", "Dictation key mods should be updated by command-line argument")
        XCTAssertEqual(updatedSettings.dictationKeyDelay, "500ms", "Dictation key delay should be updated by command-line argument")
    }

    func testParseDuration() {
        // Test standard millisecond parsing
        XCTAssertEqual(AppSettings.parseDuration("500ms"), 0.5)
        // Test the failing case
        XCTAssertEqual(AppSettings.parseDuration("2000ms"), 2.0)
        // Test standard second parsing
        XCTAssertEqual(AppSettings.parseDuration("1.5s"), 1.5)
        // Test unitless parsing (defaults to milliseconds)
        XCTAssertEqual(AppSettings.parseDuration("1200"), 1.2)
        // Test integer second parsing
        XCTAssertEqual(AppSettings.parseDuration("2s"), 2.0)
        // Test invalid string
        XCTAssertEqual(AppSettings.parseDuration("abc"), 0.0)
        // Test empty string
        XCTAssertEqual(AppSettings.parseDuration(""), 0.0)
        // Test with whitespace
        XCTAssertEqual(AppSettings.parseDuration("  750ms  "), 0.75)
    }

    func testPasteDelayIsOverriddenByCommandLine() {
        // 1. Set the command-line arguments for the test.
        appDelegate.commandLineArguments = [
            "/path/to/app",
            "--paste-delay", "1.2s"
        ]

        // 2. Trigger applicationDidFinishLaunching to parse the arguments.
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        // 3. Check that the settings have been updated.
        let updatedSettings = appDelegate.settingsManager.settings
        XCTAssertEqual(updatedSettings.pasteDelay, "1.2s", "Paste delay should be updated by command-line argument")
        XCTAssertEqual(updatedSettings.pasteDelayInterval, 1.2, "Paste delay interval should be correctly parsed")
    }
}