// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

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
                "MARKETING_VERSION": "0.1.0",
                "CURRENT_PROJECT_VERSION": "1",
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
            name: "EditorTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.leejones.dicfix.EditorTests",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .default,
            sources: ["Tests/EditorTests/**"],
            dependencies: [.target(name: "Editor")]
        ),
    ],
    schemes: [
        .scheme(
            name: "dicfix",
            buildAction: .buildAction(targets: ["dicfix"]),
            testAction: .targets(["EditorTests"]),
            runAction: .runAction(executable: "dicfix")
        )
    ]
)
