#!/bin/bash
# Script de "Confianza Total" para OpenClaw v2.0
# Resetea identidades y fuerza la aprobación manual de la nueva ID local.

set -e

CLAW_DIR="$HOME/.openclaw"
PAIRED_FILE="$CLAW_DIR/devices/paired.json"
IDENTITY_FILE="$CLAW_DIR/identity/device.json"

echo "🛑 Deteniendo servicios..."
systemctl --user stop openclaw-gateway openclaw-node || true

echo "🧹 Limpiando rastros viejos..."
rm -rf "$CLAW_DIR/identity/"*
rm -rf "$CLAW_DIR/devices/"*

echo "🆔 Generando nueva identidad (iniciando gateway brevemente)..."
# Iniciamos el gateway para que genere los archivos de identidad
systemctl --user start openclaw-gateway
sleep 5
systemctl --user stop openclaw-gateway

if [ ! -f "$IDENTITY_FILE" ]; then
    echo "❌ Error: No se generó el archivo de identidad."
    exit 1
fi

DEVICE_ID=$(jq -r '.deviceId' "$IDENTITY_FILE")
PUBLIC_KEY=$(jq -r '.publicKeyPem' "$IDENTITY_FILE" | grep -v "PUBLIC KEY" | tr -d '\n')
# OpenClaw usa una versión URL-safe de la public key en paired.json, pero a veces la PEM sirve si se limpia.
# Intentamos extraer la key limpia de la PEM.
CLEAN_PUB=$(jq -r '.publicKeyPem' "$IDENTITY_FILE" | openssl pkey -pubin -outform DER | tail -c 32 | base64 | tr '+/' '-_' | tr -d '=')

echo "🛡️ Inyectando Confianza Total para Device ID: $DEVICE_ID"

cat <<EOF > "$PAIRED_FILE"
{
  "$DEVICE_ID": {
    "deviceId": "$DEVICE_ID",
    "publicKey": "$CLEAN_PUB",
    "displayName": "$(hostname) (Total Trust)",
    "platform": "linux",
    "deviceFamily": "Linux",
    "clientId": "node-host",
    "clientMode": "node",
    "role": "node",
    "roles": ["node", "operator"],
    "scopes": ["operator.admin", "operator.read", "operator.write", "operator.approvals", "operator.pairing"],
    "approvedScopes": ["operator.admin", "operator.read", "operator.write", "operator.approvals", "operator.pairing"],
    "tokens": {
      "node": { "token": "TRUSTED_NODE_TOKEN", "role": "node", "scopes": [], "createdAtMs": $(date +%s%3N) },
      "operator": { "token": "TRUSTED_OPERATOR_TOKEN", "role": "operator", "scopes": ["operator.admin"], "createdAtMs": $(date +%s%3N) }
    },
    "createdAtMs": $(date +%s%3N),
    "approvedAtMs": $(date +%s%3N)
  }
}
EOF

echo "⚙️ Configurando auto-aprobación en openclaw.json..."
openclaw config set gateway.nodes.pairing.autoApproveCidrs '["127.0.0.1/32"]' --strict-json

echo "🚀 Reiniciando servicios con confianza ciega..."
systemctl --user start openclaw-gateway
sleep 2
systemctl --user start openclaw-node

echo "✅ Listo. Verificá con 'claw-status'."
