import Foundation
import ArgumentParser

struct Options: ParsableArguments {
    @Argument(help: "The .xcodeproj file path")
    fileprivate(set) var projectPath: String

    @Argument(help: "The output file path")
    fileprivate(set) var outputPath: String

    @Option(name: .customLong("name"),
            default: "Shark",
            help: "Top level enum name under which the cases are defined.")
    private(set) var topLevelEnumName: String

    @Option(name: .customLong("target"),
            help: "Target name of the application, useful in case there are multiple application targets")
    private(set) var targetName: String?

    @Option(name: .long,
            default: "en",
            help: "Localization code to use when selecting the Localizable.strings. i.e en, de, es.")
    private(set) var locale: String
}

struct Shark: ParsableCommand {
    static var configuration: CommandConfiguration = .init(abstract:#"""
Paste the following line in a Xcode run phase script that runs after the "Compile Sources" run phase:
shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME
"""#)

    @OptionGroup()
    private var options: Options

    mutating func validate() throws {
        guard options.projectPath.pathExtension == "xcodeproj" else {
            throw ValidationError("\(options.projectPath) should point to a .xcodeproj file")
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: options.outputPath, isDirectory: &isDirectory), isDirectory.boolValue {
            options.outputPath.append("Shark.swift")
        } else if options.outputPath.pathExtension != "swift" {
            throw ValidationError("The output path should either point to an existing folder or end with a .swift extension")
        }

        options.projectPath = options.projectPath.expandingTildeInPath
        options.outputPath = options.outputPath.expandingTildeInPath
    }

    func run() throws {
        let enumString = try SharkEnumBuilder.sharkEnumString(forOptions: options)

        try FileBuilder
            .fileContents(with: enumString, filename: options.outputPath.lastPathComponent)
            .write(to: URL(fileURLWithPath: options.outputPath), atomically: true, encoding: .utf8)
    }
}
