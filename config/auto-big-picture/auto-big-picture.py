#!/usr/bin/env python3
import os, subprocess, time, glob, sys

# ==========================================
# CONFIGURACIÓN (Cambia esto si cambias de SO)
# ==========================================
CONTROLLER_MAC = "A0:5A:59:D4:13:A3"
JOYSTICK_NODES = "/dev/input/js*"
CHECK_INTERVAL = 2  # Segundos entre escaneos
LAUNCH_ALWAYS  = True # Abrir Steam aunque ya esté abierto

# Comandos de Steam (Orden de prioridad)
STEAM_CMDS = [
    ["steam"], # Nativo
    ["flatpak", "run", "com.valvesoftware.Steam"] # Flatpak
]
# ==========================================

def get_steam_cmd():
    for cmd in STEAM_CMDS:
        binary = cmd[0]
        if subprocess.run(["which", binary], capture_output=True).returncode == 0:
            return cmd
    return None

def handle_connect():
    cmd_base = get_steam_cmd()
    if not cmd_base: return
    
    print(f"🎮 Mando detectado! Abriendo Steam...")
    subprocess.Popen(cmd_base + ["steam://open/bigpicture"])

def is_joystick_connected():
    nodes = glob.glob(JOYSTICK_NODES)
    return len(nodes) > 0

if __name__ == "__main__":
    print(f"🚀 Auto-Big-Picture Iniciado (Buscando en {JOYSTICK_NODES})")
    
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
