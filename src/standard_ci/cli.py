"""CLI entry point for standard-ci."""

import argparse
import os
import sys

from standard_ci import __version__
from standard_ci.checker import check
from standard_ci.config import read_config, write_config
from standard_ci.detect import detect_languages
from standard_ci.presets import ALL_PRESETS
from standard_ci.prompt import ask_yn
from standard_ci.templates import generate_workflow
from standard_ci.updater import resolve_tag_sha
from standard_ci.workflows import (
    ALL_WORKFLOWS,
    COMMON_WORKFLOWS,
    LANGUAGE_WORKFLOWS,
)


def cmd_init(args):
    """Scaffold workflow files and .standard.yml."""
    project_dir = args.output_dir or "."

    # Resolve SHA
    print(f"Resolving {'tag ' + args.pin if args.pin else 'latest tag'}...")
    try:
        sha, tag_name = resolve_tag_sha(args.pin)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"  {tag_name} -> {sha[:12]}")

    # Detect languages
    langs = detect_languages(project_dir)
    if langs:
        print(f"Detected: {', '.join(sorted(langs))}")
    else:
        print("No language markers detected (CMakeLists.txt, pyproject.toml, etc.)")

    # Determine which workflows to enable
    preset = ALL_PRESETS.get(args.preset, ALL_PRESETS["recommended"])
    workflow_names = list(COMMON_WORKFLOWS)
    for lang in sorted(langs):
        workflow_names.extend(LANGUAGE_WORKFLOWS.get(lang, []))
    # Deduplicate while preserving order
    seen = set()
    unique = []
    for name in workflow_names:
        if name not in seen:
            seen.add(name)
            unique.append(name)
    workflow_names = unique

    if not args.non_interactive and not langs:
        # Ask which languages to enable
        if ask_yn("Enable C++ workflows?", default=False):
            langs.add("cpp")
        if ask_yn("Enable Python workflows?", default=False):
            langs.add("python")
        workflow_names = list(COMMON_WORKFLOWS)
        for lang in sorted(langs):
            workflow_names.extend(LANGUAGE_WORKFLOWS.get(lang, []))
        seen = set()
        unique = []
        for name in workflow_names:
            if name not in seen:
                seen.add(name)
                unique.append(name)
        workflow_names = unique

    # Collect inputs per workflow
    all_configs = {}
    for wf_name in workflow_names:
        if wf_name not in ALL_WORKFLOWS:
            continue
        wf = ALL_WORKFLOWS[wf_name]
        inputs = dict(preset.get(wf_name, {}))

        if not args.non_interactive:
            # Ask for required inputs
            from standard_ci.prompt import ask_value

            for key, meta in wf["required_inputs"].items():
                if key not in inputs or not inputs[key]:
                    inputs[key] = ask_value(f"  {meta['prompt']}:", meta["default"])

            # Ask about boolean opt-ins
            for key, meta in wf["optional_inputs"].items():
                if meta["type"] == "boolean" and meta.get("group") == "checks":
                    current = inputs.get(key, meta["default"])
                    inputs[key] = ask_yn(f"  {meta['prompt']}", default=current)

        all_configs[wf_name] = inputs

    # Generate workflow files
    workflows_dir = os.path.join(project_dir, ".github", "workflows")
    os.makedirs(workflows_dir, exist_ok=True)

    generated = []
    for wf_name, inputs in all_configs.items():
        yaml_content = generate_workflow(wf_name, inputs, sha, tag_name)
        filename = ALL_WORKFLOWS[wf_name]["filename"]
        filepath = os.path.join(workflows_dir, filename)
        with open(filepath, "w") as f:
            f.write(yaml_content)
        generated.append(filename)
        print(f"  Generated: .github/workflows/{filename}")

    # Write .standard.yml
    config_data = {
        "version": __version__,
        "preset": args.preset,
        "tag": tag_name,
        "sha": sha,
        "workflows": list(all_configs.keys()),
    }
    # Store per-workflow inputs (only non-defaults)
    for wf_name, inputs in all_configs.items():
        if inputs:
            config_data[wf_name] = inputs

    config_path = os.path.join(project_dir, ".standard.yml")
    write_config(config_path, config_data)
    print("  Generated: .standard.yml")
    print(f"\nDone! {len(generated)} workflow(s) pinned to {tag_name} ({sha[:12]})")


