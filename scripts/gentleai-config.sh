#!/usr/bin/env bash
set -euo pipefail

# gentleai-config.sh - Universal Newest-Wins Manager
# Flujo: RECOLECTAR (Lo más nuevo de todos) -> UNIFICAR en Master -> DISTRIBUIR Espejo

MASTER_DIR="$HOME/.gentle-ai/shared"
OPENCODE_PATH="$HOME/.config/opencode"
CLAUDE_PATH="$HOME/.claude"
ANTIGRAVITY_GEMINI_PATH="$HOME/.gemini/skills"
ANTIGRAVITY_PATH="$HOME/.gemini/antigravity/skills"

mkdir -p "$MASTER_DIR"/{skills,commands,prompts}

sync() {
    echo "📥 Iniciando sincronización (El más nuevo manda)..."

    # 1. RECOLECTAR skills de todos (Claude, OpenCode, Antigravity x2)
    local SKILL_BACKENDS=("$OPENCODE_PATH/skills" "$CLAUDE_PATH/skills" "$ANTIGRAVITY_GEMINI_PATH" "$ANTIGRAVITY_PATH")
    for backend in "${SKILL_BACKENDS[@]}"; do
        if [ -d "$backend" ]; then
            echo "   🔍 Colectando skills de $backend..."
            rsync -au "$backend/" "$MASTER_DIR/skills/"
        fi
    done

    # 2. RECOLECTAR commands y prompts solo de Claude y OpenCode
    local CODE_BACKENDS=("$OPENCODE_PATH" "$CLAUDE_PATH")
    for backend in "${CODE_BACKENDS[@]}"; do
        if [ -d "$backend" ]; then
            [ -d "$backend/commands" ] && rsync -au "$backend/commands/" "$MASTER_DIR/commands/"
            [ -d "$backend/prompts" ] && rsync -au "$backend/prompts/" "$MASTER_DIR/prompts/"
        fi
    done

    # 3. AGENTS.md manda desde OpenCode
    echo "   🧠 Sincronizando reglas maestras desde OpenCode..."
    if [ -f "$OPENCODE_PATH/AGENTS.md" ]; then
        cp "$OPENCODE_PATH/AGENTS.md" "$MASTER_DIR/AGENTS.md"
    fi

    distribute
}

distribute() {
    echo "   📤 Distribuyendo set unificado..."

    # Claude y OpenCode reciben todo
    for backend in "$CLAUDE_PATH" "$OPENCODE_PATH"; do
        echo "      ✨ Espejando en $backend..."
        mkdir -p "$backend"/{skills,commands,prompts}
        rsync -a --delete "$MASTER_DIR/skills/"   "$backend/skills/"
        rsync -a --delete "$MASTER_DIR/commands/" "$backend/commands/"
        rsync -a --delete "$MASTER_DIR/prompts/"  "$backend/prompts/"
        cp "$MASTER_DIR/AGENTS.md" "$backend/AGENTS.md"
    done

    # Antigravity solo recibe skills, en sus dos rutas
    for backend in "$ANTIGRAVITY_GEMINI_PATH" "$ANTIGRAVITY_PATH"; do
        echo "      ✨ Espejando skills en $backend..."
        mkdir -p "$backend"
        rsync -a --delete "$MASTER_DIR/skills/" "$backend/"
    done

    # GEMINI.md para la raíz de .gemini
    cp "$MASTER_DIR/AGENTS.md" "$HOME/.gemini/GEMINI.md"

    echo "✅ Sincronización completada."
}

backup_master() {
    local BDIR="$HOME/gentleai-backup/latest"
    echo "📦 Actualizando backup en: $BDIR"
    mkdir -p "$BDIR"
    rsync -a --delete "$MASTER_DIR/" "$BDIR/"
    echo "✅ Backup actualizado."
}

case "${1:-sync}" in
    sync)        sync ;;
    distribute|restore) distribute ;;
    backup)      backup_master ;;
    *)
        echo "Uso: $0 {sync|distribute|backup}"
        exit 1
        ;;
esac
