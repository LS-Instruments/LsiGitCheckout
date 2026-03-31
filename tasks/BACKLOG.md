# RepoHerd — Backlog

Planned features, enhancements, and bugs. When entered on GitHub, the issue number is noted.

---

### #18 — Extend integration tests with additional JSON output assertions

Extend integration tests to assert additional fields from the JSON output:

- **Checkout path** — verify `$repo.path` matches expected relative paths (e.g., `test-root-a`, `libs/TestA`)
- **Post-checkout script path** — verify `$pcs.scriptPath` matches expected script location for configs that define scripts
- **Post-checkout script configured** — verify per-repo `$repo.postCheckoutScript.configured` is `$true` for repos that declare scripts
- **requestedBy chain** — verify the parent chain (e.g., TestA is requested by RootA, not RootB)
- **selectedVersion** — verify the parsed SemVer version string (e.g., `3.0.0`) not just the tag
