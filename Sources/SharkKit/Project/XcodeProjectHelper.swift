import Foundation
import XcodeGraph
import XcodeGraphMapper
import Path

enum PBXFilePathError: String, Error {
    case cannotResolvePath
}

struct ProjectMappingError: LocalizedError {
    let underlying: Error
    let projectPath: String
    let hint: String?

    var errorDescription: String? {
        var lines: [String] = []
        lines.append("Failed to parse \(projectPath):")
        lines.append("  \(underlying.localizedDescription)")
        if let hint {
            lines.append("")
            lines.append(hint)
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

    private let projectPath: AbsolutePath
    private let targetName: String?
    private let locale: String
    private let excludes: [String]
    private let depsPath: String?
    private let outputPath: String?

    private let mapper: XcodeGraphMapper = .init()

    init(options: Options) throws {
        try self.init(projectPath: options.projectPath,
                      targetName: options.targetName,
                      locale: options.locale,
                      excludes: options.exclude,
                      depsPath: options.deps,
                      outputPath: options.outputPath)
    }

    init(projectPath: String, targetName: String?, locale: String = "en", excludes: [String] = [], depsPath: String? = nil, outputPath: String? = nil) throws {
        self.projectPath = try AbsolutePath(validating: projectPath)
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
        for path in try await targetResourceFilePaths() {
            switch path.extension {
                case "strings":
                    strings.append(path.pathString)
                case "xcstrings":
                    xcstrings.append(path.pathString)
                default:
                    break
            }
        }
        return (strings, xcstrings)
    }

    func resourcePaths() async throws -> ResourcePaths {
        var result = ResourcePaths()

        for path in try await targetResourceFilePaths() {
            switch path.extension {
                case "xcassets":
                    result.assetsPaths.append(path.pathString)
                case "strings" where path.components.contains("\(locale).lproj"):
                    result.localizationPaths.append(path.pathString)
                case "xcstrings":
                    result.localizationPaths.append(path.pathString)
                case "ttf", "otf", "ttc":
                    result.fontPaths.append(path.pathString)
                case "storyboard":
                    result.storyboardPaths.append(path.pathString)
                default:
                    break
            }
        }

        if let deps = self.depsPath, let outputPath = self.outputPath {
            print("Generating dependency file at `\(deps)`")
            FileManager.default.createFile(atPath: deps, contents: nil, attributes: nil)
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: deps))
            defer { fileHandle.closeFile() }
            let sharkFile = "\(outputPath):".data(using: .utf8)!
            try fileHandle.write(contentsOf: sharkFile)

            let flattenedResources: [String] = (result.localizationPaths + result.assetsPaths + result.fontPaths + result.storyboardPaths).compactMap { $0 }
            for resource in flattenedResources {
                let safeName = resource.replacingOccurrences(of: " ", with: "\\ ")
                let dependency = " \(safeName)".data(using: .utf8)!
                try fileHandle.write(contentsOf: dependency)
            }
            try fileHandle.write(contentsOf: "\n".data(using: .utf8)!)
        }
        return result
    }

    private func targetResourceFilePaths() async throws -> [AbsolutePath] {
        let xcodeproj: XcodeGraph.Graph
        do {
            xcodeproj = try await mapper.map(at: self.projectPath)
        } catch {
            throw Self.diagnosticError(wrapping: error, projectPath: self.projectPath.pathString)
        }

        let selectedTarget = try self.selectedTarget(in: xcodeproj)
        let targetResources = selectedTarget.resources.resources
        guard targetResources.isEmpty == false else {
            throw TargetSelectionError.noResources
        }

        return targetResources.compactMap { resource in
            guard case let .file(path, _, _) = resource else { return nil }
            guard self.shouldExclude(path: path.pathString) == false else { return nil }
            return path
        }
    }

    private func selectedTarget(in graph: XcodeGraph.Graph) throws -> Target {
        if let targetName = self.targetName {
            print("Looking for target \(targetName) in project at \(self.projectPath.pathString)...")
            for project in graph.projects.values {
                if let target = project.targets[targetName] {
                    print("Found target \(targetName) in project \(project.name)")
                    return target
                }
            }
            throw TargetSelectionError.targetNotFound(name: targetName)
        }

        print("No target specified, using the first target found in the first project at \(self.projectPath.pathString)...")
        guard let mainProject = graph.projects.values.first(where: { !$0.targets.isEmpty }) else {
            throw TargetSelectionError.noTargets
        }
        guard mainProject.targets.count == 1 else {
            throw TargetSelectionError.multipleTargets(eligible: mainProject.targets.map { $0.key })
        }
        return mainProject.targets.values.first!
    }

    private func shouldExclude(path: String) -> Bool {
        excludes.contains { path.contains($0) }
    }

    /// Wraps low-level XcodeGraph mapping errors with actionable guidance.
    /// See https://github.com/kaandedeoglu/Shark/issues/52 — most reports are stale
    /// frameworks-build-phase entries the user can fix in Xcode.
    private static func diagnosticError(wrapping error: Error, projectPath: String) -> Error {
        let description = error.localizedDescription
        var hint: String?
        if description.contains("PBXBuildFile") {
            hint = """
            Hint: Shark relies on XcodeGraph to parse the project, and one of the entries in
            the target's "Link Binary With Libraries" / Frameworks build phase points to a
            file Xcode can no longer resolve. Open the target in Xcode, look for a missing
            (red) framework reference in the Frameworks build phase, remove or fix it, and
            re-run Shark.
            """
        }
        return ProjectMappingError(underlying: error, projectPath: projectPath, hint: hint)
    }
}
