"""Scan GitHub org repos for .standard.yml and validate compliance."""

import base64
import json
import os
import urllib.error
import urllib.request

from standard_ci.config import read_config_string
from standard_ci.updater import resolve_tag_sha


def _api_get(url, token=None):
    """Make a GET request to GitHub API. Returns parsed JSON."""
    headers = {"User-Agent": "standard-ci", "Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"token {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode()), resp.headers


def _api_get_paginated(url, token=None):
    """Fetch all pages from a paginated GitHub API endpoint."""
    items = []
    while url:
        data, headers = _api_get(url, token)
        items.extend(data)
        # Parse Link header for next page
        url = None
        link = headers.get("Link", "")
        for part in link.split(","):
            if 'rel="next"' in part:
                url = part.split("<")[1].split(">")[0]
    return items


def list_org_repos(org, token=None):
    """List all non-archived, non-fork repos in an org/user.

    Returns list of dicts with 'full_name' and 'default_branch'.
    """
    # Try /orgs/ first, fall back to /users/
    for endpoint in [f"https://api.github.com/orgs/{org}/repos",
                     f"https://api.github.com/users/{org}/repos"]:
        url = f"{endpoint}?per_page=100&type=sources"
        try:
            raw = _api_get_paginated(url, token)
            repos = []
            for r in raw:
                if r.get("archived") or r.get("fork"):
                    continue
                repos.append({
                    "full_name": r["full_name"],
                    "default_branch": r.get("default_branch", "main"),
                })
            return repos
        except urllib.error.HTTPError as e:
            if e.code == 404:
                continue
            raise
    raise RuntimeError(f"Could not list repos for '{org}' — not found as org or user")


def fetch_standard_config(repo_full_name, token=None, ref=None):
    """Fetch .standard.yml content from a repo via GitHub API.

    Returns parsed config dict, or None if not found.
    """
    url = f"https://api.github.com/repos/{repo_full_name}/contents/.standard.yml"
    if ref:
        url += f"?ref={ref}"
    try:
        data, _ = _api_get(url, token)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    content_b64 = data.get("content", "")
    content = base64.b64decode(content_b64).decode()
    return read_config_string(content)


def scan_repo(repo_info, latest_sha, latest_tag, token=None):
    """Scan a single repo for compliance.

    Returns a result dict with: repo, has_config, current_tag, current_sha,
    up_to_date, workflows, issues.
    """
    repo = repo_info["full_name"]
    result = {
        "repo": repo,
        "has_config": False,
        "current_tag": None,
        "current_sha": None,
        "up_to_date": False,
        "workflows": [],
        "issues": [],
    }

    config = fetch_standard_config(repo, token)
    if config is None:
        result["issues"].append("No .standard.yml found")
        return result

    result["has_config"] = True
    result["current_tag"] = config.get("tag", "")
    result["current_sha"] = config.get("sha", "")
    result["workflows"] = config.get("workflows", [])

    if result["current_sha"] == latest_sha:
        result["up_to_date"] = True
    else:
        result["issues"].append(
            f"SHA drift: {result['current_tag']} -> {latest_tag}"
        )

    return result


def scan_org(org, token=None):
    """Scan all repos in an org for compliance.

    Returns (results_list, latest_tag, latest_sha).
    """
    if not token:
        token = os.environ.get("GITHUB_TOKEN", "")

    latest_sha, latest_tag = resolve_tag_sha()
    repos = list_org_repos(org, token)
    results = []
    for repo_info in repos:
        results.append(scan_repo(repo_info, latest_sha, latest_tag, token))
    return results, latest_tag, latest_sha
