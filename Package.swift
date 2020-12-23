// swift-tools-version:5.0
// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import PackageDescription

let package = Package(
    name: "CredentialsAppleSignIn",
    products: [
        .library(
            name: "CredentialsAppleSignIn",
            targets: ["CredentialsAppleSignIn"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", .upToNextMajor(from: "2.4.1")),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", from: "1.8.1"),
        .package(url: "https://github.com/SyncServerII/AppleJWTDecoder.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "CredentialsAppleSignIn",
            dependencies: ["Credentials",  "HeliumLogger", "AppleJWTDecoder"]),
        .testTarget(
            name: "CredentialsAppleSignInTests",
            dependencies: ["CredentialsAppleSignIn"]),
    ]
)
