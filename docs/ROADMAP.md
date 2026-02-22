# Standards Enforcement Roadmap

## Current State

Reusable workflows provide diff-aware quality gates on every PR:

**C++ Static Analysis:**

| Tool | Purpose | Mode |
|------|---------|------|
| clang-format | Code formatting | Opt-in, blocking |
| clang-tidy | CERT + Core Guidelines + bugprone | Blocking (diff-aware) |
| cppcheck | Value-flow + CWE analysis | Blocking (diff-aware) |
| Flawfinder | CWE lexical scan | Blocking (threshold=0) |
| IWYU | Include-What-You-Use analysis | Opt-in, report-only |

**C++ Runtime Analysis:**

| Tool | Purpose | Mode |
|------|---------|------|
| ASan/UBSan | Address + undefined behavior sanitizer | Opt-in |
| TSan | Thread sanitizer | Opt-in |
| gcov/lcov | Code coverage + diff-cover | Opt-in |

**Script & Container Linting:**

| Tool | Purpose | Mode |
|------|---------|------|
| ShellCheck | Shell script linting (`.sh`, `.bash`) | Opt-in, report-only |
| Hadolint | Dockerfile linting (`Dockerfile*`) | Opt-in, report-only |

**Python:**

| Tool | Purpose | Mode |
|------|---------|------|
| Semgrep | Python taint/OWASP | Blocking |
| pip-audit | Python CVE scanning | Blocking |

**Supply Chain:**

| Tool | Purpose | Mode |
|------|---------|------|
| Syft | Container SBOM generation (SPDX + CycloneDX) | Opt-in |
| Grype | Vulnerability scanning against CVE databases | Opt-in |
| License check | Dependency license policy validation | Opt-in |

## Coding Conventions & Whitelisted Patterns

These conventions are enforced project-wide. Findings matching these rules should be handled by convention enforcement, not tracked as individual bugs.

### Named Parameters Required

All function parameters **must** be named, even if unused. Use `[[maybe_unused]]` for intentionally unused parameters instead of leaving them unnamed.

```cpp
// Bad — unnamed parameter
void callback(int, const std::string&);

// Good — named + attributed
void callback([[maybe_unused]] int event_id, const std::string& message);
```

**Enforcement:** `readability-named-parameter` in clang-tidy (Phase 2 as error).

### GStreamer Binding Exemptions

Code implementing GStreamer type bindings (element registration, pad templates, signal handlers, type casting macros) is **exempt** from:

- `cppcoreguidelines-pro-type-cstyle-cast` — GStreamer macros (`GST_ELEMENT_CAST`, `GST_PAD_CAST`) expand to C-style casts
- `bugprone-casting-through-void` — GStreamer `G_DEFINE_TYPE` and type-check macros cast through `void*`
- `bugprone-assignment-in-if-condition` — GStreamer `GST_*` macros assign in conditions by design
- `cppcoreguidelines-pro-type-vararg` — GStreamer property/signal APIs use variadic functions

Use `// NOLINT(check-name)` on GStreamer macro lines. Do NOT blanket-suppress these checks globally.

### Replace `fscanf`/`fprintf`/`printf` with `fmt`

All C-style formatted I/O (`fscanf`, `fprintf`, `printf`, `sprintf`) must be replaced with the `fmt` library:

```cpp
// Bad
fprintf(logfile, "%lu\t%lu\t%lu\n", pts, pre, post);

// Good
fmt::print(logfile, "{}\t{}\t{}\n", pts, pre, post);
```

**Dependencies:** `find_package(fmt REQUIRED)` + `target_link_libraries(... fmt::fmt)`

### Use `safe_cast` for Numeric Conversions

All narrowing numeric conversions must use a checked cast utility (e.g., `safe_cast<T>()`) instead of `static_cast` or implicit conversions. The utility should validate the value fits in the target type at runtime.

```cpp
// Bad — silent narrowing
int count = static_cast<int>(container.size());

// Good — checked conversion
int count = safe_cast<int>(container.size());
```

