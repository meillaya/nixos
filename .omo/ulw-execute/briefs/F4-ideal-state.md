# F4 — Ideal-state fidelity (final verification wave)

You check the delivered system against the plan's IS-1..IS-7 rows
(`/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`, section "Success criteria" and "Scope /
Affected user and ideal state"). Read the plan fully; you do not fix anything.

## Method
- Read-only in `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (identical tree to landed main) + the evidence dir
  `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/` + the ledger
  `/home/mei/nixos/.omo/ulw-execute/ledger.jsonl`.
- For EACH of IS-1..IS-7 and GAP-1..GAP-7 rows: state the claimed behavior, then find the
  code + the QA evidence that proves it (name the file and the command), and — for at least
  the four most load-bearing rows (IS-1 password on BOTH entry points; IS-2 artifacts/identity
  persist; IS-3 identity survives; IS-4 inert-by-default) — re-run the decisive command
  yourself in the worktree copy.
- A row with no delivering todo, no QA evidence, or evidence that does not cover the row is a
  SHORTFALL: report it exactly as the plan says ("a shortfall becomes new `- [ ] N.` todos,
  never a note").

## Output
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F4-ideal-state.md`: one table
(IS row -> shipped behavior -> proving artifact -> your verdict PASS/SHORTFALL) and the same
for GAP rows. End your message with:
`F4Report: {"verdict": "APPROVE|REJECT", "rows": {"IS-1": "PASS|SHORTFALL", ...}, "shortfalls": ["..."]}`
