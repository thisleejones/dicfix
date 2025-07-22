import AppKit
import SwiftUI

class TransparentWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var isTerminating = false
    var commandLineArguments: [String] = CommandLine.arguments
    // Access our new settings manager
    let settingsManager = SettingsManager.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Force disable verbose logging from the Input Method Kit
        setenv("OS_ACTIVITY_MODE", "disable", 1)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Process command-line arguments to override settings before UI is built.
        initializeSettings(with: commandLineArguments)

        let target = getTarget(args: commandLineArguments)

        // Hide the Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Pass the settings manager to the content view
        let contentView = ContentView(target: target).environmentObject(settingsManager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Use settings for window dimensions
        let settings = settingsManager.settings
        let contentRect = NSRect(
            x: settings.windowX, y: settings.windowY, width: settings.windowWidth,
            height: settings.windowHeight)

        // Setup a simple, standard window
        window = TransparentWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces]
        window.hasShadow = true

        // A simple container view for the content
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 14
        containerView.layer?.masksToBounds = true

        window.contentView = containerView
        containerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        // Set initial frame from settings
        window.setFrame(contentRect, display: true)

        // The most basic and standard way to show the window and make it active.
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func initializeSettings(with arguments: [String]) {
        // Settings are already loaded from file by the SettingsManager singleton.
        // Now, we override them with any command-line arguments.
        processCommandLineArgs(arguments)
    }

    private func processCommandLineArgs(_ arguments: [String]) {
        // Create a mutable copy of the current settings to apply argument overrides.
        var newSettings = settingsManager.settings

        // Helper to extract an argument's value
        func argumentValue(for option: String) -> String? {
            guard let index = arguments.firstIndex(of: option),
                arguments.indices.contains(index + 1)
            else {
                return nil
            }
            return arguments[index + 1]
        }

        // Map arguments to their corresponding settings
        let stringArgumentMap: [String: WritableKeyPath<AppSettings, String>] = [
            "--placeholder": \.placeholder,
            "--placeholder-color": \.placeholderColor,
            "--dictation-key": \.dictationKey,
            "--dictation-key-mods": \.dictationKeyMods,
            "--dictation-key-delay": \.dictationKeyDelay,
            "--paste-delay": \.pasteDelay,
            "--prompt": \.promptBody,
        ]

        for (argument, keyPath) in stringArgumentMap {
            if let value = argumentValue(for: argument) {
                newSettings[keyPath: keyPath] = value
            }
        }

        let boolArgumentMap: [String: WritableKeyPath<AppSettings, Bool>] = [
            "--vim-mode": \.vimMode,
        ]

        for (argument, keyPath) in boolArgumentMap {
            if let index = arguments.firstIndex(of: argument) {
                // Check if a value is provided after the argument
                if arguments.indices.contains(index + 1) && !arguments[index + 1].starts(with: "--") {
                    let valueStr = arguments[index + 1].lowercased()
                    newSettings[keyPath: keyPath] = (valueStr == "true" || valueStr == "1")
                } else {
                    // If the argument is present without a value, treat it as true
                    newSettings[keyPath: keyPath] = true
                }
            }
        }

        // Atomically update the settings to trigger UI refresh.
        settingsManager.settings = newSettings
    }

    func getTarget(args: [String]? = nil) -> Target {
        let arguments = args ?? commandLineArguments
        let targetName: String
        // Command-line argument takes precedence
        if let targetIndex = arguments.firstIndex(of: "--target"),
            arguments.indices.contains(targetIndex + 1)
        {
            targetName = arguments[targetIndex + 1].lowercased()
        } else {
            targetName = settingsManager.settings.target.lowercased()
        }
        return target(forName: targetName)
    }

    private func target(forName name: String) -> Target {
        switch name {
        case "keystroke":
            return KeystrokeTarget()
        case "paste":
            return PasteTarget(settingsManager: settingsManager)
        case "clipboard", "pasteboard":
            return ClipboardTarget()
        case "stdout":
            return StdoutTarget()
        default:
            return ClipboardTarget()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save window frame to our JSON file on quit, only if it has changed
        if let window = self.window {
            let currentFrame = window.frame
            let launchSettings = settingsManager.settings

            // Use a small tolerance for floating-point comparison
            let hasChanged =
                abs(currentFrame.origin.x - launchSettings.windowX) > 0.1
                || abs(currentFrame.origin.y - launchSettings.windowY) > 0.1
                || abs(currentFrame.size.width - launchSettings.windowWidth) > 0.1
                || abs(currentFrame.size.height - launchSettings.windowHeight) > 0.1

            if hasChanged {
                // Reload settings from disk to avoid overwriting external changes.
                var latestSettings = SettingsManager.load()

                // Apply the new window geometry.
                latestSettings.windowX = currentFrame.origin.x
                latestSettings.windowY = currentFrame.origin.y
                latestSettings.windowWidth = currentFrame.size.width
                latestSettings.windowHeight = currentFrame.size.height

                // Update the manager's state and save.
                settingsManager.settings = latestSettings
                settingsManager.save()
            }
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        // If we are not already in the process of terminating, close the app.
        if !isTerminating {
            NSApp.terminate(nil)
        }
    }
}
