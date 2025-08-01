import Foundation
import XcodeGraph
import XcodeGraphMapper
import Path

enum PBXFilePathError: String, Error {
    case cannotResolvePath
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

        //let start = CFAbsoluteTimeGetCurrent()
        let xcodeproj = try await mapper.map(at: self.projectPath)
        //let stop = CFAbsoluteTimeGetCurrent()
        //print("Mapping took \(stop - start) seconds")

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
}
