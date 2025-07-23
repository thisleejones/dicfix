// Project.swift
import ProjectDescription

let project = Project(
    name: "dicfix",
    targets: [
        .target(
            name: "dicfix",
            destinations: .macOS,
            product: .app,
            bundleId: "io.leejones.dicfix",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .extendingDefault(with: [
                "NSMicrophoneUsageDescription":
                    "This app requires microphone access for dictation.",
                "NSAccessibilityUsageDescription":
                    "This app uses accessibility features to capture dictation.",
                "NSAppleEventsUsageDescription": "This app uses Apple Events to trigger dictation.",
                "LSUIElement": "YES",
                "LSEnvironment": [
                    "OS_ACTIVITY_MODE": "disable"
                ],
            ]),
            sources: [
                "Sources/App.swift", "Sources/AppDelegate.swift", "Sources/Settings.swift",
                "Sources/Targets.swift", "Sources/ContentView.swift", "Sources/KeycodeMapper.swift",
                "Sources/ColorMapper.swift", "Sources/dicfix.entitlements",
            ],
            resources: [
                "Resources/**"
            ],
            dependencies: [.target(name: "Editor")],
            settings: .settings(base: [
                "CODE_SIGN_IDENTITY": "",
                "CODE_SIGNING_REQUIRED": "NO",
                "CODE_SIGNING_ALLOWED": "NO",
            ])
        ),
        .target(
            name: "Editor",
            destinations: .macOS,
            product: .framework,
            bundleId: "io.leejones.dicfix.Editor",
            deploymentTargets: .macOS("13.0"),
            sources: ["Sources/Editor/**"],
            dependencies: []
        ),
        .target(
            name: "dicfixTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.leejones.dicfixTests",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "Editor")]
        ),
    ],
    schemes: [
        .scheme(
            name: "dicfix",
            buildAction: .buildAction(targets: ["dicfix"]),
            testAction: .targets(["dicfixTests"]),
            runAction: .runAction(executable: "dicfix")
        )
    ]
)
