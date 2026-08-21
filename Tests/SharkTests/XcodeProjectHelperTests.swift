import Foundation
import Testing
@testable import SharkKit

struct XcodeProjectHelperTests {
    @Test func resourceScanIgnoresWorkspaceBuiltProducts() async throws {
        let projectPath = FileManager.default.currentDirectoryPath
            .appendingPathComponent("Examples/WorkspaceBuiltProductExample/WorkspaceBuiltProductExample.xcodeproj")
        let helper = try XcodeProjectHelper(projectPath: projectPath,
                                            targetName: "WorkspaceBuiltProductExample")

        let resources = try await helper.resourcePaths()

        #expect(resources.assetsPaths.contains { $0.hasSuffix("WorkspaceBuiltProductExample/Assets.xcassets") })
        #expect(resources.localizationPaths.contains { $0.hasSuffix("WorkspaceBuiltProductExample/en.lproj/Localizable.strings") })
    }

    /// A project that links a local Swift package. Nothing about the package concerns the resource
    /// scan, and that is the point: resolving it used to cost a second per package and aborted the
    /// process outright when the package was also listed as a folder reference.
    @Test func scansAProjectThatLinksALocalPackage() async throws {
        let projectPath = FileManager.default.currentDirectoryPath
            .appendingPathComponent("Examples/LocalPackageExample/LocalPackageExample.xcodeproj")
        let helper = try XcodeProjectHelper(projectPath: projectPath,
                                            targetName: "LocalPackageExample")

        let resources = try await helper.resourcePaths()

        #expect(resources.localizationPaths.contains { $0.hasSuffix("LocalPackageExample/en.lproj/Localizable.strings") })
        #expect(resources.assetsPaths.contains { $0.hasSuffix("LocalPackageExample/Assets.xcassets") })
    }

    /// Xcode 16 folder-backed targets list no files at all: membership follows the file system, and
    /// exception sets take individual entries back out again.
    @Test func scansAFolderBackedTargetAndHonoursItsExceptions() async throws {
        let projectPath = FileManager.default.currentDirectoryPath
            .appendingPathComponent("Examples/SynchronizedFolderExample/SynchronizedFolderExample.xcodeproj")
        let helper = try XcodeProjectHelper(projectPath: projectPath,
                                            targetName: "SynchronizedFolderExample")

        let resources = try await helper.resourcePaths()

        #expect(resources.assetsPaths.contains { $0.hasSuffix("SynchronizedFolderExample/Assets.xcassets") })
        #expect(resources.localizationPaths.contains { $0.hasSuffix("SynchronizedFolderExample/en.lproj/Localizable.strings") })
        #expect(resources.assetsPaths.contains { $0.hasSuffix("Excluded.xcassets") } == false)
    }

    @Test func reportsAnUnknownTargetByName() async throws {
        let projectPath = FileManager.default.currentDirectoryPath
            .appendingPathComponent("Examples/LocalPackageExample/LocalPackageExample.xcodeproj")
        let helper = try XcodeProjectHelper(projectPath: projectPath, targetName: "NoSuchTarget")

        await #expect(throws: TargetSelectionError.self) {
            try await helper.resourcePaths()
        }
    }
}
