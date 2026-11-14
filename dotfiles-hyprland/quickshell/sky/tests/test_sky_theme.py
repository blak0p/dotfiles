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
        self.assertIn('active_border = "rgba(ffb59aaa)"', out)
        # Inactive borders and the background stay as the user's config sets them.
        self.assertNotIn("inactive_border", out)
        self.assertNotIn("background_color", out)

    def test_hyprlock_variables(self):
        out = sky_theme.render_hyprlock(self.p)
        self.assertIn("$text_color = rgba(f1dfd9ff)", out)
        self.assertIn("$entry_border_color = rgba(ffb59a88)", out)
        self.assertNotIn("background_image", out)

    def test_hyprlock_card_variables_follow_the_palette(self):
        out = sky_theme.render_hyprlock(self.p)
        p = self.p
        h = sky_theme._h
        self.assertIn(f"$card_color = rgba({h(p['surface'])}cc)", out)
        self.assertIn(f"$card_border_color = rgba({h(p['outlineVariant'])}66)", out)
        self.assertIn(f"$field_color = rgba({h(p['surface2'])}99)", out)
        self.assertIn(f"$accent_color = rgba({h(p['accent'])}ff)", out)
        self.assertIn(f"$on_accent_color = rgba({h(p['onAccent'])}ff)", out)
        self.assertIn(f"$muted_color = rgba({h(p['muted'])}ff)", out)

    def test_gtk_accent(self):
        out = sky_theme.render_gtk(self.p)
        self.assertIn("@define-color accent_color #ffb59a;", out)
        self.assertIn("@define-color window_bg_color #1a110e;", out)

    def test_gtk3_rules_use_literal_colors(self):
        out = sky_theme.render_gtk3(self.p)
        # GTK3 knows no libadwaita role names, and a theme that ships no widget
        # CSS leaves every window transparent: only literal rules paint it.
        self.assertNotIn("@define-color", out)
        self.assertIn("window, .background {", out)
        self.assertIn("background-color: #1a110e;", out)
        self.assertIn("color: #f1dfd9;", out)
        self.assertIn("headerbar {", out)

    def test_btop_theme(self):
        out = sky_theme.render_btop(self.p)
        self.assertIn('theme[hi_fg]="#ffb59a"', out)
        self.assertIn('theme[main_bg]=""', out)

    def test_qt6ct_scheme_maps_qt_palette_roles(self):
        out = sky_theme.render_qt6ct(self.p)
        self.assertTrue(out.startswith("[ColorScheme]\n"))
        lines = dict(line.split("=", 1) for line in out.splitlines()[1:])
        self.assertEqual(sorted(lines), ["active_colors", "disabled_colors", "inactive_colors"])
        roles = [c.strip() for c in lines["active_colors"].split(",")]
        # QPalette::ColorRole order: WindowText, Button, Light, Midlight, Dark, Mid, Text,
        # BrightText, ButtonText, Base, Window, Shadow, Highlight, HighlightedText, Link,
        # LinkVisited, AlternateBase, NoRole, ToolTipBase, ToolTipText, PlaceholderText, Accent.
        self.assertEqual(len(roles), 22)
        self.assertEqual(roles[0], "#f1dfd9")   # WindowText
        self.assertEqual(roles[6], "#f1dfd9")   # Text
        self.assertEqual(roles[9], "#1a110e")   # Base
        self.assertEqual(roles[10], "#1a110e")  # Window
        self.assertEqual(roles[12], "#ffb59a")  # Highlight
        self.assertEqual(roles[13], "#552000")  # HighlightedText
        self.assertEqual(roles[21], "#ffb59a")  # Accent
        disabled = [c.strip() for c in lines["disabled_colors"].split(",")]
        self.assertEqual(disabled[0], "#a08d86")  # disabled text uses the outline


KDEGLOBALS_BASE = """[General]
ColorScheme=BreezeDark
ColorSchemeHash=27363f57
fixed=Hack,10

[Colors:View]
BackgroundNormal=255,255,255

[KDE]
SingleClick=false

[UiSettings]
ColorScheme=BreezeLight
"""


