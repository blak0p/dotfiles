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


WALL = dict(primary="#ffb59a", on_primary="#552000", secondary="#e7bdb0", tertiary="#d5c68e",
            surface="#1a110e", surface_container="#271d1a", surface_container_high="#322824",
            on_surface="#f1dfd9", on_surface_variant="#d8c2bb", outline="#a08d86",
            outline_variant="#53433e", source_color="#c4501d")


def hue_gap(a, b):
    return abs(((a - b + 540) % 360) - 180)


class Harmonize(unittest.TestCase):
    def test_moves_toward_the_wallpaper_at_most_15_degrees(self):
        self.assertAlmostEqual(sky_theme.harmonize(120, 300), 105)
        self.assertAlmostEqual(sky_theme.harmonize(120, 20), 105)

    def test_close_hues_move_half_way(self):
        self.assertAlmostEqual(sky_theme.harmonize(0, 10), 5)
        self.assertAlmostEqual(sky_theme.harmonize(350, 10), 0)


class HexHue(unittest.TestCase):
    def test_hues(self):
        self.assertAlmostEqual(sky_theme.hex_hue("#ff0000"), 0)
        self.assertAlmostEqual(sky_theme.hex_hue("#00ff00"), 120)
        self.assertAlmostEqual(sky_theme.hex_hue("#0000ff"), 240)


class BuildPalette(unittest.TestCase):
    def setUp(self):
        self.p = sky_theme.build_palette(matugen_dump(**WALL))

    def test_accent_follows_the_wallpaper_scheme(self):
        p = self.p
        self.assertEqual(p["accent"], "#ffb59a")
        self.assertEqual(p["onAccent"], "#552000")
        self.assertEqual(p["secondary"], "#e7bdb0")
        self.assertEqual(p["tertiary"], "#d5c68e")
        self.assertEqual(p["surface"], "#1a110e")
        self.assertEqual(p["surface2"], "#322824")
        self.assertEqual(p["widget"], "#271d1a")
        self.assertEqual(p["on"], "#f1dfd9")
        self.assertEqual(p["muted"], "#d8c2bb")
        self.assertEqual(p["outline"], "#a08d86")
        self.assertEqual(p["outlineVariant"], "#53433e")
        self.assertEqual(p["wallHue"], 18)

    def test_ansi_has_16_colors_with_semantic_hues_near_the_wallpaper(self):
        ansi = self.p["ansi"]
        self.assertEqual(len(ansi), 16)
        for c in ansi:
            self.assertRegex(c, r"^#[0-9a-f]{6}$")
        for slot, base in ((1, 0), (2, 120), (3, 50), (4, 215), (5, 300), (6, 180)):
            self.assertLessEqual(hue_gap(sky_theme.hex_hue(ansi[slot]), base), 16, slot)
            self.assertLessEqual(hue_gap(sky_theme.hex_hue(ansi[slot + 8]), base), 16, slot)
        self.assertEqual(ansi[15], "#f1dfd9")

    def test_base16_uses_the_wallpaper_for_functions_keywords_and_text(self):
        b = self.p["base16"]
        self.assertEqual(sorted(b), [f"base0{d}" for d in "0123456789ABCDEF"])
        self.assertEqual(b["base00"], "#1a110e")
        self.assertEqual(b["base05"], "#f1dfd9")
        self.assertEqual(b["base0D"], "#ffb59a")
        self.assertEqual(b["base0E"], "#d5c68e")
        self.assertEqual(b["base0C"], "#e7bdb0")
        self.assertEqual(b["base0B"], self.p["ansi"][2])


class Renderers(unittest.TestCase):
    def setUp(self):
        self.p = sky_theme.build_palette(matugen_dump(**WALL))

    def test_kitty_never_sets_the_background(self):
        out = sky_theme.render_kitty(self.p)
        keys = [line.split()[0] for line in out.splitlines() if line and not line.startswith("#")]
        self.assertNotIn("background", keys)
        self.assertNotIn("background_opacity", keys)
        self.assertIn("foreground #f1dfd9", out)
        self.assertIn("cursor #ffb59a", out)
        for i in range(16):
            self.assertIn(f"color{i} {self.p['ansi'][i]}", out)

    def test_hyprland_borders_use_the_accent(self):
        out = sky_theme.render_hyprland(self.p)
        self.assertIn('active_border = "rgba(ffb59aee)"', out)
        self.assertIn('inactive_border = "rgba(53433e88)"', out)

    def test_hyprlock_variables(self):
        out = sky_theme.render_hyprlock(self.p)
        self.assertIn("$text_color = rgba(f1dfd9ff)", out)
        self.assertIn("$entry_border_color = rgba(ffb59a88)", out)
        self.assertNotIn("background_image", out)

    def test_gtk_accent(self):
        out = sky_theme.render_gtk(self.p)
        self.assertIn("@define-color accent_color #ffb59a;", out)
        self.assertIn("@define-color window_bg_color #1a110e;", out)

    def test_btop_theme(self):
        out = sky_theme.render_btop(self.p)
        self.assertIn('theme[hi_fg]="#ffb59a"', out)
        self.assertIn('theme[main_bg]=""', out)


class Apply(unittest.TestCase):
    def test_writes_every_target_and_runs_reload_hooks(self):
        out = Path(tempfile.mkdtemp())
        btop = Path(tempfile.mkdtemp()) / "themes" / "sky.theme"
        ran = []
        p = sky_theme.build_palette(matugen_dump(**WALL))
        sky_theme.apply(p, out, btop_theme=btop, run=ran.append)
        self.assertEqual(sorted(os.listdir(out)),
                         ["colors.json", "gtk.css", "hyprland.lua", "hyprlock.conf", "kitty.conf"])
        self.assertEqual(json.loads((out / "colors.json").read_text())["accent"], "#ffb59a")
        self.assertTrue(btop.is_file())
        self.assertIn(["pkill", "-USR1", "-x", "kitty"], ran)
        self.assertIn(["hyprctl", "reload"], ran)


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
