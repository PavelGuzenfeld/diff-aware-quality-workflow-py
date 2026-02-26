"""Tests for the dashboard module."""

import json

from standard_ci.dashboard import generate_dashboard


def _sample_results():
    return [
        {
            "repo": "org/alpha",
            "has_config": True,
            "current_tag": "v1.0.0",
            "current_sha": "sha111",
            "up_to_date": True,
            "workflows": ["cpp-quality", "infra-lint"],
            "issues": [],
        },
        {
            "repo": "org/beta",
            "has_config": True,
            "current_tag": "v0.9.0",
            "current_sha": "sha222",
            "up_to_date": False,
            "workflows": ["cpp-quality"],
            "issues": ["SHA drift: v0.9.0 -> v1.0.0"],
        },
        {
            "repo": "org/gamma",
            "has_config": False,
            "current_tag": None,
            "current_sha": None,
            "up_to_date": False,
            "workflows": [],
            "issues": ["No .standard.yml found"],
        },
    ]


class TestGenerateDashboardMarkdown:
    def test_contains_header(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "## Standard Compliance Dashboard" in md

    def test_contains_summary_counts(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "**3** repos scanned" in md
        assert "**1** compliant" in md
        assert "**1** drifted" in md
        assert "**1** unconfigured" in md

    def test_contains_repo_table(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "| alpha |" in md
        assert "| beta |" in md
        assert "| gamma |" in md

    def test_drift_details_section(self):
        md = generate_dashboard(_sample_results(), "v1.0.0", "sha_latest", "org")
        assert "### Drift Details" in md
        assert "beta" in md
        assert "v0.9.0" in md

    def test_no_drift_section_when_all_current(self):
        results = [_sample_results()[0]]  # only the current one
        md = generate_dashboard(results, "v1.0.0", "sha_latest", "org")
        assert "### Drift Details" not in md


class TestGenerateDashboardJSON:
    def test_valid_json(self):
        output = generate_dashboard(
            _sample_results(), "v1.0.0", "sha_latest", "org", fmt="json"
        )
        data = json.loads(output)
        assert data["org"] == "org"
        assert data["latest_tag"] == "v1.0.0"
        assert len(data["repos"]) == 3

    def test_contains_repo_data(self):
        output = generate_dashboard(
            _sample_results(), "v1.0.0", "sha_latest", "org", fmt="json"
        )
        data = json.loads(output)
        repos = {r["repo"]: r for r in data["repos"]}
        assert repos["org/alpha"]["up_to_date"]
        assert not repos["org/beta"]["up_to_date"]
        assert not repos["org/gamma"]["has_config"]
