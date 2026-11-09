#!/usr/bin/env python3
"""Sample CPU, RAM, AMD GPU and disk usage for the island Performance module.

Prints one JSON object per line every `--interval` seconds until killed:
  {"cpu": {"percent", "temp", "ghz"}, "mem": {"used", "total", "percent"},
   "gpu": {"percent", "vramUsed", "vramTotal", "temp", "watts"} | null,
   "disks": [{"label", "used", "total", "percent"}], "readBps", "writeBps"}
Missing sensors are null. No network, swap or CPU power (RAPL needs root).
"""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

PROC = Path("/proc")
HWMON = Path("/sys/class/hwmon")
DRM = Path("/sys/class/drm")

CPU_SENSORS = ("k10temp", "zenpower", "coretemp")
REAL_FS_SOURCE = re.compile(r"^/dev/(?!loop)")
HIDDEN_MOUNTS = ("/boot", "/efi", "/boot/efi")
WHOLE_DISK = re.compile(r"^(nvme\d+n\d+|[sv]d[a-z]+|mmcblk\d+)$")


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def read_num(path, scale=1.0):
    text = read(path)
    try:
        return float(text) / scale if text is not None else None
    except ValueError:
        return None


# ---- CPU ----

def cpu_times(stat_text):
    """(busy, total) jiffies from the aggregate `cpu` line of /proc/stat."""
    for line in stat_text.splitlines():
        if line.startswith("cpu "):
            v = [int(x) for x in line.split()[1:]]
            idle = v[3] + (v[4] if len(v) > 4 else 0)
            total = sum(v[:8])
            return total - idle, total
    return 0, 0


def cpu_percent(a, b):
    total = b[1] - a[1]
    return round(100.0 * (b[0] - a[0]) / total, 1) if total > 0 else 0.0


def cpu_ghz(cpuinfo_text):
    mhz = [float(m) for m in re.findall(r"^cpu MHz\s*:\s*([\d.]+)", cpuinfo_text, re.M)]
    return round(sum(mhz) / len(mhz) / 1000, 1) if mhz else None


def cpu_temp(hwmon_root=HWMON):
    by_name = {}
    for d in sorted(Path(hwmon_root).glob("hwmon*")):
        by_name.setdefault(read(d / "name"), d)
    for name in CPU_SENSORS:
        if name in by_name:
            t = read_num(by_name[name] / "temp1_input", 1000)
            if t is not None:
                return round(t, 1)
    return None


# ---- Memory ----

def memory(meminfo_text):
    kb = {k: int(v) for k, v in re.findall(r"^(\w+):\s+(\d+) kB", meminfo_text, re.M)}
    total = kb.get("MemTotal", 0) * 1024
    used = total - kb.get("MemAvailable", 0) * 1024
    return {"used": used, "total": total, "percent": round(100.0 * used / total, 1) if total else 0.0}


# ---- GPU (amdgpu) ----

def gpu(drm_root=DRM):
    for card in sorted(Path(drm_root).glob("card*")):
        dev = card / "device"
        busy = read_num(dev / "gpu_busy_percent")
        if busy is None:
            continue
        hw = next(iter(sorted((dev / "hwmon").glob("hwmon*"))), None)
        watts = None
        if hw is not None:
            watts = read_num(hw / "power1_average", 1e6)
            if watts is None:
                watts = read_num(hw / "power1_input", 1e6)
        vram_used = read_num(dev / "mem_info_vram_used")
        vram_total = read_num(dev / "mem_info_vram_total")
        temp = read_num(hw / "temp1_input", 1000) if hw is not None else None
        return {
            "percent": busy,
            "vramUsed": int(vram_used) if vram_used is not None else None,
            "vramTotal": int(vram_total) if vram_total is not None else None,
            "temp": round(temp, 1) if temp is not None else None,
            "watts": round(watts, 1) if watts is not None else None,
        }
    return None


# ---- Disks ----

def filesystems(mounts_text):
    """[(label, mountpoint)]: one per block device, its shortest mountpoint."""
    best = {}
    for line in mounts_text.splitlines():
        parts = line.split()
        if len(parts) < 2 or not REAL_FS_SOURCE.match(parts[0]):
            continue
        src, mnt = parts[0], parts[1].replace("\\040", " ")
        if mnt in HIDDEN_MOUNTS:
            continue
        if src not in best or len(mnt) < len(best[src]):
            best[src] = mnt
    mnts = sorted(best.values(), key=lambda m: (m != "/", m))
    return [("/" if m == "/" else os.path.basename(m), m) for m in mnts]


def disk_usage(fss, statvfs=os.statvfs):
    out = []
    for label, mnt in fss:
        try:
            st = statvfs(mnt)
        except OSError:
            continue
        used = (st.f_blocks - st.f_bfree) * st.f_frsize
        total = used + st.f_bavail * st.f_frsize
        if total <= 0:
            continue
        out.append({"label": label, "used": used, "total": total, "percent": round(100.0 * used / total, 1)})
    return out


def disk_sectors(diskstats_text):
    """(read, written) 512-byte sectors summed over whole disks."""
    r = w = 0
    for line in diskstats_text.splitlines():
        p = line.split()
        if len(p) >= 10 and WHOLE_DISK.match(p[2]):
            r += int(p[5])
            w += int(p[9])
    return r, w


def disk_io(a, b, seconds):
    if seconds <= 0:
        return {"readBps": 0, "writeBps": 0}
    return {"readBps": int((b[0] - a[0]) * 512 / seconds), "writeBps": int((b[1] - a[1]) * 512 / seconds)}


# ---- Loop ----

def sample():
    return (cpu_times(read(PROC / "stat") or ""), disk_sectors(read(PROC / "diskstats") or ""), time.monotonic())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=float, default=1.0)
    args = ap.parse_args()
    prev = sample()
    while True:
        time.sleep(args.interval)
        cur = sample()
        out = {
            "cpu": {"percent": cpu_percent(prev[0], cur[0]), "temp": cpu_temp(),
                    "ghz": cpu_ghz(read(PROC / "cpuinfo") or "")},
            "mem": memory(read(PROC / "meminfo") or ""),
            "gpu": gpu(),
            "disks": disk_usage(filesystems(read(PROC / "self/mounts") or "")),
            **disk_io(prev[1], cur[1], cur[2] - prev[2]),
        }
        prev = cur
        try:
            print(json.dumps(out), flush=True)
        except BrokenPipeError:
            return


if __name__ == "__main__":
    sys.exit(main())
