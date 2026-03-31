# Test Repositories Reference

This document catalogs all GitHub test repositories used by RepoHerd integration tests, their available tags, and the `dependencies.json` content at each tag.

> **Auto-generated on 2026-03-20** from the LS-Instruments GitHub organization.

## Repository Overview

| Repository | Role | Tags | Has Dependencies |
|------------|------|------|-----------------|
| LsiCheckOutTestRootA | Root (top-level entry point) | v1.0.0, v3.0.0, v3.0.1, v3.0.2 | All tags |
| LsiCheckOutTestRootB | Root (top-level entry point) | v1.0.0–v1.0.5, v1.1.0, v3.0.0, v3.0.2–v3.0.5, v3.1.0 | 5 of 13 tags |
| LsiCheckOutTestA | Intermediate dependency | v1.0.0–v1.0.3, v3.0.0 | All tags |
| LsiCheckOutTestB | Intermediate dependency | v1.0.0–v1.0.3, v3.0.0–v3.0.2 | All tags |
| LsiCheckOutTestC | Leaf dependency (no children) | v1.0.0–v1.0.4, v2.0.0, v3.0.0–v3.0.2, v3.1.0, v4.0.0 | None |

## Dependency Graph

```
RootA ──► TestA ──► TestB ──► TestC
     └──► TestB ──► TestC

RootB ──► TestC
```

TestC is the shared leaf — it appears via multiple paths, making it the convergence point for conflict detection.

---

## LsiCheckOutTestRootA

Root repository. All tags contain `dependencies.json`.

### v1.0.0 — Agnostic mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestA.git",
    "Base Path": "../libs/test-a",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2"]
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestB.git",
    "Base Path": "../libs/test-b",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2"]
  }
]
```

### v3.0.0 — SemVer mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestA.git",
    "Base Path": "../libs/test-a",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestB.git",
    "Base Path": "../libs/test-b",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  }
]
```

### v3.0.1 — SemVer mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestA.git",
    "Base Path": "../libs/test-a",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestB.git",
    "Base Path": "../libs/test-b",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.1"
  }
]
```

### v3.0.2 — SemVer mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestA.git",
    "Base Path": "../libs/test-a",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestB.git",
    "Base Path": "../libs/test-b",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.2"
  }
]
```

---

## LsiCheckOutTestRootB

Root repository. Has `dependencies.json` at 5 of 13 tags. Tags without dependencies: v1.0.2, v1.0.3, v1.0.4, v1.0.5, v3.0.2, v3.0.3, v3.0.4, v3.0.5.

### v1.0.0 — Agnostic mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../libs/test-c",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2"]
  }
]
```

### v1.0.1 — Agnostic mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../libs/test-c",
    "Tag": "v1.0.4",
    "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2", "v1.0.3"]
  }
]
```

### v1.1.0 — Agnostic mode (breaking change)

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../libs/test-c",
    "Tag": "v2.0.0",
    "API Compatible Tags": []
  }
]
```

> **Note:** Empty `API Compatible Tags` means v2.0.0 is the only acceptable version — no backward compatibility.

### v3.0.0 — SemVer mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../libs/test-c",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  }
]
```

### v3.1.0 — SemVer mode (major version jump)

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../libs/test-c",
    "Dependency Resolution": "SemVer",
    "Version": "4.0.0"
  }
]
```

> **Note:** Requests TestC v4.0.0 while RootA's chain requests v3.0.0 — a potential SemVer conflict (different major versions).

---

## LsiCheckOutTestA

Intermediate dependency. All tags contain `dependencies.json`.

### v1.0.0, v1.0.1, v1.0.2, v1.0.3 — Agnostic mode (identical content)

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestB.git",
    "Base Path": "../test-b",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2"]
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../test-c",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2"]
  }
]
```

### v3.0.0 — SemVer mode

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestB.git",
    "Base Path": "../test-b",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  },
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../test-c",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  }
]
```

---

## LsiCheckOutTestB

Intermediate dependency. All tags contain `dependencies.json`.

### v1.0.0, v1.0.1, v1.0.2, v1.0.3 — Agnostic mode (identical content)

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../test-c",
    "Tag": "v1.0.3",
    "API Compatible Tags": ["v1.0.0", "v1.0.1", "v1.0.2"]
  }
]
```

### v3.0.0 — SemVer mode (exact version)

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../test-c",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.0"
  }
]
```

### v3.0.1 — SemVer mode (floating patch)

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../test-c",
    "Dependency Resolution": "SemVer",
    "Version": "3.0.*"
  }
]
```

### v3.0.2 — SemVer mode (floating minor)

```json
[
  {
    "Repository URL": "https://github.com/LS-Instruments/LsiCheckOutTestC.git",
    "Base Path": "../test-c",
    "Dependency Resolution": "SemVer",
    "Version": "3.*"
  }
]
```

---

## LsiCheckOutTestC

Leaf dependency. **No `dependencies.json` at any tag.** This is the terminal node in the dependency tree.

### Available tags

v1.0.0, v1.0.1, v1.0.2, v1.0.3, v1.0.4, v2.0.0, v3.0.0, v3.0.1, v3.0.2, v3.1.0, v4.0.0

---

## Base Path Resolution Notes

The `Base Path` values differ depending on which level of the tree references a repository:

| Referencing repo | Target | Base Path | Resolved from `tests/` |
|-----------------|--------|-----------|----------------------|
| RootA | TestA | `../libs/test-a` | `tests/libs/test-a` |
| RootA | TestB | `../libs/test-b` | `tests/libs/test-b` |
| RootB | TestC | `../libs/test-c` | `tests/libs/test-c` |
| TestA | TestB | `../test-b` | `tests/libs/test-b` |
| TestA | TestC | `../test-c` | `tests/libs/test-c` |
| TestB | TestC | `../test-c` | `tests/libs/test-c` |

All paths for the same repository resolve to the same absolute path — no path conflicts exist in the current test data.
