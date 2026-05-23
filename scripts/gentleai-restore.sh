#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║  gentleai-restore.sh — Backup & Restore para gentle-ai      ║
# ║  Uso: ./gentleai-restore.sh backup|restore                  ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Mergea skills/, commands/, AGENTS.md / GEMINI.md / CLAUDE.md
# entre los 3 backends (opencode, gemini, claude).
# El más nuevo gana, lo que falta se copia, todo se reparte a los 3.
# NO toca plugins, prompts, json, config, etc.

BACKUP_DIR="$HOME/gentleai-backup/latest"

# Los 3 backends
OC_BASE="$HOME/.config/opencode"
GM_BASE="$HOME/.gemini"
CL_BASE="$HOME/.claude"

# ─── SYNC: backup + restore automático ──────────────────────────
sync_all() {
    echo "🔄 Sync completo: backup + restore"
    echo ""
    backup
    echo ""
    restore
    echo ""
    echo "✅ Sync completado — los 3 backends están sincronizados."
}

# ─── HELP ───────────────────────────────────────────────────────
help() {
    echo "Uso: $0 {backup|restore|sync|help}"
    echo ""
    echo "  backup   Mergea skills, commands, AGENTS/GEMINI/CLAUDE.md"
    echo "           de opencode + gemini + claude a un backup unificado."
    echo "  restore  Distribuye el backup unificado a los 3 backends."
    echo "  sync     backup + restore automático (un solo paso)."
    echo ""
}

# ─── Encuentra el archivo más nuevo entre una lista ─────────────
newest_of() {
    local newest=""
    local newest_ts=0
    local f ts
    for f in "$@"; do
        [ -f "$f" ] || continue
        ts=$(stat -c %Y "$f" 2>/dev/null || echo 0)
        if [ "$ts" -gt "$newest_ts" ]; then
            newest_ts=$ts
            newest="$f"
        fi
    done
    echo "$newest"
}

