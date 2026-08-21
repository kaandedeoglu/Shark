# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Shark is a Swift command line tool with three subcommands:

- `generate` (default) — type-safe enums for iOS/macOS application assets (images, colors, fonts, localizations, storyboards, data assets). Parses the Xcode project to discover resources; compile-time safety for asset access.
- `lint` — localization completeness checks across all locales (missing-key, empty-source-value, placeholder-mismatch, orphaned-key); exit code 1 on findings, built as a CI gate.
- `translate` — fills localization gaps via local Claude Code by default, with Claude API and Codex CLI backends also supported; machine-validated format-specifier preservation and `needs_review` write-back.

## Positioning (keep docs/marketing consistent with this)

Shark's pitch against Xcode's generated symbols (which sherlocked images/colors in Xcode 15 and string accessors via String Catalogs later): Shark also covers fonts, storyboards, and data assets; speaks classic `.strings` *and* `.xcstrings`; namespaces by folder structure and key separators; handles multi-target/white-label setups (`--target`, `--exclude`, `--name`); and — the core argument — treats localization as a *workflow* (generate → lint → translate), not just codegen. Against SwiftGen/R.swift: project-driven instead of config-driven, zero runtime dependency, and they don't lint or translate. XcodeGen/Tuist are project generators — orthogonal, not competitors. The three subcommands deliberately share one project model and one `FormatSpecifierParser`, so claims like "lint checks exactly what generate generates" stay true — preserve that property when extending.

## Build and Development Commands

### Building the Project
```bash
# Build in debug mode
swift build

# Build for release
swift build -c release

# Install locally (after building release)
cp ./.build/release/Shark /usr/local/bin/shark
```

### Running Tests
The project uses Swift Package Manager's built-in testing. Look for test files in the standard `Tests/` directory structure.

```bash
swift test
```

### Running Smoke Tests
```bash
# Stable committed fixtures used by CI
Scripts/smoke-fixtures.sh

# Optional local pass over real-world projects
SHARK_REAL_WORLD_ROOT="$HOME/Documents/late" Scripts/smoke-real-world.sh
```

### Running the Tool
```bash
# Basic usage - generates Shark.swift in specified directory (generate is the default subcommand)
shark PROJECT_FILE_PATH OUTPUT_PATH

# Common usage with Xcode project
shark MyApp.xcodeproj ./Sources/MyApp/

# With options
shark MyApp.xcodeproj ./Sources/MyApp/ --target MyAppTarget --framework swiftui --name Assets

# Localization workflow
shark lint MyApp.xcodeproj --target MyAppTarget --format github
shark translate MyApp.xcodeproj --target MyAppTarget --to de,fr --dry-run
shark translate MyApp.xcodeproj --target MyAppTarget --to de,fr --yes
shark translate MyApp.xcodeproj --target MyAppTarget --to de,fr --backend claude-code --yes
shark translate MyApp.xcodeproj --target MyAppTarget --to de,fr --backend codex --yes
```

Field-tested on real multi-target projects; the prose-percent heuristics in the placeholder check (`"25% and"`, `"100%ig"`) and the `empty-source-value` rule came out of those runs — check `LocalizationLinterTests` before touching the normalization.

## Architecture

### Target Layout

