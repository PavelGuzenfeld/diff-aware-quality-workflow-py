---
applyTo: "**/*.{cpp,hpp,h,cc,cxx}"
---

# C++ Review Rules

## Language Standard

- Target C++23 — use modern features (`std::expected`, `std::optional`, structured bindings, concepts)
- Use `#pragma once` — not `#ifndef` include guards

## Identifier Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Functions / methods | `snake_case` | `compute_heading()` |
| Variables / parameters | `snake_case` | `max_altitude` |
| Types / classes / structs | `PascalCase` | `FlightController` |
| Private members | trailing `_` | `config_`, `state_` |
| Constants / enums | `UPPER_CASE` | `MAX_RETRIES` |
| Namespaces | `snake_case` | `nav_utils` |

Flag any `camelCase` function or variable name.

## Formatting

- 120-column limit
- 4-space indent, no tabs
- Allman braces (opening brace on its own line)
- No bin-packing of arguments or parameters

## Include Order

1. Standard library headers (`<algorithm>`, `<vector>`)
2. Project headers (`"project/header.hpp"`)

Minimize includes. Forward-declare where possible.

## Memory and Resource Safety

- No raw `new`/`delete` — use `std::make_unique` or `std::make_shared`
- No C-style casts — use `static_cast`, `dynamic_cast`, `reinterpret_cast`
- No raw owning pointers — wrap in smart pointers or containers
- Prefer RAII for resource management

## Error Handling

- Prefer `std::expected` over exceptions
- Never swallow errors silently
- Check return values from system calls and library functions

## Performance

- Pass large types by `const&` or move semantics
- Avoid unnecessary copies in range-based for loops (`const auto&`)
- Use `reserve()` when container size is known ahead of time
- Prefer `emplace_back` over `push_back` when constructing in-place
