import subprocess
import os
import time

# Usamos el binario directamente para el arranque en frío
LAUNCH_CMD = "steam -bigpicture"

def is_steam_running():
    # Comprobamos si el proceso principal existe
    try:
        subprocess.check_output(["pgrep", "-x", "steam"])
        return True
    except subprocess.CalledProcessError:
        return False

def main():
    # Escuchamos el kernel sin buffers
    cmd = ["stdbuf", "-oL", "udevadm", "monitor", "--subsystem-match=input", "--udev"]
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, bufsize=1)

    for line in process.stdout:
        # Detectamos el 'event' (es lo primero que lanza el hardware)
        if "add" in line and "event" in line:
            if not is_steam_running():
                # LANZAMIENTO CRÍTICO: 
                # Ejecutamos Steam y lo mandamos al fondo inmediatamente
                os.system(f"{LAUNCH_CMD} &")
            else:
                # Si Steam ya estaba abierto por casualidad, usamos el protocolo rápido
                os.system("steam steam://open/bigpicture &")
            
            # Pausa de seguridad para no duplicar procesos mientras Steam carga
            time.sleep(15)

if __name__ == "__main__":
    main()
