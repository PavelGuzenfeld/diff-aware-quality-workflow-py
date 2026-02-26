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
| libFuzzer | Continuous fuzzing with ASan + corpus caching | Template (`ci-fuzz.yml`) |
| Hardening | PIE, RELRO, stack canary, NX, CET verification via readelf | Opt-in |

**Script & Container Linting:**

| Tool | Purpose | Mode |
|------|---------|------|
| ShellCheck | Shell script linting (`.sh`, `.bash`) | Opt-in, report-only |
| Hadolint | Dockerfile linting (`Dockerfile*`) | Opt-in, report-only |
| cmake-lint | CMake file linting (`CMakeLists.txt`, `*.cmake`) | Opt-in, report-only |
| Dangerous-workflow audit | Detects `pull_request_target` misuse and injection patterns | Opt-in |
| Binary-artifact scan | Detects committed binary files (`.exe`, `.dll`, `.so`, etc.) | Opt-in |
| Gitleaks | Secrets detection (API keys, tokens, passwords, private keys) | Opt-in |

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
| SLSA provenance | Build attestation for releases (`actions/attest-build-provenance`) | Opt-in |
| Dependabot | Dependency update monitoring (GitHub Actions, pip, etc.) | Config file |

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

8 inputs following existing conventions:

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image to scan |
| `source_sbom_script` | `''` | Path to source-level SBOM generation script (empty = skip) |
| `grype_fail_on` | `''` | Fail on severity: "" = report-only, "critical", "high", "medium", "low" |
| `grype_ignore_file` | `''` | Path to .grype.yaml ignore file |
| `checkout_submodules` | `false` | Checkout submodules for source SBOM (true/false/recursive) |
| `license_policy_file` | `''` | Path to license policy YAML (empty = skip license check) |
| `license_check_script` | `''` | Path to license check Python script in caller repo |
| `runner` | `ubuntu-latest` | Runner labels as JSON |

### Jobs

4 jobs + summary:

1. **container-sbom** — Syft scans Docker image, produces SPDX + CycloneDX JSON
2. **source-sbom** — Custom script parses source manifests, produces CycloneDX JSON
3. **vuln-scan** — Grype scans SBOM, fails on severity threshold
4. **license-check** — Validates dependency licenses against policy
5. **summary** — PR comment with dependency count + vulnerability table

### Source SBOM

The workflow accepts a `source_sbom_script` input — a path to a caller-provided script that generates a CycloneDX JSON SBOM from source-level manifests (CMake FetchContent, .gitmodules, package.xml, pyproject.toml, etc.). If empty, the source scan step is skipped.

### Consumer Usage

