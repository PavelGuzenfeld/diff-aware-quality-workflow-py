# standard repo — Industry Comparison (Feb 2026)

## What `standard` Is
Reusable GitHub Actions workflows for diff-aware C++ and Python quality gates.
Repo: `PavelGuzenfeld/standard`, MIT license, `~/workspace/standard/`

## Unique Niche
No single tool in the industry combines all of: diff-aware C++ deep checks (clang-tidy with compilation database), Python quality gates, infra lint, secrets detection, SBOM/supply chain, hardening verification, and auto-release with SLSA provenance in one opt-in reusable workflow system. The fundamental industry gap: serious C++ analysis requires a compilation database + build environment, which no aggregator platform (MegaLinter, Super-Linter, trunk, pre-commit.ci) provides.

## Feature Coverage

### What `standard` provides (7 reusable workflows):
- **C++ quality** (56 inputs): clang-tidy, cppcheck, clang-format, flawfinder, ASan/UBSan, TSan, gcov/lcov coverage, IWYU, binary hardening verification
- **Python quality** (10 inputs): ruff/flake8, pytest, diff-cover
- **Python SAST** (9 inputs): Semgrep, pip-audit, CodeQL
- **Infra lint** (14 inputs): ShellCheck, Hadolint, cmake-lint, dangerous-workflow audit, binary-artifact scan, Gitleaks secrets detection
- **SBOM/supply chain** (8 inputs): Syft, Grype, license compliance, SLSA provenance, Dependabot config
- **Version check** (3 inputs): SemVer validation in package.xml, CMakeLists.txt, pyproject.toml
- **Auto-release** (2 inputs): conventional commits → semver tag → GitHub Release → SLSA provenance
- **Extras**: banned patterns (cout/printf, new/delete, gtest), snake_case file naming, 17 drop-in configs, 5 generator scripts, PR scoreboard comments (5 workflows)
- **Templates**: CodeQL (ci-codeql.yml), Infer (ci-infer.yml), libFuzzer (ci-fuzz.yml), multi-compiler (ci-multi-compiler.yml), CMakePresets-sanitizers.json, cmake-warnings.cmake

### Architecture advantage:
- `workflow_call` — update once, all consumer repos benefit (no copy-paste divergence)
- Diff-aware across ALL check types (only changed files checked)
- Docker-image-aware — runs inside caller's image with their exact toolchain + compile_commands.json
- Compilation-database-aware clang-tidy — the key differentiator no aggregator matches

---

## Competitors Compared

### Meta-Linters / Aggregators

| Tool | Strengths vs standard | Weaknesses vs standard |
|------|----------------------|----------------------|
| **MegaLinter** (OX Security) | 100+ linters, 50+ languages, auto-fix PRs, CI-agnostic, 4 secrets detectors (gitleaks/trufflehog/secretlint/devskim), trivy SBOM, copy-paste detection | **No clang-tidy**, no compilation-database analysis, no builds/tests, no sanitizers, no coverage, no auto-release. Only 3 C++ linters (cppcheck, cpplint, clang-format) |
| **Super-Linter** v8.5 | 70+ languages, parallel execution, GitHub-native | Only 2 C++ linters (cpplint + clang-format). No cppcheck, no clang-tidy, no security, no SBOM |
| **Trunk Check** | Hermetic tool management, hold-the-line, clang-tidy support | **Web dashboard shut down July 2025.** Company pivoted to CI reliability. Code quality is maintenance-mode. Closed-source CLI binary |
| **Reviewdog** | Universal adapter for any linter output, PR annotations | Not a framework — must wire each tool separately |
| **pre-commit.ci** | Zero-config from .pre-commit-config.yaml, auto-fix commits, weekly hook updates | **No Docker hooks** (blocks most C++ tools), no security/SBOM, GitHub only, cannot use compilation databases |

**Key insight**: All aggregators treat C++ like a scripting language. They run tools without build context, so they cannot use clang-tidy's semantic analysis (which requires compile_commands.json from CMake). This is the fundamental gap standard fills.

### C++ Project Templates

| Tool | Strengths vs standard | Weaknesses vs standard |
|------|----------------------|----------------------|
| **cmake_template (Jason Turner)** | Multi-OS (Win/Mac/Linux), MSVC, WASM builds, Catch2 fuzz testing, CMakePresets, actively maintained (Feb 2026) | **Not reusable** (fork-per-project, diverges), no diff-awareness, no SBOM, no auto-release, no PR annotations, no secrets detection, no Python |
| **aminya/project_options** | Only truly reusable CMake module (FetchContent), 30+ flags, hardening, sanitizers, IWYU | **No CI workflow included**, no diff-awareness, no SBOM, no PR annotations. Release cadence slowed (last: Nov 2024) |
| **aminya/setup-cpp** | Widest C++ tool installer (LLVM 21, GCC 15.2), cross-platform | Setup only — installs tools, no analysis logic |
| **ModernCppStarter** | 5.3k stars, clean library/exe separation, CPM.cmake | No hardening, no fuzzing, no CodeQL, low activity (Jan 2025) |
| **filipdutescu/modern-cpp-template** | 1.9k stars | **Unmaintained since Oct 2021** |

