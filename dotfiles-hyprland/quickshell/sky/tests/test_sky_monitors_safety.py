import subprocess, sys, tempfile, unittest
from pathlib import Path
SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "sky_monitors.py"
GOOD = 'hl.monitor({\n    output = "DP-2", -- scale = 3\n    mode = "2560x1440@180",\n    position = "0x0",\n    scale = 1\n})\n'

def run(*a):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), *a], capture_output=True, text=True)

class Safety(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.TemporaryDirectory(); self.f = Path(self.d.name) / "monitors.lua"
    def tearDown(self): self.d.cleanup()
    def test_unknown_output_fails_and_leaves_file(self):
        self.f.write_text(GOOD); r = run("save", str(self.f), "eDP-9", "1920x1080@60", "1")
        self.assertNotEqual(r.returncode, 0); self.assertEqual(self.f.read_text(), GOOD)
    def test_unparsable_file_fails_and_leaves_file(self):
        self.f.write_text("garbage {{{\n"); r = run("save", str(self.f), "DP-2", "1920x1080@60", "1")
        self.assertNotEqual(r.returncode, 0); self.assertEqual(self.f.read_text(), "garbage {{{\n")
    def test_injection_rejected_by_eval(self):
        self.f.write_text(GOOD)
        for out, mode in (('X"}) os.execute("id") --', "1920x1080@60"), ("DP-2", '1"}) --')):
            r = run("eval", str(self.f), out, mode, "1"); self.assertNotEqual(r.returncode, 0)
    def test_bad_mode_never_written(self):
        self.f.write_text(GOOD); r = run("save", str(self.f), "DP-2", '1"x', "1")
        self.assertNotEqual(r.returncode, 0); self.assertEqual(self.f.read_text(), GOOD)
    def test_non_finite_scale_rejected(self):
        self.f.write_text(GOOD)
        for s in ("nan", "inf", "abc"):
            self.assertNotEqual(run("save", str(self.f), "DP-2", "1920x1080@60", s).returncode, 0)
        self.assertEqual(self.f.read_text(), GOOD)
    def test_comment_inside_block_is_not_edited(self):
        self.f.write_text(GOOD); r = run("save", str(self.f), "DP-2", "1920x1080@60", "2")
        self.assertEqual(r.returncode, 0); t = self.f.read_text()
        self.assertIn("-- scale = 3", t); self.assertIn('mode = "1920x1080@60"', t); self.assertIn("scale = 2\n", t)
    def test_symlink_target_stays_a_symlink(self):
        real = Path(self.d.name) / "real.lua"; real.write_text(GOOD); self.f.symlink_to(real)
        run("save", str(self.f), "DP-2", "1920x1080@60", "2")
        self.assertTrue(self.f.is_symlink()); self.assertIn("1920x1080@60", real.read_text())
