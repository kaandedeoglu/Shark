import Foundation
import Utility
import Basic

enum Parser {
    struct Result {
        let projectPath: String
        let outputURL: Foundation.URL
        let topLevelEnumName: String
        let fileName: String
        let targetName: String?
        let locale: String?
    }
    
    static func parse() throws -> Result {
        let exampleUsageString = "$PROJECT_FILE_PATH $PROJECT_DIR/$PROJECT_NAME"
        let parser = ArgumentParser(usage: exampleUsageString, overview: "Shark")
        let pathArgument = parser.add(positional: ".xcodeproj path", kind: String.self, usage: "The path to the .xcodeproj file")
        let outputArgument = parser.add(positional: "output path", kind: String.self, usage: "Path for the output file. Creates a Shark.swift file when this value is a folder")
        let nameArgument = parser.add(option: "--name", kind: String.self, usage: #"Top level enum name under which the cases are defined. Defaults to "Shark""#, completion: nil)
        let targetArgument = parser.add(option: "--target", kind: String.self, usage: "Target name of the application, useful in case there are multiple application targets", completion: nil)
        let localeArgument = parser.add(option: "--locale",kind: String.self,usage:
            #"Localization code to use when selecting the Localizable.strings. i.e "en", "de", "es" The "en" locale is used unless specified"#)
        
        let parseResults: ArgumentParser.Result
        do {
            parseResults = try parser.parse(Array(CommandLine.arguments.dropFirst()))
        } catch {
            switch error {
            case ArgumentParserError.expectedArguments(_, let missingArguments):
                print("Missing arguments: \(missingArguments.joined(separator: ", "))")
                print("Example usage: \(exampleUsageString)")
            case ArgumentParserError.unknownOption(let option):
                print("Unknown option: \(option)")
            default:
                print(error.localizedDescription)
            }
            exit(EXIT_FAILURE)
        }
        
        guard let projectPath = parseResults.get(pathArgument)?.expandingTildeInPath, let outputPath = parseResults.get(outputArgument)?.expandingTildeInPath else {
            print("xcodeproj file path and output path parameters are required")
            exit(EXIT_FAILURE)
        }
        
        guard projectPath.pathExtension == "xcodeproj" else {
            print("\(projectPath) should point to a .xcodeproj file")
            exit(EXIT_FAILURE)
        }
        
        var isDirectory: ObjCBool = false
        
        let fileName: String
        let outputURL: Foundation.URL
        if FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDirectory), isDirectory.boolValue {
            fileName = "Shark"
            outputURL = URL(fileURLWithPath: outputPath).appendingPathComponent("\(fileName).swift")
        } else if outputPath.pathExtension == "swift" {
            fileName = outputPath.lastPathComponent.deletingPathExtension
            outputURL = URL(fileURLWithPath: outputPath)
        } else {
            print("The output path should either point to an existing folder or end with a .swift extension")
            exit(2)
        }
        
        return Result(projectPath: projectPath,
                      outputURL: outputURL,
                      topLevelEnumName: parseResults.get(nameArgument) ?? "Shark",
                      fileName: fileName,
                      targetName: parseResults.get(targetArgument),
                      locale: parseResults.get(localeArgument))
    }
}
