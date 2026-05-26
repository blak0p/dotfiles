#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║  gentleai-restore.sh — Backup & Restore para gentle-ai      ║
# ║  Uso: ./gentleai-restore.sh backup|restore|history          ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Backup/Restore de ~/.config/opencode/skills/ (openmode).
# NO toca gemini, claude, ni gentle-ai/shared.
# Snapshots con timestamp, safety check antes de restore.
#
# ¿Por qué opencode-only? Porque gemini y claude los escribe el
# oficial y siempre pisaban los skills buenos con basura.
# Ya fue.

BACKUP_ROOT="$HOME/gentleai-backup"
LATEST_LINK="$BACKUP_ROOT/latest"
KEEP_LAST=15

# ─── HELP ───────────────────────────────────────────────────────
help() {
    echo "Uso: $0 {backup|restore [snapshot]|history|help}"
    echo ""
    echo "  backup                 Crea snapshot de ~/.config/opencode/skills/"
    echo "  restore [snapshot]     Restaura desde un snapshot (o el último)"
    echo "  history                Lista snapshots disponibles"
    echo "  help                   Esto"
}

# ─── SNAPSHOTS ──────────────────────────────────────────────────
snapshot_name() { date +%Y%m%d-%H%M%S; }
snapshot_dir()  { echo "$BACKUP_ROOT/backup-$1"; }

is_valid_snapshot() { [ -d "$BACKUP_ROOT/backup-$1" ]; }

list_snapshots() {
    ls -1d "$BACKUP_ROOT"/backup-* 2>/dev/null | sort -r | while read -r d; do
        d=$(basename "$d")
        echo "${d#backup-}"
    done
}

latest_snapshot() { list_snapshots | head -1; }

cleanup_old_snapshots() {
    local total
    total=$(list_snapshots | wc -l)
    if [ "$total" -gt "$KEEP_LAST" ]; then
        list_snapshots | tail -n $((total - KEEP_LAST)) | while read -r snap; do
            rm -rf "$BACKUP_ROOT/backup-$snap"
            echo "      🗑️  Backup antiguo: $snap"
        done
    fi
}

update_latest_link() {
    local snap="$1"
    [ -d "$LATEST_LINK" ] && rm -rf "$LATEST_LINK"
    ln -snf "$BACKUP_ROOT/backup-$snap" "$LATEST_LINK"
}

