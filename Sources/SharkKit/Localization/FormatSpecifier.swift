import Foundation

public struct FormatSpecifier: Equatable, Hashable {
    public let raw: String
    public let position: Int?
    public let lengthModifier: String
    public let conversion: Character

    /// Identity used to compare placeholders between a source string and its
    /// translation — flags, width, and precision don't affect the argument
    /// list, so they are deliberately excluded.
    public var comparisonKey: String {
        let positionPart = position.map { "\($0)$" } ?? ""
        return "%\(positionPart)\(lengthModifier)\(conversion)"
    }
}

public enum FormatSpecifierParser {
    private static let conversions: Set<Character> = ["@", "d", "D", "i", "u", "U", "x", "X", "o", "O",
                                                      "f", "e", "E", "g", "G", "c", "C", "s", "S", "p",
                                                      "a", "A", "F"]
    private static let flags: Set<Character> = ["-", "+", " ", "0", "#", "'"]
    private static let lengthModifiers: Set<Character> = ["h", "l", "q", "z", "t", "j", "L"]

    public static func specifiers(in value: String) -> [FormatSpecifier] {
        var result: [FormatSpecifier] = []
        let characters = Array(value)
        var index = 0

        while index < characters.count {
            guard characters[index] == "%" else {
                index += 1
                continue
            }

            let start = index
            index += 1
            guard index < characters.count else { break }

            // %% is a literal percent sign, not a placeholder
            if characters[index] == "%" {
                index += 1
                continue
            }

            var position: Int? = nil
            var digits = ""
            var lookahead = index
            while lookahead < characters.count, characters[lookahead].isNumber {
                digits.append(characters[lookahead])
                lookahead += 1
            }
            if digits.isEmpty == false, lookahead < characters.count, characters[lookahead] == "$" {
                position = Int(digits)
                index = lookahead + 1
            }

            while index < characters.count, flags.contains(characters[index]) {
                index += 1
            }
            while index < characters.count, characters[index].isNumber {
                index += 1
            }
            if index < characters.count, characters[index] == "*" {
                index += 1
            }
            if index < characters.count, characters[index] == "." {
                index += 1
                while index < characters.count, characters[index].isNumber {
                    index += 1
                }
                if index < characters.count, characters[index] == "*" {
                    index += 1
                }
            }

            var lengthModifier = ""
            while index < characters.count, lengthModifiers.contains(characters[index]) {
                lengthModifier.append(characters[index])
                index += 1
            }

            guard index < characters.count, conversions.contains(characters[index]) else {
                // Not a placeholder after all — rescan right after the '%'
                index = start + 1
                continue
            }

            let conversion = characters[index]
            index += 1
            result.append(FormatSpecifier(raw: String(characters[start..<index]),
                                          position: position,
                                          lengthModifier: lengthModifier,
                                          conversion: conversion))
        }
        return result
    }
}
