import XCTest
@testable import dicfix

class SettingsTests: XCTestCase {

    var settingsManager: SettingsManager!
    var appDelegate: AppDelegate!
    var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()

        // 1. Create a temporary directory for test artifacts
        temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Failed to create temporary directory: \(error)")
        }

        // 2. Point the settings manager to the temporary directory
        UserDefaults.standard.set(temporaryDirectory.path, forKey: "ConfigPath")

        // 3. Re-initialize the shared instance to pick up the new path
        settingsManager = SettingsManager.shared
        appDelegate = AppDelegate()
        
        // 4. Create a temporary settings file for testing
        let settings = AppSettings(
            windowX: 100,
            windowY: 100,
            windowWidth: 420,
            windowHeight: 64,
            fontName: "DaddyTimeMono Nerd Font",
            fontSize: 16,
            opacity: 0.2,
            promptPrefix: "",
            promptPrefixColor: "",
            promptBody: "> ",
            promptBodyColor: "gray",
            promptSuffix: "",
            promptSuffixColor: "",
            textColor: "white",
            target: "paste"
        )
        settingsManager.settings = settings
        settingsManager.save()
    }

    override func tearDown() {
        super.tearDown()
        // 1. Remove the temporary directory and all its contents
        try? FileManager.default.removeItem(at: temporaryDirectory)
        
        // 2. Clear the user default to avoid side-effects
        UserDefaults.standard.removeObject(forKey: "ConfigPath")
    }

    func testTargetFromSettings() {
        // 1. Test that the target is read from the settings file
        let target = appDelegate.getTarget(args: [])
        XCTAssert(target is PasteTarget, "Target should be PasteTarget from settings")

        // 2. Test that the command-line argument overrides the settings
        let args = ["--target", "stdout"]
        let target2 = appDelegate.getTarget(args: args)
        XCTAssert(target2 is StdoutTarget, "Target should be StdoutTarget from command-line argument")
    }
}