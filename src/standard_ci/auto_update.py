"""Open update PRs in consumer repos that have drifted."""

import json
import os
import subprocess
import tempfile


def _run(args, cwd=None, timeout=30):
    """Run a subprocess command, return (stdout, returncode)."""
    result = subprocess.run(
        args, capture_output=True, text=True, cwd=cwd, timeout=timeout
    )
    return result.stdout.strip(), result.returncode


def _run_checked(args, cwd=None, timeout=30):
    """Run a subprocess command, raise on failure."""
    stdout, rc = _run(args, cwd=cwd, timeout=timeout)
    if rc != 0:
        _, _ = _run(args, cwd=cwd)  # for stderr
        result = subprocess.run(
            args, capture_output=True, text=True, cwd=cwd, timeout=timeout
        )
        raise RuntimeError(f"{' '.join(args[:3])}... failed: {result.stderr.strip()}")
    return stdout


def _check_existing_pr(repo, branch, token=None):
    """Check if an open PR exists for the given branch. Returns True if found."""
    env = dict(os.environ)
    if token:
        env["GH_TOKEN"] = token
    result = subprocess.run(
        ["gh", "pr", "list", "--repo", repo, "--head", branch,
         "--state", "open", "--json", "number", "--limit", "1"],
        capture_output=True, text=True, timeout=15, env=env,
    )
    if result.returncode != 0:
        return False
    try:
        prs = json.loads(result.stdout)
        return len(prs) > 0
    except (json.JSONDecodeError, TypeError):
        return False


def auto_update_repos(scan_results, latest_tag, latest_sha,
                      pr_title_prefix="chore(deps): ",
                      pr_labels="dependencies,standard-ci",
                      dry_run=False, token=None):
    """For each drifted repo, clone, update SHA pins, and open a PR.

    Args:
        scan_results: list of scan result dicts
        latest_tag: target tag to update to
        latest_sha: target SHA to update to
        pr_title_prefix: prefix for PR titles
        pr_labels: comma-separated labels
        dry_run: if True, show what would change without acting
        token: GitHub token for auth

    Returns list of status messages.
    """
    if not token:
        token = os.environ.get("GITHUB_TOKEN", "")

    messages = []
    branch_name = f"standard-ci/update-{latest_tag}"
    pr_title = f"{pr_title_prefix}update standard to {latest_tag}"

    for repo_info in scan_results:
        if not repo_info["has_config"] or repo_info["up_to_date"]:
            continue

        repo = repo_info["repo"]
        old_tag = repo_info.get("current_tag") or "unknown"
        old_sha = repo_info.get("current_sha") or ""

        if dry_run:
            messages.append(f"Would update {repo}: {old_tag} -> {latest_tag}")
            continue

        # Check for existing PR
        if _check_existing_pr(repo, branch_name, token):
            messages.append(f"Skipped {repo}: PR already open for {branch_name}")
            continue

        try:
            _update_single_repo(
                repo, old_sha, old_tag, latest_sha, latest_tag,
                branch_name, pr_title, pr_labels, token,
            )
            messages.append(f"Opened PR in {repo}: {old_tag} -> {latest_tag}")
        except Exception as e:
            messages.append(f"Failed {repo}: {e}")

    if not messages:
        messages.append("All repos are up to date — no PRs needed")

    return messages


def _update_single_repo(repo, old_sha, old_tag, new_sha, new_tag,
                         branch_name, pr_title, pr_labels, token):
    """Clone a repo, update SHA pins, commit, push, and open a PR."""
    env = dict(os.environ)
    if token:
        env["GH_TOKEN"] = token

    with tempfile.TemporaryDirectory() as tmpdir:
        clone_url = f"https://x-access-token:{token}@github.com/{repo}.git"
        clone_dir = os.path.join(tmpdir, "repo")

        _run_checked(["git", "clone", "--depth=1", clone_url, clone_dir])
        _run_checked(["git", "checkout", "-b", branch_name], cwd=clone_dir)

        # Update .standard.yml
        config_path = os.path.join(clone_dir, ".standard.yml")
        if os.path.exists(config_path):
            with open(config_path) as f:
                content = f.read()
            if old_sha:
                content = content.replace(old_sha, new_sha)
            content = content.replace(f"tag: {old_tag}", f"tag: {new_tag}")
            with open(config_path, "w") as f:
                f.write(content)

        # Update workflow files
        wf_dir = os.path.join(clone_dir, ".github", "workflows")
        if os.path.isdir(wf_dir):
            for fname in os.listdir(wf_dir):
                if not fname.endswith(".yml") and not fname.endswith(".yaml"):
                    continue
                fpath = os.path.join(wf_dir, fname)
                with open(fpath) as f:
                    content = f.read()
                changed = False
                if old_sha and old_sha in content:
                    content = content.replace(old_sha, new_sha)
                    changed = True
                if old_tag and f"# {old_tag}" in content:
                    content = content.replace(f"# {old_tag}", f"# {new_tag}")
                    changed = True
                if changed:
                    with open(fpath, "w") as f:
                        f.write(content)

        # Check for changes
        status, _ = _run(["git", "status", "--porcelain"], cwd=clone_dir)
        if not status:
            return  # No changes needed

        # Commit and push
        _run_checked(["git", "add", "-A"], cwd=clone_dir)
        _run_checked(
            ["git", "commit", "-m",
             f"chore(deps): update standard to {new_tag}\n\n"
             f"Automated update from {old_tag} to {new_tag}.\n"
             f"SHA: {old_sha[:12] if old_sha else '?'} -> {new_sha[:12]}"],
            cwd=clone_dir,
        )
        _run_checked(["git", "push", "-u", "origin", branch_name], cwd=clone_dir)

        # Open PR via gh CLI
        pr_body = (
            f"## Automated standard update\n\n"
            f"Updates standard workflow pins from **{old_tag}** to **{new_tag}**.\n\n"
            f"- Old SHA: `{old_sha[:12] if old_sha else '?'}`\n"
            f"- New SHA: `{new_sha[:12]}`\n\n"
            f"This PR was created automatically by the standard compliance bot."
        )

        label_args = []
        for label in pr_labels.split(","):
            label = label.strip()
            if label:
                label_args.extend(["--label", label])

        cmd = [
            "gh", "pr", "create",
            "--repo", repo,
            "--title", pr_title,
            "--body", pr_body,
            "--head", branch_name,
        ] + label_args

        subprocess.run(
            cmd, capture_output=True, text=True, timeout=30, env=env,
        )
