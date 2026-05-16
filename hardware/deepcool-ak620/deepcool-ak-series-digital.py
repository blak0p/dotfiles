import time, hid, psutil
VENDOR_ID, PRODUCT_ID, SENSOR, INTERVAL = 0x3633, 0x0002, "k10temp", 3

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
            sensors = psutil.sensors_temperatures()[SENSOR]
            tdie = next((s.current for s in sensors if s.label == "Tccd1"), sensors[0].current)
            t = round(tdie)
            h.write(get_data(v=t, m="temp"))
        except: pass
        time.sleep(INTERVAL)
        u = round(psutil.cpu_percent())
        h.write(get_data(v=u, m="util"))
        time.sleep(INTERVAL)
except: pass
finally:
    if 'h' in locals(): h.close()