```yaml
jobs:
  sbom:
    uses: PavelGuzenfeld/standard/.github/workflows/sbom.yml@main
    with:
      docker_image: ghcr.io/my-org/my-image:latest
      grype_fail_on: critical
      license_policy_file: .license-policy.yml
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
| **source_sbom_script** | Source manifest parsing | Caller-provided script for project-specific manifests (CMake FetchContent, ROS2 package.xml, .gitmodules, etc.) |

### Output Formats

- **SPDX JSON** — from Syft container scan (compliance standard)
- **CycloneDX JSON** — merged container + source (used for Grype scanning)
- **Grype report** — JSON + table format (vulnerability findings)

All uploaded as GitHub Actions artifacts.

---

## Trend Dashboard

Reusable workflow: [`trend-dashboard.yml`](../.github/workflows/trend-dashboard.yml)

- Weekly scheduled workflow aggregates scan results across all standard workflows
- Queries GitHub Actions API for historical workflow runs and per-job results
- Calculates pass rates per check per week with trend arrows (↑ ↓ →)
- Posts trend report to workflow summary, Slack (opt-in), and/or GitHub Discussions (opt-in)
- Auto-discovers which standard workflows the consumer uses

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
| ShellCheck (shell scripts) | Done | infra-lint.yml |
| Hadolint (Dockerfiles) | Done | infra-lint.yml |
| cmake-lint (CMake files) | Done | infra-lint.yml |
| Dangerous-workflow audit | Done | infra-lint.yml |
| Binary-artifact scan | Done | infra-lint.yml |
| Gitleaks secrets detection | Done | infra-lint.yml |
| SLSA provenance attestation | Done | auto-release.yml |
| SECURITY.md + template | Done | - |
| Dependabot config + template | Done | - |
| ASan/UBSan sanitizer job | Done | cpp-quality.yml |
| TSan thread sanitizer job | Done | cpp-quality.yml |
| Code coverage (gcov/lcov) | Done | cpp-quality.yml |
| IWYU include analysis | Done | cpp-quality.yml |
| libFuzzer CI template | Done | configs/ci-fuzz.yml |
| Local IWYU script (diff-iwyu.sh) | Done | cpp-quality.yml |
| Pre-commit hook installer (install-hooks.sh) | Done | - |
| Baseline/suppression generator (generate-baseline.sh) | Done | - |
| Workflow YAML generator (generate-workflow.sh) | Done | - |
| README badge generator (generate-badges.sh) | Done | - |
| AGENTS.md generator (generate-agents-md.sh) | Done | - |
| Binary hardening verification | Done | cpp-quality.yml |
| Trend dashboard | Done | trend-dashboard.yml |
| `standard-ci` CLI tool (v0.13.2) | Done | pip install |
| Starter workflow templates | Done | PavelGuzenfeld/.github |
| Composite actions (7 actions) | Done | actions/ directory |

---

## Packaging & Enforcement Roadmap

### Phase 1: `standard-ci` CLI (v0.13.2) — Done

Python CLI (`pip install`) that replaces `generate-workflow.sh` with a proper tool:

```
standard-ci init [--preset minimal|recommended|full] [--non-interactive] [--pin TAG]
standard-ci update [--dry-run]
standard-ci check
```

- **Zero dependencies** — pure Python, works on >= 3.8
- **SHA pinning** — resolves latest git tag to full SHA, emits `@<sha> # v2.2.3.4` in workflow refs
- **Presets** — `minimal` (clang-tidy + cppcheck + ruff), `recommended` (+formatting, naming, secrets), `full` (everything)
- **Auto-detection** — scans for CMakeLists.txt, package.xml, pyproject.toml to pick workflows
- **`.standard.yml` config** — records chosen preset, SHA, and per-workflow overrides for `update` and `check`
- **4 workflows for MVP** — cpp-quality, python-quality, infra-lint, sast-python

### Phase 2: Starter Workflows — Done

[Starter workflows](https://docs.github.com/en/actions/using-workflows/creating-starter-workflows) in [`PavelGuzenfeld/.github`](https://github.com/PavelGuzenfeld/.github) repo:

- **Standard C++ Quality** — clang-tidy, cppcheck, clang-format, flawfinder + infra-lint
- **Standard Python Quality** — ruff, pytest, Semgrep, pip-audit + infra-lint
- **Standard Full Quality** — C++ + Python combined
- All pinned to SHA, matched by `filePatterns` (CMakeLists.txt, pyproject.toml, etc.)
- Appear in Actions tab → "New workflow" for repos in this account

### Phase 3: Composite Actions — Done

[Composite actions](https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action) under `actions/` for granular step-level reuse:

| Action | Purpose | Docker? |
|--------|---------|---------|
| `actions/diff-files` | Shared diff-aware changed file detection | No |
| `actions/clang-tidy` | C++ static analysis (CERT + Core Guidelines) | Yes |
| `actions/cppcheck` | C++ value-flow + CWE analysis | Yes |
| `actions/clang-format` | C++ formatting check | Yes |
| `actions/ruff-check` | Python linting via diff-quality | No |
| `actions/shellcheck` | Shell script linting | No |
| `actions/gitleaks` | Secrets detection | No |

Usage: `uses: PavelGuzenfeld/standard/actions/clang-tidy@<sha>` as a step in any job.

### Phase 4: Compliance Bot

GitHub App or Actions bot that:

- Scans repos for `.standard.yml` and validates setup matches policy
- Opens PRs to update SHA pins on new releases (like Dependabot for standard)
- Posts org-wide compliance dashboard (which repos pass, which drift)

### Phase 5: Gemini Code Assist Integration

Leverage the `.gemini/` configuration pattern for AI-assisted enforcement:

- `.gemini/settings.json` can reference standard's AGENTS.md for code review context
- Gemini Code Assist applies coding conventions during PR review
- Complements static analysis with AI-powered pattern detection
