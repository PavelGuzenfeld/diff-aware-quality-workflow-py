"""Preset configurations: minimal, recommended, full."""

# Each preset maps workflow names to their input overrides.
# Only non-default values are listed — everything else uses the workflow default.

MINIMAL = {
    "cpp-quality": {
        # Just clang-tidy + cppcheck (always on) — no opt-ins
    },
    "python-quality": {
        # ruff + pytest (defaults)
    },
    "infra-lint": {
        # Nothing enabled — minimal means no infra lint
    },
    "sast-python": {
        "enable_semgrep": True,
        "enable_pip_audit": True,
    },
}

RECOMMENDED = {
    "cpp-quality": {
        "enable_clang_format": True,
        "enable_file_naming": True,
        "enable_flawfinder": True,
    },
    "python-quality": {},
    "infra-lint": {
        "enable_shellcheck": True,
        "enable_hadolint": True,
        "enable_gitleaks": True,
    },
    "sast-python": {
        "enable_semgrep": True,
        "enable_pip_audit": True,
    },
}

FULL = {
    "cpp-quality": {
        "enable_clang_format": True,
        "enable_file_naming": True,
        "ban_cout": True,
        "ban_new": True,
        "enforce_doctest": True,
        "enable_flawfinder": True,
        "enable_sarif": True,
        "enable_sanitizers": True,
        "enable_iwyu": True,
    },
    "python-quality": {},
    "infra-lint": {
        "enable_shellcheck": True,
        "enable_hadolint": True,
        "enable_cmake_lint": True,
        "enable_dangerous_workflows": True,
        "enable_binary_artifacts": True,
        "enable_gitleaks": True,
    },
    "sast-python": {
        "enable_semgrep": True,
        "enable_pip_audit": True,
        "enable_codeql": True,
    },
}

ALL_PRESETS = {
    "minimal": MINIMAL,
    "recommended": RECOMMENDED,
    "full": FULL,
}
