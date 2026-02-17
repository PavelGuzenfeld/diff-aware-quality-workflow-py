# Standards Enforcement Roadmap

## Current State

Reusable workflows provide diff-aware quality gates on every PR:

| Tool | Purpose | Mode |
|------|---------|------|
| clang-format | Code formatting | Opt-in, blocking |
| clang-tidy | CERT + Core Guidelines + bugprone | Blocking (diff-aware) |
| cppcheck | Value-flow + CWE analysis | Blocking (diff-aware) |
| Flawfinder | CWE lexical scan | Not yet integrated |
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

## Planned: Automatic Ticket Creation from Scan Results

### Goal

CI scans automatically create or update Jira tickets for new findings, so nothing slips through without tracking. This will be a reusable workflow that any consuming project can call.

### Architecture

```
PR opened/updated
       |
  quality workflow runs
       |
  ┌────┴────────────────────┐
  │  clang-tidy, cppcheck,  │
  │  flawfinder, semgrep    │
  │  produce SARIF / XML    │
  └────┬────────────────────┘
       |
  new job: create-tickets
       |
  ┌────┴────────────────────┐
  │  Python script:         │
  │  1. Parse scan results  │
  │  2. Diff against        │
  │     baseline file       │
  │  3. For NEW findings:   │
  │     create Jira ticket  │
  │  4. For FIXED findings: │
  │     close Jira ticket   │
  │  5. Comment on PR with  │
  │     summary             │
  └─────────────────────────┘
```

### Baseline File (`.standards-baseline.json`)

Track known findings so only **new** issues generate tickets:

```json
{
  "version": 1,
  "generated": "2026-02-17T00:00:00Z",
  "clang_tidy": {
    "total_warnings": 0,
    "findings": [
      {
        "check": "cert-err33-c",
        "file": "src/example.cpp",
        "line": 92,
        "hash": "a1b2c3d4"
      }
    ]
  },
  "cppcheck": {
    "total_findings": 0,
    "findings": []
  },
  "flawfinder": {
    "total_findings": 0,
    "findings": [
      {
        "cwe": "CWE-78",
        "file": "src/example.cpp",
        "line": 81,
        "hash": "e5f6g7h8"
      }
    ]
  }
}
```

### Ticket Creation Script

```
Input:  SARIF/XML scan results + baseline file
Output: Jira tickets for new findings, PR comment with summary

Logic:
  1. Parse current scan results into normalized findings list
  2. Load baseline file
  3. Compute diff: new = current - baseline, fixed = baseline - current
  4. For each NEW finding:
     - Create Jira ticket (type=Bug, labels=[sast, auto-generated])
     - Title: "[SAST/{tool}] {check}: {short description} in {file}"
     - Description: full context, CWE mapping, fix suggestion
  5. For each FIXED finding:
     - Find matching open ticket, transition to Done
  6. Post PR comment with summary table
  7. Update baseline file (committed back to branch)
```

### Reusable Workflow Interface

```yaml
# Consumer usage
jobs:
  sast-tickets:
    uses: PavelGuzenfeld/standard/.github/workflows/sast-tickets.yml@main
    with:
      baseline_file: .standards-baseline.json
      jira_project: MYPROJECT
      scan_artifacts: '*-results'
    secrets:
      jira_token: ${{ secrets.JIRA_API_TOKEN }}
      jira_user: ${{ secrets.JIRA_USER }}
      jira_url: ${{ secrets.JIRA_URL }}
```

### Workflow Implementation

```yaml
# .github/workflows/sast-tickets.yml
name: SAST Ticket Creation
on:
  workflow_call:
    inputs:
      baseline_file:
        type: string
        default: '.standards-baseline.json'
      jira_project:
        required: true
        type: string
      scan_artifacts:
        type: string
        default: '*-results'
    secrets:
      jira_token:
        required: true
      jira_user:
        required: true
      jira_url:
        required: true

jobs:
  create-tickets:
    name: Auto-create SAST tickets
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          pattern: ${{ inputs.scan_artifacts }}
      - name: Create/update Jira tickets
        env:
          JIRA_TOKEN: ${{ secrets.jira_token }}
          JIRA_USER: ${{ secrets.jira_user }}
          JIRA_URL: ${{ secrets.jira_url }}
        run: |
          python3 scripts/create_sast_tickets.py \
            --baseline ${{ inputs.baseline_file }} \
            --project ${{ inputs.jira_project }} \
            --pr-number ${{ github.event.pull_request.number }}
```

### Ticket Format

**Title:** `[SAST/{tool}] {check-id}: {short description} in {file}`

**Description:**

```markdown
## SAST Finding

**Tool:** clang-tidy 21
**Check:** cert-err33-c
**Severity:** error (CERT violation)
**File:** `src/example.cpp:92`
**CWE:** CWE-391 (Unchecked Error Condition)

## Context
The value returned by `fclose()` should not be disregarded;
neglecting it may lead to errors.

## Suggested Fix
Check the return value and handle errors appropriately.

## References
- [SEI CERT ERR33-C](https://wiki.sei.cmu.edu/confluence/display/c/ERR33-C)
- Auto-generated by Standards Enforcement CI
```

**Labels:** `sast`, `auto-generated`, `{tool-name}`, `{cwe-id}`

### Deduplication Strategy

- Hash each finding by: `{tool}:{check}:{file}:{line_range}`
- Line range = line +/- 3 (accounts for small refactors shifting lines)
- Before creating a ticket, search Jira for existing open ticket with same hash
- If found, add comment with latest scan date instead of creating a duplicate

## Planned: Trend Dashboard

- Weekly scheduled workflow aggregates scan results
- Posts trend report to Slack/Jira dashboard
- Tracks: total findings over time, new vs fixed per sprint, findings by package

## Planned: Full-Codebase Scan Mode

In addition to diff-aware PR checks, provide a workflow for full-codebase scans:

- Scheduled (weekly/nightly) runs on the main branch
- Reports all findings, not just diff
- Feeds into the baseline file for ticket creation
- Useful for initial onboarding of legacy codebases

## Timeline

| Feature | Status | Dependency |
|---------|--------|------------|
| Diff-aware C++ quality | Done | - |
| Diff-aware Python quality | Done | - |
| Python SAST (Semgrep, pip-audit) | Done | - |
| Flawfinder integration | Planned | - |
| Automatic Jira ticket creation | Planned | Jira API secrets |
| Trend dashboard | Planned | Ticket creation |
| Full-codebase scan mode | Planned | - |
