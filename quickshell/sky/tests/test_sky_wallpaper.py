"""Tests for scripts/sky_wallpaper.py (run: python3 -m unittest discover -s tests)."""
import json
import os
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import sky_wallpaper as wp  # noqa: E402


def touch(path: Path, data: bytes = b"x") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def project(dir: Path, **fields) -> Path:
    dir.mkdir(parents=True, exist_ok=True)
    (dir / "project.json").write_text(json.dumps(fields))
    return dir


class Kinds(unittest.TestCase):
    def test_classifies_by_extension(self):
        self.assertEqual(wp.kind_of(Path("a.JPG")), "image")
        self.assertEqual(wp.kind_of(Path("b.webp")), "image")
        self.assertEqual(wp.kind_of(Path("c.mp4")), "video")
        self.assertEqual(wp.kind_of(Path("d.webm")), "video")

    def test_ignores_unknown_extensions(self):
        self.assertIsNone(wp.kind_of(Path("notes.txt")))
        self.assertIsNone(wp.kind_of(Path("scene.pkg")))


class ScanFolder(unittest.TestCase):
    def test_lists_images_and_videos_sorted_by_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            touch(d / "zulu.png")
            touch(d / "alpha.mp4")
            entries = wp.scan_folder(d)
            self.assertEqual([e["title"] for e in entries], ["alpha", "zulu"])
            self.assertEqual([e["kind"] for e in entries], ["video", "image"])
            self.assertEqual(entries[0]["path"], str(d / "alpha.mp4"))

    def test_ignores_scene_symlinks_hidden_files_and_other_types(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            target = d / "workshop" / "123"
            target.mkdir(parents=True)
            os.symlink(target, d / "[SCENE] Anime Sea.scene")
            touch(d / ".hidden.png")
            touch(d / "notes.txt")
            touch(d / "real.png")
            entries = wp.scan_folder(d)
            self.assertEqual([e["title"] for e in entries], ["real"])

    def test_survives_a_missing_directory(self):
        self.assertEqual(wp.scan_folder(Path("/nonexistent/sky-wallpapers")), [])


class ScanWorkshop(unittest.TestCase):
    def test_reads_nested_and_flat_layouts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            nested = project(root / "111" / "111", title="Nested", type="scene",
                             preview="preview.jpg", file="scene.json")
            touch(nested / "preview.jpg")
            touch(nested / "scene.pkg")
            flat = project(root / "222", title="Flat", type="scene",
                           preview="preview.gif", file="scene.json")
            touch(flat / "preview.gif")
            entries = {e["title"]: e for e in wp.scan_workshop([root], set())}
            self.assertEqual(set(entries), {"Nested", "Flat"})
            self.assertEqual(entries["Nested"]["kind"], "scene")
            self.assertEqual(entries["Nested"]["path"], str(nested))
            self.assertEqual(entries["Nested"]["thumb"], str(nested / "preview.jpg"))

    def test_skips_blacklisted_items(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project(root / "333", title="Broken", type="scene", preview="preview.jpg")
            fine = project(root / "444", title="Fine", type="scene", preview="preview.jpg")
            touch(fine / "preview.jpg")
            entries = wp.scan_workshop([root], {"333"})
            self.assertEqual([e["title"] for e in entries], ["Fine"])

    def test_skips_items_without_project_json_or_preview(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "555").mkdir()
            project(root / "666", title="No preview", type="scene", file="scene.json")
            self.assertEqual(wp.scan_workshop([root], set()), [])

    def test_video_items_resolve_their_payload_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            item = project(root / "777", title="Clip", type="video",
                           preview="preview.jpg", file="clip.mp4")
            touch(item / "preview.jpg")
            touch(item / "clip.mp4")
            (entry,) = wp.scan_workshop([root], set())
            self.assertEqual(entry["kind"], "video")
            self.assertEqual(entry["path"], str(item / "clip.mp4"))
            self.assertEqual(entry["thumb"], str(item / "preview.jpg"))

    def test_probe_order_includes_flatpak_and_local_share(self):
        roots = [str(p) for p in wp.workshop_roots(home=Path("/h"), data=Path("/d"))]
        self.assertIn("/d/Steam/steamapps/workshop/content/431960", roots)
        self.assertIn(
            "/h/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content/431960",
            roots,
        )

    def test_the_same_tree_through_two_probe_paths_lists_each_item_once(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "workshop"
            item = project(root / "888", title="Once", type="scene", preview="preview.jpg")
            touch(item / "preview.jpg")
            alias = Path(tmp) / "alias"
            os.symlink(root, alias)
            entries = wp.scan_workshop([root, alias], set())
            self.assertEqual([e["title"] for e in entries], ["Once"])


class State(unittest.TestCase):
    def test_save_state_keeps_the_configured_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp) / "wallpaper.json"
            state.write_text(json.dumps({"dir": "/wallpapers", "path": "/old.png", "kind": "image"}))
            wp.save_state(Path("/wallpapers/new.mp4"), "video", state)
            saved = json.loads(state.read_text())
            self.assertEqual(saved["dir"], "/wallpapers")
            self.assertEqual(saved["path"], "/wallpapers/new.mp4")
            self.assertEqual(saved["kind"], "video")

    def test_read_state_tolerates_a_missing_or_bad_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp) / "wallpaper.json"
            self.assertEqual(wp.read_state(state), {})
            state.write_text("{not json")
            self.assertEqual(wp.read_state(state), {})

    def test_ensure_state_migrates_the_old_applied_wallpaper(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old = home / ".config" / "wallfliper" / "state.json"
            old.parent.mkdir(parents=True)
            old.write_text(json.dumps({"path": "/w/123", "kind": "scene"}))
            state = home / ".config/sky/wallpaper.json"
            with unittest.mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home / ".config")}):
                wp.ensure_state(state, home)
                saved = json.loads(state.read_text())
                self.assertEqual(saved["path"], "/w/123")
                self.assertEqual(saved["kind"], "scene")
                wp.ensure_state(state, home)  # idempotent
                self.assertEqual(json.loads(state.read_text()), saved)

    def test_folder_falls_back_to_the_old_wallfliper_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            legacy = home / ".config" / "wallfliper" / "config.json"
            legacy.parent.mkdir(parents=True)
            legacy.write_text(json.dumps({"wallpaper_dir": "/old/wallpapers"}))
            with unittest.mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home / ".config")}):
                self.assertEqual(wp.load_dir(home / ".config/sky/wallpaper.json", home),
                                 Path("/old/wallpapers"))


