# Agent Instructions

Instructions for AI agents contributing to this repository.

## Overview

This repo provides reusable GitHub Actions workflows for diff-aware C++ and Python quality gates. Only changed files are checked — legacy code never blocks PRs.

## Project Structure

```
.github/workflows/
  cpp-quality.yml           Reusable C++ quality workflow (52 inputs, 13+ opt-in checks)
  infra-lint.yml            Reusable infrastructure lint workflow (ShellCheck, Hadolint, cmake-lint)
  python-quality.yml        Reusable Python quality workflow (ruff/flake8, pytest, diff-cover)
  sast-python.yml           Reusable Python SAST workflow (Semgrep, pip-audit, CodeQL)
  sbom.yml                  Reusable SBOM & supply chain workflow (Syft, Grype, license check)
  version-check.yml         Reusable version validation workflow (SemVer in package.xml, CMakeLists.txt, pyproject.toml)
  self-test.yml             Dogfood: runs python-quality on this repo's demo code
  gatekeeper-checks.yml     Push checks for this repo (multi-version Python)
  pull-request-feedback.yml PR feedback for this repo
scripts/
  diff-clang-tidy.sh        Diff-aware clang-tidy runner
  diff-cppcheck.sh          Diff-aware cppcheck runner
  diff-clang-format.sh      Diff-aware clang-format runner
  diff-file-naming.sh       Diff-aware snake_case naming check
  diff-iwyu.sh              Diff-aware Include-What-You-Use runner
  generate-workflow.sh       Generate workflow YAML files for consuming repos
  generate-agents-md.sh      Generate tailored AGENTS.md for consuming repos
  generate-baseline.sh       Generate suppression/baseline files
  generate-badges.sh         Generate README badge markdown
  install-hooks.sh           Install git pre-commit hooks
  check-repo-structure.sh    Validate repo directory structure
  filter-excludes.sh         Filter file lists against exclusion patterns
configs/                    Drop-in configs, CI templates, and agent instructions (15 files)
tests/
  test_patterns.sh          Pattern validation tests (109 tests, bash)
  test_calculator.py        Python demo tests (pytest)
docs/
  SDLC.md                   Full software development lifecycle document
  INTEGRATION.md            Step-by-step integration guide
  VERSIONING.md             SemVer policy and bump rules
  ROADMAP.md                Conventions, coding standards, and planned features
src/calculator.py           Python demo module
```

## Running Tests

```bash
# Pattern validation tests (bash, no dependencies)
bash tests/test_patterns.sh

# Python demo tests
pytest tests/test_calculator.py

# Self-test workflow runs python-quality.yml on the demo code (CI only)
```

`test_patterns.sh` is the primary test suite. It validates grep/regex patterns used by the workflow jobs and scripts. All 109 tests must pass.

## Adding a New Check

Follow this pattern (every existing check follows it):

1. **Workflow job** — Add a job in `cpp-quality.yml` or `python-quality.yml` with an `enable_*` or `ban_*` input (default `false` for opt-in checks)
2. **Script** (if needed) — Add `scripts/diff-<name>.sh` for the diff-aware logic
3. **Config** (if needed) — Add a template config in `configs/`
4. **Tests** — Add a numbered section in `tests/test_patterns.sh`
5. **Docs** — Update README.md (Workflow Inputs table, Configs table), INTEGRATION.md (setup steps), and SDLC.md (lifecycle phases)

### Workflow Job Conventions

- Jobs that are always-on: `clang-tidy`, `cppcheck`, diff-aware linting
- Opt-in jobs: gated by a boolean input defaulting to `false`
- Every job ends with `>> $GITHUB_STEP_SUMMARY` for the summary and posts annotations via `::warning file=...`
- The `summary` job collects all results and posts/updates a single PR comment

### Script Conventions

Two script families:

**`diff-*` scripts** — diff-aware analysis:
- Take `base_ref` as the first argument (e.g., `origin/main`)
- Changed files detected with: `git diff --name-only --diff-filter=ACMR "$base_ref"...HEAD`
- Exit 0 for clean, exit 1 for violations
- Test files are excluded from banned-pattern checks

**`generate-*` scripts** — setup generators:
- Generate scaffolding files for consuming repos (workflows, configs, baselines, badges)
- Idempotent — safe to re-run
- Write output to stdout or to files in the current directory

**Utilities** — `check-repo-structure.sh` validates directory layout, `filter-excludes.sh` filters file lists against exclusion patterns.

## Test Conventions

Tests in `test_patterns.sh` follow this structure:

```bash
# ── Section N: Description ──────────────────────────────────────
pass=0 fail=0

assert_match   "pattern" "input that should match"    "test description"
assert_nomatch "pattern" "input that should not match" "test description"

section_summary "Section Name"
```

- Sections are numbered sequentially (1, 2, 3...)
- `assert_match` / `assert_nomatch` are defined at the top of the file
- Each section has its own `pass`/`fail` counters and calls `section_summary`
- The file ends with a total summary and `exit $exit_code`
- E2E tests (end-to-end) create temporary git repos and run actual scripts

When adding tests: add a new numbered section, don't modify existing sections.

## Documentation Sync

These documents must stay consistent:

| Document | Scope |
|----------|-------|
| `README.md` | Workflow inputs, configs table, scripts table, project structure, quick-start examples |
| `docs/INTEGRATION.md` | Step-by-step setup instructions, generator scripts, troubleshooting |
| `docs/SDLC.md` | Lifecycle phases (pre-commit, PR gate, SAST, hardening) |
| `docs/ROADMAP.md` | Timeline of features, coding conventions |
| `configs/AGENTS.md` | Template for consuming repos — local verification commands, setup scripts |

When adding a check: update all relevant docs. When adding a script: add to README scripts table, AGENTS.md project structure, and any relevant docs.

## Don't

- Don't change workflow input defaults from `false` to `true` — opt-in checks must stay opt-in
- Don't add Python dependencies to the C++ workflow — it runs inside the caller's Docker image
- Don't break backward compatibility on workflow inputs — existing callers must not break
- Don't use `actions/checkout` inside reusable workflows — the caller handles checkout
- Don't modify existing test sections in `test_patterns.sh` — add new sections instead
- Don't hardcode paths — use workflow inputs for all paths
