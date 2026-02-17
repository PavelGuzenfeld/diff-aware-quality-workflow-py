# Standards Enforcement Roadmap

## Current State

Reusable workflows provide diff-aware quality gates on every PR:

| Tool | Purpose | Mode |
|------|---------|------|
| clang-format | Code formatting | Opt-in, blocking |
| clang-tidy | CERT + Core Guidelines + bugprone | Blocking (diff-aware) |
| cppcheck | Value-flow + CWE analysis | Blocking (diff-aware) |
| Flawfinder | CWE lexical scan | Blocking (threshold=0) |
| Semgrep | Python taint/OWASP | Blocking |
| pip-audit | Python CVE scanning | Blocking |

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

All narrowing numeric conversions must use `safe_cast<T>()` from `rocx_utils` instead of `static_cast` or implicit conversions. `safe_cast` validates the value fits in the target type at runtime.

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
| Trend dashboard | Planned | - |
