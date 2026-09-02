# backups/

Encrypted snapshots committed to the repo. Files here are sops/age-encrypted
(both `admin` and `recovery` age keys, matching `secrets/`); they are not
plaintext. Do not add plaintext browsing/personal data here.

| Codename | Contents | Source | Taken |
|----------|----------|--------|-------|
| `tidewater` | Zen Browser `zen-sessions.jsonlz4` (spaces, pinned tabs, open-tab state) | `~/.config/zen/wqidnanv.Default Profile/zen-sessions.jsonlz4` | 2026-09-02 12:14 |

## Restore

```bash
sops --decrypt backups/tidewater.jsonlz4 > ~/.config/zen/wqidnanv.Default\ Profile/zen-sessions.jsonlz4
```

Close Zen before restoring. The live file is written by Zen while running; a
read-copy snapshot is a point-in-time capture.