"""Auto-detect project type from files in the working directory."""

import os


def detect_languages(path="."):
    """Return set of detected language categories: 'cpp', 'python'."""
    langs = set()
    entries = set(os.listdir(path))
    if "CMakeLists.txt" in entries or "package.xml" in entries:
        langs.add("cpp")
    if entries & {"pyproject.toml", "setup.py", "requirements.txt"}:
        langs.add("python")
    return langs


def has_dockerfiles(path="."):
    """Return True if any Dockerfile* exists."""
    return any(f.startswith("Dockerfile") for f in os.listdir(path))


def has_shell_scripts(path="."):
    """Return True if any .sh files exist in the tree (top-level only)."""
    return any(f.endswith(".sh") for f in os.listdir(path))