The package is split into a library and a thin executable (see TRANSLATE_PLAN.md for the rationale — this boundary also serves the planned SPM build plugin, issue #46):

- **`SharkKit` (library)** — all logic: options, project parsing, codegen. Tests run against this target (`@testable import SharkKit`).
- **`Shark` (executable)** — ArgumentParser commands only. `Generate` is the `defaultSubcommand`, so the classic `shark PROJECT OUTPUT` invocation from Xcode build phases keeps working without naming a subcommand.

### Core Components

**CLI Layer (`Sources/Shark/`)**
- `Shark.swift`: Root command declaring the subcommands.
- `GenerateCommand.swift`: The codegen subcommand (default); orchestrates the generation process.
- `LintCommand.swift`: `shark lint` — missing-key / orphaned-key / placeholder-mismatch checks across all locales; exit code 1 on findings (CI gate).
- `TranslateCommand.swift`: `shark translate` — translates missing keys via local agent or API backend; backend selection (claude-code default, api, codex, auto), confirmation prompt with cost estimate.

**Localization Workflow (`Sources/SharkKit/Localization/`, `Lint/`, `Translate/`)**
- `LocalizationTable` + readers/writers: multi-locale model over `.strings` groups and `.xcstrings` catalogs. Writers are additive-only; the `.xcstrings` writer serializes in Xcode's JSON style (byte-identical round trip) to avoid whole-file diffs.
- `FormatSpecifierParser`: shared printf-specifier parsing used by codegen, lint, and translate validation.
- `LocalizationLinter` / `LintReportFormatter`: rules and text/json/github output.
- `Translator` + `CompletionProviding` backends: `ClaudeClient` (Messages API; structured output, prompt caching, retries, parallel batches — first batch runs alone to write the cache), `ClaudeCodeBackend` (pipes through a local `claude -p` binary with `--json-schema`, billed to the user's subscription), and `CodexBackend` (pipes through `codex exec` with structured-output schema support). Every translation is validated (placeholder preservation) and written back as `needs_review`.
- Plurals are out of scope for lint and translate: those readers skip and report them
  (`skippedPluralKeys`). `generate` does handle them — a pluralized entry has no string unit of its
  own, so the accessor takes its format specifiers from the `other` variation. Watch the decoding
  model: translation states are plain strings in a catalog, and an enum without a raw value decodes
  as `{"translated": {}}` instead, which used to fail the whole run.

**Options & Project Parsing (`Sources/SharkKit/`)**
- `Options.swift`: Shared ArgumentParser options used by `generate` and the builders.
- `Project/XcodeProjectResourceScanner.swift`: Reads the target's resource files out of the project with XcodeProj — resource build phases (including variant groups for localizations) and Xcode 16 synchronized folder groups, minus their membership exceptions. References that do not live in the file system (built products, SDK paths) are skipped, which is what keeps stale entries from mattering.
- `Project/XcodeProjectHelper.swift`: Facade over the scanner — locale filtering, `--exclude`, and the `--deps` dependency file.

**Code Generation (`Sources/SharkKit/Codegen/`)**
- `SharkEnumBuilder.swift`: Main orchestrator that coordinates generation of all asset types (images, colors, fonts, localizations, storyboards, data assets).
- `FileBuilder.swift`: Handles final file output formatting with proper headers and import statements.
- Asset-specific builders: `FontEnumBuilder.swift`, `LocalizationEnumBuilder.swift`, `NestedEnumBuilder.swift`, `StoryboardEnumBuilder.swift`
- Asset type definitions: `ImageAsset.swift`, `ColorAsset.swift`, `DataAsset.swift`

**Framework Support (`Sources/SharkKit/Types/Framework.swift`)**
- Enum defining supported frameworks: UIKit, AppKit, SwiftUI
- Each framework has different import statements and API generation patterns

### Key Dependencies
- **XcodeProj**: Parses `.xcodeproj` files. The only thing between Shark and the project format.
- **ArgumentParser**: Handles command-line interface and option parsing

#### Why not XcodeGraph

Shark used XcodeGraph between 1.8 and 2.1 (issue #51), because Xcode 16 folder-backed projects broke
the direct XcodeProj usage (XcodeProj#880). It cost more than it gave:

- **Runtime.** XcodeGraph resolves Swift package manifests by shelling out to `swift package
  dump-package` — a full second per local package. Projects with five local packages paid five
  seconds per build. That is the complaint in #51 that the `--deps` dependency-file support was
  built to route around.
- **Workarounds.** The stderr/PATH wrapper around `dump-package`, the resource-only project copy for
  unresolvable link phases (#52, #55), and a de-duplication guard for local packages — every one of
  them existed because of a feature Shark does not use.
- **Correctness.** A project whose local package sits at the project's own directory (`path: .`, what
  XcodeGen writes for a repo-root package) lost its targets entirely: XcodeGraph keys projects by
  path, and the package's project overwrites the Xcode project's. The app targets simply vanished.
- **Maintenance.** `tuist/XcodeGraph` was archived on 2026-02-26 at 1.34.5; the successor inside
  `tuist/tuist` is not consumable as a Swift package. Reported bugs cannot reach us.

Shark needs two answers from a project: which target, and which resource files that target builds.
`XcodeProjectResourceScanner` reads both straight from the object graph — resource build phases plus
Xcode 16 synchronized folder groups — in about 130 lines. Cold build went from 207 s to 49 s,
dependencies from 22 to 5, and a run on a project with local packages from ~1.1 s to ~0.03 s.

Upstream report for the crash, kept for the record: https://github.com/tuist/tuist/issues/12546

### Regression fixture

`Examples/Format90Example/` is a hand-crafted minimal `.xcodeproj` with `objectVersion = 90` and a `PBXShellScriptBuildPhase` whose `shellScript` is the new array form. It's the regression case for issue #54.

`Examples/LocalPackageExample/` links a local Swift package and also carries it as a folder
reference, which is what Xcode and XcodeGen both write. It used to abort Shark before a single
resource was read; the scanner ignores packages entirely, which is the point of the fixture.

`Examples/SynchronizedFolderExample/` is an Xcode 16 folder-backed target: no files in the project
file at all, membership follows the file system, and an exception set keeps `Excluded.xcassets` out.
This is the case from issues #50/#51 and the reason the scanner walks synchronized groups itself.

`Examples/LocalizationWorkflowExample/` is a hand-crafted localization workflow fixture with expected lint findings across `.strings` and `.xcstrings`, skipped plural catalog entries, and stable `translate --dry-run` gaps.

`Scripts/smoke-fixtures.sh` also creates a temporary XcodeGen project during the run. With XcodeGen 2.45.x this covers `objectVersion = 77`, giving the parser both committed Xcode 16.3 fixtures and a generator-produced project format.

Smoke-test the toolchain against committed fixtures after dependency bumps:

```bash
Scripts/smoke-fixtures.sh
```

Also smoke-test against a real project with local Swift package dependencies that can emit manifest warnings:

```bash
swift run Shark /path/to/App.xcodeproj /tmp/SharkSmoke.swift --target App --deps /tmp/shark-smoke.d
```

Real-world projects under `$HOME/Documents/late` are useful before release tags, but they are not CI fixtures. If one fails, reduce it to the smallest synthetic `.xcodeproj` and commit that under `Examples/`.

### Resource Processing Flow
1. XcodeProjectResourceScanner parses the `.xcodeproj` file using XcodeProj
2. Extracts resource file paths based on target selection
3. Different builders process each asset type:
   - `.xcassets` → Images, Colors, Data Assets
   - `.strings`/`.xcstrings` → Localizations  
   - `.ttf`/`.otf`/`.ttc` → Fonts
   - `.storyboard` → Storyboards
4. Generated enums are namespaced based on folder structure (if "Provides Namespace" is enabled)
5. FileBuilder combines all enums into final Swift file

### Framework-Specific Generation
- **UIKit**: Uses `UIImage`, `UIColor`, `UIFont` APIs
- **AppKit**: Uses `NSImage`, `NSColor`, `NSFont` APIs  
- **SwiftUI**: Uses `Image`, `Color`, `Font` APIs with `LocalizedStringKey` extension

### Build Integration
Shark is designed to integrate with Xcode build phases to automatically regenerate asset enums when resources change. It supports dependency file generation (`--deps` flag) for efficient incremental builds.
