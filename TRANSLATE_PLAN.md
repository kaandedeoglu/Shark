# Shark `lint` & `translate` — Implementation Plan

> **Status: implemented** on the `2.0` branch (M1–M5). Additions beyond the original plan: `shark translate` defaults to `--backend claude-code`, still supports the direct API backend, and also supports a local Codex CLI backend (`--backend codex`) — see README → Localization workflow.

Two new subcommands that make Shark a localization *workflow* tool, not just a codegen tool:

- **`shark lint`** — find localization gaps (keys missing per locale, placeholder mismatches). CI-friendly, no AI involved.
- **`shark translate`** — fill those gaps via a local agent by default or the Claude API in CI, with machine-checked format-specifier preservation and human review built into the workflow.

`lint` is the foundation; `translate` builds on top of it.

---

## 1. CLI restructuring

Shark is currently a single `AsyncParsableCommand` with positional arguments. Restructure into subcommands while keeping the existing invocation working unchanged (build scripts in the wild must not break):

```swift
@main
struct Shark: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "...",
        subcommands: [Generate.self, Lint.self, Translate.self],
        defaultSubcommand: Generate.self
    )
}
```

- `Generate` receives the current `run()` body and `@OptionGroup var options: Options` verbatim. Because it is the `defaultSubcommand`, `shark PROJECT OUTPUT [options]` keeps working exactly as before.
- New files: `Sources/Shark/CLI/GenerateCommand.swift`, `LintCommand.swift`, `TranslateCommand.swift` (one file per command).
- `Options` stays as-is for `generate`; `lint`/`translate` get their own smaller option groups.

