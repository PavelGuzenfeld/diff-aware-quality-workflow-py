# Diff-Aware Code Quality Workflow Demo

Example repository demonstrating a production-ready, diff-aware CI/CD workflow for Python projects using GitHub Actions.

## 🎯 Goal

Enforce high quality standards on **new and modified code** without being blocked by technical debt in the existing codebase.

## ✨ Key Features

### 1. **Diff-Aware Linting**
Only new or modified lines are linted using `flake8 --diff`.

### 2. **Intelligent Test Selection**
Only tests affected by code changes are run using `pytest-testmon`.

### 3. **Targeted Code Coverage**
Coverage is measured only for new and modified lines using `diff-cover`.

### 4. **Parallel Execution**
Selected tests run in parallel for maximum speed using `pytest-xdist`.

### 5. **Separated Workflows**
- **Gatekeeper**: Fast checks on pushes to main (multi-version, parallel)
- **Collaborator**: Detailed PR feedback with line-by-line analysis

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│           Push to main/develop              │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
        ┌─────────────────────┐
        │ Gatekeeper Workflow │
        │  (Fast & Parallel)  │
        └─────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
  ┌──────────┐        ┌──────────┐
  │ Python   │   ...  │ Python   │
  │  3.8     │        │  3.12    │
  └──────────┘        └──────────┘
        │                   │
        └─────────┬─────────┘
                  ▼
          Run affected tests
          with pytest-testmon


┌─────────────────────────────────────────────┐
│            Open Pull Request                │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
     ┌────────────────────────────┐
     │ Pull Request Feedback      │
     │  (Detailed Analysis)       │
     └────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
  ┌──────────┐      ┌────────────────┐
  │ Diff     │      │ Diff Coverage  │
  │ Linting  │      │ Report         │
  └──────────┘      └────────────────┘
        │                   │
        └─────────┬─────────┘
                  ▼
        Post results as PR comment
```

## 📦 Tech Stack

- **Testing**: `pytest`, `pytest-cov`, `pytest-testmon`, `pytest-xdist`
- **Linting**: `flake8`
- **Coverage**: `diff-cover`
- **Build**: `hatchling`
- **CI/CD**: GitHub Actions

## 🚀 Quick Start

### Prerequisites
- Python 3.8 or higher
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/diff-aware-quality-workflow-py.git
cd diff-aware-quality-workflow-py

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Run Tests Locally

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov

# Run only affected tests (after making changes)
pytest --testmon

# Run tests in parallel
pytest -n auto
```

### Run Linting Locally

```bash
# Lint entire codebase
flake8 src/ tests/

# Lint only changed lines (requires git)
git diff -U0 main | flake8 --diff
```

## 🎬 Demo Walkthrough

### Scenario 1: Introducing a New Bug

This demonstrates how the workflow catches issues in new code.

1. **Create a feature branch**
   ```bash
   git checkout -b feature/add-power-function
   ```

2. **Add a new function with a linting issue**
   
   Edit `src/calculator.py` and add:
   ```python
   def power(a, b):
       """Calculate a to the power of b."""
       unused_var = "oops"  # This will trigger F841
       return a ** b
   ```

3. **Commit and push**
   ```bash
   git add src/calculator.py
   git commit -m "Add power function"
   git push origin feature/add-power-function
   ```

4. **Open a Pull Request**
   
   The PR workflow will:
   - ❌ Catch the `F841` error in the new code
   - ✅ Ignore the existing `F841` in `subtract()` (legacy code)
   - 📊 Post coverage report showing the new function

5. **Fix the issue**
   
   Remove the unused variable:
   ```python
   def power(a, b):
       """Calculate a to the power of b."""
       return a ** b
   ```

6. **Push the fix**
   ```bash
   git add src/calculator.py
   git commit -m "Fix linting issue"
   git push
   ```

7. **Workflow passes** ✅

### Scenario 2: Legacy Code Tolerance

This demonstrates how existing issues don't block new work.

1. **Notice the existing issue**
   
   `src/calculator.py` has `unused_variable = 123` in `subtract()`
   
2. **Verify it's ignored**
   
   Check `.flake8`:
   ```ini
   per-file-ignores =
       src/calculator.py:F841
   ```

3. **Add a new test**
   
   Edit `tests/test_calculator.py`:
   ```python
   def test_add_zero(self):
       """Test adding zero."""
       assert add(5, 0) == 5
   ```

4. **Commit and create PR**
   ```bash
   git checkout -b feature/test-add-zero
   git add tests/test_calculator.py
   git commit -m "Add test for adding zero"
   git push origin feature/test-add-zero
   ```

