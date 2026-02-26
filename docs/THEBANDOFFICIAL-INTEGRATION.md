# thebandofficial Integration Guide

## Currently Onboarded Repos

| Repo | Branch | Status | PR |
|------|--------|--------|-----|
| `thebandofficial/rocx` | `master` | Onboarded (v0.18.1) | #1792 |
| `thebandofficial/rocx` | `dev_for_Orin` | Onboarded (v0.18.1) | #1793 |

## Repos Eligible for Onboarding

C++ repos (have CMakeLists.txt or C++ source):

| Repo | Language | Notes |
|------|----------|-------|
| `rocx_lp_sdk` | C++ | Submodule of rocx |
| `gate_esad_sdk` | C++ | Submodule of rocx |
| `rocx-mission-factory` | C++ | Submodule of rocx |
| `coordinate_data_converter_cpp` | C++ | Part of rocx monorepo |
| `position-injection-examples` | C++ | Standalone |
| `rocx-l-filter` | C++ | Standalone |
| `fc-px4` | C | PX4 fork |

Python repos:

| Repo | Notes |
|------|-------|
| `ATR-VMD` | Python ML |
| `tracker_engine` | Core tracking |
| `multi-tracker` | Python |
| `geo-registration` | Python |
| `dds-connector` | Python |
| `rocx_udp_icd` | Python ICD |

## How rocx Is Configured

`rocx` uses the `full` preset with self-hosted runners. Key config:

- **Docker image**: `ghcr.io/thebandofficial/rocx_builder_base-pc-vm:latest`
- **Source mount**: `/workspace/rocx`
- **ROS setup**: `source /opt/ros/jazzy/setup.bash` (falls back to humble)
- **Pre-analysis**: `.github/scripts/pre-analysis.sh` (builds compile_commands.json)
- **Runner**: `["self-hosted","X64","Linux"]`
- **Default diff base**: `dev_for_Orin`

### Enabled checks

All of these run on every PR:

- clang-tidy (CERT + Core Guidelines)
- cppcheck (CWE analysis, c++23, with `cppcheck.suppress`)
- clang-format
- flawfinder (min level 2, SARIF upload)
- ASan/UBSan sanitizer tests
- TSan thread sanitizer tests
- Code coverage (gcov/lcov + diff-cover)
- IWYU (Include-What-You-Use)
- ShellCheck + Hadolint
- Gitleaks secrets detection
- cmake-lint
- Dangerous workflow audit
- Binary artifact scan
- File naming convention
- cout/cerr ban, new/delete ban
- doctest enforcement
- Python ruff (E,W,F,I rules, 100% diff-quality)
- Semgrep (OWASP + Python rules)
- pip-audit (CVE scanning)
- SBOM (Syft + Grype + license check)
- CIS SSC compliance
- Version check

## Onboarding a New thebandofficial Repo

For standalone repos (not submodules of rocx):

```bash
# Clone the repo
git clone https://github.com/thebandofficial/REPO.git
cd REPO

# For C++ repos:
standard-ci init --preset recommended
# Edit .github/workflows/cpp-quality.yml:
#   - Set docker_image to your builder image
#   - Set source_mount, source_setup as needed
#   - Set runner to '["self-hosted","X64","Linux"]' for self-hosted

# For Python-only repos:
standard-ci init --preset minimal
# The defaults usually work for Python repos

# Commit and push
git add .github/workflows/ .standard.yml
git commit -m "chore: onboard standard-ci quality workflows"
git push
```

## Automatic Updates

A single trigger workflow lives in `thebandofficial/.github`:

| Workflow | Schedule | Manual trigger |
|----------|----------|----------------|
| `compliance.yml` | Monday 9am UTC | `gh workflow run compliance.yml --repo thebandofficial/.github` |

This calls `PavelGuzenfeld/standard/.github/workflows/compliance.yml@main`.

Every run scans the org and generates a dashboard. To also open update PRs, trigger manually with `auto_update=true`:

```bash
# Dashboard only
gh workflow run compliance.yml --repo thebandofficial/.github

# Dashboard + open PRs
gh workflow run compliance.yml --repo thebandofficial/.github -f auto_update=true

# Dashboard + dry run
gh workflow run compliance.yml --repo thebandofficial/.github -f auto_update=true -f dry_run=true
```

PRs are labeled `dependencies,standard-ci` for easy filtering.

View dashboard results at:
https://github.com/thebandofficial/.github/actions/workflows/compliance.yml

## Token Requirements

The `COMPLIANCE_BOT_TOKEN` secret is set in `thebandofficial/.github`. It needs
`repo` + `workflow` scopes to push branches and create PRs in thebandofficial repos.

Current setup uses a PAT belonging to `PavelGuzenfeld` (who is a member of
`thebandofficial`). If PavelGuzenfeld loses access to the org, the token needs
to be replaced with one from another org member, or a GitHub App should be installed.
