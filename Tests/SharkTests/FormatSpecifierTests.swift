import Testing
import Foundation
@testable import SharkKit

struct FormatSpecifierTests {
    @Test func simpleSpecifiers() {
        let specifiers = FormatSpecifierParser.specifiers(in: "Use %@ to login with %d attempts")
        #expect(specifiers.count == 2)
        #expect(specifiers[0].conversion == "@")
        #expect(specifiers[0].raw == "%@")
        #expect(specifiers[1].conversion == "d")
        #expect(specifiers[1].raw == "%d")
    }

    @Test func positionalSpecifiers() {
        let specifiers = FormatSpecifierParser.specifiers(in: "%2$@ before %1$d")
        #expect(specifiers.count == 2)
        #expect(specifiers[0].position == 2)
        #expect(specifiers[0].conversion == "@")
        #expect(specifiers[1].position == 1)
        #expect(specifiers[1].conversion == "d")
        #expect(specifiers[0].comparisonKey == "%2$@")
        #expect(specifiers[1].comparisonKey == "%1$d")
    }

    @Test func widthPrecisionAndFlags() {
        let specifiers = FormatSpecifierParser.specifiers(in: "%5.2f and %-10d and %05d and % d")
        #expect(specifiers.count == 4)
        #expect(specifiers[0].conversion == "f")
        #expect(specifiers[0].raw == "%5.2f")
        #expect(specifiers.allSatisfy { $0.position == nil })
    }

    @Test func lengthModifiers() {
        let specifiers = FormatSpecifierParser.specifiers(in: "%ld %lld %zd %lu")
        #expect(specifiers.count == 4)
        #expect(specifiers[0].lengthModifier == "l")
        #expect(specifiers[1].lengthModifier == "ll")
        #expect(specifiers[2].lengthModifier == "z")
        #expect(specifiers[3].conversion == "u")
    }

    @Test func literalPercentIsNotASpecifier() {
        #expect(FormatSpecifierParser.specifiers(in: "100%% done").isEmpty)
        #expect(FormatSpecifierParser.specifiers(in: "50%% complete, %d left").count == 1)
    }

    @Test func trailingAndInvalidPercents() {
        #expect(FormatSpecifierParser.specifiers(in: "100%").isEmpty)
        #expect(FormatSpecifierParser.specifiers(in: "% ").isEmpty)
        #expect(FormatSpecifierParser.specifiers(in: "%-").isEmpty)
        // Rescan after an invalid run must still find later specifiers
        #expect(FormatSpecifierParser.specifiers(in: "%y %d").count == 1)
    }

    @Test func comparisonKeyIgnoresWidthAndFlags() {
        let a = FormatSpecifierParser.specifiers(in: "%5.2f")[0]
        let b = FormatSpecifierParser.specifiers(in: "%.1f")[0]
        #expect(a.comparisonKey == b.comparisonKey)
    }
}
