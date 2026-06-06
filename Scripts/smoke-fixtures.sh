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

echo "==> lint clean: Format90Example"
"${SHARK[@]}" lint "$FORMAT90_PROJECT" --target Format90Example >"$TMP_DIR/format90-lint.txt"
assert_contains "$TMP_DIR/format90-lint.txt" "No localization issues found."

WORKFLOW_PROJECT="$ROOT/Examples/LocalizationWorkflowExample/LocalizationWorkflowExample.xcodeproj"

echo "==> lint expected findings: LocalizationWorkflowExample"
assert_fails "$TMP_DIR/workflow-lint.txt" "${SHARK[@]}" lint "$WORKFLOW_PROJECT" --target LocalizationWorkflowExample
assert_contains "$TMP_DIR/workflow-lint.txt" "missing-key"
assert_contains "$TMP_DIR/workflow-lint.txt" "Greeting_WELCOME_FORMAT"
assert_contains "$TMP_DIR/workflow-lint.txt" "Catalog.button.format"
assert_contains "$TMP_DIR/workflow-lint.txt" "plural key(s) skipped"

echo "==> translate dry-run: LocalizationWorkflowExample"
"${SHARK[@]}" translate "$WORKFLOW_PROJECT" --target LocalizationWorkflowExample --to de,fr --dry-run >"$TMP_DIR/workflow-translate.txt"
assert_contains "$TMP_DIR/workflow-translate.txt" "Missing translations:"
assert_contains "$TMP_DIR/workflow-translate.txt" "Greeting_WELCOME_FORMAT"
assert_contains "$TMP_DIR/workflow-translate.txt" "Catalog.button.format"
assert_contains "$TMP_DIR/workflow-translate.txt" "Estimate:"

echo "Fixture smoke tests passed."
