# Design spec

## Extracted from

- Source: none (no reference template; lane `no-format`, derived from the destination: a chat answer
  plus the session synthesis markdown).
- Register: clean analyst report; one accent over neutral tones; generous margins; no emoji, no
  clipart.

## Tokens

- Palette: `--ink: #1f2328`, `--muted: #57606a`, `--accent: #0969da`, `--rule: #d0d7de`,
  `--surface: #ffffff`. Pandoc standalone render defaults are also declared: `#1a1a1a`, `#fdfdfd`,
  `#e6e6e6`, `#606060`.
- Lineage: inline

## Typography

- Body: system UI stack (`-apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`).
- Headings: same family, semibold; no display face.
- Mono: `ui-monospace, SFMono-Regular, Menlo, monospace` for commands and paths.

## Layout

- Single column, max width 52rem, 1.6 line height, 2rem section spacing.
- Responsive by default; no fixed-width elements; tables may scroll horizontally on phones.

## Structure

- Title, executive summary, findings by theme, codebase findings, sources (numbered), verified
  claims, instrumentation summary, debate record, contradictions, unresolved/refuted, gaps,
  expansion trace, method.

## Figures

- No figures: this deliverable is a markdown/post synthesis, not a designed document. Any future
  figure follows the standard fixed container + contain-fit + captioned rule.

## Citations

- Inline `[S<n>]` markers resolved in the Sources section; executed verifications cited as `VA<n>`.

## Open questions

- None.
