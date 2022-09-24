//
//  File.swift
//  
//
//  Created by Dr. Michael Lauer on 23.09.22.
//

import PackagePlugin
import XcodeProjectPlugin
import Foundation

enum PluginError: Error {
    case unsupported
    case configFileNotPresent(expectedAt: String)
    case debug(info: String)
}

@main
struct CreateResourceFile: XcodeBuildToolPlugin, BuildToolPlugin {

    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        throw PluginError.unsupported
    }

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        print("Requested to return build commands for target \(target.displayName) with context \(context)")

        let configFilePath = context.xcodeProject.directory.appending("\(target.displayName)-shark.json").string
        let configFileUrl = URL(fileURLWithPath: configFilePath)
        guard let data = try? Data(contentsOf: configFileUrl) else { throw PluginError.configFileNotPresent(expectedAt: configFilePath) }

        var assetPaths: [String] = []
        var localizationPaths: [String] = []
        var fontPaths: [String] = []
        var storyboardPaths: [String] = []

        var locale = "en"

        for inputFile in target.inputFiles {
            guard !inputFile.path.string.contains("Preview Content") else { continue }
            let path = inputFile.path.string
            switch inputFile.path.extension {
                case "xcassets":
                    assetPaths.append(path)
                case "strings" where path.contains("\(locale).lproj"):
                    localizationPaths.append(path)
                case "ttf", "otf", "ttc":
                    fontPaths.append(path)
                case "storyboard" where !path.hasSuffix("LaunchScreen.storyboard"):
                    storyboardPaths.append(path)
                default:
                    print("Ignoring \(inputFile)")
            }
        }

        print("Assets: \(assetPaths), localizationPaths: \(localizationPaths), fontPaths: \(fontPaths), storyboardPaths: \(storyboardPaths)")

        throw PluginError.debug(info: "yo")

        guard let target = target as? SwiftSourceModuleTarget else {
            throw PluginError.debug(info: "target \(target) not a SwiftSourceModuleTarget")
        }

        let xcassets = target.sourceFiles(withSuffix: "xcassets")
        print("xcassets: \(xcassets)")

        return [
            .buildCommand(displayName: "Generate Shark Resource File",
                          executable: try context.tool(named: "CreateResourceFile").path,
                          arguments: ["input", "output"],
                          inputFiles: [],
                          outputFiles: [])
        ]
    }
}
