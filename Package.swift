// swift-tools-version:5.0
// Adapted from https://github.com/IBM-Swift/Kitura-CredentialsGoogle

import PackageDescription

let package = Package(
    name: "CredentialsAppleSignIn",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "CredentialsAppleSignIn",
            targets: ["CredentialsAppleSignIn"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", .upToNextMajor(from: "2.4.1")),
        .package(url: "https://github.com/IBM-Swift/Swift-JWT.git", from: "3.5.3"),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", from: "1.8.1"),
        .package(url: "https://github.com/ibm-cloud-security/Swift-JWK-to-PEM", from: "0.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CredentialsAppleSignIn",
            dependencies: ["Credentials", "SwiftJWT", "HeliumLogger", "SwiftJWKtoPEM"]),
        .testTarget(
            name: "CredentialsAppleSignInTests",
            dependencies: ["CredentialsAppleSignIn"]),
    ]
)
