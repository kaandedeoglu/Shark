import Foundation
import ArgumentParser

@main
struct Shark: AsyncParsableCommand {
    static var configuration: CommandConfiguration = .init(abstract: "Paste the following line in a Xcode run phase script that runs before the \"Compile Sources\" run phase:",
                                                           discussion: "shark $PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME")

    @OptionGroup()
    private var options: Options

    func run() async throws {

        let enumString = try await SharkEnumBuilder.sharkEnumString(forOptions: options)
        var lastContent: String = ""
        if let data = try? Data(contentsOf: URL(fileURLWithPath: options.outputPath)),
           let content = String(data: data, encoding: .utf8) {
            lastContent = content
        }
        let newContent = FileBuilder.fileContents(with: enumString, options: options)
        guard newContent != lastContent else { return }
        try newContent.write(to: URL(fileURLWithPath: options.outputPath), atomically: true, encoding: .utf8)
    }
}

struct Options: ParsableArguments {
    @Argument(help: "The .xcodeproj file path", transform: Self.transform(forProjectPath:))
    fileprivate(set) var projectPath: String

    @Argument(help: "The output file path", transform: Self.transform(forOutputPath:))
    fileprivate(set) var outputPath: String

    @Option(name: .customLong("name"),
            help: "The top level enum name")
    private(set) var topLevelEnumName: String = "Shark"

    @Option(help: "The generated properties' visiblity")
    private(set) var visibility: String = "public"

    @Option(name: .customLong("target"),
            help: "Target name of the application, useful in case there are multiple application targets")
    private(set) var targetName: String?

    @Option(name: .long,
            help: "Separator character used to split localization keys")
    private(set) var separator: Character = "."

    @Option(name: .long,
            help: "Localization code to use when selecting the Localizable.strings. i.e en, de, es.")
    private(set) var locale: String = "en"

    @Flag(help: "Disable the top level enum and declare resource enums on the top level")
    private(set) var topLevelScope: Bool = false

    @Option(name: .customLong("framework"),
            help: "Enable code generation support for the specified framework. Valid frameworks are 'uikit', 'appkit', and 'swiftui'.",
            transform: Self.frameworkEnum(forFramework:))
    private(set) var framework: Framework = .uikit

    @Option(name: .customLong("exclude"),
            help: "Exclude a file from processing (postfix matching).")
    private(set) var exclude: [String] = []

    @Option(name: .long,
            help: "Path to a dependency file. Set, if Shark should generate a dependency file for Xcode")
    private(set) var deps: String? = nil

    func shouldExclude(path: String) -> Bool {
        for exclude in self.exclude {
            if path.contains(exclude) { return true }
        }
        return false
    }
}

extension Options {

    private static func frameworkEnum(forFramework framework: String) throws -> Framework {
        guard let frameEnum = Framework(rawValue: framework.lowercased()) else {
            throw ValidationError("Invalid framework name '\(framework)'. Valid frameworks are 'uikit', 'appkit', and 'swiftui'")
        }
        return frameEnum
    }

    private static func transform(forProjectPath path: String) throws -> String {
        var isDirectory: ObjCBool = false
        if path.pathExtension == "xcodeproj" {
            return path
        } else if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            let projectFiles = try FileManager
                .default
                .contentsOfDirectory(atPath: path).filter { $0.pathExtension == "xcodeproj" }

            if projectFiles.isEmpty {
                throw ValidationError("\(path) should point to a .xcodeproj file")
            } else if projectFiles.count == 1 {
                return path.appendingPathComponent(projectFiles[0])
            } else {
                throw ValidationError("There are multiple .xcodeproj files in directory: \(path). Please provide an exact path")
            }
        } else {
            throw ValidationError("\(path) should point to a .xcodeproj file")
        }
    }

    private static func transform(forOutputPath path: String) throws -> String {
        var path = path
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            path.append("Shark.swift")
        } else if path.pathExtension != "swift" {
            throw ValidationError("The output path should either point to an existing folder or end with a .swift extension")
        }

        return path
    }
}