def cmd_update(args):
    """Update SHA pins to the latest release."""
    project_dir = args.output_dir or "."
    config_path = os.path.join(project_dir, ".standard.yml")
    config = read_config(config_path)

    if not config:
        print("Error: .standard.yml not found — run `standard-ci init` first", file=sys.stderr)
        sys.exit(1)

    old_sha = config.get("sha", "")
    old_tag = config.get("tag", "")

    print(f"Current: {old_tag} ({old_sha[:12] if old_sha else 'unknown'})")
    print(f"Resolving {'tag ' + args.pin if args.pin else 'latest tag'}...")

    try:
        new_sha, new_tag = resolve_tag_sha(args.pin)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Latest:  {new_tag} ({new_sha[:12]})")

    if old_sha == new_sha:
        print("Already up to date.")
        return

    if args.dry_run:
        print(f"\nWould update: {old_tag} -> {new_tag}")
        print(f"  SHA: {old_sha[:12]} -> {new_sha[:12]}")
        return

    # Update workflow files
    workflows_dir = os.path.join(project_dir, ".github", "workflows")
    enabled = config.get("workflows", [])
    updated = 0

    for wf_name in enabled:
        if wf_name not in ALL_WORKFLOWS:
            continue
        wf = ALL_WORKFLOWS[wf_name]
        filepath = os.path.join(workflows_dir, wf["filename"])
        if not os.path.exists(filepath):
            continue

        with open(filepath) as f:
            content = f.read()

        if old_sha and old_sha in content:
            content = content.replace(old_sha, new_sha)
            content = content.replace(f"# {old_tag}", f"# {new_tag}")
            with open(filepath, "w") as f:
                f.write(content)
            updated += 1
            print(f"  Updated: .github/workflows/{wf['filename']}")

    # Update .standard.yml
    config["sha"] = new_sha
    config["tag"] = new_tag
    write_config(config_path, config)

    print(f"\nUpdated {updated} workflow(s): {old_tag} -> {new_tag}")


def cmd_install_starters(args):
    """Install starter workflow templates into an org's .github repo."""
    from standard_ci.starters import install_starters

    print(f"Resolving {'tag ' + args.pin if args.pin else 'latest tag'}...")
    try:
        sha, tag_name = resolve_tag_sha(args.pin)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"  {tag_name} -> {sha[:12]}")

    try:
        messages = install_starters(
            org=args.org,
            sha=sha,
            tag=tag_name,
            dry_run=args.dry_run,
            create_repo=args.create_repo,
        )
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    for msg in messages:
        print(msg)


def cmd_check(args):
    """Validate workflows match .standard.yml."""
    project_dir = args.output_dir or "."
    issues = check(project_dir)
    has_errors = False

    for level, msg in issues:
        if level == "error":
            print(f"ERROR: {msg}")
            has_errors = True
        elif level == "warning":
            print(f"WARNING: {msg}")
        else:
            print(f"OK: {msg}")

    if has_errors:
        sys.exit(1)