# ─── HELPERS ────────────────────────────────────────────────────
list_skills() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    for entry in "$dir"/*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        basename "$entry"
    done
}

list_commands() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    for entry in "$dir"/*.md; do
        [ -f "$entry" ] || continue
        basename "$entry"
    done
}

# Safety check: compara skills del backup contra lo que tiene opencode
safety_check() {
    local B="$1"
    local force="${2:-false}"

    local backup_skills
    backup_skills=$(list_skills "$B/skills")
    local dest_skills
    dest_skills=$(list_skills "$OC_BASE/skills")

    local only_in_backup only_in_dest
    only_in_backup=$(comm -23 <(echo "$backup_skills") <(echo "$dest_skills") | grep -c . || true)
    only_in_dest=$(comm -13 <(echo "$backup_skills") <(echo "$dest_skills") | grep -c . || true)

    local backup_count dest_count
    backup_count=$(echo "$backup_skills" | grep -c . || true)
    dest_count=$(echo "$dest_skills" | grep -c . || true)

    if [ "$only_in_backup" -gt 5 ] || [ "$only_in_dest" -gt 5 ]; then
        echo "   ⚠️  Diferencia grande detectada:"
        echo "      Skills en backup: $backup_count"
        echo "      Skills actuales:  $dest_count"
        echo "      Solo en backup:   $only_in_backup"
        echo "      Solo acá:         $only_in_dest"

        if [ "$force" != "true" ]; then
            echo ""
            echo "   ¿Querés continuar con el restore? (y/N) "
            read -r confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "   ❌ Restore cancelado."
                exit 1
            fi
        fi
    fi
}

# ─── BACKUP ──────────────────────────────────────────────────────
backup() {
    local snap
    snap=$(snapshot_name)
    local B
    B=$(snapshot_dir "$snap")

    echo "📦 Backup snapshot: $snap"
    mkdir -p "$B"/{skills,commands,md}

    # SKILLS — solo desde opencode
    echo "   Skills: copiando desde opencode..."
    if [ -d "$OC_BASE/skills" ]; then
        for entry in "$OC_BASE/skills"/*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            skill=$(basename "$entry")
            dest="$B/skills/$skill"
            if [ -L "$entry" ]; then
                cp -P "$entry" "$dest"
            else
                cp -rp "$entry" "$dest"
            fi
        done
    fi
    local total_skills
    total_skills=$(list_skills "$B/skills" | wc -l)

    # COMMANDS — solo desde opencode
    echo "   Commands: copiando..."
    if [ -d "$OC_BASE/commands" ]; then
        mkdir -p "$B/commands"
        for entry in "$OC_BASE/commands"/*.md; do
            [ -f "$entry" ] || continue
            cp -p "$entry" "$B/commands/$(basename "$entry")"
        done
    fi
    local total_cmds
    total_cmds=$(list_commands "$B/commands" | wc -l)

    # MD — AGENTS.md
    echo "   MD files: copiando..."
    if [ -f "$OC_BASE/AGENTS.md" ]; then
        cp -p "$OC_BASE/AGENTS.md" "$B/md/AGENTS.md"
    fi

    update_latest_link "$snap"
    cleanup_old_snapshots

    echo ""
    echo "════════════════════════════════════════"
    echo "  ✅ SNAPSHOT CREADO: $snap"
    echo "     $total_skills skills"
    echo "     $total_cmds commands"
    echo "════════════════════════════════════════"
    echo ""
    echo "  Restaurá con: $0 restore $snap"
    echo "  Al último:    $0 restore"
}

# ─── RESTORE ─────────────────────────────────────────────────────
restore() {
    local snap="${1:-}"
    local force="${2:-false}"
    local B

    if [ -n "$snap" ]; then
        if ! is_valid_snapshot "$snap"; then
            echo "❌ Snapshot no encontrado: backup-$snap"
            exit 1
        fi
        B=$(snapshot_dir "$snap")
    else
        snap=$(latest_snapshot)
        if [ -z "$snap" ]; then
            echo "❌ No hay snapshots. Corré backup primero."
            exit 1
        fi
        B=$(snapshot_dir "$snap")
    fi

    echo "♻️  Restaurando desde: $snap"
    echo "   ($B)"
    echo ""

    safety_check "$B" "$force"

    # SKILLS — solo a opencode
    echo "   Skills: restaurando..."
    local total
    total=$(find "$B/skills" -maxdepth 1 -mindepth 1 | wc -l)
    local count=0
    for skill_path in "$B/skills"/*; do
        [ -e "$skill_path" ] || continue
        count=$((count + 1))
        [ $((count % 10)) -eq 0 ] && echo "      [$count/$total] skills..."
        skill=$(basename "$skill_path")
        dest="$OC_BASE/skills/$skill"

        rm -rf "$dest"
        if [ -L "$skill_path" ]; then
            cp -P "$skill_path" "$dest" 2>/dev/null || true
        elif [ -d "$skill_path" ]; then
            mkdir -p "$dest"
            cp -r "$skill_path"/* "$dest/" 2>/dev/null || true
        elif [ -f "$skill_path" ]; then
            cp -p "$skill_path" "$dest"
        fi
    done

    # COMMANDS
    echo "   Commands: restaurando..."
    mkdir -p "$OC_BASE/commands"
    for cmd_path in "$B/commands"/*.md; do
        [ -f "$cmd_path" ] || continue
        cp -p "$cmd_path" "$OC_BASE/commands/$(basename "$cmd_path")"
    done

    # MD
    echo "   MD files: restaurando..."
    if [ -f "$B/md/AGENTS.md" ]; then
        cp -p "$B/md/AGENTS.md" "$OC_BASE/AGENTS.md"
    fi

    echo ""
    echo "════════════════════════════════════════"
    echo "  ✅ RESTORE COMPLETO desde: $snap"
    echo "     $total skills"
    echo "     $(find "$B/commands" -name '*.md' | wc -l) commands"
    echo "════════════════════════════════════════"
    echo ""
    echo "  Backend actualizado: ~/.config/opencode/"
}

# ─── HISTORY ─────────────────────────────────────────────────────
history() {
    echo "📋 Snapshots disponibles:"
    echo ""
    for snap in $(list_snapshots); do
        local B
        B=$(snapshot_dir "$snap")
        local skills_count commands_count
        skills_count=$(list_skills "$B/skills" | wc -l)
        commands_count=$(list_commands "$B/commands" | wc -l)
        local is_latest=""
        [ "$(latest_snapshot)" = "$snap" ] && is_latest="  ← último"
        echo "  $snap  (${skills_count} skills, ${commands_count} commands)${is_latest}"
    done
}

# ─── MAIN ────────────────────────────────────────────────────────
OC_BASE="$HOME/.config/opencode"

cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
    backup)
        backup
        ;;
    restore)
        snap_arg=""
        force_flag="false"
        for arg in "$@"; do
            if [ "$arg" = "--force" ]; then
                force_flag="true"
            elif [ -z "$snap_arg" ]; then
                snap_arg="$arg"
            fi
        done
        restore "$snap_arg" "$force_flag"
        ;;
    history)
        history
        ;;
    help|*)
        help
        exit 1
        ;;
esac