class Commands(unittest.TestCase):
    def test_image_command_transitions_to_the_file(self):
        argv = wp.image_cmd("/usr/bin/swww", Path("/w/a.png"))
        self.assertEqual(argv[:2], ["/usr/bin/swww", "img"])
        self.assertIn("--transition-type", argv)
        self.assertEqual(argv[-1], "/w/a.png")

    def test_video_command_covers_every_output_and_pauses_when_hidden(self):
        argv = wp.video_cmd("/usr/bin/mpvpaper", Path("/w/a.mp4"))
        self.assertEqual(argv[0], "/usr/bin/mpvpaper")
        self.assertEqual(argv[1], "-o")
        self.assertIn("loop", argv[2])
        self.assertIn("pause", argv[2])
        self.assertEqual(argv[-2], "*")
        self.assertEqual(argv[-1], "/w/a.mp4")

    def test_scene_command_targets_each_monitor(self):
        argv = wp.scene_cmd("/usr/bin/linux-wallpaperengine", Path("/w/123"), ["DP-2", "HDMI-A-1"])
        self.assertEqual(argv[:4], ["/usr/bin/linux-wallpaperengine", "--screen-root", "DP-2", "--screen-root"])
        self.assertIn("HDMI-A-1", argv)
        self.assertEqual(argv[argv.index("--bg") + 1], "/w/123")

    def test_scene_command_without_monitors_uses_the_default_output(self):
        argv = wp.scene_cmd("/usr/bin/linux-wallpaperengine", Path("/w/123"), [])
        self.assertNotIn("--screen-root", argv)


class Dependencies(unittest.TestCase):
    def test_reports_optional_tools_as_booleans(self):
        report = wp.check(which=lambda name: "/usr/bin/" + name if name == "swww" else None)
        self.assertTrue(report["tools"]["swww"])
        self.assertFalse(report["tools"]["mpvpaper"])
        self.assertIn("sources", report)


if __name__ == "__main__":
    unittest.main()
