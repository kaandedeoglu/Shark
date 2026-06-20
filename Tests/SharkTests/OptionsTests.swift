import Foundation
import Testing
@testable import SharkKit

struct OptionsTests {
    @Test func relativeProjectFilePathIsNormalizedToAbsolutePath() throws {
        let path = try Options.validatedProjectPath("Examples/Format90Example/Format90Example.xcodeproj")

        #expect(path == FileManager.default.currentDirectoryPath
            .appendingPathComponent("Examples/Format90Example/Format90Example.xcodeproj"))
    }

    @Test func relativeProjectDirectoryPathIsNormalizedToContainedProject() throws {
        let path = try Options.validatedProjectPath("Examples/Format90Example")

        #expect(path == FileManager.default.currentDirectoryPath
            .appendingPathComponent("Examples/Format90Example/Format90Example.xcodeproj"))
    }
}
