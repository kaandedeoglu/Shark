import Foundation
import PathKit
import XcodeProj

/// Reads the resource files a target builds straight out of the project file.
///
/// Shark needs exactly two things from a project: which target to look at, and which resource files
/// that target builds. Everything else a project describes — package graphs, link and embed phases,
/// schemes, settings — is cost without benefit here, and every one of those areas has cost us a
/// workaround at some point. So this walks the object graph itself and stops at the two questions.
struct XcodeProjectResourceScanner {

    /// The file types Shark generates code for. Anything else in a resources phase is skipped, which
    /// is also what keeps unresolvable references (built products, SDK paths) from mattering.
    static let resourceExtensions: Set<String> = [
        "xcassets", "strings", "xcstrings", "ttf", "otf", "ttc", "storyboard",
    ]

    /// Resource types that are directories; the walk treats them as leaves rather than descending.
    private static let bundleExtensions: Set<String> = ["xcassets", "storyboard", "xcstrings"]

    private let projectPath: Path
    private let targetName: String?

    init(projectPath: Path, targetName: String?) {
        self.projectPath = projectPath
        self.targetName = targetName
    }

    func resourceFilePaths() throws -> [Path] {
        let xcodeProj = try XcodeProj(path: projectPath)
        let sourceRoot = projectPath.parent()
        let target = try selectTarget(in: xcodeProj.pbxproj)

        var paths: [Path] = []
        var seen = Set<String>()

        func append(_ path: Path) {
            guard seen.insert(path.string).inserted else { return }
            paths.append(path)
        }

        for phase in target.buildPhases.compactMap({ $0 as? PBXResourcesBuildPhase }) {
            for buildFile in phase.files ?? [] {
                guard let element = buildFile.file else { continue }
                for path in try resourcePaths(of: element, sourceRoot: sourceRoot) { append(path) }
            }
        }

        // Xcode 16 folder-backed targets have no build file entries: membership follows the file
        // system, minus whatever the target's exception set takes back out.
        for group in target.fileSystemSynchronizedGroups ?? [] {
            for path in try resourcePaths(of: group, in: target, sourceRoot: sourceRoot) { append(path) }
        }

        // Sorted so the generated file does not depend on the order objects happen to sit in.
        return paths.sorted { $0.string < $1.string }
    }

    // MARK: - Target selection

    private func selectTarget(in pbxproj: PBXProj) throws -> PBXNativeTarget {
        let targets = pbxproj.nativeTargets
        if let targetName {
            guard let target = targets.first(where: { $0.name == targetName }) else {
                throw TargetSelectionError.targetNotFound(name: targetName)
            }
            return target
        }
        guard !targets.isEmpty else { throw TargetSelectionError.noTargets }
        guard targets.count == 1 else {
            throw TargetSelectionError.multipleTargets(eligible: targets.map(\.name))
        }
        return targets[0]
    }

    // MARK: - Resource phase entries

    private func resourcePaths(of element: PBXFileElement, sourceRoot: Path) throws -> [Path] {
        // A variant group is one logical resource per locale — the localizations live in its children.
        if let variantGroup = element as? PBXVariantGroup {
            return try variantGroup.children.flatMap { try resourcePaths(of: $0, sourceRoot: sourceRoot) }
        }
        if let versionGroup = element as? XCVersionGroup {
            return try versionGroup.children.flatMap { try resourcePaths(of: $0, sourceRoot: sourceRoot) }
        }
        if let group = element as? PBXGroup {
            return try group.children.flatMap { try resourcePaths(of: $0, sourceRoot: sourceRoot) }
        }

        // Anything that does not live in the file system — built products, SDK and developer dir
        // references — cannot be read, and a project may well carry stale ones.
        switch element.sourceTree {
            case .absolute, .sourceRoot, .group, .none: break
            default: return []
        }
        guard let path = try element.fullPath(sourceRoot: sourceRoot),
              Self.resourceExtensions.contains(path.extension ?? "") else { return [] }
        return [path]
    }

    // MARK: - Synchronized folders

    private func resourcePaths(of group: PBXFileSystemSynchronizedRootGroup,
                               in target: PBXNativeTarget,
                               sourceRoot: Path) throws -> [Path] {
        guard let root = try group.fullPath(sourceRoot: sourceRoot), root.exists else { return [] }

        let excluded = Set((group.exceptions ?? [])
            .compactMap { $0 as? PBXFileSystemSynchronizedBuildFileExceptionSet }
            .filter { $0.target?.name == target.name }
            .flatMap { $0.membershipExceptions ?? [] })

        return collectResources(in: root, relativeTo: root, excluding: excluded)
    }

    private func collectResources(in directory: Path, relativeTo root: Path, excluding excluded: Set<String>) -> [Path] {
        guard let children = try? directory.children() else { return [] }

        return children.flatMap { child -> [Path] in
            let relative = String(child.string.dropFirst(root.string.count + 1))
            guard !excluded.contains(relative) else { return [] }

            let fileExtension = child.extension ?? ""
            if child.isDirectory, !Self.bundleExtensions.contains(fileExtension) {
                return collectResources(in: child, relativeTo: root, excluding: excluded)
            }
            return Self.resourceExtensions.contains(fileExtension) ? [child] : []
        }
    }
}
