"""Tests for the scanner module."""

import base64
import json
from unittest.mock import MagicMock, patch

from standard_ci.scanner import (
    fetch_standard_config,
    list_org_repos,
    scan_org,
    scan_repo,
)


def _make_config_yaml(tag="v0.16.1", sha="abc123def456"):
    return f"tag: {tag}\nsha: {sha}\nworkflows:\n  - cpp-quality\n  - infra-lint\n"


def _make_api_response(data, link_header=""):
    """Create a mock urllib response."""
    mock_resp = MagicMock()
    mock_resp.read.return_value = json.dumps(data).encode()
    mock_resp.headers = {"Link": link_header}
    mock_resp.__enter__ = lambda s: s
    mock_resp.__exit__ = MagicMock(return_value=False)
    return mock_resp


class TestListOrgRepos:
    @patch("standard_ci.scanner.urllib.request.urlopen")
    def test_returns_non_archived_repos(self, mock_urlopen):
        repos = [
            {"full_name": "org/repo1", "default_branch": "main",
             "archived": False, "fork": False},
            {"full_name": "org/repo2", "default_branch": "develop",
             "archived": True, "fork": False},
            {"full_name": "org/repo3", "default_branch": "main",
             "archived": False, "fork": True},
            {"full_name": "org/repo4", "default_branch": "main",
             "archived": False, "fork": False},
        ]
        mock_urlopen.return_value = _make_api_response(repos)
        result = list_org_repos("org", token="test-token")
        assert len(result) == 2
        assert result[0]["full_name"] == "org/repo1"
        assert result[1]["full_name"] == "org/repo4"

    @patch("standard_ci.scanner.urllib.request.urlopen")
    def test_paginates(self, mock_urlopen):
        page1 = [{"full_name": "org/a", "default_branch": "main",
                   "archived": False, "fork": False}]
        page2 = [{"full_name": "org/b", "default_branch": "main",
                   "archived": False, "fork": False}]

        resp1 = _make_api_response(
            page1, link_header='<https://api.github.com/next>; rel="next"'
        )
        resp2 = _make_api_response(page2)
        mock_urlopen.side_effect = [resp1, resp2]

        result = list_org_repos("org", token="t")
        assert len(result) == 2
        assert result[0]["full_name"] == "org/a"
        assert result[1]["full_name"] == "org/b"


class TestFetchStandardConfig:
    @patch("standard_ci.scanner.urllib.request.urlopen")
    def test_returns_parsed_config(self, mock_urlopen):
        yaml_content = _make_config_yaml()
        encoded = base64.b64encode(yaml_content.encode()).decode()
        mock_urlopen.return_value = _make_api_response({"content": encoded})

        config = fetch_standard_config("org/repo", token="t")
        assert config is not None
        assert config["tag"] == "v0.16.1"
        assert config["sha"] == "abc123def456"
        assert "cpp-quality" in config["workflows"]

    @patch("standard_ci.scanner.urllib.request.urlopen")
    def test_returns_none_on_404(self, mock_urlopen):
        import urllib.error

        mock_urlopen.side_effect = urllib.error.HTTPError(
            "url", 404, "Not Found", {}, None
        )
        config = fetch_standard_config("org/repo", token="t")
        assert config is None


class TestScanRepo:
    def test_no_config(self):
        with patch("standard_ci.scanner.fetch_standard_config", return_value=None):
            result = scan_repo(
                {"full_name": "org/repo", "default_branch": "main"},
                "latest_sha", "v1.0.0", token="t",
            )
            assert not result["has_config"]
            assert "No .standard.yml found" in result["issues"]

    def test_up_to_date(self):
        config = {"tag": "v1.0.0", "sha": "latest_sha", "workflows": ["cpp-quality"]}
        with patch("standard_ci.scanner.fetch_standard_config", return_value=config):
            result = scan_repo(
                {"full_name": "org/repo", "default_branch": "main"},
                "latest_sha", "v1.0.0", token="t",
            )
            assert result["has_config"]
            assert result["up_to_date"]
            assert not result["issues"]

    def test_drifted(self):
        config = {"tag": "v0.9.0", "sha": "old_sha", "workflows": ["cpp-quality"]}
        with patch("standard_ci.scanner.fetch_standard_config", return_value=config):
            result = scan_repo(
                {"full_name": "org/repo", "default_branch": "main"},
                "latest_sha", "v1.0.0", token="t",
            )
            assert result["has_config"]
            assert not result["up_to_date"]
            assert any("drift" in i.lower() for i in result["issues"])


class TestScanOrg:
    @patch("standard_ci.scanner.resolve_tag_sha", return_value=("sha123", "v1.0.0"))
    @patch("standard_ci.scanner.list_org_repos")
    @patch("standard_ci.scanner.fetch_standard_config")
    def test_mixed_results(self, mock_fetch, mock_list, mock_resolve):
        mock_list.return_value = [
            {"full_name": "org/a", "default_branch": "main"},
            {"full_name": "org/b", "default_branch": "main"},
            {"full_name": "org/c", "default_branch": "main"},
        ]
        mock_fetch.side_effect = [
            {"tag": "v1.0.0", "sha": "sha123", "workflows": ["cpp-quality"]},
            {"tag": "v0.9.0", "sha": "old_sha", "workflows": ["infra-lint"]},
            None,
        ]

        results, tag, sha = scan_org("org", token="t")
        assert len(results) == 3
        assert tag == "v1.0.0"
        assert sha == "sha123"

        # First repo: up to date
        assert results[0]["up_to_date"]
        # Second repo: drifted
        assert not results[1]["up_to_date"]
        # Third repo: no config
        assert not results[2]["has_config"]
