"""Registry of reusable workflows and their inputs."""

# Each workflow entry: {input_name: {type, default, prompt, group}}
# 'group' is used to organize interactive prompts.
# Only inputs relevant to interactive setup are listed — obscure inputs
# (runner, exclude_file, etc.) are omitted; users can add them manually.

CPP_QUALITY = {
    "name": "cpp-quality",
    "filename": "cpp-quality.yml",
    "workflow_name": "C++ Quality",
    "ref_path": ".github/workflows/cpp-quality.yml",
    "required_inputs": {
        "docker_image": {
            "type": "string",
            "default": "",
            "prompt": "Docker image (ghcr.io/org/image:tag)",
        },
    },
    "optional_inputs": {
        "compile_commands_path": {
            "type": "string",
            "default": "build",
            "prompt": "compile_commands.json directory",
        },
        "source_setup": {
            "type": "string",
            "default": "",
            "prompt": "Source setup command (e.g. source /opt/ros/humble/setup.bash)",
        },
        "enable_clang_format": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable clang-format?",
            "group": "checks",
        },
        "enable_file_naming": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable file naming convention (snake_case)?",
            "group": "checks",
        },
        "ban_cout": {
            "type": "boolean",
            "default": False,
            "prompt": "Ban cout/printf in non-test code?",
            "group": "checks",
        },
        "ban_new": {
            "type": "boolean",
            "default": False,
            "prompt": "Ban raw new/delete in non-test code?",
            "group": "checks",
        },
        "enforce_doctest": {
            "type": "boolean",
            "default": False,
            "prompt": "Enforce doctest (ban gtest)?",
            "group": "checks",
        },
        "enable_flawfinder": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable flawfinder CWE scanning?",
            "group": "checks",
        },
        "enable_sarif": {
            "type": "boolean",
            "default": False,
            "prompt": "Upload SARIF to GitHub Security tab?",
            "group": "checks",
        },
        "enable_sanitizers": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable ASan/UBSan sanitizer tests?",
            "group": "runtime",
        },
        "enable_iwyu": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable Include-What-You-Use?",
            "group": "runtime",
        },
    },
    "permissions": {
        "actions": "read",
        "contents": "read",
        "packages": "read",
        "pull-requests": "write",
    },
    "extra_permissions_if": {
        "enable_flawfinder": {"security-events": "write"},
        "enable_sarif": {"security-events": "write"},
    },
}

PYTHON_QUALITY = {
    "name": "python-quality",
    "filename": "python-quality.yml",
    "workflow_name": "Python Quality",
    "ref_path": ".github/workflows/python-quality.yml",
    "required_inputs": {},
    "optional_inputs": {
        "python_linter": {
            "type": "string",
            "default": "ruff",
            "prompt": "Linter (ruff / flake8)",
        },
        "source_dirs": {
            "type": "string",
            "default": "src",
            "prompt": "Source directories (space-separated)",
        },
        "test_dirs": {
            "type": "string",
            "default": "tests",
            "prompt": "Test directories (space-separated)",
        },
        "enable_tests": {
            "type": "boolean",
            "default": True,
            "prompt": "Run pytest + coverage?",
            "group": "checks",
        },
    },
    "permissions": {
        "contents": "read",
        "pull-requests": "write",
    },
    "extra_permissions_if": {},
}

INFRA_LINT = {
    "name": "infra-lint",
    "filename": "infra-lint.yml",
    "workflow_name": "Infrastructure Lint",
    "ref_path": ".github/workflows/infra-lint.yml",
    "required_inputs": {},
    "optional_inputs": {
        "enable_shellcheck": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable ShellCheck (shell scripts)?",
            "group": "checks",
        },
        "enable_hadolint": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable Hadolint (Dockerfiles)?",
            "group": "checks",
        },
        "enable_cmake_lint": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable cmake-lint (CMake files)?",
            "group": "checks",
        },
        "enable_dangerous_workflows": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable dangerous-workflow audit?",
            "group": "checks",
        },
        "enable_binary_artifacts": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable binary artifact detection?",
            "group": "checks",
        },
        "enable_gitleaks": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable Gitleaks secrets detection?",
            "group": "checks",
        },
    },
    "permissions": {
        "actions": "read",
        "contents": "read",
        "pull-requests": "write",
    },
    "extra_permissions_if": {},
}

SAST_PYTHON = {
    "name": "sast-python",
    "filename": "sast-python.yml",
    "workflow_name": "Python SAST",
    "ref_path": ".github/workflows/sast-python.yml",
    "required_inputs": {},
    "optional_inputs": {
        "enable_semgrep": {
            "type": "boolean",
            "default": True,
            "prompt": "Enable Semgrep security scanning?",
            "group": "checks",
        },
        "enable_pip_audit": {
            "type": "boolean",
            "default": True,
            "prompt": "Enable pip-audit CVE scanning?",
            "group": "checks",
        },
        "enable_codeql": {
            "type": "boolean",
            "default": False,
            "prompt": "Enable CodeQL deep analysis?",
            "group": "checks",
        },
    },
    "permissions": {
        "actions": "read",
        "contents": "read",
        "pull-requests": "write",
        "security-events": "write",
    },
    "extra_permissions_if": {},
}

ALL_WORKFLOWS = {
    "cpp-quality": CPP_QUALITY,
    "python-quality": PYTHON_QUALITY,
    "infra-lint": INFRA_LINT,
    "sast-python": SAST_PYTHON,
}

LANGUAGE_WORKFLOWS = {
    "cpp": ["cpp-quality"],
    "python": ["python-quality", "sast-python"],
}

# Always offered regardless of language
COMMON_WORKFLOWS = ["infra-lint"]
