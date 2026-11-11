"""Tests for scripts/sky_keybinds.py (run: python3 -m unittest discover -s tests)."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import sky_keybinds as kb  # noqa: E402

SOURCE = '''local hyprScripts = HOME .. "/s"
hl.bind("SUPER + I", hl.dsp.global("quickshell:settingsToggle"), { description = "Shell: Toggle settings" })
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(hyprScripts .. "/snip.sh"),
    { description = "Utilities: Screen snip" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl mute"), { locked = true })
hl.bind("SUPER + J", function() print("x") end, { description = "Window: fn" })
for i = 1, 3 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }), { description = "Window: ws" })
end
'''


def live(mask, key, desc="", submap=""):
    return {"modmask": mask, "key": key, "description": desc, "submap": submap,
            "dispatcher": "x", "arg": "1"}


BINDS = [
    live(64, "I", "Shell: Toggle settings"),
    live(65, "S", "Utilities: Screen snip"),
    live(0, "XF86AudioMute"),
    live(64, "J", "Window: fn"),
    live(64, "1", "Window: ws"),
    live(64, "Z"),
    live(64, "Q", "Window: closed", submap="resize"),
]


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.hypr = root / "hypr"
        (self.hypr / "hyprland").mkdir(parents=True)
        (self.hypr / "hyprland" / "keybinds.lua").write_text(SOURCE)
        self.user = root / "sky" / "hypr"


class Combos(unittest.TestCase):
    def test_label_and_canonical(self):
        self.assertEqual(kb.combo_from_bind(65, "S"), "SUPER+SHIFT+S")
        self.assertEqual(kb.combo_from_bind(76, "F11"), "SUPER+CTRL+ALT+F11")
        self.assertEqual(kb.parse_combo("shift + super + s"), (65, "S"))

    def test_rejects_injection_and_junk(self):
        for bad in ['SUPER + A"); os.execute("x', "SUPER", "", "FOO + A", "SUPER + A B", "SUPER + a;b",
                    "SUPER + mouse:abc", "A + A"]:
            with self.assertRaises(ValueError, msg=bad):
                kb.parse_combo(bad)

    def test_accepts_code_and_mouse(self):
        self.assertEqual(kb.parse_combo("SUPER + code:10"), (64, "code:10"))
        self.assertEqual(kb.parse_combo("SUPER+mouse:273"), (64, "mouse:273"))


class Listing(Base):
    def test_groups_rows_and_flags(self):
        out = kb.list_binds(BINDS, self.hypr, self.user)
        groups = {g["name"]: g["rows"] for g in out["groups"]}
        self.assertEqual(set(groups), {"Shell", "Utilities", "Other", "Window"})
        shell = groups["Shell"][0]
        self.assertEqual((shell["title"], shell["keys"], shell["editable"], shell["custom"]),
                         ("Toggle settings", ["SUPER", "I"], True, False))
        self.assertEqual(groups["Utilities"][0]["keys"], ["SUPER", "SHIFT", "S"])
        other = groups["Other"][0]
        self.assertTrue(other["editable"])
        self.assertEqual(other["keys"], ["XF86AudioMute"])
        win = {r["title"]: r for r in groups["Window"]}
        self.assertFalse(win["fn"]["editable"])
        self.assertTrue(win["fn"]["note"])
        self.assertFalse(win["ws"]["editable"])
        self.assertEqual(out["hidden"], 2)  # no description and not in source / other submap


class Collisions(Base):
    def test_collision_names_the_other_shortcut(self):
        c = kb.find_collision(BINDS, "SUPER + I", ignore="SUPER+SHIFT+S")
        self.assertEqual(c["title"], "Toggle settings")
        self.assertIsNone(kb.find_collision(BINDS, "SUPER + CTRL + ALT + F11"))

    def test_own_combo_is_not_a_collision(self):
        self.assertIsNone(kb.find_collision(BINDS, "SUPER + I", ignore="SUPER+I"))

    def test_other_submap_ignored(self):
        self.assertIsNone(kb.find_collision(BINDS, "SUPER + Q"))


class Overrides(Base):
    def test_set_writes_block_with_unbind_and_bind(self):
        kb.set_override("SUPER+SHIFT+S", "SUPER + ALT + S", BINDS, self.hypr, self.user)
        text = (self.user / "keybinds.lua").read_text()
        self.assertIn("-- sky:shortcut SUPER+SHIFT+S begin to=SUPER+ALT+S", text)
        self.assertIn('hl.unbind("SUPER + SHIFT + S")', text)
        self.assertIn('hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd(hyprScripts .. "/snip.sh")', text)
        self.assertIn('local hyprScripts = HOME .. "/s"', text)
        self.assertIn("-- sky:shortcut SUPER+SHIFT+S end", text)
        self.assertIn("Utilities: Screen snip", text)

    def test_set_keeps_handwritten_and_makes_backup_and_replaces_block(self):
        self.user.mkdir(parents=True)
        f = self.user / "keybinds.lua"
        f.write_text('-- mine\nhl.bind("SUPER + F5", hl.dsp.exec_cmd("x"))\n')
        kb.set_override("SUPER+I", "SUPER + O", BINDS, self.hypr, self.user)
        kb.set_override("SUPER+I", "SUPER + P", BINDS, self.hypr, self.user)
        text = f.read_text()
        self.assertTrue(text.startswith('-- mine\nhl.bind("SUPER + F5"'))
        self.assertEqual(text.count("sky:shortcut SUPER+I begin"), 1)
        self.assertIn("to=SUPER+P", text)
        self.assertNotIn("to=SUPER+O", text)
        self.assertTrue((self.user / "keybinds.lua.bak").exists())

    def test_set_rejects_bad_combo_and_unknown_or_readonly(self):
        for cid, combo in (("SUPER+I", 'SUPER + A"); x("'), ("SUPER+J", "SUPER + K"), ("SUPER+9", "SUPER + K")):
            with self.assertRaises(ValueError):
                kb.set_override(cid, combo, BINDS, self.hypr, self.user)
        self.assertFalse((self.user / "keybinds.lua").exists())

    def test_replacing_a_taken_combo_unbinds_it(self):
        kb.set_override("SUPER+SHIFT+S", "SUPER + I", BINDS, self.hypr, self.user)
        text = (self.user / "keybinds.lua").read_text()
        self.assertIn('hl.unbind("SUPER + I")', text)

    def test_reset_removes_only_its_block(self):
        kb.set_override("SUPER+I", "SUPER + O", BINDS, self.hypr, self.user)
        kb.set_override("SUPER+SHIFT+S", "SUPER + ALT + S", BINDS, self.hypr, self.user)
        kb.reset_override("SUPER+I", self.user)
        text = (self.user / "keybinds.lua").read_text()
        self.assertNotIn("SUPER+I begin", text)
        self.assertIn("SUPER+SHIFT+S begin", text)

    def test_listing_marks_custom_with_original(self):
        kb.set_override("SUPER+SHIFT+S", "SUPER + ALT + S", BINDS, self.hypr, self.user)
        now = [b for b in BINDS if b["key"] != "S"] + [live(72, "S", "Utilities: Screen snip")]
        out = kb.list_binds(now, self.hypr, self.user)
        row = [r for g in out["groups"] for r in g["rows"] if r["title"] == "Screen snip"][0]
        self.assertTrue(row["custom"])
        self.assertEqual(row["id"], "SUPER+SHIFT+S")
        self.assertEqual(row["original"], ["SUPER", "SHIFT", "S"])
        self.assertEqual(row["keys"], ["SUPER", "ALT", "S"])


if __name__ == "__main__":
    unittest.main()
