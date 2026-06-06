#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_WORLD_ROOT="${SHARK_REAL_WORLD_ROOT:-$HOME/Documents/late}"
LIMIT="${SHARK_REAL_WORLD_LIMIT:-20}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/shark-real-world-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -n "${SHARK_BIN:-}" ]]; then
  SHARK=("$SHARK_BIN")
else
  SHARK=(swift run --package-path "$ROOT" Shark)
fi

if [[ ! -d "$REAL_WORLD_ROOT" ]]; then
  echo "Skipping real-world smoke: $REAL_WORLD_ROOT does not exist."
  exit 0
fi

PROJECT_LIST="$TMP_DIR/projects.txt"
if [[ -n "${SHARK_REAL_WORLD_PROJECTS_FILE:-}" ]]; then
  cp "$SHARK_REAL_WORLD_PROJECTS_FILE" "$PROJECT_LIST"
else
  find "$REAL_WORLD_ROOT" -name "*.xcodeproj" -type d | sort | head -n "$LIMIT" >"$PROJECT_LIST"
fi

if [[ ! -s "$PROJECT_LIST" ]]; then
  echo "No .xcodeproj files found under $REAL_WORLD_ROOT."
  exit 0
fi

failures=0
checked=0

while IFS= read -r raw_line; do
  [[ -z "$raw_line" || "$raw_line" == \#* ]] && continue

  project="$raw_line"
  target=""
  if [[ "$raw_line" == *"|"* ]]; then
    project="${raw_line%%|*}"
    target="${raw_line#*|}"
  fi

  checked=$((checked + 1))
  output="$TMP_DIR/real-world-$checked.swift"
  log="$TMP_DIR/real-world-$checked.log"

  echo "==> real-world generate: $project${target:+ (target: $target)}"
  args=("$project" "$output")
  if [[ -n "$target" ]]; then
    args+=(--target "$target")
  fi

  if "${SHARK[@]}" "${args[@]}" >"$log" 2>&1; then
    echo "    ok"
  else
    failures=$((failures + 1))
    echo "    failed" >&2
    sed 's/^/    /' "$log" >&2
  fi
done <"$PROJECT_LIST"

if [[ "$checked" -eq 0 ]]; then
  echo "No projects selected for real-world smoke."
  exit 0
fi

if [[ "$failures" -ne 0 ]]; then
  echo "$failures of $checked real-world smoke(s) failed." >&2
  exit 1
fi

echo "Real-world smoke passed for $checked project(s)."
