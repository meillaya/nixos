# Excursion log (one ENTER and one EXIT row per excursion)

| excursion_id | parent claim/axis | ENTER trigger | depth | workers | EXIT rule | changed the top-level answer | ledger mirror |
|---|---|---|---|---|---|---|---|
| X1 | Axis A/C: "the fix is new work" | find contradicted the assumption that no in-repo mechanism existed (trigger 1: contradicts a locked claim) | 1 | lane2 (repo history) + lead probes | ENTER trigger resolved: the mechanism was recovered verbatim | YES: reframed the password work from invention to restore | annotate_ledger: "recovered deleted installer script" |
| X2 | C8: ISO can read the old btrfs disk | the find would change the design if mounting were impossible (trigger 2: changes the answer) | 1 | lane6 + lead evals + secrets-route | two consecutive probes changed nothing (config=m, kmod present, subvols known); budget spent | YES: added `boot.kernelModules` + `supportedFilesystems` to the ISO design | annotate_ledger: "btrfs support gap closed with a one-line ISO fix" |
| X3 | I3: "reuse the sops store" | user steering ("one exists on this laptop") + contrarian evidence (trigger 4 + 1) | 1 | secrets-route + lane14 + lead sweeps | ENTER trigger resolved: reframed to identity preservation | YES: R3 reframed; staging list changed (age identity added) | annotate_ledger: "identity preservation replaces store reuse" |

Anti-drift check after each EXIT: the core question (zero-touch install for antagony) stayed the goal;
all three excursions changed the parent answer, so no drift.
