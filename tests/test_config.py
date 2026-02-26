"""Tests for .standard.yml config read/write."""

from standard_ci.config import read_config, write_config


class TestConfigRoundtrip:
    def test_flat_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"version": "0.12.0", "preset": "recommended", "sha": "abc123"}
        write_config(path, data)
        result = read_config(path)
        assert result["version"] == "0.12.0"
        assert result["preset"] == "recommended"
        assert result["sha"] == "abc123"

    def test_nested_dict(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {
            "version": "0.12.0",
            "cpp-quality": {
                "enable_clang_format": True,
                "ban_cout": False,
                "docker_image": "ghcr.io/org/image:latest",
            },
        }
        write_config(path, data)
        result = read_config(path)
        assert result["cpp-quality"]["enable_clang_format"] is True
        assert result["cpp-quality"]["ban_cout"] is False
        assert result["cpp-quality"]["docker_image"] == "ghcr.io/org/image:latest"

    def test_list_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"workflows": ["cpp-quality", "python-quality", "infra-lint"]}
        write_config(path, data)
        result = read_config(path)
        assert result["workflows"] == ["cpp-quality", "python-quality", "infra-lint"]

    def test_bool_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"enabled": True, "disabled": False}
        write_config(path, data)
        result = read_config(path)
        assert result["enabled"] is True
        assert result["disabled"] is False

    def test_empty_string(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"value": ""}
        write_config(path, data)
        result = read_config(path)
        assert result["value"] == ""

    def test_read_nonexistent(self, tmp_path):
        path = str(tmp_path / "missing.yml")
        assert read_config(path) == {}

    def test_numeric_values(self, tmp_path):
        path = str(tmp_path / ".standard.yml")
        data = {"count": 42, "ratio": 3.14}
        write_config(path, data)
        result = read_config(path)
        assert result["count"] == 42
        assert result["ratio"] == 3.14
