"""Tests for project type auto-detection."""

import os

from standard_ci.detect import detect_languages, has_dockerfiles, has_shell_scripts


class TestDetectLanguages:
    def test_cpp_cmake(self, tmp_path):
        (tmp_path / "CMakeLists.txt").touch()
        assert detect_languages(str(tmp_path)) == {"cpp"}

    def test_cpp_package_xml(self, tmp_path):
        (tmp_path / "package.xml").touch()
        assert detect_languages(str(tmp_path)) == {"cpp"}

    def test_python_pyproject(self, tmp_path):
        (tmp_path / "pyproject.toml").touch()
        assert detect_languages(str(tmp_path)) == {"python"}

    def test_python_setup_py(self, tmp_path):
        (tmp_path / "setup.py").touch()
        assert detect_languages(str(tmp_path)) == {"python"}

    def test_python_requirements(self, tmp_path):
        (tmp_path / "requirements.txt").touch()
        assert detect_languages(str(tmp_path)) == {"python"}

    def test_both(self, tmp_path):
        (tmp_path / "CMakeLists.txt").touch()
        (tmp_path / "pyproject.toml").touch()
        assert detect_languages(str(tmp_path)) == {"cpp", "python"}

    def test_empty(self, tmp_path):
        assert detect_languages(str(tmp_path)) == set()


class TestHasDockerfiles:
    def test_found(self, tmp_path):
        (tmp_path / "Dockerfile").touch()
        assert has_dockerfiles(str(tmp_path)) is True

    def test_not_found(self, tmp_path):
        assert has_dockerfiles(str(tmp_path)) is False

    def test_multi_stage(self, tmp_path):
        (tmp_path / "Dockerfile.dev").touch()
        assert has_dockerfiles(str(tmp_path)) is True


class TestHasShellScripts:
    def test_found(self, tmp_path):
        (tmp_path / "build.sh").touch()
        assert has_shell_scripts(str(tmp_path)) is True

    def test_not_found(self, tmp_path):
        assert has_shell_scripts(str(tmp_path)) is False
