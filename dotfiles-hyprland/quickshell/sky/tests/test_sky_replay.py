"""Tests for scripts/sky_replay.py (run: python3 -m unittest discover -s tests)."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import sky_replay as rp  # noqa: E402


def run_cli(*args):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = rp.main(["sky_replay.py", *map(str, args)])
    return code, out.getvalue(), err.getvalue()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.home = self.dir / "home"
        self.home.mkdir()
        self.settings = self.dir / "settings.json"
        self._env = os.environ.copy()
        os.environ["HOME"] = str(self.home)
        os.environ["XDG_CACHE_HOME"] = str(self.dir / "cache")
        os.environ.pop("XDG_VIDEOS_DIR", None)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._env)
        self.tmp.cleanup()


class Options(Base):
    def test_defaults_without_settings_file(self):
        o = rp.load_options(self.settings)
        self.assertEqual(o, {"enabled": False, "seconds": 30, "fps": 60, "quality": "very_high",
                             "audio": "desktop", "dir": str(self.home / "Videos" / "Clips")})

    def test_reads_replay_block_and_ignores_bad_values(self):
        self.settings.write_text(json.dumps({"language": "es", "replay": {
            "enabled": True, "seconds": 9999, "fps": 61, "quality": "ultra", "audio": "nope", "dir": "~/Clips"}}))
        o = rp.load_options(self.settings)
        self.assertTrue(o["enabled"])
        self.assertEqual(o["seconds"], rp.MAX_SECONDS)
        self.assertEqual(o["fps"], 60)
        self.assertEqual(o["quality"], "ultra")
        self.assertEqual(o["audio"], "desktop")
        self.assertEqual(o["dir"], str(self.home / "Clips"))


class Command(Base):
    def test_builds_replay_command_for_the_screen(self):
        self.settings.write_text(json.dumps({"replay": {"seconds": 60, "fps": 120, "audio": "desktop_mic"}}))
        code, out, err = run_cli("cmd", self.settings, "DP-1")
        self.assertEqual((code, err), (0, ""))
        argv = json.loads(out)
        clips = str(self.home / "Videos" / "Clips")
        self.assertEqual(argv, ["gpu-screen-recorder", "-w", "DP-1", "-f", "120", "-c", "mp4", "-r", "60",
                                "-q", "very_high", "-a", "default_output|default_input", "-o", clips])
        self.assertTrue(Path(clips).is_dir())

    def test_no_screen_and_no_audio(self):
        self.settings.write_text(json.dumps({"replay": {"audio": "none"}}))
        code, out, _ = run_cli("cmd", self.settings)
        self.assertEqual(code, 0)
        argv = json.loads(out)
        self.assertEqual(argv[1:3], ["-w", "screen"])
        self.assertNotIn("-a", argv)


class SetOption(Base):
    def test_merges_into_settings_keeping_other_keys(self):
        self.settings.write_text(json.dumps({"language": "es", "replay": {"fps": 30}}))
        code, out, err = run_cli("set", self.settings, "seconds", "45")
        self.assertEqual((code, out, err), (0, "", ""))
        data = json.loads(self.settings.read_text())
        self.assertEqual(data, {"language": "es", "replay": {"fps": 30, "seconds": 45}})

    def test_typed_values(self):
        run_cli("set", self.settings, "enabled", "true")
        run_cli("set", self.settings, "audio", "none")
        run_cli("set", self.settings, "dir", "~/Movies/Clips")
        data = json.loads(self.settings.read_text())
        self.assertEqual(data["replay"], {"enabled": True, "audio": "none", "dir": "~/Movies/Clips"})

    def test_rejects_invalid_value_without_touching_the_file(self):
        before = json.dumps({"language": "es"})
        self.settings.write_text(before)
        for key, value in [("fps", "61"), ("seconds", "abc"), ("seconds", "2"), ("quality", "max"),
                           ("audio", "mic"), ("enabled", "maybe"), ("dir", ""), ("bogus", "1")]:
            code, out, err = run_cli("set", self.settings, key, value)
            self.assertEqual(code, 1, (key, value))
            self.assertEqual(out, "")
            self.assertTrue(err.startswith("sky_replay: "), err)
        self.assertEqual(self.settings.read_text(), before)

    def test_refuses_broken_json(self):
        self.settings.write_text("{nope")
        code, _, err = run_cli("set", self.settings, "fps", "30")
        self.assertEqual(code, 1)
        self.assertIn("not valid JSON", err)
        self.assertEqual(self.settings.read_text(), "{nope")


class Clips(Base):
    def setUp(self):
        super().setUp()
        self.clips = self.dir / "clips"
        self.clips.mkdir()
        old = self.clips / "Replay_old.mp4"
        old.write_bytes(b"a" * 10)
        os.utime(old, (1000, 1000))
        new = self.clips / "Replay new.mp4"
        new.write_bytes(b"b" * 20)
        os.utime(new, (2000, 2000))
        (self.clips / "notes.txt").write_text("x")

    def test_scan_lists_videos_newest_first(self):
        code, out, err = run_cli("scan", self.clips)
        self.assertEqual((code, err), (0, ""))
        items = json.loads(out)
        self.assertEqual([i["name"] for i in items], ["Replay new.mp4", "Replay_old.mp4"])
        self.assertEqual(items[0]["size"], 20)
        self.assertEqual(items[0]["mtime"], 2000)
        self.assertEqual(items[0]["path"], str(self.clips / "Replay new.mp4"))
        self.assertIn("thumb", items[0])

    def test_scan_missing_dir_is_empty(self):
        code, out, _ = run_cli("scan", self.dir / "missing")
        self.assertEqual((code, json.loads(out)), (0, []))

    def test_delete_inside_clips_dir(self):
        code, out, err = run_cli("delete", self.clips, self.clips / "Replay_old.mp4")
        self.assertEqual((code, out, err), (0, "", ""))
        self.assertFalse((self.clips / "Replay_old.mp4").exists())

    def test_delete_refuses_outside_or_non_video(self):
        outside = self.dir / "other.mp4"
        outside.write_bytes(b"z")
        for target in [outside, self.clips / "notes.txt", self.clips / ".." / "other.mp4"]:
            code, _, err = run_cli("delete", self.clips, target)
            self.assertEqual(code, 1, target)
            self.assertTrue(err.startswith("sky_replay: "))
        self.assertTrue(outside.exists())
        self.assertTrue((self.clips / "notes.txt").exists())

    def test_delete_refuses_symlink_to_outside_clip(self):
        outside = self.dir / "other" / "x.mp4"
        outside.parent.mkdir()
        outside.write_bytes(b"v")
        (self.clips / "l.mp4").symlink_to(outside)
        code, _, err = run_cli("delete", self.clips, self.clips / "l.mp4")
        self.assertEqual(code, 1)
        self.assertTrue(err.startswith("sky_replay: "))
        self.assertTrue(outside.exists())

    def test_delete_tilde_dir_through_symlinked_videos_folder(self):
        real = self.home / "Vídeos" / "Clips"
        real.mkdir(parents=True)
        (self.home / "Videos").symlink_to(self.home / "Vídeos")
        clip = real / "a.mp4"
        clip.write_bytes(b"v")
        code, out, err = run_cli("delete", "~/Videos/Clips", self.home / "Videos" / "Clips" / "a.mp4")
        self.assertEqual((code, out, err), (0, "", ""))
        self.assertFalse(clip.exists())

    def test_uri_is_percent_encoded(self):
        code, out, _ = run_cli("uri", self.clips / "Replay new.mp4")
        self.assertEqual(code, 0)
        self.assertEqual(out, "file://" + str(self.clips).replace(" ", "%20") + "/Replay%20new.mp4\r\n")


class Thumb(Base):
    def test_prints_cached_still_for_a_clip(self):
        import shutil, subprocess
        if not shutil.which("ffmpeg"):
            self.skipTest("ffmpeg not installed")
        clip = self.dir / "c.mp4"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=320x180:rate=10",
                        "-t", "2", "-pix_fmt", "yuv420p", str(clip)], check=True)
        code, out, err = run_cli("thumb", clip)
        self.assertEqual((code, err), (0, ""))
        path = Path(out.strip())
        self.assertTrue(path.is_file())
        self.assertTrue(str(path).startswith(str(self.dir / "cache")))

    def test_without_ffmpeg_prints_empty_line(self):
        clip = self.dir / "c.mp4"
        clip.write_bytes(b"x")
        with unittest.mock.patch("shutil.which", return_value=None):
            code, out, err = run_cli("thumb", clip)
        self.assertEqual((code, out, err), (0, "\n", ""))

    def test_missing_clip_fails(self):
        code, out, err = run_cli("thumb", self.dir / "nope.mp4")
        self.assertEqual((code, out), (1, ""))
        self.assertTrue(err.startswith("sky_replay: "))


class Usage(Base):
    def test_unknown_command_prints_usage(self):
        code, out, _ = run_cli("wat")
        self.assertEqual(code, 2)
        self.assertIn("sky_replay.py", out)


if __name__ == "__main__":
    unittest.main()
