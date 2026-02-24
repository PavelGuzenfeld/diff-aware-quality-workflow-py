---
applyTo: "**/*.py"
---

# Python Review Rules

## Style

- Follow PEP 8
- Use type hints on all function signatures
- Use `snake_case` for functions and variables, `PascalCase` for classes
- Maximum line length: 88 characters (ruff/black default)

## Security

- No `eval()`, `exec()`, or `__import__()` with user input
- No hardcoded credentials or secrets
- Use parameterized queries for database access — never string formatting
- Validate and sanitize all external input

## Testing

- Use `pytest` — not `unittest`
- Every new function or class must have corresponding tests
- Use fixtures for setup/teardown, not `setUp`/`tearDown` methods

## Dependencies

- Pin dependency versions in `requirements.txt` or `pyproject.toml`
- No known-vulnerable packages (checked by pip-audit in CI)

## Error Handling

- Use specific exception types — never bare `except:`
- Document exceptions in docstrings when functions raise intentionally
