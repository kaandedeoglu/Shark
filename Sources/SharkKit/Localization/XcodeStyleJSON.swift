import Foundation

/// Serializes JSON the way Xcode writes `.xcstrings` files — 2-space indent,
/// `" : "` key separator, sorted keys, empty objects spanning three lines.
/// Matching Xcode's style keeps catalogs written by Shark from producing
/// whole-file diffs the next time Xcode touches them.
enum XcodeStyleJSON {
    static func string(from object: Any) -> String {
        var output = ""
        append(object, to: &output, indentLevel: 0)
        return output
    }

    private static func append(_ object: Any, to output: inout String, indentLevel: Int) {
        switch object {
            case let dictionary as [String: Any]:
                guard dictionary.isEmpty == false else {
                    output += "{\n\n\(indent(indentLevel))}"
                    return
                }
                output += "{\n"
                let keys = dictionary.keys.sorted(by: <)
                for (offset, key) in keys.enumerated() {
                    output += "\(indent(indentLevel + 1))\(escaped(key)) : "
                    append(dictionary[key]!, to: &output, indentLevel: indentLevel + 1)
                    output += offset == keys.count - 1 ? "\n" : ",\n"
                }
                output += "\(indent(indentLevel))}"
            case let array as [Any]:
                guard array.isEmpty == false else {
                    output += "[\n\n\(indent(indentLevel))]"
                    return
                }
                output += "[\n"
                for (offset, element) in array.enumerated() {
                    output += indent(indentLevel + 1)
                    append(element, to: &output, indentLevel: indentLevel + 1)
                    output += offset == array.count - 1 ? "\n" : ",\n"
                }
                output += "\(indent(indentLevel))]"
            case let string as String:
                output += escaped(string)
            case let number as NSNumber:
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    output += number.boolValue ? "true" : "false"
                } else {
                    output += "\(number)"
                }
            default:
                output += "null"
        }
    }

    private static func indent(_ level: Int) -> String {
        String(repeating: "  ", count: level)
    }

    private static func escaped(_ string: String) -> String {
        var output = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
                case "\"": output += "\\\""
                case "\\": output += "\\\\"
                case "\n": output += "\\n"
                case "\r": output += "\\r"
                case "\t": output += "\\t"
                case let other where other.value < 0x20:
                    output += String(format: "\\u%04x", other.value)
                default:
                    output.unicodeScalars.append(scalar)
            }
        }
        return output + "\""
    }
}
