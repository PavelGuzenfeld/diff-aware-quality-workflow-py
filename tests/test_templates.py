"""Tests for workflow YAML generation."""

from standard_ci.templates import generate_workflow


class TestGenerateWorkflow:
    SHA = "abc123def456789012345678901234567890abcd"
    TAG = "v2.2.3.4"

    def test_cpp_quality_minimal(self):
        yaml = generate_workflow(
            "cpp-quality",
            {"docker_image": "ghcr.io/org/builder:latest"},
            self.SHA,
            self.TAG,
        )
        assert "name: C++ Quality" in yaml
        assert f"@{self.SHA}  # {self.TAG}" in yaml
        assert "docker_image: 'ghcr.io/org/builder:latest'" in yaml
        assert "pull-requests: write" in yaml
        # Default values should NOT appear
        assert "compile_commands_path" not in yaml

    def test_cpp_quality_with_opts(self):
        yaml = generate_workflow(
            "cpp-quality",
            {
                "docker_image": "ghcr.io/org/builder:latest",
                "enable_clang_format": True,
                "enable_flawfinder": True,
            },
            self.SHA,
            self.TAG,
        )
        assert "enable_clang_format: true" in yaml
        assert "enable_flawfinder: true" in yaml
        assert "security-events: write" in yaml

    def test_python_quality_defaults(self):
        yaml = generate_workflow("python-quality", {}, self.SHA, self.TAG)
        assert "name: Python Quality" in yaml
        assert "with:" not in yaml  # all defaults
        assert "contents: read" in yaml

    def test_python_quality_custom_linter(self):
        yaml = generate_workflow(
            "python-quality",
            {"python_linter": "flake8"},
            self.SHA,
            self.TAG,
        )
        assert "python_linter: flake8" in yaml

    def test_infra_lint(self):
        yaml = generate_workflow(
            "infra-lint",
            {"enable_shellcheck": True, "enable_gitleaks": True},
            self.SHA,
            self.TAG,
        )
        assert "enable_shellcheck: true" in yaml
        assert "enable_gitleaks: true" in yaml

    def test_sast_python(self):
        yaml = generate_workflow(
            "sast-python",
            {"enable_codeql": True},
            self.SHA,
            self.TAG,
        )
        assert "enable_codeql: true" in yaml
        assert "security-events: write" in yaml
        # semgrep and pip_audit are True by default — should not appear
        assert "enable_semgrep" not in yaml
        assert "enable_pip_audit" not in yaml

    def test_default_values_omitted(self):
        yaml = generate_workflow(
            "cpp-quality",
            {
                "docker_image": "img:latest",
                "compile_commands_path": "build",  # matches default
                "enable_clang_format": False,  # matches default
            },
            self.SHA,
            self.TAG,
        )
        assert "compile_commands_path" not in yaml
        assert "enable_clang_format" not in yaml

    def test_valid_yaml_structure(self):
        yaml = generate_workflow(
            "cpp-quality",
            {"docker_image": "img:latest"},
            self.SHA,
            self.TAG,
        )
        lines = yaml.splitlines()
        assert lines[0] == "name: C++ Quality"
        assert "on:" in yaml
        assert "jobs:" in yaml
        assert "permissions:" in yaml
