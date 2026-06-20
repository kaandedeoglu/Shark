# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Shark is a Swift command line tool that generates type-safe enums for iOS/macOS application assets (images, colors, fonts, localizations, storyboards). It parses Xcode project files to automatically discover resources and generate Swift code that provides compile-time safety for asset access.

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

### Running the Tool
```bash
# Basic usage - generates Shark.swift in specified directory
shark PROJECT_FILE_PATH OUTPUT_PATH

# Common usage with Xcode project
shark MyApp.xcodeproj ./Sources/MyApp/

# With options
shark MyApp.xcodeproj ./Sources/MyApp/ --target MyAppTarget --framework swiftui --name Assets
```

## Architecture

### Core Components

**CLI Layer (`Sources/Shark/CLI/`)**
- `Shark.swift`: Main command-line interface using ArgumentParser. Handles options parsing and orchestrates the generation process.
- `XcodeProjectHelper.swift`: Interfaces with XcodeGraph library to parse `.xcodeproj` files and extract resource paths. Handles target selection and resource discovery.

**Code Generation (`Sources/Shark/Codegen/`)**
- `SharkEnumBuilder.swift`: Main orchestrator that coordinates generation of all asset types (images, colors, fonts, localizations, storyboards, data assets).
- `FileBuilder.swift`: Handles final file output formatting with proper headers and import statements.
- Asset-specific builders: `FontEnumBuilder.swift`, `LocalizationEnumBuilder.swift`, `NestedEnumBuilder.swift`, `StoryboardEnumBuilder.swift`
- Asset type definitions: `ImageAsset.swift`, `ColorAsset.swift`, `DataAsset.swift`

**Framework Support (`Sources/Shark/Types/Framework.swift`)**
- Enum defining supported frameworks: UIKit, AppKit, SwiftUI
- Each framework has different import statements and API generation patterns

### Key Dependencies
- **XcodeGraph**: Parses Xcode project files and workspace structures
- **ArgumentParser**: Handles command-line interface and option parsing

#### Note on XcodeGraph maintenance status

The standalone `tuist/XcodeGraph` repo was archived on 2026-02-26; final release is **1.34.5**. Its sources have moved into `tuist/tuist:cli/Sources/XcodeGraph`, but that copy uses Swift Package Registry IDs (`.package(id:)`) and is not exposed as a public product, so it can't be consumed as a Swift Package dependency without additional work.

We deliberately stay on `tuist/XcodeGraph` 1.34.5 because:
- The actually consequential parser lives in `tuist/XcodeProj` (still actively maintained — 9.12.0+).
- 1.34.5's `Package.swift` pins XcodeProj as `.upToNextMajor(from: "9.9.0")`, so XcodeProj fixes (e.g. the Xcode 16.3 `objectVersion = 90` shellScript-as-array fix in 9.7.1) flow through transitively.

Revisit vendoring/submoduling only if XcodeGraph itself needs format-driven changes — until then, the standalone 1.34.5 release plus a fresh XcodeProj is the cheapest correct setup.

#### SwiftPM warning output during package mapping

XcodeGraph 1.34.5's `PackageInfoLoader` collects stdout and stderr together before decoding `swift package dump-package` output as JSON. Some package manifests, notably newer Swift manifests using deprecated PackageDescription APIs, can emit warnings to stderr while still returning valid JSON on stdout. Shark wraps `swift` during project mapping so successful `dump-package` calls expose only stdout to XcodeGraph; failed calls still forward stderr so real SwiftPM errors remain visible.

### Regression fixture

`Examples/Format90Example/` is a hand-crafted minimal `.xcodeproj` with `objectVersion = 90` and a `PBXShellScriptBuildPhase` whose `shellScript` is the new array form. It's the regression case for issue #54. Smoke-test the toolchain against it after dependency bumps:

```bash
swift run Shark Examples/Format90Example/Format90Example.xcodeproj Examples/Format90Example/Format90Example/
```

Also smoke-test against a real project with local Swift package dependencies that can emit manifest warnings:

```bash
swift run Shark /path/to/App.xcodeproj /tmp/SharkSmoke.swift --target App --deps /tmp/shark-smoke.d
```

### Resource Processing Flow
1. XcodeProjectHelper parses the `.xcodeproj` file using XcodeGraph
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
