"""Generate org-wide compliance dashboard."""

import json


def generate_dashboard(results, latest_tag, latest_sha, org, fmt="markdown"):
    """Generate a compliance dashboard from scan results.

    Args:
        results: list of scan result dicts from scanner.scan_org()
        latest_tag: latest standard release tag
        latest_sha: latest standard release SHA
        org: GitHub org/user name
        fmt: 'markdown' or 'json'

    Returns:
        Formatted dashboard string.
    """
    if fmt == "json":
        return _generate_json(results, latest_tag, latest_sha, org)
    return _generate_markdown(results, latest_tag, latest_sha, org)


def _generate_json(results, latest_tag, latest_sha, org):
    """Generate JSON dashboard."""
    payload = {
        "org": org,
        "latest_tag": latest_tag,
        "latest_sha": latest_sha,
        "repos": results,
    }
    return json.dumps(payload, indent=2)


def _generate_markdown(results, latest_tag, latest_sha, org):
    """Generate markdown dashboard."""
    total = len(results)
    configured = [r for r in results if r["has_config"]]
    current = [r for r in configured if r["up_to_date"]]
    drifted = [r for r in configured if not r["up_to_date"]]
    unconfigured = [r for r in results if not r["has_config"]]

    lines = [
        "## Standard Compliance Dashboard",
        "",
        f"**Org:** {org} | **Latest:** {latest_tag} | "
        f"**SHA:** `{latest_sha[:12]}`",
        "",
        "### Summary",
        "",
        f"- **{total}** repos scanned",
        f"- **{len(current)}** compliant"
        f" ({_pct(len(current), total)})",
        f"- **{len(drifted)}** drifted (needs update)",
        f"- **{len(unconfigured)}** unconfigured",
        "",
    ]

    # Repo status table
    lines.extend([
        "### Repo Status",
        "",
        "| Repo | Config | Tag | Status | Workflows |",
        "|:-----|:------:|:----|:------:|:----------|",
    ])

    for r in sorted(results, key=lambda x: x["repo"]):
        repo_name = r["repo"].split("/")[-1]
        has_cfg = "Yes" if r["has_config"] else "No"
        tag = r["current_tag"] or "-"
        if r["has_config"] and r["up_to_date"]:
            status = "Current"
        elif r["has_config"]:
            status = "**Drift**"
        else:
            status = "Unconfigured"
        wfs = ", ".join(r["workflows"]) if r["workflows"] else "-"
        lines.append(f"| {repo_name} | {has_cfg} | {tag} | {status} | {wfs} |")

    lines.append("")

    # Drift details
    if drifted:
        lines.extend([
            "### Drift Details",
            "",
            "| Repo | Current | Latest | Action |",
            "|:-----|:--------|:-------|:-------|",
        ])
        for r in sorted(drifted, key=lambda x: x["repo"]):
            repo_name = r["repo"].split("/")[-1]
            cur = r["current_tag"] or "unknown"
            lines.append(
                f"| {repo_name} | {cur} | {latest_tag} | Update needed |"
            )
        lines.append("")

    return "\n".join(lines)


def _pct(num, total):
    """Format a percentage string."""
    if total == 0:
        return "0%"
    return f"{num * 100 // total}%"
