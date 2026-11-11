"""Tests for scripts/sky_default_apps.py (run: python3 -m unittest discover -s tests)."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "sky_default_apps.py"
sys.path.insert(0, str(SCRIPT.parent))
import sky_default_apps as da  # noqa: E402


def desktop(dir: Path, name: str, body: str) -> None:
    p = dir / "applications" / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("[Desktop Entry]\nType=Application\n" + body)


class Apps(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_lists_apps_handling_the_mime_sorted_by_name(self):
        desktop(self.d, "b.desktop", "Name=Beta\nMimeType=text/plain;image/png;\n")
        desktop(self.d, "a.desktop", "Name=Alpha\nMimeType=text/plain;\n")
        desktop(self.d, "c.desktop", "Name=Gamma\nMimeType=image/png;\n")
        got = da.apps_for("text/plain", [self.d])
        self.assertEqual(got, [{"id": "a.desktop", "name": "Alpha"}, {"id": "b.desktop", "name": "Beta"}])

    def test_skips_hidden_and_nodisplay(self):
        desktop(self.d, "h.desktop", "Name=H\nNoDisplay=true\nMimeType=text/plain;\n")
        desktop(self.d, "i.desktop", "Name=I\nHidden=true\nMimeType=text/plain;\n")
        self.assertEqual(da.apps_for("text/plain", [self.d]), [])

    def test_first_dir_wins_for_same_id(self):
        other = self.d / "sys"
        desktop(self.d, "a.desktop", "Name=User\nMimeType=text/plain;\n")
        desktop(other, "a.desktop", "Name=System\nMimeType=text/plain;\n")
        self.assertEqual(da.apps_for("text/plain", [self.d, other]), [{"id": "a.desktop", "name": "User"}])

    def test_missing_dir_and_garbage_are_ignored(self):
        (self.d / "applications").mkdir()
        (self.d / "applications" / "bad.desktop").write_bytes(b"\xff\xfe\x00junk")
        self.assertEqual(da.apps_for("text/plain", [self.d, self.d / "nope"]), [])

    def test_cli_prints_json(self):
        desktop(self.d, "a.desktop", "Name=Alpha\nMimeType=text/plain;\n")
        out = subprocess.run(
            [sys.executable, "-I", str(SCRIPT), "apps", "text/plain"],
            capture_output=True, text=True, check=True,
            env={"XDG_DATA_HOME": str(self.d), "XDG_DATA_DIRS": str(self.d / "none"), "PATH": "/usr/bin"},
        )
        self.assertEqual(json.loads(out.stdout), [{"id": "a.desktop", "name": "Alpha"}])

    def test_cli_usage_error(self):
        r = subprocess.run([sys.executable, "-I", str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
