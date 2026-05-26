#!/usr/bin/env bash
set -euo pipefail

# Update Ollama models — solo descarga si hay versión nueva

OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
MANIFEST_DIR="$HOME/.ollama/models/manifests/registry.ollama.ai/library"

check_update() {
  local model="$1"
  local name="${2%%:*}"
  local tag="${2##*:}"
  [[ "$tag" == "$name" ]] && tag="latest"

  local manifest="$MANIFEST_DIR/$name/$tag"
  if [[ ! -f "$manifest" ]]; then
    return 0  # no existe local, descargar
  fi

  # Digest del config en el manifiesto local
  local local_digest
  local_digest=$(python3 -c "import json; print(json.load(open('$manifest'))['config']['digest'])" 2>/dev/null)
  if [[ -z "$local_digest" ]]; then
    return 0
  fi

  # Digest remoto via registry API
  local remote_digest
  remote_digest=$(curl -sfL --max-time 5 \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "https://registry.ollama.ai/v2/library/$name/manifests/$tag" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['config']['digest'])" 2>/dev/null) || true

  if [[ -z "$remote_digest" ]]; then
    echo "  ⚠ No se pudo consultar registry, descargando igual..."
    return 0
  fi

  if [[ "$local_digest" == "$remote_digest" ]]; then
    echo "  ✔ Ya actualizado"
    return 1
  fi

  echo "  ↻ Nueva versión disponible"
  return 0
}

models=$(ollama list | tail -n +2 | awk '{print $1}')
count=0
skipped=0

for model in $models; do
  echo "==> $model ..."
  if check_update "$model" "$model"; then
    ollama pull "$model"
    count=$((count + 1))
  else
    skipped=$((skipped + 1))
  fi
  echo ""
done

echo "✅ $count actualizados, $skipped ya al día."
