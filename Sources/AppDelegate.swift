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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for command-line arguments before doing anything else
        let arguments = commandLineArguments
        let target = getTarget(args: arguments)

        // If --text is provided, send the text and terminate immediately.
        if let textIndex = arguments.firstIndex(of: "--text"),
            arguments.indices.contains(textIndex + 1)
        {
            let text = arguments[textIndex + 1]
            print("Sending text directly to target and terminating.")
            target.send(text: text)
            NSApp.terminate(nil)
            return  // Exit before showing any UI
        }

        if let placeholderIndex = arguments.firstIndex(of: "--placeholder"),
           arguments.indices.contains(placeholderIndex + 1)
        {
            let placeholderValue = arguments[placeholderIndex + 1]
            settingsManager.settings.placeholder = placeholderValue
            print("Overriding placeholder with value from command line: \"\(placeholderValue)\"")
        }

        if let placeholderColorIndex = arguments.firstIndex(of: "--placeholder-color"),
           arguments.indices.contains(placeholderColorIndex + 1)
        {
            let placeholderColorValue = arguments[placeholderColorIndex + 1]
            settingsManager.settings.placeholderColor = placeholderColorValue
            print(
                "Overriding placeholderColor with value from command line: \"\(placeholderColorValue)\""
            )
        }

        if let promptIndex = arguments.firstIndex(of: "--prompt"),
           arguments.indices.contains(promptIndex + 1)
        {
            let promptValue = arguments[promptIndex + 1]
            settingsManager.settings.promptBody = promptValue
            print("Overriding promptBody with value from command line: \"\(promptValue)\"")
        }

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

        // Invoke dictation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.invokeDictation()
        }
    }

    func getTarget(args: [String]? = nil) -> Target {
        let arguments = args ?? commandLineArguments
        let targetName: String
        // Command-line argument takes precedence
        if let targetIndex = arguments.firstIndex(of: "--target"),
           arguments.indices.contains(targetIndex + 1) {
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
            return PasteTarget()
        case "clipboard", "pasteboard":
            return ClipboardTarget()
        case "stdout":
            return StdoutTarget()
        default:
            print("Unknown target '\(name)'. Using default (clipboard).")
            return ClipboardTarget()
        }
    }

    func invokeDictation() {
        let scriptSource = """
            tell application "System Events"
                key code 40 using control down
            end tell
            """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error = error {
                print("Error invoking dictation: \(error)")
            }
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