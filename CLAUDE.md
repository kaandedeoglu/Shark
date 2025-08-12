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