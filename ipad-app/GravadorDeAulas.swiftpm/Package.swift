// swift-tools-version: 5.9

// Projeto de App para o Swift Playgrounds (roda direto no iPad).
// Abra a pasta "GravadorDeAulas.swiftpm" no app Swift Playgrounds e toque em ▶.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Gravador de Aulas",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Gravador de Aulas",
            targets: ["AppModule"],
            bundleIdentifier: "com.arvi.GravadorDeAulas",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .microphone(purposeString: "O microfone é usado para gravar o áudio das aulas.")
            ],
            additionalInfoPlistContentFilePath: "Info.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