**Library/executable split.** As part of M1, `Package.swift` is restructured into a `SharkKit` library target (all logic: codegen, localization model, lint rules, translate engine) plus a thin `Shark` executable target (ArgumentParser commands only). Rationale: the planned SPM Build Tool Plugin (backlog, issue #46) needs a library boundary anyway, and it keeps the door open for a future GUI (`import SharkKit`) without committing to one now. Decision: the product stays CLI-only — `shark lint` as a CI gate and translate-after-merge automation require it, and the `needs_review` workflow deliberately delegates review UI to Xcode's String Catalog editor instead of rebuilding it.

## 2. Shared localization model (`Sources/SharkKit/Localization/`)

`LocalizationEnumBuilder` currently parses *one* locale and discards everything else. `lint`/`translate` need the full multi-locale picture. Extract a reusable reader/writer layer — the enum builder keeps its own parsing for now (no risky refactor); the new layer is additive:

```
Sources/SharkKit/Localization/
    LocalizationTable.swift        // model: [Key: [Locale: Entry]], entry state, source language
    StringsFileReader.swift        // .lproj/*.strings via NSDictionary (reuse existing approach)
    StringCatalogReader.swift      // .xcstrings via existing StringCatalogModels (extended: read ALL locales + state)
    StringCatalogWriter.swift      // write .xcstrings back
    StringsFileWriter.swift        // append missing keys to .strings files
    FormatSpecifier.swift          // extracted/shared specifier parser (%@, %d, %1$@ …)
```

Key points:

- `StringCatalogModels` already decodes `localizations` per language and `state` — extend it to be `Codable` (encode side) so the writer round-trips.
- **Writer fidelity:** Xcode serializes `.xcstrings` with a specific JSON style (`"key" : value` spacing, sorted keys, 2-space indent). The writer must match it, otherwise every translate run produces a full-file diff. `JSONEncoder` can't do `" : "` spacing → implement a small custom serializer (the format is simple and stable). Verify by round-tripping a real Xcode-written catalog byte-identically.
- **`.strings` writing:** append-only at end of file, grouped under a `/* Added by shark translate — review before release */` comment block. Never reorder or reformat existing content.
- `FormatSpecifier` parsing is extracted from `LocalizationValue.InterpolationType` so codegen, lint, and translate share one implementation.

## 3. `shark lint`

```
shark lint PROJECT_FILE_PATH [--target T] [--source-locale en] [--format text|json|github] [--strict]
```

- Resource discovery reuses `XcodeProjectHelper` (collect *all* `.lproj` variants and `.xcstrings`, not just the `--locale` one).
- Checks (each a small, separately testable rule):
  1. **Missing key** — key exists in source locale, absent (or empty / state ≠ translated) in another locale.
  2. **Orphaned key** — key exists in a non-source locale only.
  3. **Placeholder mismatch** — format specifiers differ between source and translation (count, type, or positional index). This catches real crashes (`String(format:)` with wrong arg types).
- Output: human-readable table (default), `--format json` for tooling, `--format github` emitting `::warning file=…` annotations for Actions.
- Exit codes: `0` clean, `1` findings (so CI can gate), `2` usage/parse errors. `--strict` also fails on orphaned keys.
- Prerequisite touched here: the discovery path must `throw` instead of `exit()` (Backlog item 2 partially lands as a side effect — only the code paths lint needs).

## 4. `shark translate`

```
shark translate PROJECT_FILE_PATH --to de,fr [--source-locale en]
                [--glossary Glossary.md] [--context AppContext.md]
                [--backend claude-code|api|codex|auto]
                [--model MODEL] [--batch-size 30] [--dry-run] [--yes]
```

### Flow

1. Run the lint gap analysis → list of `(key, sourceValue, targetLocale)` to translate. Only **missing/empty** entries are candidates; existing translations are never overwritten (no `--force` in v1 — keep the tool incapable of destroying human work).
2. `--dry-run`: print the candidate list + token/cost estimate and exit.
3. Without `--yes`: show summary (N keys → M locales, estimated cost) and ask for confirmation.
4. Chunk into batches, call the selected backend per batch (per target locale), validate, write back.

### Backend selection

`shark translate` now supports three model backends behind the shared `CompletionProviding` protocol:

- **`claude-code`** (default): local Claude Code binary, invoked as `claude -p --output-format json --json-schema ...`; no API key required, billed through the user's Claude subscription.
- **`api`**: direct Anthropic Messages API via `ANTHROPIC_API_KEY`; best fit for CI because it has explicit retries, prompt caching, structured output, and no dependency on a locally installed agent binary.
- **`codex`**: local Codex CLI binary, invoked as `codex exec --output-schema ... --output-last-message ...`; no additional Swift API client.
- **`auto`**: resolve in order `api` (when `ANTHROPIC_API_KEY` is set), `claude-code`, then `codex`.

Claude backends default to `claude-opus-4-8`; `codex` uses the user's Codex CLI default unless `--model` is provided.

### API integration (`Sources/SharkKit/Translate/ClaudeClient.swift`)

No Swift SDK exists → thin `URLSession` client against `POST https://api.anthropic.com/v1/messages`. Async/await, `Codable` request/response types, ~150 lines. No new SPM dependency.

- Auth: `ANTHROPIC_API_KEY` env var (header `x-api-key`), `anthropic-version: 2023-06-01`.
- Model: default `claude-opus-4-8`, overridable via `--model`.
- `thinking: {"type": "adaptive"}`, `max_tokens: 16000` per batch request.
- Retries: respect `retry-after` on 429; exponential backoff on 5xx/529 (max 3 attempts).

### Prompt design (API caching-aware)

The direct API backend caches by **prefix match** — stable content first, volatile last:

```
system[0]: role instructions (fixed text: professional iOS localizer; rules:
           preserve format specifiers exactly incl. positional %1$@; keep length
           similar; respect platform conventions; typographic quotes per locale)
system[1]: app context (--context file) + glossary (--glossary file)
           ← cache_control: {"type": "ephemeral"} on this block
user:      JSON array of the batch: [{ "key": …, "source": … }] + target locale
```

- On the API backend, one cache write on the first batch and cache reads on every subsequent batch of the run mean the (potentially large) glossary/context is paid for ~once.
- Note: Opus only caches prefixes ≥ 4096 tokens — with a small glossary the marker is simply a no-op, no harm.
- **Keys are context!** The naming convention `ViewName_ELEMENT_DESCRIPTION` carries UI placement information ("BUTTON" → keep it short) — the system prompt instructs the model to use the key as context.

### Structured output

Every backend gets the same response schema:

- `api` uses Messages API `output_config.format`.
- `claude-code` passes the schema through `--json-schema`.
- `codex` writes the schema to a temp file and passes it through `--output-schema`, reading the final answer from `--output-last-message`.

The schema shape:

```json
{ "type": "json_schema", "schema": {
    "type": "object",
    "properties": { "translations": { "type": "array", "items": {
        "type": "object",
        "properties": { "key": {"type": "string"}, "value": {"type": "string"} },
        "required": ["key", "value"], "additionalProperties": false } } },
    "required": ["translations"], "additionalProperties": false } }
```

### Validation (the moat — what generic translation tools can't do)

Per translated value, machine-checked before anything is written:

1. Format specifiers in translation == specifiers in source (multiset + positional indices, via shared `FormatSpecifier`).
2. Key returned == key requested; no missing/extra keys in the batch response.
3. Non-empty, no leaked prompt artifacts (value starting with `{` or containing `"key"` heuristics).

Failures → single retry of just the failed keys with the validation error in the prompt; still failing → reported as skipped, exit code reflects partial success.

### Write-back & review workflow

- `.xcstrings`: write value with `"state": "needs_review"` — **never** `"translated"`. Xcode then surfaces them in its review UI; the human stays in the loop.
- `.strings`: append under the marker comment (no state field exists in that format).
- Per-locale summary at the end: translated / skipped / failed.

### Batching & concurrency

- `--batch-size 30` keys per request (bounded output size, granular retry).
- Up to 3 batches concurrently via `TaskGroup` — but the **first** request runs alone and the rest start only after it completes, so API runs can read the cache the first one wrote.
- v2 idea (not now): `--async` using the Message Batches API (50 % cost) for very large catalogs.

## 5. Testing

- `FormatSpecifier`: exhaustive unit tests (`%@`, `%d`, `%1$@ %2$d`, `%%`, `%.2f`).
- Readers/writers: round-trip fixtures, incl. byte-identical re-serialization of an Xcode-written `.xcstrings`.
- Lint rules: small fixture catalogs per rule.
- `ClaudeClient`: `URLProtocol` mock — request shape (headers, schema, cache_control placement) and response handling (success, 429 + retry-after, malformed) without network.
- `ClaudeCodeBackend`: CLI argument construction, structured-output schema flag, JSON envelope parsing, code-fence stripping.
- `CodexBackend`: CLI argument construction, structured-output schema file, final-message parsing, code-fence stripping.
- Translate validation: crafted "bad model responses" (dropped specifier, extra key, empty value) must be rejected.
- Synthetic smoke fixtures: `Scripts/smoke-fixtures.sh` runs committed `.xcodeproj` fixtures for generate/lint and `translate --dry-run`. Real-world projects stay opt-in through `Scripts/smoke-real-world.sh`; reduce any discovered breakage to a committed fixture.

## 6. Milestones

| # | Deliverable | Depends on |
|---|---|---|
| M1 | CLI subcommand restructure + `SharkKit`/`Shark` target split, `shark …` backward compatible | — |
| M2 | Localization model: readers, writers, `FormatSpecifier` extraction | M1 |
| M3 | `shark lint` with all three rules + CI output formats | M2 |
| M4 | `shark translate` core: gap analysis → API → validate → write-back | M3 |
| M5 | Polish: retries, concurrency+cache ordering, dry-run cost estimate, README | M4 |

Each milestone is a separate PR-sized chunk with green tests before the next starts.

## 7. Resolved decisions

1. **Glossary format** — plain Markdown, handed verbatim to the model. Structured per-term format deferred until a real need shows up.
2. **Plurals** — out of scope for translate v1 (depends on backlog item "plural generation"); lint counts and reports the plural entries it skips.
3. **Cost guardrail** — confirmation prompt with token/cost estimate is sufficient; no `--max-cost` flag in v1.
4. **Naming** — `shark translate`.
5. **Form factor** — CLI only. Logic lives in a `SharkKit` library target so a GUI or the SPM build plugin can reuse it later, but no macOS app is planned: CI gating and automation require the CLI, and translation review is deliberately delegated to Xcode's String Catalog editor via `needs_review`.
