"""Tests for scripts/sys_stats.py (run: python3 -m unittest discover -s tests)."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import sys_stats  # noqa: E402


def write(root, rel, text):
    p = Path(root) / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


class Cpu(unittest.TestCase):
    def test_percent_is_busy_share_of_the_delta_between_two_samples(self):
        a = "cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 1 2 3 4\n"
        b = "cpu  150 0 150 850 150 0 0 0 0 0\ncpu0 1 2 3 4\n"
        # busy delta 100, idle (idle + iowait) delta 200 -> 33.3%
        self.assertEqual(sys_stats.cpu_percent(sys_stats.cpu_times(a), sys_stats.cpu_times(b)), 33.3)

    def test_percent_is_zero_when_no_time_passed(self):
        t = sys_stats.cpu_times("cpu  1 2 3 4 5 0 0 0\n")
        self.assertEqual(sys_stats.cpu_percent(t, t), 0.0)

    def test_ghz_averages_every_core(self):
        info = "processor\t: 0\ncpu MHz\t\t: 4600.000\n\nprocessor\t: 1\ncpu MHz\t\t: 3400.000\n"
        self.assertEqual(sys_stats.cpu_ghz(info), 4.0)

    def test_ghz_is_none_without_mhz_lines(self):
        self.assertIsNone(sys_stats.cpu_ghz("processor\t: 0\n"))

    def test_temp_reads_k10temp(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "hwmon0/name", "nvme\n")
            write(d, "hwmon0/temp1_input", "40000\n")
            write(d, "hwmon3/name", "k10temp\n")
            write(d, "hwmon3/temp1_input", "58250\n")
            self.assertEqual(sys_stats.cpu_temp(d), 58.2)

    def test_temp_falls_back_to_coretemp(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "hwmon1/name", "coretemp\n")
            write(d, "hwmon1/temp1_input", "61000\n")
            self.assertEqual(sys_stats.cpu_temp(d), 61.0)

    def test_temp_is_none_without_a_cpu_sensor(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "hwmon0/name", "nvme\n")
            write(d, "hwmon0/temp1_input", "40000\n")
            self.assertIsNone(sys_stats.cpu_temp(d))


class Memory(unittest.TestCase):
    def test_used_is_total_minus_available_and_ignores_swap(self):
        text = "MemTotal:       32000000 kB\nMemFree:  1000 kB\nMemAvailable:   16000000 kB\nSwapTotal: 8000000 kB\nSwapFree: 0 kB\n"
        self.assertEqual(sys_stats.memory(text), {"used": 16000000 * 1024, "total": 32000000 * 1024, "percent": 50.0})


class Gpu(unittest.TestCase):
    def amd(self, d, power="power1_average"):
        write(d, "card1/device/gpu_busy_percent", "41\n")
        write(d, "card1/device/mem_info_vram_used", str(6 * 1024**3) + "\n")
        write(d, "card1/device/mem_info_vram_total", str(16 * 1024**3) + "\n")
        write(d, "card1/device/hwmon/hwmon2/name", "amdgpu\n")
        write(d, "card1/device/hwmon/hwmon2/temp1_input", "62000\n")
        write(d, "card1/device/hwmon/hwmon2/" + power, "148000000\n")

    def test_reads_amdgpu_usage_vram_temp_and_watts(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "card0-DP-1/status", "connected\n")
            self.amd(d)
            self.assertEqual(sys_stats.gpu(d), {
                "percent": 41.0, "vramUsed": 6 * 1024**3, "vramTotal": 16 * 1024**3,
                "temp": 62.0, "watts": 148.0,
            })

    def test_watts_fall_back_to_power1_input(self):
        with tempfile.TemporaryDirectory() as d:
            self.amd(d, power="power1_input")
            self.assertEqual(sys_stats.gpu(d)["watts"], 148.0)

    def test_missing_sensors_are_none(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "card1/device/gpu_busy_percent", "7\n")
            self.assertEqual(sys_stats.gpu(d), {
                "percent": 7.0, "vramUsed": None, "vramTotal": None, "temp": None, "watts": None,
            })

    def test_no_amd_gpu_is_none(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "card0/device/vendor", "0x10de\n")
            self.assertIsNone(sys_stats.gpu(d))


class Disks(unittest.TestCase):
    MOUNTS = (
        "proc /proc proc rw 0 0\n"
        "tmpfs /tmp tmpfs rw 0 0\n"
        "/dev/nvme0n1p2 /home btrfs rw,subvol=/@home 0 0\n"
        "/dev/nvme0n1p2 / btrfs rw,subvol=/@ 0 0\n"
        "/dev/nvme0n1p2 /var/log btrfs rw 0 0\n"
        "/dev/nvme0n1p1 /boot vfat rw 0 0\n"
        "/dev/sda1 /mnt/Juegos ext4 rw 0 0\n"
        "/dev/loop0 /snap/core squashfs ro 0 0\n"
        "overlay /var/lib/docker/x overlay rw 0 0\n"
    )

    def test_one_entry_per_real_device_with_the_shortest_mountpoint(self):
        self.assertEqual(sys_stats.filesystems(self.MOUNTS), [("/", "/"), ("Juegos", "/mnt/Juegos")])

    def test_usage_from_statvfs(self):
        class St:
            f_frsize = 4096
            f_blocks = 1000
            f_bavail = 250
            f_bfree = 300
        out = sys_stats.disk_usage([("/", "/")], statvfs=lambda path: St)
        # used = (blocks - bfree) * frsize, total = used + bavail * frsize
        self.assertEqual(out, [{"label": "/", "used": 700 * 4096, "total": 950 * 4096, "percent": 73.7}])

    def test_unreadable_mount_is_skipped(self):
        def boom(path):
            raise OSError("gone")
        self.assertEqual(sys_stats.disk_usage([("/", "/")], statvfs=boom), [])

    def test_io_counts_whole_disks_only(self):
        a = (
            " 259       0 nvme0n1 10 0 1000 0 20 0 2000 0 0 0 0\n"
            " 259       1 nvme0n1p1 5 0 500 0 5 0 500 0 0 0 0\n"
            "   8       0 sda 1 0 100 0 1 0 100 0 0 0 0\n"
            "   7       0 loop0 1 0 9999 0 1 0 9999 0 0 0 0\n"
            " 254       0 dm-0 1 0 9999 0 1 0 9999 0 0 0 0\n"
            " 252       0 zram0 1 0 9999 0 1 0 9999 0 0 0 0\n"
        )
        b = (
            " 259       0 nvme0n1 10 0 3000 0 20 0 2400 0 0 0 0\n"
            " 259       1 nvme0n1p1 5 0 2500 0 5 0 900 0 0 0 0\n"
            "   8       0 sda 1 0 200 0 1 0 100 0 0 0 0\n"
            "   7       0 loop0 1 0 99999 0 1 0 99999 0 0 0 0\n"
            " 254       0 dm-0 1 0 99999 0 1 0 99999 0 0 0 0\n"
            " 252       0 zram0 1 0 99999 0 1 0 99999 0 0 0 0\n"
        )
        # sectors are 512 bytes; read (2000 + 100) * 512, written 400 * 512, over 2 s
        self.assertEqual(sys_stats.disk_io(sys_stats.disk_sectors(a), sys_stats.disk_sectors(b), 2.0),
                         {"readBps": 2100 * 256, "writeBps": 400 * 256})


if __name__ == "__main__":
    unittest.main()
