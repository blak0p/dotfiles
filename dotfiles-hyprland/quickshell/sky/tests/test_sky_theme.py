"""Tests for scripts/sky_theme.py (run: python3 -m unittest discover -s tests)."""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import sky_theme  # noqa: E402


def matugen_dump(**colors):
    """Shape of `matugen ... -j hex` output for the given role -> hex map."""
    return {"colors": {k: {"dark": {"color": v}, "default": {"color": v}, "light": {"color": v}}
                       for k, v in colors.items()}}


class SkyAccentHue(unittest.TestCase):
    def test_blue_wallpaper_keeps_its_hue_with_zero_bias(self):
        self.assertAlmostEqual(sky_theme.sky_accent_hue(215, 0.0), 215)

    def test_full_bias_is_always_sky(self):
        for wall in (0, 18, 120, 215, 300):
            self.assertAlmostEqual(sky_theme.sky_accent_hue(wall, 1.0), sky_theme.SKY_HUE)

    def test_orange_wallpaper_is_pulled_at_most_40_degrees(self):
        # 18 is 173deg above 205 going up through 360, clamped to +40
        self.assertAlmostEqual(sky_theme.sky_accent_hue(18, 0.0), 245)
        self.assertAlmostEqual(sky_theme.sky_accent_hue(18, 0.7), 217)

    def test_green_wallpaper_pulls_down(self):
        self.assertAlmostEqual(sky_theme.sky_accent_hue(120, 0.0), 165)

    def test_bias_is_clamped(self):
        self.assertAlmostEqual(sky_theme.sky_accent_hue(120, 3), sky_theme.SKY_HUE)
        self.assertAlmostEqual(sky_theme.sky_accent_hue(120, -1), 165)


class HexHue(unittest.TestCase):
    def test_hues(self):
        self.assertAlmostEqual(sky_theme.hex_hue("#ff0000"), 0)
        self.assertAlmostEqual(sky_theme.hex_hue("#00ff00"), 120)
        self.assertAlmostEqual(sky_theme.hex_hue("#0000ff"), 240)

    def test_seed_has_the_requested_hue(self):
        self.assertAlmostEqual(sky_theme.hex_hue(sky_theme.seed_for_hue(205)), 205, delta=1)


class BuildPalette(unittest.TestCase):
    def test_roles_come_from_accent_scheme_and_wall_scheme(self):
        accent = matugen_dump(primary="#8fcff3", on_primary="#003548", secondary="#b4cad6",
                              on_surface="#dfe3e7", on_surface_variant="#c0c8cd", outline="#8a9297",
                              surface_container_high="#262b2e")
        wall = matugen_dump(primary="#ffb59a", surface="#1a110e", surface_container="#271d1a",
                            source_color="#c4501d")
        p = sky_theme.build_palette(accent, wall, wall_hue=18, accent_hue=217)
        self.assertEqual(p["accent"], "#8fcff3")
        self.assertEqual(p["onAccent"], "#003548")
        self.assertEqual(p["secondary"], "#b4cad6")
        self.assertEqual(p["tertiary"], "#ffb59a")
        self.assertEqual(p["surface"], "#1a110e")
        self.assertEqual(p["surface2"], "#262b2e")
        self.assertEqual(p["widget"], "#271d1a")
        self.assertEqual(p["on"], "#dfe3e7")
        self.assertEqual(p["muted"], "#c0c8cd")
        self.assertEqual(p["outline"], "#8a9297")
        self.assertEqual(p["wallHue"], 18)
        self.assertEqual(p["accentHue"], 217)


class ColorSource(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def test_plain_image_is_used_directly(self):
        img = self.tmp / "wall.jpg"
        img.write_bytes(b"x")
        self.assertEqual(sky_theme.color_source(img), (img, "image"))

    def test_scene_uses_preview_from_project_json(self):
        scene = self.tmp / "3554319148"
        scene.mkdir()
        (scene / "project.json").write_text(json.dumps({"preview": "preview.gif"}))
        (scene / "preview.gif").write_bytes(b"x")
        self.assertEqual(sky_theme.color_source(scene), (scene / "preview.gif", "animated"))

    def test_scene_without_preview_falls_back(self):
        scene = self.tmp / "empty"
        scene.mkdir()
        (scene / "project.json").write_text("{}")
        self.assertEqual(sky_theme.color_source(scene), (None, "none"))

    def test_video_needs_a_frame(self):
        vid = self.tmp / "clip.mp4"
        vid.write_bytes(b"x")
        self.assertEqual(sky_theme.color_source(vid), (vid, "video"))

    def test_missing_path(self):
        self.assertEqual(sky_theme.color_source(self.tmp / "nope.png"), (None, "none"))


class CurrentWallpaper(unittest.TestCase):
    def test_reads_the_shell_wallpaper_state(self):
        tmp = Path(tempfile.mkdtemp())
        state = tmp / "wallpaper.json"
        state.write_text(json.dumps({"path": "/w/123", "kind": "scene"}))
        self.assertEqual(sky_theme.current_wallpaper(state), Path("/w/123"))

    def test_default_state_lives_under_the_sky_config_dir(self):
        self.assertEqual(sky_theme.SKY_STATE, sky_theme.CONFIG_HOME / "sky/wallpaper.json")

    def test_missing_state(self):
        self.assertIsNone(sky_theme.current_wallpaper(Path(tempfile.mkdtemp()) / "none.json"))


class WriteAtomic(unittest.TestCase):
    def test_writes_json_and_leaves_no_temp_files(self):
        out = Path(tempfile.mkdtemp()) / "sub" / "colors.json"
        sky_theme.write_palette(out, {"accent": "#8fcff3"})
        self.assertEqual(json.loads(out.read_text()), {"accent": "#8fcff3"})
        self.assertEqual(os.listdir(out.parent), ["colors.json"])


if __name__ == "__main__":
    unittest.main()
