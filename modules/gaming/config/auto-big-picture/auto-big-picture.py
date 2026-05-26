#!/usr/bin/env python3
import os, subprocess, time, glob

JOYSTICK_NODES = "/dev/input/js*"

CHECK_INTERVAL = 2
ESDE_PATH = "/home/alejandro/Emulation/tools/ES-DE.AppImage"
STEAM_LIBRARY = "/run/media/system/Juegos/SteamLibrary/steamapps"
DESKTOP_OUTPUT = "/home/alejandro/Emulation/roms/steam"

EXCLUDE = ["Proton", "Steam Linux", "Steamworks"]

def update_steam_shortcuts():
    import glob as g
    for f in g.glob(f"{STEAM_LIBRARY}/appmanifest_*.acf"):
        with open(f) as file:
            content = file.read()
        
        import re
        app_id = re.search(r'"appid"\s+"([^"]+)"', content)
        name = re.search(r'"name"\s+"([^"]+)"', content)
        
        if not app_id or not name:
            continue
        
        name = name.group(1)
        app_id = app_id.group(1)
        
        if any(ex in name for ex in EXCLUDE):
            continue
        
        desktop = f"[Desktop Entry]\nName={name}\nExec=steam steam://rungameid/{app_id}\nIcon=steam\nType=Application"
        path = f"{DESKTOP_OUTPUT}/{name}.desktop"
        
        with open(path, "w") as out:
            out.write(desktop)
    
    print("✅ Shortcuts de Steam actualizados")

def is_joystick_connected():
    return len(glob.glob(JOYSTICK_NODES)) > 0

def handle_connect():
    print("🎮 Mando detectado! Actualizando juegos y abriendo ES-DE...")
    update_steam_shortcuts()
    subprocess.Popen([ESDE_PATH])

if __name__ == "__main__":
    print(f"🚀 Iniciado (Escuchando mandos...)")
    was_connected = is_joystick_connected()
    
    try:
        while True:
            is_now_connected = is_joystick_connected()
            if is_now_connected and not was_connected:
                handle_connect()
            was_connected = is_now_connected
            time.sleep(CHECK_INTERVAL)
    except KeyboardInterrupt:
        pass
