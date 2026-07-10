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
}