def cmd_scan(args):
    """Scan an org for .standard.yml compliance."""
    from standard_ci.scanner import scan_org

    token = args.token or os.environ.get("GITHUB_TOKEN", "")
    print(f"Scanning {args.org}...", file=sys.stderr)

    try:
        results, latest_tag, latest_sha = scan_org(args.org, token)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        from standard_ci.dashboard import generate_dashboard

        print(generate_dashboard(results, latest_tag, latest_sha, args.org, fmt="json"))
    else:
        configured = [r for r in results if r["has_config"]]
        current = [r for r in configured if r["up_to_date"]]
        drifted = [r for r in configured if not r["up_to_date"]]
        unconfigured = [r for r in results if not r["has_config"]]

        print(f"\nLatest: {latest_tag} ({latest_sha[:12]})\n", file=sys.stderr)
        for r in sorted(results, key=lambda x: x["repo"]):
            name = r["repo"].split("/")[-1]
            if r["has_config"] and r["up_to_date"]:
                print(f"  {name:<30} {r['current_tag']:<12} OK", file=sys.stderr)
            elif r["has_config"]:
                print(f"  {name:<30} {r['current_tag']:<12} DRIFT -> {latest_tag}", file=sys.stderr)
            else:
                print(f"  {name:<30} {'':12} NO CONFIG", file=sys.stderr)

        print(f"\n{len(results)} repos: {len(current)} current, "
              f"{len(drifted)} drifted, {len(unconfigured)} unconfigured", file=sys.stderr)

    if args.exit_code:
        drifted = [r for r in results if r["has_config"] and not r["up_to_date"]]
        if drifted:
            sys.exit(1)


def cmd_dashboard(args):
    """Generate an org-wide compliance dashboard."""
    from standard_ci.dashboard import generate_dashboard
    from standard_ci.scanner import scan_org

    token = args.token or os.environ.get("GITHUB_TOKEN", "")

    if args.scan_results:
        import json

        try:
            with open(args.scan_results) as f:
                content = f.read()
            if not content.strip():
                print(f"Error: scan results file is empty: {args.scan_results}",
                      file=sys.stderr)
                sys.exit(1)
            data = json.loads(content)
        except json.JSONDecodeError as e:
            print(f"Error: invalid JSON in scan results: {e}", file=sys.stderr)
            sys.exit(1)
        except FileNotFoundError:
            print(f"Error: scan results file not found: {args.scan_results}",
                  file=sys.stderr)
            sys.exit(1)
        results = data["repos"]
        latest_tag = data["latest_tag"]
        latest_sha = data["latest_sha"]
    else:
        print(f"Scanning {args.org}...", file=sys.stderr)
        try:
            results, latest_tag, latest_sha = scan_org(args.org, token)
        except RuntimeError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

    output = generate_dashboard(
        results, latest_tag, latest_sha, args.org, fmt=args.format
    )
    print(output)


