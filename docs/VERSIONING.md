# Versioning Rules

All projects consuming this standard **must** follow Semantic Versioning (SemVer) with the rules below.

---

## Initial Version

Every new project, package, library, or component starts at **`0.0.1`**.

- `0.0.1` — not `1.0.0`, not `0.1.0`, not `0.0.0`
- This applies to: ROS2 packages (`package.xml`), CMake projects (`project(... VERSION ...)`), Python packages (`pyproject.toml`), Docker images, Helm charts, and any other versionable artifact

---

## Version Format

```
MAJOR.MINOR.PATCH[-PRERELEASE]
```

| Segment | Meaning | When to bump |
|---------|---------|-------------|
| **MAJOR** | Breaking changes | Public API removed/changed, protocol incompatibility, data format break |
| **MINOR** | New features | New API added, new capability, backward-compatible behavior change |
| **PATCH** | Bug fixes | Bug fix, performance improvement, internal refactor, documentation |

### Pre-release Tags

Optional pre-release suffix for work-in-progress:

| Tag | Use |
|-----|-----|
| `-alpha.N` | Early development, API may change freely |
| `-beta.N` | Feature-complete, API stable but may have bugs |
| `-rc.N` | Release candidate, no known issues |

Example: `1.2.0-beta.3`

---

## `0.x.y` — Development Phase

While `MAJOR` is `0`, the project is in initial development:

- `0.MINOR.PATCH` — MINOR bumps may include breaking changes
- No stability guarantee on public API
- Acceptable for internal/unreleased projects

**Promotion to `1.0.0`** requires:
1. Public API is defined and documented
2. All CI quality gates pass
3. Explicit decision by project owner

---

## Bump Rules

### What triggers each bump

**PATCH bump (`x.y.Z`):**
- Bug fix
- Performance optimization (no API change)
- Internal refactoring
- Dependency update (non-breaking)
- Documentation fix
- Test addition/fix

**MINOR bump (`x.Y.0`):**
- New public function, class, or endpoint
- New optional parameter with default value
- New ROS2 topic/service/action
- New CLI flag or config option
- Deprecation of existing API (still functional)

**MAJOR bump (`X.0.0`):**
- Removed or renamed public function/class/endpoint
- Changed function signature (parameter type, order, or count)
- Changed ROS2 message/service definition
- Changed wire protocol or serialization format
- Changed config file format (existing configs stop working)
- Removed deprecated API
- Minimum dependency version raised (e.g., ROS2 Humble -> Jazzy)

### Gray areas

| Change | Bump |
|--------|------|
| Fixing a bug that people depend on (Hyrum's Law) | PATCH — bugs are not API |
| Adding a required field to a config file | MAJOR — existing configs break |
| Changing default parameter value | MINOR — behavior changes but signature doesn't |
| Renaming internal (non-public) functions | PATCH — no public API impact |
| Adding a new dependency | MINOR if optional, MAJOR if it requires consumer changes |

---

## Where to Set Versions

| Artifact | Location | Example |
|----------|----------|---------|
| CMake project | `project(my_lib VERSION 0.0.1)` | `CMakeLists.txt` |
| ROS2 package | `<version>0.0.1</version>` | `package.xml` |
| Python package | `version = "0.0.1"` | `pyproject.toml` |
| Docker image | Tag: `ghcr.io/org/image:0.0.1` | CI/CD pipeline |
| Git tag | `git tag v0.0.1` | Release workflow |

---

## Git Tags

- Tags use the `v` prefix: `v0.0.1`, `v1.2.3`
- Every release **must** have a corresponding git tag
- Tags are immutable — never delete or move a published tag
- Annotated tags preferred: `git tag -a v0.0.1 -m "Initial release"`

---

## Changelog

Every version bump should have a corresponding entry in `CHANGELOG.md` (if the project maintains one) following [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [0.0.2] - 2026-02-19
### Fixed
- Corrected timeout handling in serial port reader
```

Categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.