Note: cmake_template's former unique advantages (hardening, fuzzing, CMakePresets) are now fully matched by standard's configs (CMakePresets-sanitizers.json, ci-fuzz.yml, cmake-warnings.cmake, hardening verification job).

### Google / OpenSSF

| Tool | What it does | Reusable workflow? | Coverage |
|------|-------------|-------------------|----------|
| **ClusterFuzzLite** | PR fuzzing + batch fuzzing + corpus management | No (composite Docker actions) | Fuzzing only (libFuzzer + ASan/MSan/UBSan) |
| **OSS-Fuzz** | Hosted continuous fuzzing (1,336+ projects, 13k+ vulns) | N/A (hosted service) | Open-source only, by invitation |
| **OSS-Fuzz-Gen** | LLM-generated fuzz targets (26 bugs found, incl. OpenSSL CVE-2024-9143) | N/A | Auto-generates harnesses |
| **OSV-Scanner** v2 | Dependency vulnerability scanning, container scanning | **Yes** (2 reusable workflows) | SCA only, 11+ ecosystems, SARIF output |
| **OpenSSF Scorecard** | 20-check security posture (Binary-Artifacts, Branch-Protection, Dangerous-Workflow, SAST, SBOM, Security-Policy, etc.) | No (GitHub Action) | Process checks, not code quality |
| **SLSA GitHub Generator** v1.10 | Build provenance (achieves Build L3) | **Yes** (reusable workflows) | Supply chain only. Go/Node/Maven/Container builders |
| **Allstar** | Continuous policy enforcement GitHub App | N/A (GitHub App) | Enforces Scorecard-like policies |

**Gap**: Google invented the foundational tools (sanitizers, fuzzing, SLSA) but never assembled them into a unified CI framework. standard integrates ASan/TSan as opt-in jobs, SLSA provenance in auto-release, and aligns with Scorecard via SECURITY.md + Dependabot + dangerous-workflow audit.

### Microsoft / GitHub

| Tool | What it does | C++ value |
|------|-------------|-----------|
| **CodeQL** (GHAS) | Deep semantic/dataflow SAST, 87 C++ queries, ~50 CWEs, buildless mode GA | **Best C++ security analysis** — but security only, not quality/style |
| **BinSkim** v4.4.8 | Binary hardening validation: PIE, RELRO, NX, stack-protector, FORTIFY, CFG (PE+ELF, 27 PE + 11 ELF rules) | Strong post-build validation. Similar to standard's hardening job but more rules |
| **DevSkim** v1.0.70 | Regex-based security linter (banned APIs, weak crypto) | Shallow — no AST/dataflow, catches low-hanging fruit only |
| **msvc-code-analysis-action** | MSVC /analyze + Core Guidelines | **Abandoned** (last release Aug 2021), Windows-only |
| **vcpkg SBOM** | Per-port SPDX generation + `license-report` command (July 2025) | Good for vcpkg-managed deps only |
| **microsoft/sbom-tool** | Generic SPDX 2.2/3.0 generation | **Cannot detect C++ dependencies** (no Conan/CMake/vcpkg awareness) |
| **Security DevOps Action** | Bundles BinSkim + Checkov + Trivy + Bandit + ESLint | Only BinSkim relevant for C++. No source analysis |

**Gap**: Microsoft provides strong individual pieces (CodeQL, BinSkim) but **no orchestration layer**. No reusable C++ quality workflow exists. The msvc-code-analysis-action is dead.

### JFrog