class KdeGlobals(unittest.TestCase):
    def setUp(self):
        self.p = sky_theme.build_palette(matugen_dump(**WALL))

    def parse(self, text):
        import configparser
        cp = configparser.ConfigParser(interpolation=None)
        cp.optionxform = str
        cp.read_string(text)
        return cp

    def test_sets_sky_colors_and_keeps_the_rest(self):
        cp = self.parse(sky_theme.render_kdeglobals(KDEGLOBALS_BASE, self.p))
        self.assertEqual(cp["General"]["ColorScheme"], "Sky")
        self.assertEqual(cp["General"]["fixed"], "Hack,10")
        # The Breeze scheme hash would make KDE re-apply the old scheme.
        self.assertNotIn("ColorSchemeHash", cp["General"])
        self.assertEqual(cp["KDE"]["SingleClick"], "false")
        # KColorSchemeManager (Dolphin and other KF6 apps outside Plasma) reads
        # the explicit choice from UiSettings; without it, it falls back to Breeze.
        self.assertEqual(cp["UiSettings"]["ColorScheme"], "Sky")
        self.assertEqual(cp["Colors:View"]["BackgroundNormal"], "26,17,14")
        self.assertEqual(cp["Colors:Window"]["ForegroundNormal"], "241,223,217")
        self.assertEqual(cp["Colors:Selection"]["BackgroundNormal"], "255,181,154")
        self.assertEqual(cp["Colors:Selection"]["ForegroundNormal"], "85,32,0")
        for group in ("Window", "View", "Button", "Selection", "Tooltip", "Header",
                      "Complementary"):
            self.assertIn(f"Colors:{group}", cp)

    def test_is_idempotent_and_writes_the_scheme_once(self):
        once = sky_theme.render_kdeglobals(KDEGLOBALS_BASE + "[General]\nextra=1\n", self.p)
        self.assertEqual(sky_theme.render_kdeglobals(once, self.p), once)
        # Once in [General] and once in [UiSettings], even with repeated [General] groups.
        self.assertEqual(once.count("ColorScheme=Sky"), 2)
        self.assertEqual(once.count("[UiSettings]"), 1)

    def test_empty_file_gets_general_and_colors(self):
        cp = self.parse(sky_theme.render_kdeglobals("", self.p))
        self.assertEqual(cp["General"]["ColorScheme"], "Sky")
        self.assertEqual(cp["Colors:Button"]["BackgroundNormal"], "39,29,26")


class KdeScheme(unittest.TestCase):
    def test_is_a_complete_dark_color_scheme_file(self):
        import configparser
        p = sky_theme.build_palette(matugen_dump(**WALL))
        cp = configparser.ConfigParser(interpolation=None)
        cp.optionxform = str
        cp.read_string(sky_theme.render_kde_scheme(p))
        self.assertEqual(cp["General"]["Name"], "Sky")
        self.assertEqual(cp["General"]["ColorScheme"], "Sky")
        self.assertEqual(cp["Colors:View"]["BackgroundNormal"], "26,17,14")
        for g in ("Window", "View", "Button", "Selection", "Tooltip", "Header", "Complementary"):
            self.assertIn(f"Colors:{g}", cp)
        self.assertEqual(cp["ColorEffects:Inactive"]["Enable"], "false")
        self.assertEqual(cp["ColorEffects:Inactive"]["ChangeSelectionColor"], "false")
        self.assertIn("ColorEffects:Disabled", cp)


class Vivid(unittest.TestCase):
    def test_ansi_colors_are_saturated_enough_to_tell_apart(self):
        import colorsys
        ansi = sky_theme.build_palette(matugen_dump(**WALL))["ansi"]
        for slot in range(1, 7):
            c = ansi[slot].lstrip("#")
            r, g, b = (int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))
            self.assertGreaterEqual(colorsys.rgb_to_hls(r, g, b)[2], 0.7, slot)


STARSHIP_BASE = """format = "$directory$character"
palette = "ii"

[directory]
style = "fg:blue bold"

[palettes.ii]
blue = "blue"
green = "green"
"""