5. **PR passes** ✅ despite legacy code issues

### Scenario 3: Performance Benefits

This demonstrates the speed improvements from intelligent test selection.

1. **Make a small change**
   
   Edit docstring in `src/calculator.py`:
   ```python
   def add(a, b):
       """Add two numbers together."""  # Changed
       return a + b
   ```

2. **Run without testmon** (all tests)
   ```bash
   pytest
   # All 13 tests run
   ```

3. **Run with testmon** (affected tests only)
   ```bash
   pytest --testmon
   # Only 3 tests run (those testing add function)
   ```

4. **Observe the speedup** 🚀

## 📁 Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── gatekeeper-checks.yml      # Fast multi-version testing
│       └── pull-request-feedback.yml  # Detailed PR analysis
├── src/
│   ├── __init__.py
│   └── calculator.py                  # Example module (with legacy issue)
├── tests/
│   ├── __init__.py
│   └── test_calculator.py             # Comprehensive test suite
├── .flake8                            # Linting configuration
├── .gitignore                         # Git ignore rules
├── pyproject.toml                     # Project metadata & tool configs
├── requirements.txt                   # Python dependencies
├── LICENSE                            # MIT License
└── README.md                          # This file
```

## ⚙️ Configuration Details

### Gatekeeper Workflow

**Triggers**: Push to `main` or `develop`

**Strategy**:
- Matrix build across Python 3.8-3.12
- Parallel execution with `pytest-xdist`
- Intelligent test selection with `pytest-testmon`
- Caching of `.testmondata` for speed

**Benefits**:
- Fast feedback (only affected tests)
- Multi-version compatibility check
- Efficient use of CI minutes

### Pull Request Feedback Workflow

**Triggers**: PR opened, synchronized, or reopened

**Features**:
- Diff-aware linting (`flake8 --diff`)
- Coverage only on changed lines (`diff-cover`)
- Automatic PR comments with results
- Fails PR if new linting issues found

**Benefits**:
- Clear, actionable feedback
- No noise from legacy code
- Encourages quality in new code

### Legacy Code Handling

The `.flake8` configuration uses `per-file-ignores` to suppress known issues:

```ini
per-file-ignores =
    src/calculator.py:F841
```

This allows you to:
- ✅ Enforce standards on new code
- ✅ Gradually fix legacy issues
- ✅ Avoid "big bang" refactoring
- ✅ Ship features without tech debt blockers

## 🔧 Customization Guide

### Add More Python Versions

Edit `.github/workflows/gatekeeper-checks.yml`:
```yaml
strategy:
  matrix:
    python-version: ['3.8', '3.9', '3.10', '3.11', '3.12', '3.13']
```

### Adjust Linting Rules

Edit `.flake8`:
```ini
[flake8]
max-line-length = 100  # Increase line length
extend-ignore = E203, W503, E402  # Add more ignores
```

### Change Coverage Thresholds

Edit `pyproject.toml`:
```toml
[tool.coverage.report]
fail_under = 80  # Require 80% coverage
```

### Add More Test Options

Edit `pyproject.toml`:
```toml
[tool.pytest.ini_options]
addopts = "-v --tb=short --strict-markers"
```

## 🐛 Troubleshooting

### Tests not being selected by testmon

**Problem**: `pytest --testmon` runs all tests

**Solution**: Delete `.testmondata` and rebuild:
```bash
rm -rf .testmondata
pytest --testmon
```

### Flake8 --diff not working locally

**Problem**: `git diff | flake8 --diff` shows no output

**Solution**: Ensure you have uncommitted changes:
```bash
# Check diff
git diff

# If empty, make changes or use:
git diff HEAD~1 | flake8 --diff
```

### PR workflow not posting comments

**Problem**: No comment appears on PR

**Check**:
1. Workflow has `pull-requests: write` permission
2. GitHub token has correct scopes
3. Check workflow logs for errors

## 📚 Further Reading

- [pytest-testmon documentation](https://testmon.org/)
- [diff-cover documentation](https://github.com/Bachmann1234/diff_cover)
- [flake8 documentation](https://flake8.pycqa.org/)
- [GitHub Actions documentation](https://docs.github.com/en/actions)

## 🤝 Contributing

This is a demo repository, but feel free to:
- Open issues for questions
- Submit PRs with improvements
- Fork and adapt for your projects

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Built with excellent tools from the Python community:
- pytest team
- flake8 maintainers
- diff-cover contributors
- GitHub Actions team

---

**Questions?** Open an issue or check the workflows for inline comments explaining each step.