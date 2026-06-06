import Foundation

/// Routes accepted translations to the right file writer.
public enum TranslationWriteBack {
    public struct Summary {
        public internal(set) var writtenByLocale: [String: Int] = [:]
        public internal(set) var failed: [(gap: TranslationGap, reason: String)] = []
    }

    public static func write(_ translated: [(gap: TranslationGap, value: String)]) throws -> Summary {
        var summary = Summary()

        var catalogTranslations: [String: [StringCatalogWriter.Translation]] = [:]
        var stringsTranslations: [String: [(key: String, value: String)]] = [:]

        for (gap, value) in translated {
            switch gap.origin {
                case .stringCatalog(let path):
                    catalogTranslations[path, default: []].append(.init(key: gap.key, locale: gap.targetLocale, value: value))
                    summary.writtenByLocale[gap.targetLocale, default: 0] += 1
                case .stringsFiles(let pathsByLocale):
                    guard let path = pathsByLocale[gap.targetLocale] else {
                        summary.failed.append((gap, "no .strings file for locale \(gap.targetLocale) — create \(gap.targetLocale).lproj/\(gap.tableName).strings in Xcode first"))
                        continue
                    }
                    stringsTranslations[path, default: []].append((gap.key, value))
                    summary.writtenByLocale[gap.targetLocale, default: 0] += 1
            }
        }

        for (path, translations) in catalogTranslations.sorted(by: { $0.key < $1.key }) {
            try StringCatalogWriter.add(translations, toCatalogAtPath: path)
        }
        for (path, translations) in stringsTranslations.sorted(by: { $0.key < $1.key }) {
            try StringsFileWriter.append(translations, toFileAtPath: path)
        }
        return summary
    }
}
