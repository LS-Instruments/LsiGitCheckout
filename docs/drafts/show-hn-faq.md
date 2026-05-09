# Show HN Quick-Reference FAQ

Keep this open during the engagement window. Anticipated questions and short, honest replies you can adapt on the fly.

## On the tool itself

**Q: Why PowerShell?**
A: It's cross-platform now (PS 7.6 LTS runs on macOS, Linux, Windows), native on Windows, and ships without requiring Python or Node. JSON parsing and HTTPS are built in. For a tool that wraps Git, those primitives were enough.

**Q: Why JSON for config? No comments, verbose, etc.**
A: Fair drawback in general, but for structured nested data (arrays of repo objects with multiple fields), JSON is a natural fit. Native PowerShell support, no external parser dependency. Field names are self-explanatory ("Repository URL", "Version", "Path"). VS Code made the same tradeoff for its settings files.

**Q: Why not git submodules?**
A: No version resolution, detached HEAD friction, and nested submodule fragility at depth. Submodules pin to commit SHAs, not version ranges. RepoHerd does SemVer floating versions and walks the dependency graph with conflict detection.

**Q: Why not [language-specific package manager / monorepo / Bazel]?**
A: Those are great for their use case. RepoHerd targets the gap where you have arbitrary Git repos that aren't language-specific packages and don't fit a monorepo. LabVIEW is the original example, but it applies to any multi-repo setup with shared libraries.

**Q: How is this different from Bender?**
A: Bender is domain-specific for hardware design (ASIC/FPGA). RepoHerd is general-purpose for any Git repos. Both do SemVer-aware resolution, just for different audiences.

**Q: How is this different from Peru / Vdm / gitman?**
A: Those tools require exact pinning (commit hash or tag). RepoHerd resolves SemVer ranges like `2.1.*` against actual Git tags and picks the latest compatible one. Different philosophy: pin-based vs constraint-based.

**Q: What about GPack (the LabVIEW-specific tool)?**
A: GPack solves the same multi-repo Git problem but deliberately avoids version management. The author prefers a "source is source" approach with no formal release process. RepoHerd takes the opposite stance: SemVer constraints give you reproducibility and explicit API contracts.

**Q: Doesn't this require disciplined SemVer tagging upstream?**
A: Yes. If your dependencies don't tag releases with proper SemVer, the SemVer mode won't help. There's also an Agnostic mode for explicit tag-based control without SemVer assumptions.

## On the tech

**Q: Why floating versions over lockfiles?**
A: Both have a place. The exact version you specify in `dependencies.json` (e.g. `"2.1.3"`) acts as a lock. Floating versions (`"2.1.*"`) are for projects that want automatic patch updates. The structured JSON output (`-OutputFile`) records exactly what was checked out for reproducibility / CI logging.

**Q: Performance on large dependency trees?**
A: We use it on trees of 5-20 repos, depth 3-4. Network-bound on `git fetch --tags`, not CPU-bound. Recursion has a configurable max depth.

**Q: How does it handle private repos?**
A: SSH credentials are configured in a separate `git_credentials.json` (not committed). Cross-platform SSH: PuTTY/Pageant on Windows (.ppk), OpenSSH on macOS/Linux.

## On the AI / Claude Code mention

**Q: Vibe-coded means slop, no?**
A: That's a fair concern. Have a look at the test coverage (83 automated tests, unit + integration), the architecture (separation of concerns between dependency resolution, version handling, and Git operations), and the actual problem it solves. The code was AI-assisted but every change was reviewed and tested. The motivation came from a real pain point we'd been living with for years.

**Q: How was the Claude Code experience?**
A: Effective for a project this size and scope. We started with a small script and the breadth of features grew faster than expected. The discipline of writing tests early (and before features in some cases) was important to keep quality up. Documentation also benefited a lot.

**Q: Would you do it again?**
A: Yes, with the same caveat: reviewing every diff and writing tests is non-negotiable.

## On scope and future

**Q: Will you add [feature X]?**
A: Open to suggestions. Issues welcome on the GitHub repo. Design is intentionally minimal — it's a checkout tool, not a build system or CI orchestrator.

**Q: Is this enterprise-ready?**
A: It's used internally at LS Instruments AG for production work. BSD-3-Clause license. No commercial support offered yet.

**Q: How can I contribute?**
A: PRs welcome. Tests must pass (Pester 5.x). See `docs/developer_guide.md` for setup.

## When you don't know

If you don't know the answer, **say so**. "Good question, I haven't tried that" is much better than guessing. HN respects honesty more than fake confidence.

## Tone reminders

- Thank people for feedback, even sharp criticism
- Avoid superlatives ("first", "only", "best")
- Don't get into prolonged arguments — make your point once, then disengage
- If someone surfaces a competitor you didn't know about, acknowledge and learn
- Stay humble: this is a tool for a specific problem, not a revolution
