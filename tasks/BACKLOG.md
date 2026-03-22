# LsiGitCheckout — Backlog

Planned features, enhancements, and bugs. When entered on GitHub, the issue number is noted.

---

### #18 — Extend integration tests with additional JSON output assertions

Extend integration tests to assert additional fields from the JSON output:

- **Checkout path** — verify `$repo.path` matches expected relative paths (e.g., `test-root-a`, `libs/TestA`)
- **Post-checkout script path** — verify `$pcs.scriptPath` matches expected script location for configs that define scripts
- **Post-checkout script configured** — verify per-repo `$repo.postCheckoutScript.configured` is `$true` for repos that declare scripts
- **requestedBy chain** — verify the parent chain (e.g., TestA is requested by RootA, not RootB)
- **selectedVersion** — verify the parsed SemVer version string (e.g., `3.0.0`) not just the tag

---

### #19 — Split README.md into smaller documentation files

The large README.md (~600 lines) may prevent Google from indexing the GitHub repo page. Split detailed sections into separate files under `docs/`, keeping only overview content in README.md.

**Keep in README.md**: Features list, Supported Platforms table, Platform Setup, Quick Start, Basic/Advanced Usage

**Move to docs/**: SemVer Mode (detailed), Agnostic Mode (detailed), SSH Setup Windows, SSH Setup macOS/Linux, Post-Checkout Scripts, Advanced Topics, Troubleshooting

README links to each doc file. This reduces the rendered page size and improves Google crawlability.
