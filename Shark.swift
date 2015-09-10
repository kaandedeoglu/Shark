#!/usr/bin/env xcrun -sdk macosx swift

import Foundation

struct EnumBuilder {
    private enum Resource {
        case File(String)
        case Directory((String, [Resource]))
    }
    
    private static let forbiddenCharacterSet: NSCharacterSet = {
        let validSet = NSMutableCharacterSet(charactersInString: "_")
        validSet.formUnionWithCharacterSet(NSCharacterSet.letterCharacterSet())
        return validSet.invertedSet
        }()
    
    static func enumStringForPath(path: String, topLevelName: String = "Shark") throws -> String {
        let resources = try imageResourcesAtPath(path)
        if resources.isEmpty {
            return ""
        }
        let topLevelResource = Resource.Directory(topLevelName, resources)
        return createEnumDeclarationForResources([topLevelResource], indentLevel: 0)
    }
    
    private static func imageResourcesAtPath(path: String) throws -> [Resource] {
        var results = [Resource]()
        let URL = NSURL.fileURLWithPath(path)
        
        let contents = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(URL, includingPropertiesForKeys: [NSURLNameKey, NSURLIsDirectoryKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles)
        
        for fileURL in contents {
            var directoryKey: AnyObject?
            try fileURL.getResourceValue(&directoryKey, forKey: NSURLIsDirectoryKey)
            
            guard let isDirectory = directoryKey as? NSNumber else { continue }
            
            if isDirectory.integerValue == 1 {
                if fileURL.absoluteString.hasSuffix(".imageset/") {
                    let name = fileURL.lastPathComponent!.componentsSeparatedByString(".imageset")[0]
                    results.append(.File(name))
                } else if !fileURL.absoluteString.hasSuffix(".appiconset/") {
                    let folderName = fileURL.lastPathComponent!
                    let subResources = try imageResourcesAtPath(fileURL.relativePath!)
                    results.append(.Directory((folderName, subResources)))
                }
            }
        }
        return results
    }
    
    private static func correctedNameForString(string: String) -> String? {
        //First try replacing -'s with _'s only, then remove illegal characters
        if let _ = string.rangeOfString("-") {
            let replacedString = string.stringByReplacingOccurrencesOfString("-", withString: "_")
            if replacedString.rangeOfCharacterFromSet(forbiddenCharacterSet) == nil {
                return replacedString
            }
        }
        
        if let _ = string.rangeOfCharacterFromSet(forbiddenCharacterSet) {
            return string.componentsSeparatedByCharactersInSet(forbiddenCharacterSet).joinWithSeparator("")
        }
        
        return nil
    }
    
    //An enum should extend String and conform to SharkImageConvertible if and only if it has at least on image asset in it.
    //We return empty string when we get a Directory of directories.
    private static func conformanceStringForResource(resource: Resource) -> String {
        switch resource {
        case .Directory(_, let subResources):
            
            let index = subResources.indexOf({
                if case .File = $0 {
                    return true
                } else {
                    return false
                }
            })
            
            if let _ = index {
                return ": String, SharkImageConvertible"
            } else {
                return ""
            }
        case _:
            return ""
        }
    }
    
    private static func createEnumDeclarationForResources(resources: [Resource], indentLevel: Int) -> String {
        let sortedResources = resources.sort { first, _ in
            if case .Directory = first {
                return true
            }
            return false
        }
        
        var resultString = ""
        for singleResource in sortedResources {
            switch singleResource {
            case .File(let name):
                print("Creating Case: \(name)")
                let indentationString = String(count: 4 * (indentLevel + 1), repeatedValue: Character(" "))
                if let correctedName = correctedNameForString(name) {
                    resultString += indentationString + "case \(correctedName) = \"\(name)\"\n"
                } else {
                    resultString += indentationString + "case \(name)\n"
                }
            case .Directory(let (name, subResources)):
                let correctedName = name.stringByReplacingOccurrencesOfString(" ", withString: "")
                print("Creating Enum: \(correctedName)")
                let indentationString = String(count: 4 * (indentLevel), repeatedValue: Character(" "))
                resultString += "\n" + indentationString + "public enum \(correctedName)" + conformanceStringForResource(singleResource)  + " {" + "\n"
                resultString += createEnumDeclarationForResources(subResources, indentLevel: indentLevel + 1)
                resultString += indentationString + "}\n\n"
            }
        }
        return resultString
    }
}


struct FileBuilder {
    static func fileStringWithEnumString(enumString: String) -> String {
        return acknowledgementsString() + "\n\n" + importString() + "\n\n" + imageExtensionString() + "\n" + enumString
    }
    
    private static func importString() -> String {
        return "import UIKit"
    }
    
    private static func acknowledgementsString() -> String {
        return "//SharkImages.swift\n//Generated by Shark"
    }
    
    private static func imageExtensionString() -> String {
        return "public protocol SharkImageConvertible {}\n\npublic extension SharkImageConvertible where Self: RawRepresentable, Self.RawValue == String {\n    public var image: UIImage? {\n        return UIImage(named: self.rawValue)\n    }\n}\n\npublic extension UIImage {\n    convenience init?<T: RawRepresentable where T.RawValue == String>(shark: T) {\n        self.init(named: shark.rawValue)\n    }\n}\n"
    }
}

//-----------------------------------------------------------//
//-----------------------------------------------------------//


//Process arguments and run the script
let arguments = Process.arguments

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
if NSFileManager.defaultManager().fileExistsAtPath(outputPath, isDirectory: &isDirectory) == false {
    print("The output path does not exist")
    exit(1)
}

if !isDirectory{
    print("The output path is not a valid directory")
    exit(1)
}


//Create the file string
let enumString = try EnumBuilder.enumStringForPath(path)
let fileString = FileBuilder.fileStringWithEnumString(enumString)

//Save the file string
let outputURL = NSURL.fileURLWithPath(outputPath).URLByAppendingPathComponent("SharkImages.swift")
try fileString.writeToURL(outputURL, atomically: true, encoding: NSUTF8StringEncoding)