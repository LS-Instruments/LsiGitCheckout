# Draft Posts for Reddit and Hacker News

These are starting points for you to edit. Adjust tone, add personal anecdotes, remove what doesn't fit.

---

## r/PowerShell

**Title:** I built RepoHerd — a PowerShell tool for managing multi-repo Git dependencies with SemVer resolution

**Body:**

At work we manage a handful of shared libraries across multiple Git repositories. We used to manually check out the right tags before each build, which was error-prone and tedious — especially when repos had their own nested dependencies.

I built RepoHerd to solve this. You define your dependencies in a JSON file with version constraints, and it clones/checks out everything to the right versions automatically.

What it does:

- **SemVer version resolution** with floating versions (`2.1.*`, `3.*`) — picks the latest compatible tag
- **Recursive dependency discovery** — walks nested `dependencies.json` files across repos, detects conflicts
- **Cross-platform SSH** — PuTTY/Pageant on Windows, OpenSSH on macOS/Linux, configured per-host via a credentials file
- **Structured JSON output** for CI/CD integration (`-OutputFile result.json`)
- **Post-checkout scripts** — run PowerShell scripts after successful checkouts
- **Dry run mode** — preview everything before executing

It's written in PowerShell 7.6 LTS, BSD-3-Clause licensed, and has 65 unit + 18 integration tests.

GitHub: https://github.com/LS-Instruments/RepoHerd

Happy to answer questions or hear feedback.

---

## r/devops

**Title:** RepoHerd — open-source alternative to git submodules for multi-repo dependency management (PowerShell, cross-platform)

**Body:**

We hit the limits of git submodules managing shared libraries across ~10 repositories. Detached HEAD pain, no version resolution, submodule-of-submodule nightmares. Monorepo wasn't an option for us.

So I built RepoHerd — a PowerShell-based tool that reads a JSON config and clones/checks out repos to pinned versions with proper dependency resolution.

Why it might be useful:

- **SemVer-aware**: define version constraints like `"2.1.*"` and it picks the latest compatible tag from the remote
- **Recursive**: repos can have their own `dependencies.json` — RepoHerd walks the tree, detects version conflicts across the graph
- **CI/CD friendly**: `-OutputFile result.json` gives structured JSON with per-repo status, dependency chains, errors. `-DryRun` for previewing
- **Cross-platform SSH**: PuTTY on Windows, OpenSSH on macOS/Linux — credentials in a separate file, not baked into the config
- **Post-checkout hooks**: run scripts after checkout for additional build steps

It's not trying to replace a full build system — it just handles the "get these repos at these versions" step reliably.

PowerShell 7.6 LTS, BSD-3-Clause, 83 automated tests.

GitHub: https://github.com/LS-Instruments/RepoHerd

---

## Show HN

**Title:** Show HN: RepoHerd – Multi-repo Git dependency manager with SemVer resolution

**Body (HN text field):**

RepoHerd is a cross-platform PowerShell tool that clones and checks out multiple Git repositories to pinned versions from a single JSON config.

It solves the problem of managing shared libraries across multiple repos without git submodules. You define version constraints (exact or floating like "2.1.*"), and it resolves the dependency graph recursively, detecting conflicts.

Features: SemVer floating versions, recursive dependency discovery, cross-platform SSH (PuTTY on Windows, OpenSSH on macOS/Linux), structured JSON output for CI/CD, post-checkout scripts.

PowerShell 7.6 LTS, BSD-3-Clause. 65 unit tests + 18 integration tests.

https://github.com/LS-Instruments/RepoHerd
