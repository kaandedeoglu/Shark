import Foundation
import ArgumentParser

public enum LintReportFormat: String, CaseIterable, ExpressibleByArgument {
    case text
    case json
    case github
}

public enum LintReportFormatter {
    public static func report(findings: [LintFinding], skippedPluralKeys: [String: Set<String>], format: LintReportFormat) -> String {
        switch format {
            case .text:
                return textReport(findings: findings, skippedPluralKeys: skippedPluralKeys)
            case .json:
                return jsonReport(findings: findings, skippedPluralKeys: skippedPluralKeys)
            case .github:
                return githubReport(findings: findings)
        }
    }

    private static func textReport(findings: [LintFinding], skippedPluralKeys: [String: Set<String>]) -> String {
        var lines: [String] = []
        let byRule = Dictionary(grouping: findings, by: \.rule)
        for rule in [LintFinding.Rule.missingKey, .placeholderMismatch, .emptySourceValue, .orphanedKey] {
            guard let ruleFindings = byRule[rule], ruleFindings.isEmpty == false else { continue }
            lines.append("\(rule.rawValue) (\(ruleFindings.count)):")
            for finding in ruleFindings {
                lines.append("  [\(finding.table)] \(finding.message)")
            }
            lines.append("")
        }
        for (table, keys) in skippedPluralKeys.sorted(by: { $0.key < $1.key }) where keys.isEmpty == false {
            lines.append("note: [\(table)] \(keys.count) plural key(s) skipped — plural support is not implemented yet: \(keys.sorted().joined(separator: ", "))")
        }
        if findings.isEmpty {
            lines.append("No localization issues found.")
        } else {
            lines.append("\(findings.count) issue(s) found.")
        }
        return lines.joined(separator: "\n")
    }

    private static func jsonReport(findings: [LintFinding], skippedPluralKeys: [String: Set<String>]) -> String {
        struct Report: Codable {
            let findings: [LintFinding]
            let skippedPluralKeys: [String: [String]]
        }
        let report = Report(findings: findings,
                            skippedPluralKeys: skippedPluralKeys.mapValues { $0.sorted() })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(report), let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func githubReport(findings: [LintFinding]) -> String {
        findings.map { finding in
            let severity = finding.rule.failsByDefault ? "error" : "warning"
            let location = finding.path.map { "file=\($0)," } ?? ""
            // %0A is GitHub's escaped newline; messages here are single-line already
            return "::\(severity) \(location)title=shark lint \(finding.rule.rawValue)::\(finding.message)"
        }.joined(separator: "\n")
    }
}
