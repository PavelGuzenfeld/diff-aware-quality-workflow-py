"""Generate and install starter workflow templates into an org's .github repo."""

import os
import subprocess
import tempfile

from standard_ci.updater import REPO

ICON_SVG = """\
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" \
fill="none" stroke="#2088FF" stroke-width="2" stroke-linecap="round" \
stroke-linejoin="round">
  <path d="M9 12l2 2 4-4"/>
  <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20z"/>
</svg>
"""

TEMPLATES = [
    {
        "slug": "standard-cpp-quality",
        "properties": {
            "name": "Standard C++ Quality",
            "description": (
                "Diff-aware C++ quality gates: clang-tidy, cppcheck, "
                "clang-format, flawfinder, ShellCheck, Hadolint, Gitleaks. "
                "Powered by PavelGuzenfeld/standard."
            ),
            "iconName": "standard-icon",
            "categories": ["C++", "CMake", "quality", "security"],
            "filePatterns": ["CMakeLists.txt", "package.xml"],
        },
        "jobs": ["cpp_quality", "infra_lint"],
    },
    {
        "slug": "standard-python-quality",
        "properties": {
            "name": "Standard Python Quality",
            "description": (
                "Diff-aware Python quality gates: ruff, pytest, Semgrep, "
                "pip-audit, ShellCheck, Gitleaks. "
                "Powered by PavelGuzenfeld/standard."
            ),
            "iconName": "standard-icon",
            "categories": ["Python", "quality", "security"],
            "filePatterns": ["pyproject.toml", "setup.py", "requirements.txt"],
        },
        "jobs": ["python_quality", "sast_python", "infra_lint_py"],
    },
    {
        "slug": "standard-full-quality",
        "properties": {
            "name": "Standard Full Quality (C++ + Python)",
            "description": (
                "Complete quality gates for C++ and Python: clang-tidy, "
                "cppcheck, ruff, Semgrep, pip-audit, ShellCheck, Hadolint, "
                "Gitleaks. Powered by PavelGuzenfeld/standard."
            ),
            "iconName": "standard-icon",
            "categories": ["C++", "Python", "CMake", "quality", "security"],
            "filePatterns": [
                "CMakeLists.txt",
                "pyproject.toml",
                "package.xml",
            ],
        },
        "jobs": ["cpp_quality", "python_quality", "sast_python", "infra_lint_full"],
    },
]

# Job YAML snippets keyed by job id
_JOB_SNIPPETS = {
    "cpp_quality": """\
  cpp_quality:
    uses: {repo}/.github/workflows/cpp-quality.yml@{sha}  # {tag}
    with:
      docker_image: ''  # TODO: set your Docker image
      enable_clang_format: true
      enable_file_naming: true
      enable_flawfinder: true
    permissions:
      actions: read
      contents: read
      packages: read
      pull-requests: write
      security-events: write""",
    "python_quality": """\
  python_quality:
    uses: {repo}/.github/workflows/python-quality.yml@{sha}  # {tag}
    permissions:
      contents: read
      pull-requests: write""",
    "sast_python": """\
  sast_python:
    uses: {repo}/.github/workflows/sast-python.yml@{sha}  # {tag}
    with:
      enable_semgrep: true
      enable_pip_audit: true
    permissions:
      actions: read
      contents: read
      pull-requests: write
      security-events: write""",
    "infra_lint": """\
  infra_lint:
    uses: {repo}/.github/workflows/infra-lint.yml@{sha}  # {tag}
    with:
      enable_shellcheck: true
      enable_hadolint: true
      enable_gitleaks: true
    permissions:
      actions: read
      contents: read
      pull-requests: write""",
    "infra_lint_py": """\
  infra_lint:
    uses: {repo}/.github/workflows/infra-lint.yml@{sha}  # {tag}
    with:
      enable_shellcheck: true
      enable_gitleaks: true
    permissions:
      actions: read
      contents: read
      pull-requests: write""",
    "infra_lint_full": """\
  infra_lint:
    uses: {repo}/.github/workflows/infra-lint.yml@{sha}  # {tag}
    with:
      enable_shellcheck: true
      enable_hadolint: true
      enable_cmake_lint: true
      enable_gitleaks: true
    permissions:
      actions: read
      contents: read
      pull-requests: write""",
}

WORKFLOW_HEADER = """\
name: {name}

on:
  pull_request:
    branches: [$default-branch]
  workflow_dispatch:

jobs:
"""


