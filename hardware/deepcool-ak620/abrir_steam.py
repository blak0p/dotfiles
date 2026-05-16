import subprocess
import os

def steam_esta_abierto():
    try:
        subprocess.check_output(["pgrep", "steam"])
        return True
    except:
        return False

if not steam_esta_abierto():
    # El comando "-tenfoot" es el que lanza Big Picture directamente
    subprocess.Popen(["steam", "-tenfoot"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
