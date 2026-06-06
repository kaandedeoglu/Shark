# Shark 2.0 Follow-up Analysis

This document tracks technical risks that are still relevant after the 2.0 branch split the package into `SharkKit` and the thin `Shark` executable, and after the `lint` / `translate` workflow landed.

## Release-Critical Checks

1. Run `swift test` and the committed synthetic fixture smoke before every dependency bump or 2.0 release candidate:

   ```bash
   swift test
   Scripts/smoke-fixtures.sh
   ```

2. Before release tags, optionally run `SHARK_REAL_WORLD_ROOT="$HOME/Documents/late" Scripts/smoke-real-world.sh` to catch unknown real-project shapes.
3. Before advertising local agent backends as stable, run one real small-batch translation through `--backend claude-code` and `--backend codex`.

## Open Risks

### 1. Generated Asset Accessors Still Force-Unwrap

**Severity:** Medium  
**Locations:**
- `Sources/SharkKit/Codegen/ImageAsset.swift`
- `Sources/SharkKit/Codegen/ColorAsset.swift`
- `Sources/SharkKit/Codegen/DataAsset.swift`
- `Sources/SharkKit/Codegen/FontEnumBuilder.swift`

Shark intentionally generates force-unwrapped resource accessors so missing assets fail loudly during development. That behavior matches the historical API, but it should be documented as a contract: generated code assumes the Xcode project and bundle contain the discovered resources at runtime.

### 2. Sanitization Uses a Force-Unwrap

**Severity:** Low
**Location:** `Sources/SharkKit/Extensions/String+Extensions.swift`

`propertyNameSanitized` filters characters with `unicodeScalars.first!`. Swift `Character` values normally contain at least one scalar, so this is not a practical crash path, but replacing it with a guarded form would remove a noisy audit finding.

### 3. Character Argument Parsing Uses a Force-Unwrap

**Severity:** Low
**Location:** `Sources/SharkKit/Extensions/Character+ExpressibleByArgument.swift`

The initializer checks `argument.count == 1` before `argument.first!`, so the force unwrap is guarded by the count check. This can be cleaned up for style, but it is not a release blocker.

### 4. Dependency File Writing Force-Unwraps UTF-8 Encoding

**Severity:** Low
**Location:** `Sources/SharkKit/Project/XcodeProjectHelper.swift`

The dependency-file writer force-unwraps `.data(using: .utf8)`. UTF-8 encoding of Swift strings should not fail, but converting this to a small helper would make the code easier to audit.

### 5. Output Directory Path Joining Uses String Append

**Severity:** Low
**Location:** `Sources/SharkKit/Options.swift`

When the output argument points to an existing directory, `transform(forOutputPath:)` currently appends `"Shark.swift"` directly. Use `appendingPathComponent(_:)` to handle trailing slashes consistently.

### 6. Asset Namespace Detection Uses String Matching

**Severity:** Low
**Location:** `Sources/SharkKit/Codegen/NestedEnumBuilder.swift`

Namespace detection checks `Contents.json` text for `"provides-namespace" : true`. It works for Xcode's current formatting, but a structured JSON read would be more robust.

### 7. CLI Backend Version Checks Are Missing

**Severity:** Medium
**Locations:**
- `Sources/SharkKit/Translate/ClaudeCodeBackend.swift`
- `Sources/SharkKit/Translate/CodexBackend.swift`

The local translate backends assume recent CLIs:
- Claude Code must support `--json-schema`.
- Codex CLI must support `exec --output-schema` and `--output-last-message`.

Add startup/version checks with actionable error messages before the 2.0 release.

## Resolved Since The Original Report

- `XcodeProjectHelper` no longer exits the process for target-selection failures; it throws typed errors.
- Target lookup no longer force-unwraps `project.targets[targetName]`.
- The codebase now has focused tests for format-specifier parsing, localization linting, `.strings` / `.xcstrings` read-write behavior, API request construction, and local backend command construction.

## Recommended Next Actions

1. Add CLI capability checks for `claude` and `codex`.
2. When real-world smokes fail, reduce them to committed synthetic fixtures under `Examples/`.
3. Clean up the remaining low-risk force unwraps and path joining.
4. Decide whether generated force unwraps are an explicit design contract or whether Shark 2.x should offer an opt-in safe-access generation mode.
