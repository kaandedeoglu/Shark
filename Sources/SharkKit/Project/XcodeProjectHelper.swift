import Foundation
import PathKit

struct ProjectReadError: LocalizedError {
    let underlying: Error
    let projectPath: String

    var errorDescription: String? {
        var lines = ["Failed to parse \(projectPath):", "  \(underlying.localizedDescription)"]
        let detailedDescription = String(reflecting: underlying)
        if detailedDescription != underlying.localizedDescription {
            lines.append("  \(detailedDescription)")
        }
        return lines.joined(separator: "\n")
    }
}

enum TargetSelectionError: LocalizedError {
    case targetNotFound(name: String)
    case noTargets
    case multipleTargets(eligible: [String])
    case noResources

    var errorDescription: String? {
        switch self {
            case .targetNotFound(let name):
                return "Could not find target \(name) in the project"
            case .noTargets:
                return "Could not find a project with at least one target"
            case .multipleTargets(let eligible):
                return "Multiple application targets found, please specify the target by using the --target flag. Eligible targets are: \(eligible)"
            case .noResources:
                return "No resources found for target"
        }
    }
}

struct XcodeProjectHelper {
    struct ResourcePaths {
        fileprivate(set) var localizationPaths: [String] = []
        fileprivate(set) var assetsPaths: [String] = []
        fileprivate(set) var fontPaths: [String] = []
        fileprivate(set) var storyboardPaths: [String] = []
    }

    private let projectPath: Path
    private let targetName: String?
    private let locale: String
    private let excludes: [String]
    private let depsPath: String?
    private let outputPath: String?

    init(options: Options) throws {
        try self.init(projectPath: options.projectPath,
                      targetName: options.targetName,
                      locale: options.locale,
                      excludes: options.exclude,
                      depsPath: options.deps,
                      outputPath: options.outputPath)
    }

    init(projectPath: String, targetName: String?, locale: String = "en", excludes: [String] = [], depsPath: String? = nil, outputPath: String? = nil) throws {
        self.projectPath = Path(projectPath).absolute()
        self.targetName = targetName
        self.locale = locale
        self.excludes = excludes
        self.depsPath = depsPath
        self.outputPath = outputPath
    }

    /// All localization file paths of the target, unfiltered by locale —
    /// lint and translate need the full multi-locale picture.
    func localizationResourcePaths() async throws -> (strings: [String], xcstrings: [String]) {
        var strings: [String] = []
        var xcstrings: [String] = []
        for path in try targetResourceFilePaths() {
            switch path.extension {
                case "strings":
                    strings.append(path.string)
                case "xcstrings":
                    xcstrings.append(path.string)
                default:
                    break
            }
        }
        return (strings, xcstrings)
    }

    func resourcePaths() async throws -> ResourcePaths {
        var result = ResourcePaths()

        for path in try targetResourceFilePaths() {
            switch path.extension {
                case "xcassets":
                    result.assetsPaths.append(path.string)
                case "strings" where path.components.contains("\(locale).lproj"):
                    result.localizationPaths.append(path.string)
                case "xcstrings":
                    result.localizationPaths.append(path.string)
                case "ttf", "otf", "ttc":
                    result.fontPaths.append(path.string)
                case "storyboard":
                    result.storyboardPaths.append(path.string)
                default:
                    break
            }
        }

        if let deps = self.depsPath, let outputPath = self.outputPath {
            Self.log("Generating dependency file at `\(deps)`")
            FileManager.default.createFile(atPath: deps, contents: nil, attributes: nil)
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: deps))
            defer { fileHandle.closeFile() }
            let sharkFile = "\(outputPath):".data(using: .utf8)!
            try fileHandle.write(contentsOf: sharkFile)

            let flattenedResources: [String] = result.localizationPaths + result.assetsPaths + result.fontPaths + result.storyboardPaths
            for resource in flattenedResources {
                let safeName = resource.replacingOccurrences(of: " ", with: "\\ ")
                let dependency = " \(safeName)".data(using: .utf8)!
                try fileHandle.write(contentsOf: dependency)
            }
            try fileHandle.write(contentsOf: "\n".data(using: .utf8)!)
        }
        return result
    }

    private func targetResourceFilePaths() throws -> [Path] {
        if let targetName {
            Self.log("Looking for target \(targetName) in project at \(projectPath.string)...")
        } else {
            Self.log("No target specified, using the only target in the project at \(projectPath.string)...")
        }

        let scanner = XcodeProjectResourceScanner(projectPath: projectPath, targetName: targetName)
        let resources: [Path]
        do {
            resources = try scanner.resourceFilePaths()
        } catch let error as TargetSelectionError {
            throw error
        } catch {
            throw ProjectReadError(underlying: error, projectPath: projectPath.string)
        }

        let filtered = resources.filter { !shouldExclude(path: $0.string) }
        guard !filtered.isEmpty else { throw TargetSelectionError.noResources }
        return filtered
    }

    private func shouldExclude(path: String) -> Bool {
        excludes.contains { path.contains($0) }
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
