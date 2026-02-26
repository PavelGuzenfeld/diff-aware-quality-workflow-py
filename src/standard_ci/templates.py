"""Generate workflow YAML files from configuration."""

from standard_ci.workflows import ALL_WORKFLOWS

REPO = "PavelGuzenfeld/standard"


def _yaml_value(value):
    """Format a value for inline YAML."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        if not value:
            return "''"
        # Quote strings that could be misinterpreted
        if value in ("true", "false", "yes", "no", "null") or ":" in value:
            return f"'{value}'"
        return value
    return str(value)


def generate_workflow(workflow_name, inputs, sha, tag_name):
    """Generate a workflow YAML string.

    Args:
        workflow_name: key in ALL_WORKFLOWS (e.g. 'cpp-quality')
        inputs: dict of input values (only non-defaults are emitted)
        sha: full SHA to pin the workflow ref
        tag_name: tag name for the comment

    Returns:
        YAML string
    """
    wf = ALL_WORKFLOWS[workflow_name]
    lines = [
        f"name: {wf['workflow_name']}",
        "",
        "on:",
        "  pull_request:",
        "    branches: [main, master]",
        "  workflow_dispatch:",
        "",
        "jobs:",
        f"  {workflow_name.replace('-', '_')}:",
        f"    uses: {REPO}/{wf['ref_path']}@{sha}  # {tag_name}",
    ]

    # Collect non-default inputs
    all_inputs = {}
    all_inputs.update(wf["required_inputs"])
    all_inputs.update(wf["optional_inputs"])

    with_lines = []
    for key, meta in all_inputs.items():
        if key in inputs:
            value = inputs[key]
            # Skip if it matches the default
            if value == meta["default"]:
                continue
            with_lines.append(f"      {key}: {_yaml_value(value)}")
        elif key in wf["required_inputs"]:
            # Required but not provided — emit a TODO
            with_lines.append(f"      {key}: ''  # TODO: set this value")

    if with_lines:
        lines.append("    with:")
        lines.extend(with_lines)

    # Permissions
    perms = dict(wf["permissions"])
    for trigger_input, extra in wf.get("extra_permissions_if", {}).items():
        if inputs.get(trigger_input):
            perms.update(extra)

    lines.append("    permissions:")
    for perm, level in sorted(perms.items()):
        lines.append(f"      {perm}: {level}")

    lines.append("")
    return "\n".join(lines)
