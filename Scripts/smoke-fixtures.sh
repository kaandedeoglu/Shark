#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/shark-fixture-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -n "${SHARK_BIN:-}" ]]; then
  SHARK=("$SHARK_BIN")
else
  SHARK=(swift run --package-path "$ROOT" Shark)
fi

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    echo "Expected to find '$needle' in $file" >&2
    echo "--- $file ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_fails() {
  local output="$1"
  shift
  if "$@" >"$output" 2>&1; then
    echo "Expected command to fail: $*" >&2
    echo "--- output ---" >&2
    cat "$output" >&2
    exit 1
  fi
}

FORMAT90_PROJECT="$ROOT/Examples/Format90Example/Format90Example.xcodeproj"
FORMAT90_OUTPUT="$TMP_DIR/Format90Shark.swift"

echo "==> generate: Format90Example"
"${SHARK[@]}" "$FORMAT90_PROJECT" "$FORMAT90_OUTPUT" --target Format90Example
assert_contains "$FORMAT90_OUTPUT" "public enum Shark"
assert_contains "$FORMAT90_OUTPUT" "public enum I"
assert_contains "$FORMAT90_OUTPUT" "public enum L"
assert_contains "$FORMAT90_OUTPUT" "Greeting_HELLO"

echo "==> generate relative path: Format90Example"
(cd "$ROOT" && "${SHARK[@]}" Examples/Format90Example/Format90Example.xcodeproj "$TMP_DIR/Format90RelativeShark.swift" --target Format90Example)
assert_contains "$TMP_DIR/Format90RelativeShark.swift" "public enum Shark"

echo "==> lint clean: Format90Example"
"${SHARK[@]}" lint "$FORMAT90_PROJECT" --target Format90Example >"$TMP_DIR/format90-lint.txt"
assert_contains "$TMP_DIR/format90-lint.txt" "No localization issues found."

if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN_ROOT="$TMP_DIR/XcodeGenSmoke"
  mkdir -p "$XCODEGEN_ROOT/XcodeGenSmoke/Assets.xcassets/Logo.imageset"
  mkdir -p "$XCODEGEN_ROOT/XcodeGenSmoke/en.lproj"

  cat >"$XCODEGEN_ROOT/project.yml" <<'YAML'
name: XcodeGenSmoke
options:
  minimumXcodeGenVersion: 2.45.0
targets:
  XcodeGenSmoke:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - XcodeGenSmoke
    resources:
      - XcodeGenSmoke/Assets.xcassets
      - XcodeGenSmoke/en.lproj/Localizable.strings
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: dev.shark.XcodeGenSmoke
YAML

  cat >"$XCODEGEN_ROOT/XcodeGenSmoke/AppDelegate.swift" <<'SWIFT'
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}
SWIFT

  cat >"$XCODEGEN_ROOT/XcodeGenSmoke/Assets.xcassets/Contents.json" <<'JSON'
{"info":{"version":1,"author":"xcode"}}
JSON

  cat >"$XCODEGEN_ROOT/XcodeGenSmoke/Assets.xcassets/Logo.imageset/Contents.json" <<'JSON'
{"images":[],"info":{"version":1,"author":"xcode"}}
JSON

  cat >"$XCODEGEN_ROOT/XcodeGenSmoke/en.lproj/Localizable.strings" <<'STRINGS'
"HELLO_FROM_XCODEGEN" = "Hello from XcodeGen";
STRINGS

  echo "==> generate: XcodeGenSmoke"
  (cd "$XCODEGEN_ROOT" && xcodegen generate --quiet)
  XCODEGEN_OBJECT_VERSION="$(awk '/objectVersion =/ { gsub(";", "", $3); print $3; exit }' "$XCODEGEN_ROOT/XcodeGenSmoke.xcodeproj/project.pbxproj")"
  if [[ "$XCODEGEN_OBJECT_VERSION" == "90" || -z "$XCODEGEN_OBJECT_VERSION" ]]; then
    echo "Expected XcodeGenSmoke to cover a non-90 objectVersion; got '${XCODEGEN_OBJECT_VERSION:-missing}'" >&2
    exit 1
  fi
  "${SHARK[@]}" "$XCODEGEN_ROOT/XcodeGenSmoke.xcodeproj" "$TMP_DIR/XcodeGenSmokeShark.swift" --target XcodeGenSmoke
  assert_contains "$TMP_DIR/XcodeGenSmokeShark.swift" "HELLO_FROM_XCODEGEN"
  assert_contains "$TMP_DIR/XcodeGenSmokeShark.swift" "Logo"
else
  echo "==> skipping XcodeGenSmoke: xcodegen not installed"
fi

WORKFLOW_PROJECT="$ROOT/Examples/LocalizationWorkflowExample/LocalizationWorkflowExample.xcodeproj"

echo "==> lint expected findings: LocalizationWorkflowExample"
assert_fails "$TMP_DIR/workflow-lint.txt" "${SHARK[@]}" lint "$WORKFLOW_PROJECT" --target LocalizationWorkflowExample
assert_contains "$TMP_DIR/workflow-lint.txt" "missing-key"
assert_contains "$TMP_DIR/workflow-lint.txt" "Greeting_WELCOME_FORMAT"
assert_contains "$TMP_DIR/workflow-lint.txt" "Catalog.button.format"
assert_contains "$TMP_DIR/workflow-lint.txt" "plural key(s) skipped"

echo "==> lint json is clean stdout: LocalizationWorkflowExample"
if "${SHARK[@]}" lint "$WORKFLOW_PROJECT" --target LocalizationWorkflowExample --format json >"$TMP_DIR/workflow-lint.json" 2>"$TMP_DIR/workflow-lint-json.err"; then
  echo "Expected json lint command to fail" >&2
  echo "--- stdout ---" >&2
  cat "$TMP_DIR/workflow-lint.json" >&2
  echo "--- stderr ---" >&2
  cat "$TMP_DIR/workflow-lint-json.err" >&2
  exit 1
fi
python3 -m json.tool "$TMP_DIR/workflow-lint.json" >/dev/null
assert_contains "$TMP_DIR/workflow-lint.json" "\"findings\""

echo "==> translate dry-run: LocalizationWorkflowExample"
"${SHARK[@]}" translate "$WORKFLOW_PROJECT" --target LocalizationWorkflowExample --to de,fr --dry-run >"$TMP_DIR/workflow-translate.txt"
assert_contains "$TMP_DIR/workflow-translate.txt" "Missing translations:"
assert_contains "$TMP_DIR/workflow-translate.txt" "Greeting_WELCOME_FORMAT"
assert_contains "$TMP_DIR/workflow-translate.txt" "Catalog.button.format"
assert_contains "$TMP_DIR/workflow-translate.txt" "Estimate:"

echo "Fixture smoke tests passed."