| Tool | What it does | C++ value |
|------|-------------|-----------|
| **Xray** | Binary SCA, SBOM (SPDX + CycloneDX), license compliance, contextual CVE analysis | Conan support. Contextual analysis reduces false positives. Requires Artifactory |
| **Artifactory** | Universal artifact repo, Conan remote, build info, binary caching | Strong for Conan-based teams |
| **Frogbot** | PR vulnerability scanning bot | **No Conan/C++ support** (open issue #355 unresolved). Significant gap given JFrog owns Conan |

### Other SCA / SAST Platforms

| Tool | Strengths vs standard | Weaknesses vs standard |
|------|----------------------|----------------------|
| **SonarQube** | Deep engine, quality dashboard, tech debt tracking, AI fix suggestions | No sanitizers, no IWYU, no infra lint, no SBOM. C++ needs paid tier ($150+/yr) |
| **Snyk** | Hash-based unmanaged C++ dep detection (no manifest needed), SAST for C/C++, container scanning | Enterprise plan required for SBOM. No formatting/build integration |
| **Sonatype Lifecycle** | CPE-based C++ vuln matching, curated CVE data beyond NVD | CPE matching produces false positives. Requires Conan manifests or SBOMs. Commercial |
| **Coverity** | Deepest C++ analysis, MISRA/CERT/AUTOSAR, <15% false positives | $50k-200k+/yr |
| **PVS-Studio** | Proprietary rules, copy-paste detection, 64-bit portability checks | $570+/yr. C++/C#/Java only |
| **CodeQL** | 87 C++ queries, dataflow analysis, free for public repos, buildless mode | Security only. Slow. $49/committer/mo for private repos |
| **Semgrep** | Fast (10s scans), easy custom rules, 40+ languages | Pattern-based (shallow C++), no builds |

### Dependency Update Tools

| Tool | C++ support | Notes |
|------|-------------|-------|
| **Renovate** | Conan (conanfile.txt/py/lock), CPM.cmake | 90+ package managers, multi-platform, monorepo grouping, regex managers for custom patterns |
| **Dependabot** | vcpkg only (Aug 2025) | **No Conan support** (feature request closed). GitHub only. Simpler config |

---

## What `standard` Could Adopt

| Feature | Source | Priority | Notes |
|---------|--------|----------|-------|
| ClusterFuzzLite as reusable workflow | Google | Medium | ci-fuzz.yml template exists but not workflow_call |
| OpenSSF Scorecard Action | Google/OpenSSF | Low | SECURITY.md + Dependabot + SLSA + dangerous-workflow already cover key checks |
| Copy-paste detection (jscpd) | MegaLinter | Low | Code smell, not bugs. High noise |
| BinSkim (richer binary checks) | Microsoft | Low | standard's readelf-based hardening job covers the essentials; BinSkim adds stack-clash-protection + SafeStack |
| Renovate support in generate-workflow.sh | Renovate | Low | Better C++ dep update support than Dependabot (Conan) |
| ~~Trend dashboard~~ | Internal | **Done** | `trend-dashboard.yml` — weekly aggregate scan results, Slack/Discussions posting |

### Already Done (previously listed as TODO):
- ~~Hardening flags~~ → CMakePresets-sanitizers.json + hardening verification job
- ~~SLSA provenance~~ → auto-release.yml with enable_provenance
- ~~Secrets detection~~ → enable_gitleaks in infra-lint.yml
- ~~CodeQL C++ weekly~~ → configs/ci-codeql.yml template
- ~~Infer C++ analysis~~ → configs/ci-infer.yml template
- ~~Allstar policy templates~~ → configs/.allstar/ (branch protection, security policy, binary artifacts, dangerous workflows, outside collaborators, actions)

---

## Industry Coverage Matrix

What each platform covers for C++ projects:

| Capability | standard | MegaLinter | cmake_template | JFrog | Snyk | SonarQube | CodeQL |
|---|---|---|---|---|---|---|---|
| clang-tidy (semantic) | **Yes** | No | Yes* | No | No | No | No |
| cppcheck | **Yes** | Yes | Yes* | No | No | No | No |
| clang-format | **Yes** | Yes | Yes* | No | No | No | No |
| Sanitizers (ASan/TSan) | **Yes** | No | Yes* | No | No | No | No |
| Coverage + diff-cover | **Yes** | No | Yes* | No | No | Yes | No |
| Fuzz testing | Template | No | Yes* | No | No | No | No |
| Hardening verification | **Yes** | No | Flags only | No | No | No | No |
| SBOM | **Yes** | Via trivy | No | **Yes** | **Yes** | No | No |
| Vulnerability scan | **Yes** (Grype) | Via trivy | No | **Yes** | **Yes** | No | No |
| License compliance | **Yes** | No | No | **Yes** | **Yes** | No | No |
| Secrets detection | **Yes** | **Yes** (4 tools) | No | Via Adv.Sec | No | No | No |
| Security SAST | Templates | Semgrep | CodeQL | No | **Yes** | **Yes** | **Yes** |
| Diff-aware | **Yes** | No | No | No | No | No | Incremental |
| Reusable (no copy-paste) | **Yes** | Yes | **No** | N/A | N/A | N/A | N/A |
| Auto-release + SLSA | **Yes** | No | No | No | No | No | No |
| PR annotations | **Yes** | Yes | No | Frogbot | Yes | Yes | Yes |
| Free/open-source | **Yes** | Yes | Yes | No ($$$) | No ($$$) | No ($$$) | Public repos only |

*cmake_template: copy-per-project, not reusable. Diverges after fork.

---

## strong-types as Consumer Proof

`strong-types` is the first real consumer of `standard` with full fuzz testing:
- 2 fuzz harnesses: `fuzz_safe_math.cpp` (oracle-based), `fuzz_quantity_point.cpp` (magnitude-aware)
- Dedicated `fuzz.yml` workflow: Clang 18 + libFuzzer + ASan/UBSan, 30s/harness
- CMake: `BUILD_FUZZING` + `FUZZ_USE_LIBCXX` options
- 5+ commits fixing fuzz-discovered edge cases (UB, extreme magnitudes, missing includes)
- Proves the ci-fuzz.yml template works end-to-end
