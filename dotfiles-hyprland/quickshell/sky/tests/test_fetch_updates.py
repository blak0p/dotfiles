"""Tests for scripts/fetch_updates.py (run: python3 -m unittest discover -s tests)."""
import io
import json
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import fetch_updates  # noqa: E402

PREVIOUS = {"checked_at": 1, "pending": {"total": 3, "pacman": 2, "aur": 1, "brew": 0}, "packages": []}


def fake_run(results):
    """subprocess.run stand-in keyed by the executable name."""
    def run(cmd, **_kwargs):
        rc, out, err = results.get(Path(cmd[0]).name, (0, "", ""))
        return subprocess.CompletedProcess(cmd, rc, out, err)
    return run


class FetchUpdates(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cache = Path(self.tmp.name) / "updates.json"
        self.cache.write_text(json.dumps(PREVIOUS))
        for name, value in (("STATE_DIR", self.tmp.name), ("CACHE_FILE", str(self.cache))):
            patcher = mock.patch.object(fetch_updates, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def run_main(self, results):
        which = lambda name: f"/usr/bin/{name}" if name in ("checkupdates", "paru") else None
        out = io.StringIO()
        with mock.patch.object(fetch_updates.shutil, "which", which), \
                mock.patch.object(fetch_updates.os.path, "exists", lambda _p: False), \
                mock.patch.object(fetch_updates.subprocess, "run", fake_run(results)), \
                redirect_stdout(out):
            code = fetch_updates.main()
        return code, out.getvalue()

    def test_failed_check_keeps_the_previous_cache(self):
        failures = {
            "checkupdates": {"checkupdates": (1, "", "==> ERROR: Cannot fetch updates")},
            "paru": {"checkupdates": (2, "", ""),
                     "paru": (1, "", "error: failed to retrieve aur packages")},
        }
        for source, results in failures.items():
            with self.subTest(source=source):
                code, out = self.run_main(results)
                self.assertEqual(code, 1)
                self.assertEqual(out, "")
                self.assertEqual(json.loads(self.cache.read_text()), PREVIOUS)

    def test_no_updates_still_writes_zero(self):
        code, out = self.run_main({"checkupdates": (2, "", ""), "paru": (1, "", "")})
        self.assertEqual(code, 0)
        data = json.loads(self.cache.read_text())
        self.assertEqual(data["pending"], {"total": 0, "pacman": 0, "aur": 0, "brew": 0})
        self.assertEqual(json.loads(out), data)

    def test_pending_updates_are_counted(self):
        code, _ = self.run_main({
            "checkupdates": (0, "linux 6.1-1 -> 6.2-1\nmesa 1-1 -> 2-1\n", ""),
            "paru": (0, "foo-git 1-1 -> 2-1\n", ""),
        })
        self.assertEqual(code, 0)
        pending = json.loads(self.cache.read_text())["pending"]
        self.assertEqual(pending, {"total": 3, "pacman": 2, "aur": 1, "brew": 0})


if __name__ == "__main__":
    unittest.main()