**Enforcement:** `bugprone-narrowing-conversions` in clang-tidy (Phase 2 as error).

---

## PR Gate Keeping

All standards checks run as **required status checks** on pull requests. PRs cannot be merged until all checks pass. This eliminates the need for separate ticket tracking — findings are caught and fixed before they enter the codebase.

### How It Works

```
PR opened/updated
       |
  Standards workflow runs (diff-aware)
       |
  ┌────┴──────────────────────────┐
  │  clang-format    → pass/fail  │
  │  clang-tidy      → pass/fail  │
  │  cppcheck        → pass/fail  │
  │  flawfinder      → pass/fail  │
  └────┬──────────────────────────┘
       |
  All pass? ──── No ──→ PR blocked, author fixes
       |
      Yes
       |
  PR mergeable
```

### Branch Protection Rules

Configure in GitHub repo settings (`Settings > Branches > Branch protection rules`):

- **Require status checks to pass before merging**: enabled
- **Required checks**: `clang-format`, `Clang-Tidy (CERT + Core Guidelines)`, `Cppcheck (CWE)`, `Flawfinder (CWE)`
- **Require branches to be up to date**: enabled (ensures checks run against latest base)

### Suppression Policy

When a finding is a false positive:

| Tool | Suppression Method |
|------|-------------------|
| clang-tidy | `// NOLINTNEXTLINE(check-name)` or `// NOLINT(check-name)` |
| cppcheck | Add to `.cppcheck-suppressions` file |
| flawfinder | `// Flawfinder: ignore` on the same line |
| clang-format | Wrap with `// clang-format off` / `// clang-format on` |

Suppressions are reviewed as part of the PR code review.

## SBOM & Supply Chain Security

Generate a Software Bill of Materials covering both container and source-level dependencies, with vulnerability scanning.

### Architecture

```
PR opened / weekly schedule
       |
  ┌────┴───────────────────────────────┐
  │  Layer 1: Container scan (Syft)    │
  │    → apt packages, pip packages,   │
  │      system libraries              │
  │                                    │
  │  Layer 2: Source scan (custom)     │
  │    → FetchContent (CMake)          │
  │    → .gitmodules (recursive)       │
  │    → package.xml (ROS2)            │
  │    → pyproject.toml / requirements │
  └────┬───────────────────────────────┘
       |
  Merge SBOMs (CycloneDX)
       |
  Grype vulnerability scan
       |
  PR comment + artifacts
```

### Reusable Workflow: `sbom.yml`

10 inputs following existing conventions:

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image to scan |
| `enable_container_scan` | `true` | Syft container image scan |
| `enable_source_scan` | `true` | Source-level dependency scan |
| `enable_grype` | `true` | Grype vulnerability scanning |
| `grype_fail_on` | `critical` | Severity threshold to fail (negligible/low/medium/high/critical) |
| `grype_ignore_file` | `''` | Path to .grype.yaml for CVE suppressions |
| `source_scan_config` | `''` | Path to sbom-config.yml overrides |
| `scan_depth` | `2` | Max depth for recursive .gitmodules scan |
| `python_version` | `3.12` | Python version for source scanner |
| `runner` | `ubuntu-latest` | Runner label |

### Jobs

4 jobs + summary:

1. **container-scan** — Syft scans Docker image, produces SPDX + CycloneDX JSON
2. **source-scan** — Custom Python script parses source manifests, produces CycloneDX JSON
3. **merge-sboms** — Merges container + source SBOMs, deduplicates by (name, version)
4. **vulnerability-scan** — Grype scans merged SBOM, fails on severity threshold
5. **summary** — PR comment with dependency count + vulnerability table

### Source Scanner: `scripts/source-sbom.py`

Python stdlib only (no pip deps). Parses:

