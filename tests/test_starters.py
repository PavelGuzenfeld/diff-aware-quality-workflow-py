"""Tests for starter workflow template generation."""

import json

from standard_ci.starters import (
    TEMPLATES,
    generate_all_files,
    generate_properties_json,
    generate_starter_workflow,
)

FAKE_SHA = "abc123def456789012345678901234567890abcd"
FAKE_TAG = "v0.14.1"


class TestGenerateStarterWorkflow:
    def test_cpp_quality_has_sha_pin(self):
        tmpl = TEMPLATES[0]
        assert tmpl["slug"] == "standard-cpp-quality"
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert f"@{FAKE_SHA}" in yaml
        assert f"# {FAKE_TAG}" in yaml

    def test_cpp_quality_has_default_branch(self):
        tmpl = TEMPLATES[0]
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "$default-branch" in yaml

    def test_cpp_quality_has_docker_todo(self):
        tmpl = TEMPLATES[0]
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "# TODO:" in yaml

    def test_python_quality_has_sast(self):
        tmpl = TEMPLATES[1]
        assert tmpl["slug"] == "standard-python-quality"
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "sast-python.yml" in yaml
        assert "python-quality.yml" in yaml

    def test_full_quality_has_all_workflows(self):
        tmpl = TEMPLATES[2]
        assert tmpl["slug"] == "standard-full-quality"
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "cpp-quality.yml" in yaml
        assert "python-quality.yml" in yaml
        assert "sast-python.yml" in yaml
        assert "infra-lint.yml" in yaml

    def test_full_quality_infra_has_cmake_lint(self):
        tmpl = TEMPLATES[2]
        yaml = generate_starter_workflow(tmpl, FAKE_SHA, FAKE_TAG)
        assert "enable_cmake_lint: true" in yaml


class TestGenerateProperties:
    def test_valid_json(self):
        for tmpl in TEMPLATES:
            raw = generate_properties_json(tmpl)
            data = json.loads(raw)
            assert "name" in data
            assert "description" in data
            assert "filePatterns" in data

    def test_cpp_file_patterns(self):
        tmpl = TEMPLATES[0]
        data = json.loads(generate_properties_json(tmpl))
        assert "CMakeLists.txt" in data["filePatterns"]

    def test_python_file_patterns(self):
        tmpl = TEMPLATES[1]
        data = json.loads(generate_properties_json(tmpl))
        assert "pyproject.toml" in data["filePatterns"]


class TestGenerateAllFiles:
    def test_generates_7_files(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        assert len(files) == 7  # 3 yml + 3 json + 1 svg

    def test_all_paths_under_workflow_templates(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        for path in files:
            assert path.startswith("workflow-templates/")

    def test_icon_svg_present(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        assert "workflow-templates/standard-icon.svg" in files

    def test_all_ymls_have_sha(self):
        files = generate_all_files(FAKE_SHA, FAKE_TAG)
        for path, content in files.items():
            if path.endswith(".yml"):
                assert FAKE_SHA in content
