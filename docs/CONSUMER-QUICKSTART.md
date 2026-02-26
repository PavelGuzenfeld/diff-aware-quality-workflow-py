# Consumer Quick-Start Guide

How to integrate `standard` quality workflows into your repo.

## Prerequisites

- Your repo has C++ and/or Python source code
- You have a Docker image with your build tools (for C++ analysis)
- You have push access to the repo

## Option 1: CLI (Recommended)

```bash
pip install git+https://github.com/PavelGuzenfeld/standard.git

cd /path/to/your-repo
standard-ci init --preset recommended
```

This generates:
- `.github/workflows/cpp-quality.yml` — clang-tidy, cppcheck, clang-format, flawfinder
- `.github/workflows/python-quality.yml` — ruff, diff-quality
- `.github/workflows/infra-lint.yml` — ShellCheck, Hadolint, Gitleaks
- `.standard.yml` — config file for the compliance bot

Commit and push. PRs will now run quality checks.

## Option 2: Copy from an existing repo

Look at `thebandofficial/rocx/.github/workflows/standards.yml` for a working example
with all features enabled.

## Presets

| Preset | Workflows | Use case |
|--------|-----------|----------|
| `minimal` | clang-tidy, cppcheck, ruff | Fast CI, essential checks only |
| `recommended` | + clang-format, flawfinder, infra-lint | Good balance of coverage and speed |
| `full` | + sanitizers, coverage, IWYU, SBOM, SAST | Maximum quality enforcement |

## Keeping up to date

Once `.standard.yml` exists in your repo, the compliance bot will:
- Detect when your SHA pins are outdated
- Automatically open a PR to update them
- You just review and merge

The bot runs from your org's `.github` repo (e.g. `thebandofficial/.github`).
See [COMPLIANCE-BOT.md](COMPLIANCE-BOT.md) for setup instructions if your org
doesn't have trigger workflows yet.

To update manually:

```bash
standard-ci update          # update to latest
standard-ci update --dry-run # preview changes
standard-ci check           # verify current setup
```
