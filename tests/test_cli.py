"""End-to-end tests for the standard-ci CLI."""

from unittest import mock

from standard_ci.cli import main
from standard_ci.config import read_config

FAKE_SHA = "abc123def456789012345678901234567890abcd"
FAKE_TAG = "v2.2.3.4"


def _mock_resolve(tag=None):
    return FAKE_SHA, FAKE_TAG


class TestCLIInit:
    def test_init_minimal_noninteractive_cpp(self, tmp_path):
        project = tmp_path / "myproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main([
                "init",
                "--preset", "minimal",
                "--non-interactive",
                "--output-dir", str(project),
            ])

        # Check workflow files were generated
        wf_dir = project / ".github" / "workflows"
        assert (wf_dir / "cpp-quality.yml").exists()
        assert (wf_dir / "infra-lint.yml").exists()

        # Check .standard.yml
        config = read_config(str(project / ".standard.yml"))
        assert config["preset"] == "minimal"
        assert config["sha"] == FAKE_SHA
        assert config["tag"] == FAKE_TAG
        assert "cpp-quality" in config["workflows"]

        # Check SHA pin in generated file
        content = (wf_dir / "cpp-quality.yml").read_text()
        assert FAKE_SHA in content
        assert FAKE_TAG in content

    def test_init_recommended_noninteractive_python(self, tmp_path):
        project = tmp_path / "pyproject"
        project.mkdir()
        (project / "pyproject.toml").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main([
                "init",
                "--preset", "recommended",
                "--non-interactive",
                "--output-dir", str(project),
            ])

        wf_dir = project / ".github" / "workflows"
        assert (wf_dir / "python-quality.yml").exists()
        assert (wf_dir / "sast-python.yml").exists()
        assert (wf_dir / "infra-lint.yml").exists()
        # No C++ workflow for a Python project
        assert not (wf_dir / "cpp-quality.yml").exists()

    def test_init_full_noninteractive_both(self, tmp_path):
        project = tmp_path / "fullproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()
        (project / "pyproject.toml").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main([
                "init",
                "--preset", "full",
                "--non-interactive",
                "--output-dir", str(project),
            ])

        wf_dir = project / ".github" / "workflows"
        assert (wf_dir / "cpp-quality.yml").exists()
        assert (wf_dir / "python-quality.yml").exists()
        assert (wf_dir / "sast-python.yml").exists()
        assert (wf_dir / "infra-lint.yml").exists()

        # Full preset should have extra options enabled
        content = (wf_dir / "cpp-quality.yml").read_text()
        assert "enable_clang_format: true" in content
        assert "ban_cout: true" in content


class TestCLICheck:
    def test_check_passes(self, tmp_path):
        project = tmp_path / "checkproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main([
                "init",
                "--preset", "minimal",
                "--non-interactive",
                "--output-dir", str(project),
            ])

        # check should pass without error
        main(["check", "--output-dir", str(project)])

    def test_check_fails_no_config(self, tmp_path, capsys):
        try:
            main(["check", "--output-dir", str(tmp_path)])
            assert False, "Should have exited"
        except SystemExit as e:
            assert e.code == 1
        captured = capsys.readouterr()
        assert "not found" in captured.out


class TestCLIUpdate:
    def test_update_dry_run(self, tmp_path, capsys):
        project = tmp_path / "updateproject"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main([
                "init",
                "--preset", "minimal",
                "--non-interactive",
                "--output-dir", str(project),
            ])

        new_sha = "new123def456789012345678901234567890neww"
        new_tag = "v3.0.0"

        def _mock_new(tag=None):
            return new_sha, new_tag

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_new):
            main([
                "update",
                "--dry-run",
                "--output-dir", str(project),
            ])

        captured = capsys.readouterr()
        assert "Would update" in captured.out

        # File should NOT be changed (dry run)
        content = (project / ".github" / "workflows" / "cpp-quality.yml").read_text()
        assert FAKE_SHA in content

    def test_update_applies(self, tmp_path):
        project = tmp_path / "updateproject2"
        project.mkdir()
        (project / "CMakeLists.txt").touch()

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_resolve):
            main([
                "init",
                "--preset", "minimal",
                "--non-interactive",
                "--output-dir", str(project),
            ])

        new_sha = "new123def456789012345678901234567890neww"
        new_tag = "v3.0.0"

        def _mock_new(tag=None):
            return new_sha, new_tag

        with mock.patch("standard_ci.cli.resolve_tag_sha", side_effect=_mock_new):
            main([
                "update",
                "--output-dir", str(project),
            ])

        content = (project / ".github" / "workflows" / "cpp-quality.yml").read_text()
        assert new_sha in content
        assert FAKE_SHA not in content

        config = read_config(str(project / ".standard.yml"))
        assert config["sha"] == new_sha
        assert config["tag"] == new_tag
