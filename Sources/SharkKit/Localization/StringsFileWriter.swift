import Foundation

/// Appends new keys to a `.strings` file. Append-only by design — existing
/// content is never reordered or reformatted, so manual edits and VCS history
/// stay intact.
public enum StringsFileWriter {
    public static func append(_ translations: [(key: String, value: String)],
                              toFileAtPath path: String,
                              comment: String = "Added by shark translate — review before release") throws {
        guard translations.isEmpty == false else { return }

        var contents = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        if contents.isEmpty == false, contents.hasSuffix("\n") == false {
            contents += "\n"
        }
        contents += "\n/* \(comment) */\n"
        for translation in translations.sorted(by: { $0.key < $1.key }) {
            contents += "\"\(escaped(translation.key))\" = \"\(escaped(translation.value))\";\n"
        }
        try contents.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    private static func escaped(_ string: String) -> String {
        string.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
