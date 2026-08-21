# Changelog

## 2.2.0

- Replaced the XcodeGraph dependency with direct XcodeProj parsing. Shark reads the target's resource build phases and Xcode 16 synchronized folder groups itself, and no longer resolves Swift package manifests, link phases or a dependency graph it never used. Runs that took seconds now take milliseconds: a project with eight local Swift packages went from 2.85s to 0.11s, and cold builds of Shark itself from 207s to 49s with 22 dependencies down to 5.
- Fixed projects that reference a local Swift package both as a package and as a folder in the navigator, which is what Xcode and XcodeGen write. Those aborted the process outright.
- Fixed projects whose local Swift package sits at the project's own directory. Their application targets were invisible, so Shark reported them as not found.
- Fixed `generate` for string catalogs with pluralized entries. Decoding failed on the whole catalog; a pluralized key now generates an accessor that takes its format specifiers from the plural variations.
- `unset SDKROOT` is no longer needed in Xcode Run Script phases: nothing in Shark shells out to SwiftPM any more.
- Added fixtures for local packages, Xcode 16 folder-backed targets and their membership exceptions.

## 2.1.0

- Fixed resource scanning for projects that link workspace-built products such as sibling frameworks from `BUILT_PRODUCTS_DIR`. Shark now ignores unresolved Frameworks and Embed phase entries while mapping resources, so valid workspace projects no longer need Xcode project format changes or hand-sanitized build phases.
- Added a dedicated workspace-built-product fixture and smoke coverage for this parser fallback.
- Added `shark --version` output for release verification.

## 2.0

- Added `shark lint`, a localization CI gate for missing keys, empty source values, orphaned keys, placeholder mismatches, and skipped plural entries.
- Added `shark translate`, which fills localization gaps via Claude Code, Codex CLI, or the Claude API, validates placeholder preservation, and writes results back for human review.
- Added first-class `.xcstrings` support alongside classic `.strings` files across generation, linting, and translation.
- Split the package into a reusable `SharkKit` library and a thin `Shark` executable while preserving the existing default `shark PROJECT OUTPUT` generation workflow.
- Improved Xcode project parser resilience with committed smoke fixtures for modern object versions and SwiftPM warning output.

## 1.8.7

- Fixed Homebrew source installs on macOS 27 / Xcode 27 by updating the formula to use SwiftPM's native build system, avoiding a Swift macro expansion failure in transitive dependencies.

## 1.8.6

- Fixed project parsing when SwiftPM prints warnings while Shark maps local package dependencies. Shark now keeps successful `swift package dump-package` JSON clean even when package manifest warnings are written to stderr.
- Improved Xcode project parsing errors by including the underlying Swift decoding error where available.
- Documented that Xcode run script dependency file paths should be quoted in the project file when they contain path separators, for compatibility with the Xcode project parser.
