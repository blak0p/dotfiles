"""Tests for scripts/fetch_usage.py (run: python3 -m unittest discover -s tests)."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import fetch_usage  # noqa: E402


def claude_entry():
    """Trimmed shape of `codexbar usage --provider claude --format json --status`."""
    return {
        "provider": "claude",
        "source": "oauth",
        "status": {"indicator": "none", "description": "All Systems Operational"},
        "pace": {
            "primary": {"summary": "8% in deficit | Expected 6% used | Projected empty in 1h 58m"},
            "secondary": {"summary": "36% in reserve | Expected 45% used | Lasts until reset"},
        },
        "usage": {
            "loginMethod": "Claude Max",
            "primary": {"usedPercent": 14, "windowMinutes": 300, "resetsAt": "2026-11-02T21:19:59Z"},
            "secondary": {"usedPercent": 9, "windowMinutes": 10080, "resetsAt": "2026-11-06T12:59:59Z"},
        },
    }


class NormalizeWindows(unittest.TestCase):
    def test_primary_and_secondary_become_titled_windows_with_pace(self):
        p = fetch_usage.normalize(claude_entry())
        self.assertTrue(p["ok"])
        self.assertEqual(p["provider"], "claude")
        self.assertEqual(p["name"], "Claude")
        self.assertEqual(p["plan"], "Claude Max")
        self.assertEqual(p["status"], {"indicator": "none", "description": "All Systems Operational"})
        self.assertEqual(p["windows"], [
            {"title": "5-hour", "usedPercent": 14, "resetsAt": "2026-11-02T21:19:59Z",
             "pace": "8% in deficit | Expected 6% used | Projected empty in 1h 58m"},
            {"title": "Weekly", "usedPercent": 9, "resetsAt": "2026-11-06T12:59:59Z",
             "pace": "36% in reserve | Expected 45% used | Lasts until reset"},
        ])

    def test_rate_window_labels_win_over_the_window_length(self):
        e = claude_entry()
        e["rateWindowLabels"] = {"primary": "Gemini Models"}
        titles = [w["title"] for w in fetch_usage.normalize(e)["windows"]]
        self.assertEqual(titles, ["Gemini Models", "Weekly"])

    def test_extra_window_with_same_reset_renames_instead_of_duplicating(self):
        e = {
            "provider": "antigravity",
            "usage": {
                "primary": {"usedPercent": 71.04, "windowMinutes": 10080, "resetsAt": "2026-11-07T09:45:11Z"},
                "extraRateWindows": [
                    {"title": "Gemini weekly", "window": {"usedPercent": 71.04, "windowMinutes": 10080,
                                                          "resetsAt": "2026-11-07T09:45:11Z"}},
                    {"title": "Claude/GPT weekly", "window": {"usedPercent": 20, "windowMinutes": 10080,
                                                              "resetsAt": "2026-11-09T16:39:10Z"}},
                ],
            },
        }
        windows = fetch_usage.normalize(e)["windows"]
        self.assertEqual([(w["title"], w["usedPercent"]) for w in windows],
                         [("Gemini weekly", 71.04), ("Claude/GPT weekly", 20)])

    def test_unknown_provider_name_is_capitalized(self):
        self.assertEqual(fetch_usage.normalize({"provider": "cursor", "usage": {}})["name"], "Cursor")


class NormalizeErrors(unittest.TestCase):
    def test_expired_token_is_reported_as_a_sign_in_hint(self):
        e = {"provider": "codex", "status": {"indicator": "none", "description": "All Systems Operational"},
             "error": {"code": 1, "message": "Codex connection failed: failed to fetch codex rate limits: "
                                             "GET https://chatgpt.com/backend-api/wham/usage failed: "
                                             "401 Unauthorized; body={\"code\": \"token_expired\"}"}}
        p = fetch_usage.normalize(e)
        self.assertFalse(p["ok"])
        self.assertEqual(p["name"], "Codex")
        self.assertEqual(p["error"], "Session expired, sign in again")
        self.assertEqual(p["windows"], [])

    def test_other_errors_keep_their_first_clause(self):
        e = {"provider": "claude", "error": {"message": "Claude connection failed: timeout\nmore"}}
        self.assertEqual(fetch_usage.normalize(e)["error"], "Claude connection failed")

    def test_failed_run_without_json_yields_an_error_provider(self):
        p = fetch_usage.failed("codex", "codexbar exited 1")
        self.assertEqual(p, {"provider": "codex", "name": "Codex", "ok": False, "error": "codexbar exited 1",
                             "plan": "", "status": None, "windows": []})


class ParseOutput(unittest.TestCase):
    def test_codexbar_list_output_yields_its_first_entry(self):
        self.assertEqual(fetch_usage.parse_output("claude", '[{"provider": "claude", "usage": {}}]')["provider"],
                         "claude")

    def test_garbage_output_is_an_error_provider(self):
        p = fetch_usage.parse_output("claude", "not json")
        self.assertFalse(p["ok"])
        self.assertEqual(p["error"], "Unreadable codexbar output")


if __name__ == "__main__":
    unittest.main()
