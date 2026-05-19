#!/usr/bin/env bash
set -euo pipefail

# gentleai-config.sh - Universal Newest-Wins Manager
# Flujo: RECOLECTAR (Lo más nuevo de todos) -> UNIFICAR en Master -> DISTRIBUIR Espejo

MASTER_DIR="$HOME/.gentle-ai/shared"
OPENCODE_PATH="$HOME/.config/opencode"
CLAUDE_PATH="$HOME/.claude"
GEMINI_PATH="$HOME/.gemini"

# Asegurar directorios base
mkdir -p "$MASTER_DIR"/{skills,commands,prompts}

sync() {
    echo "📥 Iniciando sincronización (El más nuevo manda)..."

    # 1. RECOLECTAR de todos los backends
    # Usamos -u (--update): solo copia si el origen es más nuevo que el destino
    local BACKENDS=("$OPENCODE_PATH" "$CLAUDE_PATH" "$GEMINI_PATH")
    
    for backend in "${BACKENDS[@]}"; do
        if [ -d "$backend" ]; then
            echo "   🔍 Colectando novedades de $backend..."
            # -a: archivo, -u: update (solo más nuevos), -v: verbose (para ver qué hace)
            [ -d "$backend/skills" ] && rsync -au "$backend/skills/" "$MASTER_DIR/skills/"
            [ -d "$backend/commands" ] && rsync -au "$backend/commands/" "$MASTER_DIR/commands/"
            [ -d "$backend/prompts" ] && rsync -au "$backend/prompts/" "$MASTER_DIR/prompts/"
        fi
    done

    # 2. DEFINIR REGLAS (AGENTS.md)
    # Las reglas de conducta NO se mezclan, mandan las de OpenCode
    echo "   🧠 Sincronizando reglas maestros desde OpenCode..."
    if [ -f "$OPENCODE_PATH/AGENTS.md" ]; then
        cp "$OPENCODE_PATH/AGENTS.md" "$MASTER_DIR/AGENTS.md"
    fi

    # 3. DISTRIBUIR el resultado unificado a todos
    distribute
}

distribute() {
    echo "   📤 Distribuyendo set unificado (Espejo total)..."
    
    local KEYS=("opencode" "claude" "gemini")
    
    for key in "${KEYS[@]}"; do
        local backend=""
        case "$key" in
            opencode) backend="$OPENCODE_PATH" ;;
            claude)   backend="$CLAUDE_PATH" ;;
            gemini)   backend="$GEMINI_PATH" ;;
        esac

        echo "      ✨ Espejando en $key..."
        mkdir -p "$backend"/{skills,commands,prompts}
        
        # DISTRIBUCIÓN ESPEJO: El backend se vuelve idéntico al Maestro
        rsync -a --delete "$MASTER_DIR/skills/" "$backend/skills/"
        rsync -a --delete "$MASTER_DIR/commands/" "$backend/commands/"
        rsync -a --delete "$MASTER_DIR/prompts/" "$backend/prompts/"
        
        # LIMPIEZA Y RECREACIÓN de reglas
        rm -f "$backend/AGENTS.md" "$backend/GEMINI.md"
        cp "$MASTER_DIR/AGENTS.md" "$backend/AGENTS.md"
        if [[ "$key" == "gemini" ]]; then
            cp "$MASTER_DIR/AGENTS.md" "$backend/GEMINI.md"
        fi
    done
    echo "✅ Sincronización Global 'Newest-Wins' completada."
}

backup_master() {
    local BDIR="$HOME/gentleai-backup/latest"
    echo "📦 Actualizando backup único en: $BDIR"
    mkdir -p "$BDIR"
    # Usamos rsync con --delete para que el backup sea un reflejo fiel y no acumule basura
    rsync -a --delete "$MASTER_DIR/" "$BDIR/"
    echo "✅ Backup único actualizado."
}

case "${1:-sync}" in
    sync)
        sync
        ;;
    distribute|restore)
        distribute
        ;;
    backup)
        backup_master
        ;;
    *)
        echo "Uso: $0 {sync|distribute|backup}"
        exit 1
        ;;
esac