def generate_starter_workflow(template, sha, tag):
    """Generate a single starter workflow YAML string."""
    name_map = {
        "standard-cpp-quality": "C++ Quality",
        "standard-python-quality": "Python Quality",
        "standard-full-quality": "Full Quality",
    }
    header = WORKFLOW_HEADER.format(name=name_map[template["slug"]])
    jobs = []
    for job_id in template["jobs"]:
        snippet = _JOB_SNIPPETS[job_id].format(repo=REPO, sha=sha, tag=tag)
        jobs.append(snippet)
    return header + "\n\n".join(jobs) + "\n"


def generate_properties_json(template):
    """Generate a properties.json string."""
    import json

    return json.dumps(template["properties"], indent=2) + "\n"


def generate_all_files(sha, tag):
    """Return dict of {relative_path: content} for all starter files."""
    files = {}
    files["workflow-templates/standard-icon.svg"] = ICON_SVG
    for tmpl in TEMPLATES:
        slug = tmpl["slug"]
        files[f"workflow-templates/{slug}.yml"] = generate_starter_workflow(
            tmpl, sha, tag
        )
        files[f"workflow-templates/{slug}.properties.json"] = (
            generate_properties_json(tmpl)
        )
    return files


def _run_gh(args, check_rc=True):
    """Run a gh CLI command, return stdout."""
    try:
        result = subprocess.run(
            ["gh"] + args, capture_output=True, text=True, timeout=30
        )
    except FileNotFoundError:
        raise RuntimeError(
            "gh CLI not found. Install from https://cli.github.com/"
        )
    if check_rc and result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout.strip(), result.returncode


def install_starters(org, sha, tag, dry_run=False, create_repo=False):
    """Install starter workflows into <org>/.github repo.

    Returns list of status messages.
    """
    messages = []
    repo_name = f"{org}/.github"
    files = generate_all_files(sha, tag)

    if dry_run:
        messages.append(f"Target: {repo_name}")
        if create_repo:
            messages.append(f"Would create repo if missing: {repo_name}")
        messages.append(f"Would write {len(files)} files:")
        for path in sorted(files):
            messages.append(f"  {path}")
        return messages

    # Check if repo exists (requires gh CLI)
    _, rc = _run_gh(["repo", "view", repo_name], check_rc=False)
    repo_exists = rc == 0

    if not repo_exists:
        if not create_repo:
            raise RuntimeError(
                f"Repository {repo_name} does not exist. "
                f"Use --create-repo to create it."
            )
        _run_gh([
            "repo", "create", repo_name,
            "--public",
            "--description",
            "Organization-level GitHub configuration: "
            "starter workflows, community health files",
        ])
        messages.append(f"Created repo: {repo_name}")

    # Clone, write files, commit, push
    with tempfile.TemporaryDirectory() as tmpdir:
        clone_dir = os.path.join(tmpdir, "dot-github")

        # Clone (or init if empty)
        subprocess.run(
            ["git", "clone", f"git@github.com:{repo_name}.git", clone_dir],
            capture_output=True, text=True, timeout=30,
        )

        # Ensure workflow-templates dir
        templates_dir = os.path.join(clone_dir, "workflow-templates")
        os.makedirs(templates_dir, exist_ok=True)

        # Write all files
        for rel_path, content in files.items():
            filepath = os.path.join(clone_dir, rel_path)
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            with open(filepath, "w") as f:
                f.write(content)

        # Check if there are changes
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True, text=True, cwd=clone_dir,
        )
        if not result.stdout.strip():
            messages.append("No changes — starter workflows already up to date.")
            return messages

        # Commit and push
        subprocess.run(
            ["git", "add", "-A"], cwd=clone_dir,
            capture_output=True, text=True,
        )
        subprocess.run(
            ["git", "commit", "-m",
             f"feat: update starter workflow templates to {tag}"],
            cwd=clone_dir, capture_output=True, text=True,
        )
        push_result = subprocess.run(
            ["git", "push"], cwd=clone_dir,
            capture_output=True, text=True, timeout=30,
        )
        if push_result.returncode != 0:
            raise RuntimeError(
                f"git push failed: {push_result.stderr.strip()}"
            )

        messages.append(f"Pushed {len(files)} files to {repo_name}")
        for path in sorted(files):
            messages.append(f"  {path}")

    return messages
