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
}