class Starship(unittest.TestCase):
    def setUp(self):
        self.p = sky_theme.build_palette(matugen_dump(**WALL))

    def test_switches_to_a_generated_palette_with_the_accent(self):
        import tomllib
        out = sky_theme.render_starship(STARSHIP_BASE, self.p)
        d = tomllib.loads(out)
        self.assertEqual(d["palette"], "sky")
        sky = d["palettes"]["sky"]
        self.assertEqual(sky["blue"], "#ffb59a")
        self.assertEqual(sky["mauve"], "#d5c68e")
        self.assertEqual(sky["text"], "#f1dfd9")
        # Success and error keep their meaning.
        self.assertEqual(sky["green"], "green")
        self.assertEqual(sky["red"], "red")
        # The rest of the user's config is untouched.
        self.assertEqual(d["directory"]["style"], "fg:blue bold")
        self.assertEqual(d["palettes"]["ii"]["blue"], "blue")

    def test_base_without_palette_line_still_selects_sky(self):
        import tomllib
        out = sky_theme.render_starship('format = "$character"\n', self.p)
        self.assertEqual(tomllib.loads(out)["palette"], "sky")


class Apply(unittest.TestCase):
    def test_writes_every_target_and_runs_reload_hooks(self):
        out = Path(tempfile.mkdtemp())
        btop = Path(tempfile.mkdtemp()) / "themes" / "sky.theme"
        ran = []
        p = sky_theme.build_palette(matugen_dump(**WALL))
        base = Path(tempfile.mkdtemp()) / "starship.toml"
        base.write_text(STARSHIP_BASE)
        kdeglobals = Path(tempfile.mkdtemp()) / "kdeglobals"
        kdeglobals.write_text(KDEGLOBALS_BASE)
        scheme = Path(tempfile.mkdtemp()) / "color-schemes" / "Sky.colors"
        sky_theme.apply(p, out, btop_theme=btop, starship_base=base, kdeglobals=kdeglobals,
                        kde_scheme=scheme, run=ran.append)
        self.assertIn("Name=Sky", scheme.read_text())
        self.assertIn("[Colors:View]", scheme.read_text())
        self.assertEqual(sorted(os.listdir(out)),
                         ["colors.json", "gtk.css", "gtk3.css", "hyprland.lua", "hyprlock.conf", "kitty.conf",
                          "qt6ct-colors.conf", "starship.toml"])
        self.assertIn("SingleClick=false", kdeglobals.read_text())
        self.assertIn("ColorScheme=Sky", kdeglobals.read_text())
        self.assertEqual(json.loads((out / "colors.json").read_text())["accent"], "#ffb59a")
        self.assertTrue(btop.is_file())
        self.assertIn(["pkill", "-USR1", "-x", "kitty"], ran)
        self.assertIn(["hyprctl", "reload"], ran)

    def test_missing_starship_base_is_skipped(self):
        out = Path(tempfile.mkdtemp())
        p = sky_theme.build_palette(matugen_dump(**WALL))
        sky_theme.apply(p, out, btop_theme=out / "b.theme", starship_base=out / "none.toml",
                        kdeglobals=out / "kdeglobals", kde_scheme=out / "Sky.colors",
                        run=lambda _a: None)
        self.assertNotIn("starship.toml", os.listdir(out))


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


class ThemePrefs(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.orig = sky_theme._matugen
        sky_theme._matugen = lambda *a: (self.calls.append(a), matugen_dump(**WALL))[1]
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        sky_theme._matugen = self.orig

    def test_missing_file_means_todays_behavior(self):
        self.assertEqual(sky_theme.load_prefs(self.tmp / "nope.json"), (None, None))
        sky_theme.generate(None, self.tmp / "nope.json")
        self.assertEqual(self.calls, [("color", "hex", sky_theme.FALLBACK_SEED)])

    def test_scheme_is_passed_to_matugen(self):
        f = self.tmp / "theme.json"
        f.write_text('{"scheme": "scheme-vibrant", "accent": null}')
        sky_theme.generate(None, f)
        self.assertEqual(self.calls, [("color", "hex", sky_theme.FALLBACK_SEED, "-t", "scheme-vibrant")])

    def test_fixed_accent_replaces_the_wallpaper_source(self):
        f = self.tmp / "theme.json"
        f.write_text('{"scheme": "scheme-content", "accent": "#112233"}')
        img = self.tmp / "w.png"
        img.write_bytes(b"x")
        sky_theme.generate(img, f)
        self.assertEqual(self.calls, [("color", "hex", "#112233", "-t", "scheme-content")])

    def test_invalid_values_are_ignored(self):
        f = self.tmp / "theme.json"
        f.write_text('{"scheme": "evil", "accent": "red"}')
        self.assertEqual(sky_theme.load_prefs(f), (None, None))
        f.write_text("not json")
        self.assertEqual(sky_theme.load_prefs(f), (None, None))
