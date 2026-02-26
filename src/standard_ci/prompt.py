"""Interactive prompt helpers."""

import sys


def ask_yn(question, default=True):
    """Ask a yes/no question, return bool."""
    hint = "[Y/n]" if default else "[y/N]"
    try:
        answer = input(f"{question} {hint} ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(1)
    if not answer:
        return default
    return answer.startswith("y")


def ask_value(question, default=""):
    """Ask for a string value with a default."""
    suffix = f" [{default}]" if default else ""
    try:
        answer = input(f"{question}{suffix} ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(1)
    return answer if answer else default
