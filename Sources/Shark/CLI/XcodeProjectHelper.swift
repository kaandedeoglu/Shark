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

        let xcodeproj = try await mapper.map(at: self.projectPath)
        guard let mainProject = xcodeproj.projects.values.first(where: { $0.schemes.count >= 2 }) else { return .init() }

        let selectedTarget: Target

        if let targetName = self.targetName {
            guard let target = mainProject.targets.first(where: { $0.key == targetName }) else {
                let eligibleTargets = mainProject.targets.map { $0.key }
                print("No target found with name \(targetName). Eligible targets are: \(eligibleTargets)")
                exit(EXIT_FAILURE)
            }
            selectedTarget = target.value
        } else {
            guard mainProject.targets.count == 1 else {
                let eligibleTargets = mainProject.targets.map { $0.key }
                print("Multiple application targets found, please specify the target by using the --target flag. Eligible targets are: \(eligibleTargets)")
                exit(EXIT_FAILURE)
            }
            selectedTarget = mainProject.targets.first!.value
        }
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
        return result
    }
}
