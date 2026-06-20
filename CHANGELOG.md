# Changelog

## 1.8.6

- Fixed project parsing when SwiftPM prints warnings while Shark maps local package dependencies. Shark now keeps successful `swift package dump-package` JSON clean even when package manifest warnings are written to stderr.
- Improved Xcode project parsing errors by including the underlying Swift decoding error where available.
- Documented that Xcode run script dependency file paths should be quoted in the project file when they contain path separators, for compatibility with the Xcode project parser.

