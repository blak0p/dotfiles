import time, hid, psutil, os

# ==========================================
# CONFIGURACIÓN (Hardware y Sensores)
# ==========================================
VENDOR_ID  = 0x3633
PRODUCT_ID = 0x0002
INTERVAL   = 3          # Segundos entre actualizaciones
SENSOR_NAME = "k10temp" # Cambia esto si cambias de CPU (Intel/AMD)
LABEL_TEMP  = "Tccd1"   # Etiqueta del sensor de temperatura
# ==========================================

def get_data(v=0, m="util"):
    d = [16] + [0]*63
    if m == "util": d[1] = 76
    elif m == "start": return [16, 170] + [0]*62
    elif m == "temp": d[1] = 19
    d[2] = (v - 1) // 10 + 1
    nums = [int(c) for c in str(v)]
    for i, n in enumerate(nums[::-1]): d[5-i] = n
    return d

try:
    h = hid.device()
    h.open(VENDOR_ID, PRODUCT_ID)
    h.write(get_data(m="start"))
    while True:
        try:
            sensors = psutil.sensors_temperatures()[SENSOR_NAME]
            tdie = next((s.current for s in sensors if s.label == LABEL_TEMP), sensors[0].current)
            t = round(tdie)
            h.write(get_data(v=t, m="temp"))
        except Exception as e:
            pass
        
        time.sleep(INTERVAL)
        u = round(psutil.cpu_percent())
        h.write(get_data(v=u, m="util"))
        time.sleep(INTERVAL)
except Exception as e:
    pass
finally:
    if 'h' in locals(): h.close()
