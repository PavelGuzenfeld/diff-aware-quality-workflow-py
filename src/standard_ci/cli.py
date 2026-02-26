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

    # check
    p_check = sub.add_parser("check", help="Validate setup matches .standard.yml")
    p_check.add_argument("--output-dir", metavar="DIR", help="Project directory (default: .)")

    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help()
        sys.exit(1)

    commands = {"init": cmd_init, "update": cmd_update, "check": cmd_check}
    commands[args.command](args)
