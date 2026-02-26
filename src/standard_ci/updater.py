"""Resolve latest tag SHA from the standard repo."""

import json
import subprocess
import urllib.error
import urllib.request

REPO = "PavelGuzenfeld/standard"
API_URL = f"https://api.github.com/repos/{REPO}/tags"


def resolve_tag_sha(tag=None):
    """Resolve a git tag to its full SHA.

    If tag is None, resolves the latest tag.
    Returns (sha, tag_name) or raises RuntimeError.
    """
    # Try GitHub API first (no git required)
    try:
        return _resolve_via_api(tag)
    except Exception:
        pass
    # Fallback to git ls-remote
    return _resolve_via_git(tag)


def _resolve_via_api(tag):
    """Resolve via GitHub REST API."""
    req = urllib.request.Request(API_URL, headers={"User-Agent": "standard-ci"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        tags = json.loads(resp.read().decode())
    if not tags:
        raise RuntimeError("No tags found")
    if tag is None:
        entry = tags[0]
        return entry["commit"]["sha"], entry["name"]
    for entry in tags:
        if entry["name"] == tag:
            return entry["commit"]["sha"], entry["name"]
    raise RuntimeError(f"Tag {tag} not found")


def _resolve_via_git(tag):
    """Resolve via git ls-remote (fallback)."""
    try:
        result = subprocess.run(
            ["git", "ls-remote", "--tags", f"https://github.com/{REPO}.git"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except FileNotFoundError:
        raise RuntimeError("git not found and GitHub API unavailable")
    if result.returncode != 0:
        raise RuntimeError(f"git ls-remote failed: {result.stderr.strip()}")

    entries = []
    for line in result.stdout.strip().splitlines():
        sha, ref = line.split("\t", 1)
        ref = ref.replace("refs/tags/", "").rstrip("^{}")
        entries.append((sha, ref))

    if not entries:
        raise RuntimeError("No tags found via git ls-remote")

    if tag is None:
        # Last entry is the latest
        return entries[-1]
    for sha, name in entries:
        if name == tag:
            return sha, name
    raise RuntimeError(f"Tag {tag} not found via git ls-remote")
