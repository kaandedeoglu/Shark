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
    let other: Variation

    var all: [Variation] { [zero, one, two, few, many, other].compactMap { $0 } }
}

struct Variation: Decodable {
    
    enum TranslationState: Decodable {
        case translated
        case needs_review
    }

    let stringUnit: StringUnit
    let state: TranslationState
}

struct StringUnit: Decodable {
    let value: String
}
