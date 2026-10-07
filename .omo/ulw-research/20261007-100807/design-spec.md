# Design spec - zix x machine0 x Railway research report

Template family: clean analyst report. No reference document was supplied; the
lane derived from the request is a plain report for the operator.

Palette tokens:
- ink #111418, ink-soft #3c444d, muted #6b7480
- line #dfe3e8, panel #f7f8fa
- accent #1d4ed8, accent-soft #e8eeff
- ok #157347, warn #9a6700

Fonts:
- body: -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif
- mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace
- report language is English; no CJK webfont is required. No gothic-only stacks.

Responsive breakpoints: figure grid collapses to one column below 640px;
body text stays between 860px max width and full width.

Charts: inline SVG only (no remote assets, no CDN). Every chart carries a
title, axis labels, units and value labels in the report language; bars use
the palette above (neutral for the baseline, accent for the result).

Figure standard: each figure sits in a fixed, bordered container styled from
this spec; the image or SVG fits inside with its aspect ratio preserved, never
stretched, cropped or spilling out; captions are styled from the spec.

Lineage: inline - every unit-bearing number is tagged MEASURED, ASSUMED or
DERIVED, or cited to a source, in the same element that states it.

Emoji: none. Em dashes: none (hyphens only).