def cmd_auto_update(args):
    """Open update PRs in drifted consumer repos."""
    from standard_ci.auto_update import auto_update_repos

    token = args.token or os.environ.get("GITHUB_TOKEN", "")

    if args.scan_results:
        import json

        try:
            with open(args.scan_results) as f:
                content = f.read()
            if not content.strip():
                print(f"Error: scan results file is empty: {args.scan_results}",
                      file=sys.stderr)
                sys.exit(1)
            data = json.loads(content)
        except json.JSONDecodeError as e:
            print(f"Error: invalid JSON in scan results: {e}", file=sys.stderr)
            sys.exit(1)
        except FileNotFoundError:
            print(f"Error: scan results file not found: {args.scan_results}",
                  file=sys.stderr)
            sys.exit(1)
        scan_results = data["repos"]
        latest_tag = data["latest_tag"]
        latest_sha = data["latest_sha"]
    else:
        from standard_ci.scanner import scan_org

        print(f"Scanning {args.org}...", file=sys.stderr)
        try:
            scan_results, latest_tag, latest_sha = scan_org(args.org, token)
        except RuntimeError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

    messages = auto_update_repos(
        scan_results,
        latest_tag,
        latest_sha,
        pr_title_prefix=args.pr_title_prefix,
        pr_labels=args.pr_labels,
        dry_run=args.dry_run,
        token=token,
    )
    for msg in messages:
        print(msg)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="standard-ci",
        description="Setup and manage standard quality workflows",
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}"
    )

    sub = parser.add_subparsers(dest="command")

    # init
    p_init = sub.add_parser("init", help="Scaffold workflow files")
    p_init.add_argument(
        "--preset",
        choices=["minimal", "recommended", "full"],
        default="recommended",
        help="Preset configuration (default: recommended)",
    )
    p_init.add_argument(
        "--non-interactive",
        action="store_true",
        help="Accept all defaults without prompting",
    )
    p_init.add_argument("--pin", metavar="TAG", help="Pin to specific tag (default: latest)")
    p_init.add_argument("--output-dir", metavar="DIR", help="Project directory (default: .)")

    # update
    p_update = sub.add_parser("update", help="Update SHA pins to latest release")
    p_update.add_argument("--dry-run", action="store_true", help="Show what would change")
    p_update.add_argument("--pin", metavar="TAG", help="Pin to specific tag (default: latest)")
    p_update.add_argument("--output-dir", metavar="DIR", help="Project directory (default: .)")

    # install-starters
    p_starters = sub.add_parser(
        "install-starters",
        help="Install starter workflow templates into an org's .github repo",
    )
    p_starters.add_argument(
        "--org", required=True, help="GitHub org or user (e.g. MyOrg)"
    )
    p_starters.add_argument(
        "--pin", metavar="TAG", help="Pin to specific tag (default: latest)"
    )
    p_starters.add_argument(
        "--dry-run", action="store_true", help="Show what would change"
    )
    p_starters.add_argument(
        "--create-repo", action="store_true",
        help="Create the .github repo if it doesn't exist",
    )

    # check
    p_check = sub.add_parser("check", help="Validate setup matches .standard.yml")
    p_check.add_argument("--output-dir", metavar="DIR", help="Project directory (default: .)")

    # scan
    p_scan = sub.add_parser("scan", help="Scan org repos for compliance")
    p_scan.add_argument("--org", required=True, help="GitHub org or user to scan")
    p_scan.add_argument("--token", help="GitHub token (default: GITHUB_TOKEN env)")
    p_scan.add_argument("--json", action="store_true", help="Output as JSON")
    p_scan.add_argument(
        "--exit-code", action="store_true",
        help="Exit non-zero if any repo is non-compliant",
    )

    # dashboard
    p_dash = sub.add_parser("dashboard", help="Generate compliance dashboard")
    p_dash.add_argument("--org", required=True, help="GitHub org or user")
    p_dash.add_argument("--token", help="GitHub token (default: GITHUB_TOKEN env)")
    p_dash.add_argument(
        "--format", choices=["markdown", "json"], default="markdown",
        help="Output format (default: markdown)",
    )
    p_dash.add_argument(
        "--scan-results", metavar="FILE",
        help="Use pre-computed scan results JSON instead of scanning",
    )

    # auto-update
    p_auto = sub.add_parser(
        "auto-update", help="Open update PRs in drifted consumer repos",
    )
    p_auto.add_argument("--org", required=True, help="GitHub org or user")
    p_auto.add_argument("--token", help="GitHub token (default: GITHUB_TOKEN env)")
    p_auto.add_argument("--dry-run", action="store_true", help="Show what would change")
    p_auto.add_argument(
        "--scan-results", metavar="FILE",
        help="Use pre-computed scan results JSON instead of scanning",
    )
    p_auto.add_argument(
        "--pr-title-prefix", default="chore(deps): ",
        help="Prefix for auto-update PR titles",
    )
    p_auto.add_argument(
        "--pr-labels", default="dependencies,standard-ci",
        help="Comma-separated labels for auto-update PRs",
    )

    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help()
        sys.exit(1)

    commands = {
        "init": cmd_init,
        "update": cmd_update,
        "check": cmd_check,
        "install-starters": cmd_install_starters,
        "scan": cmd_scan,
        "dashboard": cmd_dashboard,
        "auto-update": cmd_auto_update,
    }
    commands[args.command](args)
