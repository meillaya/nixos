# Focused machine-readiness fixtures

This directory contains only the G012 partial integrations for Tasks 7, 15,
17, 22, and 23. The runner is fixture-only: it does not support external status
claims and records zero protected actions.

Run all cases for one task and mode:

```bash
tests/readiness/run-task.sh 15 fixture
tests/readiness/run-task.sh 15 negative
```

Pass a case ID as the third argument to run one selector. Task 23 covers only
portable journal behavior. External evidence gates are absent; Darwin-native
status is **NOT VERIFIED**.
