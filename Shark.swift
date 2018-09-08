#!/usr/bin/env xcrun -sdk macosx swift

import Foundation

//A simple counted set implementation that uses a dictionary for storage.
struct CountedSet<Element: Hashable>: Sequence {
    typealias Iterator = DictionaryIterator<Element, Int>
    
    private var backingDictionary: [Element: Int] = [:]
    
    @discardableResult
    mutating func addObject(_ object: Element) -> Int {
        let currentCount = backingDictionary[object] ?? 0
        let newCount = currentCount + 1
        backingDictionary[object] = newCount
        return newCount
    }
    
    func countForObject(_ object: Element) -> Int {
        return backingDictionary[object] ?? 0
    }
    
    func makeIterator() -> DictionaryIterator<Element, Int> {
        return backingDictionary.makeIterator()
    }
}

struct EnumBuilder {
    private enum Resource {
        case file(String)
        case directory(String, [Resource])
    }
    
    private static let forbiddenCharacterSet: CharacterSet = {
        let validSet = NSMutableCharacterSet(charactersIn: "_")
        validSet.formUnion(with: CharacterSet.letters)
        return validSet.inverted
    }()
    
    private static let forbiddenPathExtensions = [".appiconset/", ".launchimage/", ".colorset/"]
    private static let imageSetExtension = "imageset"
    
    static func enumStringForPath(_ path: String, topLevelName: String = "Shark") throws -> String {
        let resources = try imageResourcesAtPath(path)
        if resources.isEmpty {
            return ""
        }
        let topLevelResource = Resource.directory(topLevelName, resources)
        return createEnumDeclarationForResources([topLevelResource], indentLevel: 0)
    }
    
    private static func imageResourcesAtPath(_ path: String) throws -> [Resource] {
        var results = [Resource]()
        let url = URL(fileURLWithPath: path)
        
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey], options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
        
        for fileURL in contents {
            var directoryKey: AnyObject?
            try (fileURL as NSURL).getResourceValue(&directoryKey, forKey: URLResourceKey.isDirectoryKey)
            
            guard let isDirectory = directoryKey as? NSNumber else { continue }
            
            if isDirectory.intValue == 1 {
                if fileURL.pathExtension == imageSetExtension {
                    if let name = fileURL.lastPathComponent.components(separatedBy: "." + imageSetExtension).first {
                        results.append(.file(name))
                    }
                } else if forbiddenPathExtensions.index(where: { fileURL.absoluteString.hasSuffix($0) }) == nil {
                    let folderName = fileURL.lastPathComponent
                    let subResources = try imageResourcesAtPath(fileURL.relativePath)
                    results.append(.directory(folderName, subResources))
                }
            }
        }
        return results
    }
    
    private static func correctedNameForString(_ string: String) -> String? {
        //First try replacing -'s with _'s only, then remove illegal characters
        if let _ = string.range(of: "-") {
            let replacedString = string.replacingOccurrences(of: "-", with: "_")
            if replacedString.rangeOfCharacter(from: forbiddenCharacterSet) == nil {
                return replacedString
            }
        }
        
        if let _ = string.rangeOfCharacter(from: forbiddenCharacterSet) {
            return string.components(separatedBy: forbiddenCharacterSet).joined(separator: "")
        }
        
        return nil
    }
    
    //An enum should extend String and conform to SharkImageConvertible if and only if it has at least on image asset in it.
    //We return empty string when we get a Directory of directories.
    private static func conformanceStringForResource(_ resource: Resource) -> String {
        switch resource {
        case .directory(_, let subResources):
            
            for resource in subResources {
                if case .file = resource {
                    return ": String, SharkImageConvertible"
                }
            }
            
            return ""
        case _:
            return ""
        }
    }
    
    private static func createEnumDeclarationForResources(_ resources: [Resource], indentLevel: Int) -> String {
        let sortedResources = resources.sorted { first, _ in
            if case .directory = first {
                return true
            }
            return false
        }
        
        var fileNameSeen = CountedSet<String>()
        var folderNameSeen = CountedSet<String>()
        
        var resultString = ""
        for singleResource in sortedResources {
            switch singleResource {
            case .file(let name):
                print("Creating Case: \(name)")
                let indentationString = String(repeating: " ", count: 4 * (indentLevel + 1))
                if let correctedName = correctedNameForString(name) {
                    let seenCount = fileNameSeen.countForObject(correctedName)
                    let duplicateCorrectedName = correctedName + String(repeating: "_", count: seenCount)
                    resultString += indentationString + "case \(duplicateCorrectedName) = \"\(name)\"\n"
                    
                    fileNameSeen.addObject(correctedName)
                } else {
                    resultString += indentationString + "case \(name)\n"
                }
            case .directory(let (name, subResources)):
                print("Creating Enum: \(name)")
                let indentationString = String(repeating: " ", count: 4 * (indentLevel))
                let duplicateCorrectedName: String
                if let correctedName = correctedNameForString(name) {
                    let seenCount = folderNameSeen.countForObject(correctedName)
                    duplicateCorrectedName = correctedName + String(repeating: "_", count: seenCount)
                    folderNameSeen.addObject(correctedName)
                } else {
                    duplicateCorrectedName = name
                }
                resultString += "\n" + indentationString + "public enum \(duplicateCorrectedName)" + conformanceStringForResource(singleResource)  + " {" + "\n"
                resultString += createEnumDeclarationForResources(subResources, indentLevel: indentLevel + 1)
                resultString += indentationString + "}\n\n"
            }
        }
        return resultString
    }
}


struct FileBuilder {
    static func fileStringWithEnumString(_ enumString: String) -> String {
        return acknowledgementsString() + "\n\n" + importString() + "\n\n" + imageExtensionString() + "\n" + enumString
    }
    
    private static func importString() -> String {
        return "import UIKit"
    }
    
    private static func acknowledgementsString() -> String {
        return "//SharkImages.swift\n//Generated by Shark"
    }
    
    private static func imageExtensionString() -> String {
        return "public protocol SharkImageConvertible {}\n\npublic extension SharkImageConvertible where Self: RawRepresentable, Self.RawValue == String {\n    public var image: UIImage? {\n        return UIImage(named: self.rawValue)\n    }\n}\n\npublic extension UIImage {\n    convenience init?<T: RawRepresentable>(shark: T)  where T.RawValue == String {\n        self.init(named: shark.rawValue)\n    }\n}\n"
    }
}

//-----------------------------------------------------------//
//-----------------------------------------------------------//


//Process arguments and run the script
let arguments = CommandLine.arguments

if arguments.count != 3 {
    print("You must supply the path to the .xcassets folder, and the output path for the Shark file")
    print("\n\nExample Usage:\nswift Shark.swift /Users/john/Code/GameProject/GameProject/Images.xcassets/ /Users/john/Code/GameProject/GameProject/")
    exit(1)
}

let path = arguments[1]

if !(path.hasSuffix(".xcassets") || path.hasSuffix(".xcassets/")) {
    print("The path should point to a .xcassets folder")
    exit(1)
}

let outputPath = arguments[2]

var isDirectory: ObjCBool = false
if FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDirectory) == false {
    print("The output path does not exist")
    exit(1)
}

if isDirectory.boolValue == false {
    print("The output path is not a valid directory")
    exit(1)
}


//Create the file string
let enumString = try EnumBuilder.enumStringForPath(path)
let fileString = FileBuilder.fileStringWithEnumString(enumString)

//Save the file string
let outputURL = URL(fileURLWithPath: outputPath).appendingPathComponent("SharkImages.swift")
try fileString.write(to: outputURL, atomically: true, encoding: String.Encoding.utf8)
