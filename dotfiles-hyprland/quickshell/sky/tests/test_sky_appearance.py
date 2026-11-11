"""Tests for scripts/sky_appearance.py (run: python3 -m unittest discover -s tests)."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import sky_appearance as ap  # noqa: E402


def tree(root: Path):
    for rel in ("themes/Adw/gtk-3.0", "themes/Dark/gtk-4.0", "themes/NoGtk/metacity-1",
                "icons/Papirus/16x16", "icons/Bib/cursors", "icons/Hicolor/16x16"):
        (root / rel).mkdir(parents=True)
    (root / "icons/Papirus/index.theme").write_text("[Icon Theme]\nName=P\nDirectories=16x16\n")
    (root / "icons/Hicolor/index.theme").write_text("[Icon Theme]\nDirectories=16x16\n")
    (root / "icons/Bib/index.theme").write_text("[Icon Theme]\nName=B\n")  # cursor only
    return [root / "themes"], [root / "icons"]


class Scan(unittest.TestCase):
    def test_lists_installed_themes(self):
        root = Path(tempfile.mkdtemp())
        themes, icons = tree(root)
        s = ap.scan(themes, icons)
        self.assertEqual(s["gtk"], ["Adw", "Dark"])
        self.assertEqual(s["icons"], ["Hicolor", "Papirus"])
        self.assertEqual(s["cursors"], ["Bib"])


class Cursor(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.themes, self.icons = tree(self.root)
        self.file = self.root / "cfg/sky/hypr/appearance.lua"
        self.ran = []

    def save(self, theme, size):
        return ap.save_cursor(self.file, theme, size, self.themes, self.icons, run=self.ran.append)

    def test_writes_generated_file_and_applies_live(self):
        self.assertEqual(self.save("Bib", 32), 0)
        t = self.file.read_text()
        self.assertIn("do not edit", t.lower())
        self.assertIn('hl.env("XCURSOR_THEME", "Bib")', t)
        self.assertIn('hl.env("XCURSOR_SIZE", "32")', t)
        self.assertIn('hl.env("HYPRCURSOR_THEME", "Bib")', t)
        self.assertIn('hl.env("HYPRCURSOR_SIZE", "32")', t)
        self.assertIn(["hyprctl", "setcursor", "Bib", "32"], self.ran)
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", "Bib"], self.ran)
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", "32"], self.ran)

    def test_second_save_keeps_a_backup(self):
        self.save("Bib", 24)
        self.save("Bib", 48)
        self.assertIn('"24"', Path(str(self.file) + ".bak").read_text())
        self.assertIn('"48"', self.file.read_text())

    def test_rejects_unknown_or_injected_input_without_touching_anything(self):
        for theme, size in (('x"); os.execute("id") --', 24), ("Nope", 24), ("Bib", 0),
                            ("Bib", "24; rm"), ("Bib", 999)):
            self.assertNotEqual(self.save(theme, size), 0, (theme, size))
        self.assertFalse(self.file.exists())
        self.assertEqual(self.ran, [])


class GtkIcons(unittest.TestCase):
    def test_apply_only_installed_names(self):
        root = Path(tempfile.mkdtemp())
        themes, icons = tree(root)
        ran = []
        self.assertEqual(ap.set_gsetting("gtk-theme", "Adw", themes, icons, run=ran.append), 0)
        self.assertEqual(ap.set_gsetting("icon-theme", "Papirus", themes, icons, run=ran.append), 0)
        self.assertEqual(ran, [["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "Adw"],
                               ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", "Papirus"]])
        self.assertNotEqual(ap.set_gsetting("gtk-theme", "Bib", themes, icons, run=ran.append), 0)
        self.assertNotEqual(ap.set_gsetting("icon-theme", "Bib", themes, icons, run=ran.append), 0)
        self.assertEqual(len(ran), 2)


class Palette(unittest.TestCase):
    def setUp(self):
        self.file = Path(tempfile.mkdtemp()) / "sky/theme.json"

    def test_saves_scheme_and_accent(self):
        self.assertEqual(ap.save_palette(self.file, "scheme-vibrant", "#AABBCC"), 0)
        self.assertEqual(json.loads(self.file.read_text()), {"scheme": "scheme-vibrant", "accent": "#aabbcc"})
        self.assertEqual(ap.save_palette(self.file, "scheme-neutral", None), 0)
        self.assertEqual(json.loads(self.file.read_text()), {"scheme": "scheme-neutral", "accent": None})
        self.assertTrue(Path(str(self.file) + ".bak").is_file())

    def test_rejects_bad_values_and_keeps_the_file(self):
        ap.save_palette(self.file, "scheme-vibrant", None)
        before = self.file.read_text()
        self.assertNotEqual(ap.save_palette(self.file, "scheme-evil", None), 0)
        self.assertNotEqual(ap.save_palette(self.file, "scheme-vibrant", "red"), 0)
        self.assertNotEqual(ap.save_palette(self.file, "scheme-vibrant", "#12345"), 0)
        self.assertEqual(self.file.read_text(), before)


if __name__ == "__main__":
    unittest.main()