| Source | Files | PURL Pattern |
|--------|-------|-------------|
| CMake FetchContent | `**/CMakeLists.txt` | `pkg:github/{owner}/{repo}@{tag}` |
| Git submodules | `**/.gitmodules` | `pkg:github/{owner}/{repo}` |
| ROS2 packages | `**/package.xml` | `pkg:ros/{distro}/{name}` |
| Python deps | `**/pyproject.toml` | `pkg:pypi/{name}@{version}` |
| Python reqs | `**/requirements*.txt` | `pkg:pypi/{name}@{version}` |

### Config Template: `configs/sbom-config.yml`

Optional config for consuming repos:
- `exclude_paths` — glob patterns to skip (build/, install/, .git/)
- `ros_distro` — ROS2 distro name for PURL (default: humble)
- `extra_components` — manually declared deps not discoverable from source (e.g., libs built from source in Docker)

### Consumer Usage

```yaml
jobs:
  sbom:
    uses: PavelGuzenfeld/standard/.github/workflows/sbom.yml@main
    with:
      docker_image: ghcr.io/my-org/my-image:latest
      grype_fail_on: critical
      source_scan_config: sbom-config.yml
    permissions:
      contents: read
      pull-requests: write
      packages: read
```

### Tool Selection

| Tool | Role | Why |
|------|------|-----|
| **Syft** (Anchore) | SBOM generation from containers | Dual SPDX+CycloneDX output, lightweight Go binary, official GitHub Action |
| **Grype** (Anchore) | Vulnerability scanning | Consumes Syft output natively, configurable thresholds, CVE suppressions |
| **source-sbom.py** | Source manifest parsing | No existing tool covers CMake FetchContent + ROS2 package.xml + .gitmodules together |

### Output Formats

- **SPDX JSON** — from Syft container scan (compliance standard)
- **CycloneDX JSON** — merged container + source (used for Grype scanning)
- **Grype report** — JSON + table format (vulnerability findings)

All uploaded as GitHub Actions artifacts.

---

## Planned: Trend Dashboard

- Weekly scheduled workflow aggregates scan results
- Posts trend report to Slack/Jira dashboard
- Tracks: total findings over time, new vs fixed per sprint, findings by package

## Full-Codebase Scan Mode (Local)

Run full scans locally to audit the entire codebase (not just PR diffs):

```bash
# Inside the builder container:
# clang-tidy (all files)
find . -name '*.cpp' | xargs clang-tidy -p build/

# cppcheck (all files)
cppcheck --enable=all --suppressions-list=.cppcheck-suppressions .

# flawfinder (all files)
flawfinder --minlevel=2 --columns --context .
```

Useful for initial onboarding of legacy codebases or periodic audits.

## Timeline

| Feature | Status | Dependency |
|---------|--------|------------|
| Diff-aware C++ quality | Done | - |
| Diff-aware Python quality | Done | - |
| Python SAST (Semgrep, pip-audit) | Done | - |
| Flawfinder integration | Done | - |
| PR gate keeping (required checks) | Done | Branch protection rules |
| Full-codebase scan (local) | Done | Builder container |
| SBOM generation (Syft + source) | Done | Docker image |
| Grype vulnerability scanning | Done | Merged SBOM |
| License policy check | Done | SBOM workflow |
| ShellCheck (shell scripts) | Done | cpp-quality.yml |
| Hadolint (Dockerfiles) | Done | cpp-quality.yml |
| ASan/UBSan sanitizer job | Done | cpp-quality.yml |
| TSan thread sanitizer job | Done | cpp-quality.yml |
| Code coverage (gcov/lcov) | Done | cpp-quality.yml |
| IWYU include analysis | Done | cpp-quality.yml |
| Local IWYU script (diff-iwyu.sh) | Done | cpp-quality.yml |
| Pre-commit hook installer (install-hooks.sh) | Done | - |
| Baseline/suppression generator (generate-baseline.sh) | Done | - |
| Workflow YAML generator (generate-workflow.sh) | Done | - |
| README badge generator (generate-badges.sh) | Done | - |
| AGENTS.md generator (generate-agents-md.sh) | Done | - |
| Trend dashboard | Planned | - |
