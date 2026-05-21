#!/bin/bash
# switch-model.sh: Full model cleanup + switch + session restart
# Usage: ./switch-model.sh [model_id]
# Default: ollama/qwen3.5:latest

MODEL="${1:-ollama/qwen3.5:latest}"

echo "=== 1. Parando TODOS los modelos de Ollama ==="
# Obtener lista de modelos corriendo y pararlos uno por uno
RUNNING=$(curl -s http://127.0.0.1:11434/api/ps | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
if [ -n "$RUNNING" ]; then
  for m in $RUNNING; do
    echo "  Stopping: $m"
    curl -s -X POST http://127.0.0.1:11434/api/generate -d "{\"model\": \"$m\", \"prompt\": \"\", \"keep_alive\": 0}" > /dev/null
    ollama stop "$m" 2>/dev/null || true
  done
else
  echo "  Ningun modelo corriendo."
fi

echo "=== 2. Eviction total de VRAM ==="
curl -s -X POST http://127.0.0.1:11434/api/generate -d '{"model": "", "prompt": "", "keep_alive": 0}' > /dev/null
sleep 2

echo "=== 3. Verificando VRAM liberada ==="
FREE_VRAM=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
if [ -n "$FREE_VRAM" ]; then
  echo "  VRAM libre: ${FREE_VRAM} MiB"
fi

echo "=== 4. Cambiando modelo en OpenClaw ==="
openclaw models set "$MODEL"
echo "  Modelo configurado: $MODEL"

echo "=== 5. Borrando sesiones activas de WhatsApp para forzar nueva sesion ==="
# Eliminar la entrada de session.json para que la proxima interaccion cree sesion nueva
python3 -c "
import json, os, glob

# 1. Limpiar sessions.json
path = '/var/home/alejandro/.openclaw/agents/main/sessions/sessions.json'
if os.path.exists(path):
    with open(path, 'r') as f: data = json.load(f)
    # Borrar todas las sesiones de whatsapp
    keys = [k for k in list(data.keys()) if 'whatsapp' in k.lower()]
    for k in keys: del data[k]
    with open(path, 'w') as f: json.dump(data, f, indent=2)
    print('  Entradas de WhatsApp eliminadas:', len(keys))
else:
    print('  No sessions.json encontrado')

# 2. Borrar archivos fisicos de sesiones de whatsapp (jsonl, trajectory, path)
session_dir = '/var/home/alejandro/.openclaw/agents/main/sessions'
for pattern in ['*.jsonl', '*.trajectory.jsonl', '*.trajectory-path.json']:
    for f in glob.glob(os.path.join(session_dir, pattern)):
        # Leer si es whatsapp
        try:
            with open(f, 'r') as fh:
                content = fh.read(2000)
            if 'whatsapp' in content.lower():
                os.remove(f)
                print('  Archivo borrado:', os.path.basename(f))
        except:
            pass
" 2>/dev/null || echo "  (python3 no disponible, sesion no reseteada)"

echo "=== 6. Reiniciando OpenClaw services ==="
systemctl --user restart openclaw-gateway.service openclaw-node.service

echo "=== 7. Esperando a que levanten ==="
sleep 5

echo "=== 8. Estado actual ==="
openclaw status | grep -E "default|Session|service|Gateway|Node"
