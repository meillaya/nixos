# tests/readiness/ - fixture-only readiness harness

## OVERVIEW
A portable runner plus per-task adapters for the G012 machine-readiness slices (tasks 7,
15, 17, 22, 23). It executes fixtures and records outcomes; it never touches a real host.

## STRUCTURE
```
readiness/
├── run-task.sh     # the only entry point: run-task.sh <task> <mode> [caseId]
├── runner.py       # canonical-JSON manifest validator + subprocess driver
├── cases/          # case inputs, one directory per case family
├── adapters/       # per-task adapter that runs a case
├── schemas/        # JSON Schemas for manifests and case outputs
├── task7/ task15/ task17/ task22/ task23/
└── README.md       # the authoritative scope statement - read it first
```

## COMMANDS
```bash
tests/readiness/run-task.sh 15 fixture      # all fixture cases for task 15
tests/readiness/run-task.sh 15 negative     # all negative cases for task 15
tests/readiness/run-task.sh 15 fixture <caseId>   # a single selector
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add a case | `cases/` + the task's manifest | manifest must be canonical JSON and ordered |
| Change how a case runs | `adapters/` | adapters are the only process launchers |
| Understand scope | `README.md` | G012 partials only; external evidence gates are absent |

## CONVENTIONS
- The runner validates manifests hard before executing anything: canonical JSON (sorted
  keys, no whitespace, trailing newline), exact key sets, `schemaVersion == 1`, matching
  `task`, cases sorted by `(mode, caseId)`, unique case ids, `timeoutSeconds` in 1..300,
  and `expectedExitClass` derived from `mode` (`fixture` -> exit-0, `negative` -> exit-nonzero).
- A case is a subprocess with its own timeout; the runner records an exit code, a signal,
  or a timeout classification. Nothing is inferred from output text.
- One task per directory: `task7`, `task15`, `task17`, `task22`, `task23`. Most case logic
  sits in `task<N>/` and is driven by the shared `cases/` + `adapters/` machinery.
- `scripts/readiness/task7/` holds the task-7 implementation library; this directory holds
  its fixtures and adapters. Keep that split.
- Run the harness from the repo root; adapters are invoked as `python3 -B` with the repo
  root on `PYTHONPATH`.

## ANTI-PATTERNS
- Do not add external status claims or "protected action" records; the README states the
  runner is fixture-only and records zero protected actions.
- Do not write a manifest by hand without canonicalising it - the runner rejects
  non-canonical JSON before any case runs.
- Do not treat a passing task as machine readiness for a real host. Darwin-native status
  and external evidence are explicitly NOT VERIFIED here; real enrollment lives in
  `scripts/hardware/` and `bin/host-install.sh`.
- Do not add timing-based waits to a case; the runner owns timeouts, cases own behavior.
