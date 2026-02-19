# Versioning Rules

All projects consuming this standard **must** follow Semantic Versioning (SemVer) with the rules below.

---

## Initial Version

Every new project, package, library, or component starts at **`0.0.1`**.

- `0.0.1` or `0.0.0.1` — not `1.0.0`, not `0.1.0`, not `0.0.0`
- This applies to: ROS2 packages (`package.xml`), CMake projects (`project(... VERSION ...)`), Python packages (`pyproject.toml`), Docker images, Helm charts, and any other versionable artifact

---

## Version Format

```
major.minor.patch[-prerelease]
major.minor.patch.tweak[-prerelease]
```

3 or 4 numeric segments separated by dots. **Everything lowercase.** Version strings contain only digits, dots, hyphens, and lowercase letters.

### Validation Regex

```
^[0-9]+(\.[0-9]+){2,3}(-rc\.[0-9]+)?$
```

For git tags (with `v` prefix):

```
^v[0-9]+(\.[0-9]+){2,3}(-rc\.[0-9]+)?$
```

Valid: `0.0.1`, `0.0.0.1`, `1.2.3`, `1.2.3.4`, `1.0.0-rc.1`, `2.0.0-rc.3`
Invalid: `1.0`, `1.0.0-beta.1`, `1.0.0-RC1`, `1.0.0-alpha.1`

| Segment | Meaning | When to bump |
|---------|---------|-------------|
| **major** | Breaking changes | Public API removed/changed, protocol incompatibility, data format break |
| **minor** | New features | New API added, new capability, backward-compatible behavior change |
| **patch** | Bug fixes | Bug fix, performance improvement, internal refactor, documentation |

### Pre-release Tag

The only pre-release tag is **`-rc.N`** (release candidate):

```
1.2.0-rc.1
0.0.3-rc.2
```

No `alpha`, `beta`, or other pre-release tags. Code is either released or a release candidate.

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

---

## Enforcement

### Git Tag Validation (CI)

A CI job can validate that git tags match the version regex before allowing a release:

```yaml
- name: Validate tag format
  if: startsWith(github.ref, 'refs/tags/v')
  run: |
    TAG="${GITHUB_REF#refs/tags/}"
    if ! echo "$TAG" | grep -qE '^v[0-9]+(\.[0-9]+){2,3}(-rc\.[0-9]+)?$'; then
      echo "::error::Invalid tag format: $TAG (expected: v0.0.1 or v0.0.0.1)"
      exit 1
    fi
```

### Source File Version Check (CI)

Validate version strings in `package.xml`, `CMakeLists.txt`, and `pyproject.toml` on every PR:

```yaml
- name: Validate version strings in source files
  run: |
    VERSION_RE='^[0-9]+(\.[0-9]+){2,3}(-rc\.[0-9]+)?$'
    ERRORS=0

    # package.xml
    for f in $(find . -name 'package.xml' -not -path '*/build/*' -not -path '*/.git/*'); do
      VER=$(grep -oP '(?<=<version>)[^<]+' "$f" || true)
      if [ -n "$VER" ] && ! echo "$VER" | grep -qE "$VERSION_RE"; then
        echo "::error file=$f::Invalid version '$VER' — must match $VERSION_RE"
        ERRORS=$((ERRORS + 1))
      fi
    done

    # CMakeLists.txt project(... VERSION ...)
    for f in $(find . -name 'CMakeLists.txt' -not -path '*/build/*' -not -path '*/.git/*'); do
      VER=$(grep -oP 'project\s*\([^)]*VERSION\s+\K[0-9][^\s)]*' "$f" || true)
      if [ -n "$VER" ] && ! echo "$VER" | grep -qE "$VERSION_RE"; then
        echo "::error file=$f::Invalid version '$VER' — must match $VERSION_RE"
        ERRORS=$((ERRORS + 1))
      fi
    done

    # pyproject.toml
    for f in $(find . -name 'pyproject.toml' -not -path '*/build/*' -not -path '*/.git/*'); do
      VER=$(grep -oP '^version\s*=\s*"\K[^"]+' "$f" || true)
      if [ -n "$VER" ] && ! echo "$VER" | grep -qE "$VERSION_RE"; then
        echo "::error file=$f::Invalid version '$VER' — must match $VERSION_RE"
        ERRORS=$((ERRORS + 1))
      fi
    done

    if [ "$ERRORS" -gt 0 ]; then
      echo "Found $ERRORS invalid version string(s)."
      exit 1
    fi
    echo "All version strings valid."
```

### Future: Reusable Job

These checks will be added as an opt-in job in `cpp-quality.yml` (like `file-naming` or `shellcheck`) so consumers get version validation automatically.
