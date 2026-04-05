# Draft Posts for r/git, r/devops, Show HN, and LabVIEW Discord

These are starting points for you to edit. Adjust tone, add personal anecdotes, remove what doesn't fit.

---

## r/devops

**Title:** RepoHerd: open-source tool for managing multi-repo Git dependencies with SemVer resolution

**Body:**

At my company, our LabVIEW codebase lives in Git and is structured as a multi-level dependency tree: several main projects, each pulling in shared libraries that are themselves reused across different levels and projects.

LabVIEW manages dependencies automatically, but it's extremely sensitive to file paths. If the relative path of a dependency changes, relocating it is a painful manual process. This means the entire dependency tree must be checked out with the exact same folder structure every time, no shortcuts.

As our projects grew, manually checking out the right version of every repository across the tree became practically impossible. We'd routinely waste time hunting down which tag went where, and mistakes meant broken builds or subtle version mismatches.

So we decided to write a small PowerShell script to automate the checkout process. Around the same time, we had started exploring vibe-coding with Claude Code, and this project seemed like the perfect test case: well-scoped, clearly defined, useful regardless of the outcome.

We got a bit carried away. Claude Code was so effective that we kept adding features, and the "small script" grew into something genuinely feature-rich and well-documented. At that point we figured it might be useful beyond our specific setup, so we decided to open-source it.

The tool is called **RepoHerd**. You define your dependencies in a JSON file with SemVer version constraints, and it handles the rest:

- **Floating SemVer versions**: specify `"2.1.*"` or `"3.*"` and it picks the latest compatible tag from the remote
- **Recursive dependency resolution**: repos can have their own `dependencies.json`; RepoHerd walks the full tree and detects version conflicts across the graph
- **Major version conflict detection**: cross-major incompatibilities are always rejected, since different major versions imply breaking APIs

It's cross-platform (PowerShell 7.6 LTS), BSD-3-Clause licensed, and has 83 automated tests.

Give it a look, we'd love to hear if this solves a problem for you too.

GitHub: https://github.com/LS-Instruments/RepoHerd
PowerShell Gallery: `Install-Module RepoHerd`

---

## r/git

**Title:** RepoHerd: an alternative to git submodules for managing multi-repo dependencies with SemVer resolution

**Body:**

At my company we have a codebase spread across multiple Git repos in a multi-level dependency tree. Several main projects pull in shared libraries, and those libraries are reused across different levels and projects.

Our tooling (LabVIEW) requires that every dependency sits at a fixed relative path. If the path changes, it breaks. So checking out the full tree with the right versions at the right locations has to be done correctly every time. We used to do this manually, and as the project grew it became practically impossible to get right.

Git submodules didn't work well for us. The detached HEAD workflow is awkward, nested submodules are fragile, and there's no built-in version resolution. We needed something that could look at version constraints and figure out which tag to check out for each repo.

So we decided to write a small script to automate it. Around the same time, we had started exploring vibe-coding with Claude Code, and this project seemed like the perfect test case: well-scoped, clearly defined, useful regardless of the outcome.

We got a bit carried away. Claude Code was so effective that we kept adding features, and the "small script" grew into something genuinely feature-rich and well-documented. At that point we figured it might be useful beyond our specific setup, so we decided to open-source it.

You define your dependencies in a JSON file with SemVer version constraints, and it handles the rest:

- **Floating SemVer versions**: specify `"2.1.*"` or `"3.*"` and it picks the latest compatible tag from the remote
- **Recursive dependency resolution**: repos can have their own `dependencies.json`; it walks the full tree and detects version conflicts across the graph
- **Major version conflict detection**: cross-major incompatibilities are always rejected, since different major versions imply breaking APIs

It's called **RepoHerd**. Cross-platform, PowerShell 7.6 LTS, BSD-3-Clause, 83 automated tests.

GitHub: https://github.com/LS-Instruments/RepoHerd
PowerShell Gallery: `Install-Module RepoHerd`

Curious if anyone else has run into similar multi-repo pain points and how you solved them.

---

## LabVIEW Discord

Hey everyone, I am new here and I started browsing the hole history of announcements when I saw Derrik Bommarito's post about GPack (https://github.com/illuminated-g/lv-gpack) and honestly had to laugh a bit because we ran into the exact same problem at my company and ended up building our own thing for it, totally independently. Funny how the same pain hits everyone sooner or later.

The issue is always the same for multi-level dependency trees: LabVIEW and relative paths. If something moves, you're stuck relinking for hours. We have a bunch of repos in a dependency tree and at some point checking out the right version of everything manually just wasn't realistic anymore. 

So we started writing a small PowerShell script to automate it. We'd also been playing around with vibe-coding using Claude Code and figured this was a good project to try it on. Well... we got a **bit** carried away. The script kept growing and at some point we looked at it and thought "ok this is actually kind of a proper tool now."

The main difference from GPack is that ours does SemVer version resolution. You put version constraints like `"2.1.*"` in a JSON config and it figures out which tag to check out from the remote. It also walks dependency trees recursively and catches version conflicts.

We called it RepoHerd and open-sourced it. No idea if anyone else needs this but given that Derrik clearly hit the same wall, maybe it's useful to some of you too.

If you want to see how the version resolution works in a bit more detail, I wrote a Medium post about it:
https://medium.com/@andr.vacc/taming-the-multi-repository-beast-intelligent-dependency-management-with-lsigitcheckout-de455e09d2a3

GitHub: https://github.com/LS-Instruments/RepoHerd
Or just install PowerShell 7.6 LTS and type `Install-Module RepoHerd` if you want to try it.

---

## Show HN

**Title:** Show HN: RepoHerd, a multi-repo Git dependency manager with SemVer resolution

**Body (HN text field):**

At my company, our LabVIEW codebase is spread across multiple Git repos in a multi-level dependency tree. LabVIEW requires every dependency to sit at an exact relative path. If it moves, you're in for hours of manual relinking. Checking out the full tree with the right versions had become practically impossible as our projects grew.

We set out to write a small PowerShell script to automate it. We were also exploring vibe-coding with Claude Code at the time and chose this as a test case. It worked so well that we kept going, and the script grew into a proper tool. We decided to open-source it in case others have a similar multi-repo problem.

RepoHerd reads a JSON config with SemVer version constraints (e.g. `"2.1.*"`) and checks out every repo to the right version. It resolves dependencies recursively (repos can declare their own dependencies) and detects version conflicts across the graph.

Cross-platform (PowerShell 7.6 LTS), BSD-3-Clause, 83 automated tests.

https://github.com/LS-Instruments/RepoHerd
