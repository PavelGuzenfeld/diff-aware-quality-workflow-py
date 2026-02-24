# Code Review Instructions

This repository follows the [standard](https://github.com/PavelGuzenfeld/standard) quality gates.
All reviews must enforce these rules on changed code.

## Diff-Aware Review

- Only flag issues in changed lines — do not comment on unchanged legacy code
- Every new or modified line must comply with the rules below

## File and Directory Naming

- All files and directories must be `snake_case` (lowercase letters, digits, underscores)
- Valid: `flight_controller.cpp`, `nav_utils/`, `terrain_map.hpp`
- Invalid: `FlightController.cpp`, `NavUtils/`, `terrainMap.hpp`
- Exempt: `CMakeLists.txt`, `Dockerfile`, `README.md`, `LICENSE`, `CHANGELOG.md`, `AGENTS.md`, dotfiles, `__init__.py`

## Banned Patterns (Production Code)

Flag any of these in non-test files:

| Pattern | Alternative |
|---------|-------------|
| `std::cout`, `std::cerr`, `printf`, `fprintf`, `puts` | Use the project's structured logger |
| `new T`, `delete p` | `std::make_unique<T>()`, `std::make_shared<T>()` |
| `#include <gtest/gtest.h>` | `#include <doctest/doctest.h>` |
| `#include <benchmark/benchmark.h>` | `#include <nanobench.h>` |

## Security

- No hardcoded secrets, tokens, passwords, or API keys
- No command injection vectors (`system()`, `popen()` with unsanitized input)
- No SQL injection, XSS, or OWASP Top 10 vulnerabilities
- Prefer `std::expected` over exceptions for error handling

## Git and PR Hygiene

- Commit messages must use conventional prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- No AI attribution lines (`Co-Authored-By`, "Generated with Claude Code", etc.)
- No commented-out code blocks — delete dead code instead

## Testing

- Every non-trivial change should have corresponding tests
- Tests must cover: empty inputs, boundary conditions, single-element cases, invalid inputs
- Test files must use doctest (`TEST_CASE`, `CHECK`, `REQUIRE`), not gtest
