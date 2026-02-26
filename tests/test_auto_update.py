"""Tests for the auto_update module."""

from unittest.mock import patch

from standard_ci.auto_update import auto_update_repos


def _sample_scan_results():
    return [
        {
            "repo": "org/current-repo",
            "has_config": True,
            "current_tag": "v1.0.0",
            "current_sha": "sha_latest",
            "up_to_date": True,
            "workflows": ["cpp-quality"],
            "issues": [],
        },
        {
            "repo": "org/drifted-repo",
            "has_config": True,
            "current_tag": "v0.9.0",
            "current_sha": "sha_old",
            "up_to_date": False,
            "workflows": ["cpp-quality"],
            "issues": ["SHA drift: v0.9.0 -> v1.0.0"],
        },
        {
            "repo": "org/no-config",
            "has_config": False,
            "current_tag": None,
            "current_sha": None,
            "up_to_date": False,
            "workflows": [],
            "issues": ["No .standard.yml found"],
        },
    ]


class TestAutoUpdateRepos:
    def test_dry_run_no_side_effects(self):
        messages = auto_update_repos(
            _sample_scan_results(),
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=True,
            token="test-token",
        )
        assert any("Would update org/drifted-repo" in m for m in messages)
        assert not any("current-repo" in m for m in messages)
        assert not any("no-config" in m for m in messages)

    def test_skips_up_to_date(self):
        results = [_sample_scan_results()[0]]  # only current
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=True,
            token="test-token",
        )
        assert any("up to date" in m.lower() for m in messages)

    def test_skips_no_config(self):
        results = [_sample_scan_results()[2]]  # only no-config
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=True,
            token="test-token",
        )
        assert any("up to date" in m.lower() for m in messages)

    @patch("standard_ci.auto_update._check_existing_pr", return_value=True)
    def test_skips_existing_pr(self, mock_check):
        results = [_sample_scan_results()[1]]  # drifted
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=False,
            token="test-token",
        )
        assert any("already open" in m.lower() for m in messages)

    @patch("standard_ci.auto_update._check_existing_pr", return_value=False)
    @patch("standard_ci.auto_update._update_single_repo")
    def test_opens_pr_for_drifted(self, mock_update, mock_check):
        results = [_sample_scan_results()[1]]  # drifted
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=False,
            token="test-token",
        )
        mock_update.assert_called_once()
        assert any("Opened PR" in m for m in messages)

    @patch("standard_ci.auto_update._check_existing_pr", return_value=False)
    @patch("standard_ci.auto_update._update_single_repo", side_effect=RuntimeError("clone failed"))
    def test_handles_failure_gracefully(self, mock_update, mock_check):
        results = [_sample_scan_results()[1]]  # drifted
        messages = auto_update_repos(
            results,
            latest_tag="v1.0.0",
            latest_sha="sha_latest",
            dry_run=False,
            token="test-token",
        )
        assert any("Failed" in m for m in messages)
