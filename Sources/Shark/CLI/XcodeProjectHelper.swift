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
        let detailedDescription = String(reflecting: underlying)
        if detailedDescription != underlying.localizedDescription {
            lines.append("  \(detailedDescription)")
        }
        if let hint {
            lines.append("")
            lines.append(hint)
        }
        return lines.joined(separator: "\n")
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
    private let options: Options

    private let mapper: XcodeGraphMapper = .init()

    init(options: Options) throws {
        self.options = options
        self.projectPath = try AbsolutePath(validating: options.projectPath)
        self.targetName = options.targetName
        self.locale = options.locale
    }
    
    func resourcePaths() async throws -> ResourcePaths {

        let xcodeproj: XcodeGraph.Graph
        let swiftWrapper = try SwiftPackageDumpWrapper.install()
        defer { swiftWrapper.restore() }
        do {
            xcodeproj = try await mapper.map(at: self.projectPath)
        } catch {
            throw Self.diagnosticError(wrapping: error, projectPath: self.projectPath.pathString)
        }

        var selectedTarget: Target? = nil // will host the found target
        
        if let targetName = self.targetName {
            print("Looking for target \(targetName) in project at \(self.projectPath.pathString)...")
            for project in xcodeproj.projects.values {
                if project.targets.keys.contains(targetName) {
                    print("Found target \(targetName) in project \(project.name)")
                    selectedTarget = project.targets[targetName]!
                    break
                }
            }
        } else {
            print("No target specified, using the first target found in the first project at \(self.projectPath.pathString)...")
            guard let mainProject = xcodeproj.projects.values.first(where: { !$0.targets.isEmpty }) else {
                print("Could not find a project with at least one target")
                exit(EXIT_FAILURE)
            }
            guard mainProject.targets.count == 1 else {
                let eligibleTargets = mainProject.targets.map { $0.key }
                print("Multiple application targets found, please specify the target by using the --target flag. Eligible targets are: \(eligibleTargets)")
                exit(EXIT_FAILURE)
            }
            selectedTarget = mainProject.targets.values.first!
        }
        guard let selectedTarget else {
            print("Could not find suitable target)")
            exit(EXIT_FAILURE)
        }

        // target found, let's find its resources
        let targetResources = selectedTarget.resources.resources
        guard !targetResources.isEmpty else {
            print("No resources found for target")
            exit(EXIT_FAILURE)
        }

        var result = ResourcePaths()

        for resource in targetResources {
            guard case let .file(path, _, _) = resource else { continue }
            guard !self.options.shouldExclude(path: path.pathString) else { continue }

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

        if let deps = self.options.deps {
            print("Generating dependency file at `\(deps)`")
            FileManager.default.createFile(atPath: deps, contents: nil, attributes: nil)
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: deps))
            defer { fileHandle.closeFile() }
            let sharkFile = "\(options.outputPath):".data(using: .utf8)!
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

private struct SwiftPackageDumpWrapper {
    private let originalPath: String?
    private let wrapperDirectory: URL

    static func install() throws -> Self {
        let environment = ProcessInfo.processInfo.environment
        let originalPath = environment["PATH"]
        let swiftPath = try resolveSwiftExecutable()
        let wrapperDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("shark-swift-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: wrapperDirectory, withIntermediateDirectories: true)

        let wrapperPath = wrapperDirectory.appendingPathComponent("swift")
        let script = """
        #!/bin/sh
        case " $* " in
          *" dump-package "*|*" dump-package")
            stderr_file=$(mktemp "${TMPDIR:-/tmp}/shark-swift-stderr.XXXXXX") || exit 1
            '\(shellEscaped(swiftPath))' "$@" 2>"$stderr_file"
            status=$?
            if [ "$status" -ne 0 ]; then
              cat "$stderr_file" >&2
            fi
            rm -f "$stderr_file"
            exit "$status"
            ;;
          *)
            exec '\(shellEscaped(swiftPath))' "$@"
            ;;
        esac
        """
        try script.write(to: wrapperPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperPath.path)

        let newPath = [wrapperDirectory.path, originalPath].compactMap(\.self).joined(separator: ":")
        setenv("PATH", newPath, 1)
        return Self(originalPath: originalPath, wrapperDirectory: wrapperDirectory)
    }

    func restore() {
        if let originalPath {
            setenv("PATH", originalPath, 1)
        } else {
            unsetenv("PATH")
        }
        try? FileManager.default.removeItem(at: wrapperDirectory)
    }

    private static func resolveSwiftExecutable() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["swift"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let data = try pipe.fileHandleForReading.readToEnd(),
              let output = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            throw SwiftPackageDumpWrapperError.swiftExecutableNotFound
        }
        return output
    }

    private static func shellEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\\''")
    }
}

private enum SwiftPackageDumpWrapperError: LocalizedError {
    case swiftExecutableNotFound

    var errorDescription: String? {
        switch self {
        case .swiftExecutableNotFound:
            "Unable to locate the Swift executable"
        }
    }
}
