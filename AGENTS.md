# Agent Instructions

Instructions for AI agents contributing to this repository.

## Overview

This repo provides reusable GitHub Actions workflows for diff-aware C++ and Python quality gates. Only changed files are checked — legacy code never blocks PRs.

## Project Structure

```
.github/workflows/
  cpp-quality.yml           Reusable C++ quality workflow (20 inputs, 7 jobs)
  python-quality.yml        Reusable Python quality workflow (8 inputs)
  sast-python.yml           Reusable Python SAST workflow (8 inputs)
  self-test.yml             Dogfood: runs python-quality on this repo's demo code
  gatekeeper-checks.yml     Push checks for this repo (multi-version Python)
  pull-request-feedback.yml PR feedback for this repo
scripts/
  diff-clang-tidy.sh        Diff-aware clang-tidy runner
  diff-clang-format.sh      Diff-aware clang-format runner
  diff-cppcheck.sh          Diff-aware cppcheck runner
  diff-file-naming.sh       Diff-aware snake_case naming check
  check-repo-structure.sh   Validate repo directory structure
configs/                    Drop-in configs and CI templates for consuming projects
tests/
  test_patterns.sh          Pattern validation tests (109 tests, bash)
  test_calculator.py        Python demo tests (pytest)
docs/
  SDLC.md                   Full software development lifecycle document
  INTEGRATION.md            Step-by-step integration guide
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

- Scripts take `base_ref` as the first argument (e.g., `origin/main`)
- Changed files detected with: `git diff --name-only --diff-filter=ACMR "$base_ref"...HEAD`
- Exit 0 for clean, exit 1 for violations
- Test files are excluded from banned-pattern checks

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

These three documents must stay consistent:

| Document | Scope |
|----------|-------|
| `README.md` | Workflow inputs, configs table, project structure, quick-start examples |
| `docs/INTEGRATION.md` | Step-by-step setup instructions, troubleshooting |
| `docs/SDLC.md` | Lifecycle phases (pre-commit, PR gate, SAST, hardening) |

When adding a check: update all three. When adding a config: update README configs table and INTEGRATION copy instructions.

## Don't

- Don't change workflow input defaults from `false` to `true` — opt-in checks must stay opt-in
- Don't add Python dependencies to the C++ workflow — it runs inside the caller's Docker image
- Don't break backward compatibility on workflow inputs — existing callers must not break
- Don't use `actions/checkout` inside reusable workflows — the caller handles checkout
- Don't modify existing test sections in `test_patterns.sh` — add new sections instead
- Don't hardcode paths — use workflow inputs for all paths
