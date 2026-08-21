struct StringCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: StringCatalogEntry]
}

struct StringCatalogEntry: Decodable {
    let comment: String?
    let localizations: [String: Localization]?
}

struct Localization: Decodable {
    let stringUnit: StringUnit?
    let variations: Variations?
}

struct Variations: Decodable {
    let plural: PluralVariation?
}

struct PluralVariation: Decodable {
    let zero: Variation?
    let one: Variation?
    let two: Variation?
    let few: Variation?
    let many: Variation?
    let other: Variation?

    /// Ordered from the most specific category to the most general, so callers that need a single
    /// representative value — for format specifiers, say — can take the first one.
    var all: [Variation] { [other, many, few, two, one, zero].compactMap { $0 } }
}

struct Variation: Decodable {
    let stringUnit: StringUnit?
    /// Xcode keeps the translation state inside the string unit; some tools also write it here.
    let state: TranslationState?
}

/// Raw-value backed on purpose: without one, the synthesized decoding expects `{"translated": {}}`
/// and chokes on the `"translated"` a catalog actually contains.
enum TranslationState: String, Decodable {
    case translated
    case needs_review
}

struct StringUnit: Decodable {
    let value: String
    let state: TranslationState?
}
