"""Tests for scripts/sky_monitors.py (run: python3 -m unittest discover -s tests)."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import sky_monitors as mon  # noqa: E402

SAMPLE = """-- Monitores en serie
-- HDMI-A-2 (1080p) a la izquierda

hl.monitor({
    output = "HDMI-A-2",
    mode = "1920x1080@100",
    position = "0x0",
    scale = 1
})

hl.monitor({
    output = "DP-2",
    mode = "2560x1440@180",
    position = "1920x0",
    scale = 1,
    bitdepth = 10
})
"""

ONE_LINE = 'hl.monitor({ output="DP-2", mode="2560x1440@180", position="1920x0", scale=1, bitdepth=10 })\n'


class Parse(unittest.TestCase):
    def test_parses_multiline_blocks(self):
        m = mon.parse_monitors(SAMPLE)
        self.assertEqual(list(m), ["HDMI-A-2", "DP-2"])
        self.assertEqual(m["DP-2"], {"output": "DP-2", "mode": "2560x1440@180", "position": "1920x0", "scale": 1, "bitdepth": 10})
        self.assertEqual(m["HDMI-A-2"]["scale"], 1)

    def test_parses_single_line_and_fractional_scale(self):
        m = mon.parse_monitors(ONE_LINE.replace("scale=1,", "scale=1.25,"))
        self.assertEqual(m["DP-2"]["scale"], 1.25)
        self.assertEqual(m["DP-2"]["bitdepth"], 10)

    def test_ignores_comments_and_garbage(self):
        self.assertEqual(mon.parse_monitors("-- nothing\n"), {})


class Rewrite(unittest.TestCase):
    def test_changes_only_mode_and_scale_of_one_output(self):
        out = mon.rewrite(SAMPLE, "DP-2", mode="1920x1080@60", scale=1.5)
        self.assertIn('mode = "1920x1080@60"', out)
        self.assertIn("scale = 1.5,", out)
        self.assertIn("bitdepth = 10", out)
        self.assertIn('position = "1920x0"', out)
        # the other monitor and the comments are untouched
        self.assertEqual(out.split("hl.monitor")[1], SAMPLE.split("hl.monitor")[1])
        self.assertTrue(out.startswith("-- Monitores en serie\n-- HDMI-A-2 (1080p) a la izquierda\n"))

    def test_identity_rewrite_is_byte_identical(self):
        self.assertEqual(mon.rewrite(SAMPLE, "DP-2", mode="2560x1440@180", scale=1), SAMPLE)
        self.assertEqual(mon.rewrite(ONE_LINE, "DP-2", mode="2560x1440@180", scale=1), ONE_LINE)

    def test_single_line_rewrite(self):
        out = mon.rewrite(ONE_LINE, "DP-2", mode="1920x1080@60", scale=2)
        self.assertEqual(out, 'hl.monitor({ output="DP-2", mode="1920x1080@60", position="1920x0", scale=2, bitdepth=10 })\n')

    def test_unknown_output_is_appended_as_new_block(self):
        out = mon.rewrite(SAMPLE, "eDP-1", mode="1920x1080@60", scale=1, position="3840x0")
        self.assertTrue(out.startswith(SAMPLE))
        self.assertEqual(mon.parse_monitors(out)["eDP-1"],
                         {"output": "eDP-1", "mode": "1920x1080@60", "position": "3840x0", "scale": 1})

    def test_position_is_written_when_given(self):
        out = mon.rewrite(SAMPLE, "DP-2", mode="2560x1440@180", scale=1, position="0x1080")
        self.assertEqual(mon.parse_monitors(out)["DP-2"]["position"], "0x1080")
        self.assertEqual(mon.parse_monitors(out)["DP-2"]["bitdepth"], 10)

    def test_scale_without_existing_field_is_added(self):
        text = 'hl.monitor({ output = "X-1", mode = "800x600@60", position = "0x0" })\n'
        self.assertEqual(mon.parse_monitors(mon.rewrite(text, "X-1", mode="800x600@60", scale=2))["X-1"]["scale"], 2)


class Modes(unittest.TestCase):
    MODES = ["2560x1440@59.95Hz", "2560x1440@180.00Hz", "1920x1080@60.00Hz", "1920x1080@60.00Hz", "1920x1080@59.94Hz", "640x480@60.00Hz"]

    def test_groups_by_resolution_biggest_first_without_duplicates(self):
        g = mon.group_modes(self.MODES)
        self.assertEqual([r for r, _ in g], ["2560x1440", "1920x1080", "640x480"])
        self.assertEqual(g[0][1], [180.0, 59.95])
        self.assertEqual(g[1][1], [60.0, 59.94])

    def test_format_rate(self):
        self.assertEqual(mon.fmt_rate(180.0), "180")
        self.assertEqual(mon.fmt_rate(59.95), "59.95")
        self.assertEqual(mon.fmt_rate(59.94000), "59.94")

    def test_bad_modes_are_skipped(self):
        self.assertEqual(mon.group_modes(["junk", "1920x1080@60.00Hz"]), [("1920x1080", [60.0])])


class Lua(unittest.TestCase):
    def test_eval_prefers_live_position_and_keeps_extra_fields(self):
        s = mon.eval_call(SAMPLE, "DP-2", mode="1920x1080@60", scale=1.25, position="9x9")
        self.assertEqual(s, 'hl.monitor({ output = "DP-2", mode = "1920x1080@60", position = "9x9", scale = 1.25, bitdepth = 10 })')

    def test_eval_uses_given_position_when_not_in_file(self):
        s = mon.eval_call("", "DP-3", mode="800x600@60", scale=1, position="5x6")
        self.assertEqual(s, 'hl.monitor({ output = "DP-3", mode = "800x600@60", position = "5x6", scale = 1 })')


class Save(unittest.TestCase):
    def test_save_writes_backup_and_new_content(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "monitors.lua"
            f.write_text(SAMPLE)
            mon.save(f, "DP-2", mode="1920x1080@60", scale=1)
            self.assertEqual((Path(d) / "monitors.lua.bak").read_text(), SAMPLE)
            self.assertIn('mode = "1920x1080@60"', f.read_text())

    def test_dry_run_changes_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "monitors.lua"
            f.write_text(SAMPLE)
            out = mon.save(f, "DP-2", mode="1920x1080@60", scale=1, dry_run=True)
            self.assertIn("1920x1080@60", out)
            self.assertEqual(f.read_text(), SAMPLE)
            self.assertFalse((Path(d) / "monitors.lua.bak").exists())


TEMPLATE = "-- Your monitors.\n-- hl.monitor({ output = \"DP-1\", mode = \"1x1@1\" })\n"
CHANGES = [{"output": "HDMI-A-2", "mode": "1920x1080@100", "scale": 1, "position": "0x1440"},
           {"output": "DP-2", "mode": "2560x1440@180", "scale": 1, "position": "0x0"}]


class UserLayer(unittest.TestCase):
    def test_create_when_file_and_directory_missing(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "sky" / "hypr" / "monitors.lua"
            mon.save_many(f, CHANGES[:1])
            m = mon.parse_monitors(f.read_text())
            self.assertEqual(m["HDMI-A-2"]["position"], "0x1440")
            self.assertFalse((f.parent / "monitors.lua.bak").exists())

    def test_template_only_file_keeps_comments_and_appends(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "monitors.lua"
            f.write_text(TEMPLATE)
            mon.save_many(f, CHANGES[:1])
            t = f.read_text()
            self.assertTrue(t.startswith(TEMPLATE))
            self.assertEqual(list(mon.parse_monitors(t)), ["HDMI-A-2"])
            self.assertEqual((Path(d) / "monitors.lua.bak").read_text(), TEMPLATE)

    def test_save_many_changes_all_and_keeps_other_fields(self):
        out = mon.rewrite_many(SAMPLE, CHANGES)
        m = mon.parse_monitors(out)
        self.assertEqual(m["HDMI-A-2"]["position"], "0x1440")
        self.assertEqual(m["DP-2"]["position"], "0x0")
        self.assertEqual(m["DP-2"]["bitdepth"], 10)

    def test_save_many_is_all_or_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "monitors.lua"
            f.write_text(SAMPLE)
            with self.assertRaises(ValueError):
                mon.save_many(f, [CHANGES[0], {"output": "DP-2", "mode": "bad", "scale": 1}])
            self.assertEqual(f.read_text(), SAMPLE)

    def test_unparsable_content_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "monitors.lua"
            f.write_text("local x = 1\n")
            with self.assertRaises(ValueError):
                mon.save_many(f, CHANGES[:1])
            self.assertEqual(f.read_text(), "local x = 1\n")


if __name__ == "__main__":
    unittest.main()
