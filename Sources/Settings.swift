import Combine
import Foundation
import SwiftUI

// The main, non-optional struct used throughout the app
struct AppSettings {
    var windowX: Double
    var windowY: Double
    var windowWidth: Double
    var windowHeight: Double
    var fontName: String
    var fontSize: Double
    var opacity: Double
    var promptPrefix: String
    var promptPrefixColor: String
    var promptBody: String
    var promptBodyColor: String
    var promptSuffix: String
    var promptSuffixColor: String
    var textColor: String
    var placeholder: String
    var placeholderColor: String
    var target: String

    // The original, sensible defaults
    static func defaultSettings() -> AppSettings {
        return AppSettings(
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
            placeholder: "...",
            placeholderColor: "gray",
            target: "paste"
        )
    }
}

// A temporary, codable struct to handle missing or empty keys in the JSON file.
// Optional properties are omitted by the encoder if they are nil.
private struct CodableSettings: Codable {
    var windowX: Double?
    var windowY: Double?
    var windowWidth: Double?
    var windowHeight: Double?
    var fontName: String?
    var fontSize: Double?
    var opacity: Double?
    var promptPrefix: String?
    var promptPrefixColor: String?
    var promptBody: String?
    var promptBodyColor: String?
    var promptSuffix: String?
    var promptSuffixColor: String?
    var textColor: String?
    var placeholder: String?
    var placeholderColor: String?
    var target: String?
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    #if DEBUG
        // This is a test-only variable to override the support directory.
        static var testSupportDirectory: URL?
    #endif

    @Published var settings: AppSettings

    private static func getSupportDirectory() -> URL {
        #if DEBUG
            if let testDir = testSupportDirectory {
                return testDir
            }
        #endif

        if let configPath = UserDefaults.standard.string(forKey: "ConfigPath") {
            let tildeExpandedPath = (configPath as NSString).expandingTildeInPath
            return URL(fileURLWithPath: tildeExpandedPath, isDirectory: true)
        } else {
            let appSupportDir = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            return appSupportDir.appendingPathComponent("dicfix")
        }
    }

    internal static var settingsUrl: URL {
        let appDir = getSupportDirectory()

        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(
                at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        return appDir.appendingPathComponent("settings.json")
    }

    static var historyUrl: URL {
        let appDir = getSupportDirectory()

        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(
                at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        return appDir.appendingPathComponent("history.txt")
    }

    private init() {
        self.settings = SettingsManager.load()
    }

    static func load() -> AppSettings {
        let defaults = AppSettings.defaultSettings()
        let url = Self.settingsUrl

        guard let data = try? Data(contentsOf: url),
            let loaded = try? JSONDecoder().decode(CodableSettings.self, from: data)
        else {
            // If file doesn't exist or is invalid, return defaults
            return defaults
        }

        // Merge loaded settings with defaults. The loaded value wins.
        return AppSettings(
            windowX: loaded.windowX ?? defaults.windowX,
            windowY: loaded.windowY ?? defaults.windowY,
            windowWidth: loaded.windowWidth ?? defaults.windowWidth,
            windowHeight: loaded.windowHeight ?? defaults.windowHeight,
            fontName: loaded.fontName ?? defaults.fontName,
            fontSize: loaded.fontSize ?? defaults.fontSize,
            opacity: loaded.opacity ?? defaults.opacity,
            promptPrefix: loaded.promptPrefix ?? defaults.promptPrefix,
            promptPrefixColor: loaded.promptPrefixColor ?? defaults.promptPrefixColor,
            promptBody: loaded.promptBody ?? defaults.promptBody,
            promptBodyColor: loaded.promptBodyColor ?? defaults.promptBodyColor,
            promptSuffix: loaded.promptSuffix ?? defaults.promptSuffix,
            promptSuffixColor: loaded.promptSuffixColor ?? defaults.promptSuffixColor,
            textColor: loaded.textColor ?? defaults.textColor,
            placeholder: loaded.placeholder ?? defaults.placeholder,
            placeholderColor: loaded.placeholderColor ?? defaults.placeholderColor,
            target: loaded.target ?? defaults.target
        )
    }

    func save() {
        // To save, we need to encode the complete AppSettings struct
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(settings)
            try data.write(to: Self.settingsUrl, options: [.atomicWrite])
        } catch {
            print("Failed to save settings: \(error.localizedDescription)")
        }
    }
}

// We need to make AppSettings Codable for the save function to work
extension AppSettings: Codable {}

// MARK: - SwiftUI Previews Support
#if DEBUG
    // A helper for providing mock settings in previews
    class MockSettingsManager: ObservableObject {
        @Published var settings: AppSettings

        init(settings: AppSettings) {
            self.settings = settings
        }
    }
#endif
