"""Tests for scripts/sky_input.py (run: python3 -m unittest discover -s tests)."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import sky_input as inp  # noqa: E402

RULES = """! model
  pc105           Generic 105-key PC

! layout
  us              English (US)
  es              Spanish
  de              German

! variant
  intl            us: English (US, intl., with dead keys)
  dvorak          us: English (Dvorak)
  cat             es: Catalan (Spain, with middle-dot L)
  nodeadkeys      de: German (no dead keys)

! option
  lv3             Key to choose the 3rd level
"""


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.rules = self.dir / "evdev.lst"
        self.rules.write_text(RULES)
        self.xkb = inp.parse_rules(RULES)

    def model(self, **kw):
        m = {"layouts": [{"layout": "us", "variant": "intl"}, {"layout": "es", "variant": ""}], "rate": 35, "delay": 250}
        m.update(kw)
        return m


class TestRules(Base):
    def test_layouts_and_variants(self):
        self.assertEqual(self.xkb["layouts"]["es"], "Spanish")
        self.assertEqual(self.xkb["variants"]["us"]["intl"], "English (US, intl., with dead keys)")
        self.assertEqual(set(self.xkb["variants"]), {"us", "es", "de"})


class TestRender(Base):
    def test_render_lua(self):
        lua = inp.render(self.model(), self.xkb)
        self.assertTrue(lua.startswith("-- "))
        self.assertIn("do not edit by hand", lua.splitlines()[0] + lua.splitlines()[1])
        self.assertIn('kb_layout = "us,es"', lua)
        self.assertIn('kb_variant = "intl,"', lua)
        self.assertIn("repeat_rate = 35", lua)
        self.assertIn("repeat_delay = 250", lua)
        self.assertIn("hl.config({", lua)

    def test_eval_has_no_comment_header_but_same_config(self):
        ev = inp.render(self.model(), self.xkb, header=False)
        self.assertNotIn("--", ev)
        self.assertIn('kb_layout = "us,es"', ev)

    def test_rejects_injection_and_unknown(self):
        bad = [
            self.model(layouts=[{"layout": 'us"}) os.execute("x") --', "variant": ""}]),
            self.model(layouts=[{"layout": "zz", "variant": ""}]),
            self.model(layouts=[{"layout": "us", "variant": "cat"}]),
            self.model(layouts=[]),
            self.model(rate=0), self.model(rate=1000), self.model(rate="35"), self.model(rate=True),
            self.model(delay=5), self.model(delay=99999), self.model(delay=250.5),
            {"layouts": [{"layout": "us", "variant": ""}]},
        ]
        for m in bad:
            with self.assertRaises(ValueError, msg=str(m)):
                inp.render(m, self.xkb)

    def test_bounds_accepted(self):
        inp.render(self.model(rate=1, delay=100), self.xkb)
        inp.render(self.model(rate=100, delay=2000), self.xkb)


class TestSave(Base):
    def test_save_creates_then_backs_up(self):
        f = self.dir / "sub" / "input.lua"
        inp.save(f, self.model(), self.xkb)
        first = f.read_text()
        self.assertIn('kb_layout = "us,es"', first)
        inp.save(f, self.model(layouts=[{"layout": "de", "variant": "nodeadkeys"}]), self.xkb)
        self.assertEqual((self.dir / "sub" / "input.lua.bak").read_text(), first)
        self.assertIn('kb_layout = "de"', f.read_text())

    def test_invalid_leaves_file_untouched(self):
        f = self.dir / "input.lua"
        inp.save(f, self.model(), self.xkb)
        before = f.read_text()
        with self.assertRaises(ValueError):
            inp.save(f, self.model(rate=0), self.xkb)
        self.assertEqual(f.read_text(), before)
        self.assertFalse((self.dir / "input.lua.bak").exists())

    def test_dry_run_writes_nothing(self):
        f = self.dir / "input.lua"
        out = inp.save(f, self.model(), self.xkb, dry_run=True)
        self.assertIn("kb_layout", out)
        self.assertFalse(f.exists())


class TestLanguage(Base):
    def test_merge_keeps_other_keys(self):
        f = self.dir / "settings.json"
        f.write_text(json.dumps({"screen": "DP-2"}))
        inp.set_language(f, "es")
        self.assertEqual(json.loads(f.read_text()), {"screen": "DP-2", "language": "es"})
        inp.set_language(f, "auto")
        self.assertEqual(json.loads(f.read_text()), {"screen": "DP-2", "language": "auto"})

    def test_creates_missing_and_validates(self):
        f = self.dir / "a" / "settings.json"
        inp.set_language(f, "en")
        self.assertEqual(json.loads(f.read_text()), {"language": "en"})
        with self.assertRaises(ValueError):
            inp.set_language(f, "fr")
        self.assertEqual(json.loads(f.read_text()), {"language": "en"})

    def test_refuses_unparsable_file(self):
        f = self.dir / "settings.json"
        f.write_text("{not json")
        with self.assertRaises(ValueError):
            inp.set_language(f, "es")
        self.assertEqual(f.read_text(), "{not json")


class TestCli(Base):
    def run_cli(self, *args):
        env = dict(os.environ, SKY_XKB_RULES=str(self.rules))
        return subprocess.run([sys.executable, str(SCRIPTS / "sky_input.py"), *args], capture_output=True, text=True, env=env)

    def test_layouts_variants(self):
        r = self.run_cli("layouts")
        self.assertEqual(r.returncode, 0)
        self.assertIn({"code": "es", "name": "Spanish"}, json.loads(r.stdout))
        r = self.run_cli("variants", "us")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(r.stdout)[0], {"code": "", "name": ""})
        self.assertIn({"code": "dvorak", "name": "English (Dvorak)"}, json.loads(r.stdout))
        self.assertEqual(self.run_cli("variants", "zz").returncode, 1)

    def test_save_and_eval_cli(self):
        f = self.dir / "input.lua"
        r = self.run_cli("save", str(f), "--json", json.dumps(self.model()))
        self.assertEqual((r.returncode, r.stderr), (0, ""))
        self.assertIn('kb_variant = "intl,"', f.read_text())
        r = self.run_cli("eval", "--json", json.dumps(self.model()))
        self.assertEqual(r.returncode, 0)
        self.assertIn('kb_layout = "us,es"', r.stdout)
        r = self.run_cli("save", str(f), "--json", json.dumps(self.model(rate=0)))
        self.assertEqual(r.returncode, 1)
        self.assertIn("sky_input:", r.stderr)

    def test_language_cli(self):
        f = self.dir / "s.json"
        r = self.run_cli("language", str(f), "es")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(f.read_text()), {"language": "es"})


if __name__ == "__main__":
    unittest.main()