# ─── Lista skills (archivos + directorios) de un directorio ─────
list_skills() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    for entry in "$dir"/*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        basename "$entry"
    done
}

# ─── Lista commands (archivos .md) de un directorio ─────────────
list_commands() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    for entry in "$dir"/*.md; do
        [ -f "$entry" ] || continue
        basename "$entry"
    done
}

# ─── BACKUP ──────────────────────────────────────────────────────
backup() {
    echo "📦 Backup unificado en: $BACKUP_DIR"
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"/{skills,commands,md}

    # ── SKILLS ────────────────────────────────────────────────────
    echo "   Skills: mergeando..."
    # Agarrar todos los nombres de skills de los 3 backends
    all_skills=$( (list_skills "$OC_BASE/skills"; list_skills "$GM_BASE/skills"; list_skills "$CL_BASE/skills") | sort -u )

    total=$(echo "$all_skills" | wc -l)
    count=0
    for skill in $all_skills; do
        count=$((count + 1))
        # Mostrar progreso cada 10 skills
        [ $((count % 10)) -eq 0 ] && echo "      [$count/$total] skills procesados..."

        # Posibles ubicaciones
        oc_src="$OC_BASE/skills/$skill"
        gm_src="$GM_BASE/skills/$skill"
        cl_src="$CL_BASE/skills/$skill"
        dest="$BACKUP_DIR/skills/$skill"

        if [ -d "$oc_src" ] || [ -d "$gm_src" ] || [ -d "$cl_src" ]; then
            # ── Es un directorio ──
            mkdir -p "$dest"
            # Recopilar todos los archivos dentro de la skill en los 3 backends
            declare -A seen_files
            for src in "$oc_src" "$gm_src" "$cl_src"; do
                [ -d "$src" ] || continue
                while IFS= read -r -d '' f; do
                    rel="${f#$src/}"
                    # Si ya vimos este archivo, comparar y quedarnos con el más nuevo
                    if [ -n "${seen_files[$rel]:-}" ]; then
                        existing="${seen_files[$rel]}"
                        if [ "$(stat -c %Y "$f")" -gt "$(stat -c %Y "$existing")" ]; then
                            seen_files["$rel"]="$f"
                        fi
                    else
                        seen_files["$rel"]="$f"
                    fi
                done < <(find "$src" -type f -print0)
            done
            # Copiar los más nuevos
            for rel in "${!seen_files[@]}"; do
                mkdir -p "$(dirname "$dest/$rel")"
                cp -p "${seen_files[$rel]}" "$dest/$rel"
            done
        elif [ -f "$oc_src" ] || [ -f "$gm_src" ] || [ -f "$cl_src" ] || [ -L "$oc_src" ] || [ -L "$gm_src" ] || [ -L "$cl_src" ]; then
            # ── Es un archivo suelto o symlink (code-review, init, etc) ──
            # Si es symlink (posiblemente roto), copiamos como symlink
            if [ -L "$oc_src" ] || [ -L "$gm_src" ] || [ -L "$cl_src" ]; then
                for src in "$oc_src" "$gm_src" "$cl_src"; do
                    [ -L "$src" ] && cp -P "$src" "$dest" 2>/dev/null && break
                done
            else
                newest=$(newest_of "$oc_src" "$gm_src" "$cl_src")
                cp -p "$newest" "$dest"
            fi
        fi
    done

    # ── COMMANDS ──────────────────────────────────────────────────
    echo "   Commands: mergeando..."
    mkdir -p "$BACKUP_DIR/commands"
    all_cmds=$( (list_commands "$OC_BASE/commands"; list_commands "$GM_BASE/commands"; list_commands "$CL_BASE/commands") | sort -u)
    for cmd in $all_cmds; do
        newest=$(newest_of "$OC_BASE/commands/$cmd" "$GM_BASE/commands/$cmd" "$CL_BASE/commands/$cmd")
        cp -p "$newest" "$BACKUP_DIR/commands/$cmd"
    done

    # ── AGENTS.md / GEMINI.md / CLAUDE.md ───────────────────────
    echo "   MD files: eligiendo el más nuevo..."
    newest_md=$(newest_of \
        "$OC_BASE/AGENTS.md" \
        "$GM_BASE/GEMINI.md" \
        "$CL_BASE/CLAUDE.md" \
    )
    if [ -n "$newest_md" ]; then
        cp -p "$newest_md" "$BACKUP_DIR/md/master.md"
        echo "      Más nuevo: $(basename "$(dirname "$newest_md")")/$(basename "$newest_md")"
    else
        echo "      ⚠️  No se encontró ningún AGENTS/GEMINI/CLAUDE.md"
    fi

    echo ""
    echo "════════════════════════════════════════"
    echo "  ✅ Backup unificado completado"
    echo "     $total skills"
    echo "     $(list_commands "$BACKUP_DIR/commands" | wc -l) commands"
    echo "════════════════════════════════════════"
    echo ""
    echo "  Distribuí con: $0 restore"
}

# ─── RESTORE ─────────────────────────────────────────────────────
restore() {
    local B="$BACKUP_DIR"
    if [ ! -d "$B" ]; then
        echo "❌ No hay backup en $B. Corré backup primero."
        exit 1
    fi
    echo "♻️  Restaurando desde: $B"
    echo ""

    # ── SKILLS: de backup a los 3 backends ──────────────────────
    echo "   Skills: distribuyendo..."
    total=$(find "$B/skills" -maxdepth 1 -mindepth 1 | wc -l)
    count=0
    for skill_path in "$B/skills"/*; do
        [ -e "$skill_path" ] || continue
        skill=$(basename "$skill_path")
        count=$((count + 1))
        [ $((count % 10)) -eq 0 ] && echo "      [$count/$total] skills distribuidos..."

        for base in "$OC_BASE" "$GM_BASE" "$CL_BASE"; do
            dest="$base/skills/$skill"
            if [ -d "$skill_path" ]; then
                rm -rf "$dest"
                cp -r "$skill_path" "$dest"
            elif [ -f "$skill_path" ] || [ -L "$skill_path" ]; then
                [ -L "$skill_path" ] && cp -P "$skill_path" "$dest" || cp -p "$skill_path" "$dest"
            fi
        done
    done

    # ── COMMANDS: de backup a los que tengan commands ───────────
    echo "   Commands: distribuyendo..."
    for cmd_path in "$B/commands"/*.md; do
        [ -f "$cmd_path" ] || continue
        cmd=$(basename "$cmd_path")
        for base in "$OC_BASE" "$GM_BASE" "$CL_BASE"; do
            # opencode, claude tienen commands/; gemini no
            [ -d "$base/commands" ] || continue
            cp -p "$cmd_path" "$base/commands/$cmd"
        done
    done

    # ── MD files: el master a cada backend con su nombre ─────────
    echo "   MD files: distribuyendo..."
    if [ -f "$B/md/master.md" ]; then
        cp -p "$B/md/master.md" "$OC_BASE/AGENTS.md"
        cp -p "$B/md/master.md" "$GM_BASE/GEMINI.md"
        cp -p "$B/md/master.md" "$CL_BASE/CLAUDE.md"
        echo "      master.md → AGENTS.md / GEMINI.md / CLAUDE.md"
    else
        echo "      ⚠️  No hay master.md en el backup"
    fi

    # ── Sincronizar gentle-ai shared ─────────────────────────────
    if [ -d "$HOME/.gentle-ai/shared/skills" ]; then
        echo "   📥 Sincronizando gentle-ai shared..."
        rm -rf "$HOME/.gentle-ai/shared/skills"
        cp -r "$B/skills" "$HOME/.gentle-ai/shared/skills"

        rm -f "$HOME/.gentle-ai/shared/AGENTS.md"
        rm -f "$HOME/.gentle-ai/shared/GEMINI.md"
        rm -f "$HOME/.gentle-ai/shared/CLAUDE.md"
        [ -f "$B/md/master.md" ] && cp -p "$B/md/master.md" "$HOME/.gentle-ai/shared/AGENTS.md"

        if [ -d "$HOME/.gentle-ai/shared/commands" ]; then
            rm -rf "$HOME/.gentle-ai/shared/commands"
            cp -r "$B/commands" "$HOME/.gentle-ai/shared/commands"
        fi
    fi

    echo ""
    echo "════════════════════════════════════════"
    echo "  ✅ RESTORE COMPLETO"
    echo "     $total skills"
    echo "     $(find "$B/commands" -name '*.md' | wc -l) commands"
    echo "     AGENTS/GEMINI/CLAUDE.md sincronizados"
    echo "════════════════════════════════════════"
    echo ""
    echo "  Backends actualizados:"
    echo "    - ~/.config/opencode/"
    echo "    - ~/.gemini/"
    echo "    - ~/.claude/"
    echo "    - ~/.gentle-ai/shared/"
}

case "${1:-help}" in
    sync)
        sync_all
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    help|*)
        help
        exit 1
        ;;
esac
