#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║  gentleai-restore.sh — Backup & Restore para gentle-ai      ║
# ║  Uso: ./gentleai-restore.sh backup|restore                  ║
# ╚══════════════════════════════════════════════════════════════╝

BACKUP_DIR="$HOME/gentleai-backup/$(date +%Y%m%d_%H%M%S)"
LATEST_LINK="$HOME/gentleai-backup/latest"
MASTER_DIR="$HOME/.gentle-ai/shared"
OPENCODE="$HOME/.config/opencode"
GEMINI="$HOME/.gemini"
VAULT="$HOME/dev/Boveda"

# ─── Archivos a trackear ───────────────────────────────────────
SKILLS_SRC="$MASTER_DIR/skills"
REGISTRY="$HOME/dev/git-courer/.atl/skill-registry.md"

# ─── BACKUP ─────────────────────────────────────────────────────
backup() {
    echo "📦 Haciendo backup completo en: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    rm -f "$LATEST_LINK"
    ln -s "$BACKUP_DIR" "$LATEST_LINK"

    # AGENTS.md
    cp "$OPENCODE/AGENTS.md" "$BACKUP_DIR/AGENTS.md"

    # Skills (solo los que customizamos)
    for skill in tempo-rapido tempo-normal tempo-profundo; do
        mkdir -p "$BACKUP_DIR/skills/$skill"
        cp "$SKILLS_SRC/$skill/SKILL.md" "$BACKUP_DIR/skills/$skill/SKILL.md"
    done

    # SDD shared
    mkdir -p "$BACKUP_DIR/skills/_shared"
    cp "$SKILLS_SRC/_shared/sdd-phase-common.md" "$BACKUP_DIR/skills/_shared/sdd-phase-common.md"

    # Skill registry
    mkdir -p "$BACKUP_DIR/git-courer"
    cp "$REGISTRY" "$BACKUP_DIR/git-courer/skill-registry.md"

    # Vault master copy
    if [ -f "$VAULT/02_Cerebro/patrones/colaboracion/AGENTS_MASTER.md" ]; then
        cp "$VAULT/02_Cerebro/patrones/colaboracion/AGENTS_MASTER.md" \
           "$BACKUP_DIR/AGENTS_MASTER.md"
    fi

    echo "✅ Backup completo en: $BACKUP_DIR"
    echo "   Symlink 'latest' apunta ahí."
}

# ─── RESTORE ────────────────────────────────────────────────────
restore() {
    if [ ! -d "$LATEST_LINK" ]; then
        echo "❌ No hay backup en $LATEST_LINK. Corré backup primero."
        exit 1
    fi
    echo "♻️  Restaurando desde: $LATEST_LINK"
    local B="$LATEST_LINK"

    # 1. Restaurar AGENTS.md con nuestras reglas custom en el MAESTRO
    if [ -f "$B/AGENTS.md" ]; then
        cp "$B/AGENTS.md" "$MASTER_DIR/AGENTS.md"
        echo "   ✅ AGENTS.md restaurado en MAESTRO"
    fi

    # 2. Restaurar skills de tempo
    for skill in tempo-rapido tempo-normal tempo-profundo; do
        if [ -f "$B/skills/$skill/SKILL.md" ]; then
            mkdir -p "$SKILLS_SRC/$skill"
            cp "$B/skills/$skill/SKILL.md" "$SKILLS_SRC/$skill/SKILL.md"
            echo "   ✅ skills/$skill/SKILL.md restaurado en MAESTRO"
        fi
    done

    # 3. Restaurar sdd-phase-common (git-courer rule for sub-agents)
    if [ -f "$B/skills/_shared/sdd-phase-common.md" ]; then
        cp "$B/skills/_shared/sdd-phase-common.md" \
           "$SKILLS_SRC/_shared/sdd-phase-common.md"
        echo "   ✅ _shared/sdd-phase-common.md restaurado"
    fi

    # 4. Restaurar skill registry de git-courer
    if [ -f "$B/git-courer/skill-registry.md" ]; then
        cp "$B/git-courer/skill-registry.md" \
           "$HOME/dev/git-courer/.atl/skill-registry.md"
        echo "   ✅ git-courer skill-registry.md restaurado"
    fi

    # 5. Sin crono copia en vault
    if [ -f "$B/AGENTS_MASTER.md" ]; then
        cp "$B/AGENTS_MASTER.md" \
           "$VAULT/02_Cerebro/patrones/colaboracion/AGENTS_MASTER.md"
        echo "   ✅ Vault master copy restaurado"
    fi

    # 6. REEMPLAZAR engram-destillation/SKILL.md (v3)
    cat > "$SKILLS_SRC/engram-destillation/SKILL.md" << 'ENGRAMEOF'
---
name: engram-destillation
description: >
  Sub-agente especializado en destilar aprendizajes de sesiones SDD desde Engram hacia Obsidian.
  El objetivo NO es documentar qué se hizo — es capturar por qué se tomó una decisión y cómo
  razonar ante ese tipo de problema en el futuro. Trigger: Al final de cada sesión SDD o cuando
  el usuario dice "destila".
license: Apache-2.0
metadata:
  author: alejandro
  version: "3.0"
---

## Propósito Real

Este agente no es un generador de documentación técnica. Es un extractor de razonamiento.

Regla de oro: Si la nota explica el cómo, está mal. Si explica el por qué y entrena el criterio para decidir, está bien.

❌ Documentación técnica | ✅ Razonamiento destilado
- Usa strings.EqualFold para Bearer | Los headers HTTP tienen esquema case-insensitive por RFC — cuando algo falla silenciosamente con strings, pregúntate si hay un estándar que estás ignorando
- El LLM recibe el AnnotatedDiff | Antes de llamar a un LLM, pregúntate: ¿qué parte de este trabajo puede hacer Go de forma determinista? El LLM solo hace lo que no puede automatizarse
- go-enry detecta el lenguaje | Divide responsabilidades: cada herramienta hace lo que sabe hacer bien. Un modelo 3B no clasifica semántica — un detector de lenguaje sí detecta lenguaje

## Cuándo Se Activa

- Cuando sdd-archive completa
- Cuando el usuario dice "destila", "done", "listo" después de trabajo SDD
- Cuando el usuario dice "destila esto" en cualquier sesión

## Flujo

1. ESCANEAR Engram → `sdd/{change}/design` + `sdd/{change}/spec` + `sdd/{change}/apply-progress`. Si no hay SDD activo → escanear observaciones de la sesión actual
2. IDENTIFICAR decisiones de diseño, desvíos del design, problemas encontrados
3. PROPONER al usuario qué destilar con resumen breve — esperar confirmación
4. CLASIFICAR cada razonamiento (ver tabla de destinos)
5. GENERAR notas en `00_Inbox/` — UNA por cada razonamiento distinto
6. NOTIFICAR al humano

## Qué buscar en cada fuente

| Fuente | Qué contiene | Señales a buscar |
|--------|-------------|------------------|
| `sdd/{change}/design` | Decisiones de arquitectura con alternativas | Choice:, Alternatives considered:, Rationale:, Trade-off accepted: |
| `sdd/{change}/spec` | Comportamiento esperado y constraints | requisitos edge case, restricciones no obvias |
| `sdd/{change}/apply-progress` | Lo que realmente pasó durante la implementación | Deviations from Design, Issues Found, What Would Be Done Differently |
| sesión actual | Aprendizajes del día a día fuera de SDD | decisiones, gotchas, patrones aplicados |

Prioridad: **apply-progress** es la fuente más valiosa — ahí está la diferencia entre el diseño teórico y la realidad.

## Qué Destilar

### 🏗️ Decisiones de arquitectura
- ¿Por qué se dividió el sistema de esta manera y no de otra?
- ¿Qué alternativa se descartó y por qué?
- ¿Qué trade-off se aceptó conscientemente?

### 🔁 Patrones de diseño aplicados
- ¿Qué patrón resolvió el problema? ¿Por qué ese y no otro?
- ¿Cuándo aplicar este patrón? ¿Cuándo NO?

### 🧠 Criterio que hay que entrenar
- ¿Qué pregunta hay que hacerse antes de tomar este tipo de decisión?
- ¿Qué error de razonamiento se evitó o se cometió?

### ⚠️ Desvíos del design (fuente: apply-progress)
- ¿Dónde el design estaba equivocado y por qué?
- ¿Qué supuesto falló en la implementación real?
- ¿Qué harías diferente si empezaras de nuevo?

## Lo Que NO Destilar

- Sintaxis específica del lenguaje
- Configuración de herramientas sin razonamiento detrás
- Bugs puntuales sin aprendizaje generalizable
- Cambios mecánicos sin decisión de diseño detrás
- Secciones de apply-progress que digan "None"

## Formato de Nota

```yaml
---
tipo: razonamiento
area: arquitectura|patrones
tags: [tag1, tag2]
estado: pendiente
fecha: YYYY-MM-DD
destino_sugerido: 02_Cerebro/arquitectura/
---
```

```
# 🧠 {nombre-del-razonamiento}

## El Problema de Fondo
(No el bug — el problema de diseño o de razonamiento que había debajo)

## La Pregunta Que Hay Que Hacerse
(La pregunta que te llevas para la próxima vez que veas este tipo de problema)

## La Decisión y Por Qué
(Qué se eligió, qué se descartó, qué trade-off se aceptó)

## Cuándo Aplicar Este Razonamiento
- Señales de que estás ante este tipo de problema: ...
- Señales de que NO es este caso: ...

## El Error de Razonamiento a Evitar
(Qué camino parece obvio pero está mal y por qué)

## Ejemplo Concreto
(El caso real de esta sesión, en 3-4 líneas máximo)
```

Destino sugerido: 02_Cerebro/arquitectura/ — motivo: decisión de diseño reutilizable

## Clasificación de Destinos

| Tipo de Razonamiento | Destino |
|---------------------|---------|
| Decisión de cómo dividir un sistema | 02_Cerebro/arquitectura/ |
| Patrón de diseño con criterio de cuándo usarlo | 02_Cerebro/patrones/ |
| Cómo trabajar mejor con agentes/LLMs | 02_Cerebro/patrones/ |

## Notificación Final

💎 Destilé X notas en Inbox — razonamientos de esta sesión:

- soft-failure-pipelines.md → 02_Cerebro/patrones/
  "Cuándo usar soft failure vs hard failure en pipelines"

- llm-vs-determinismo.md → 02_Cerebro/arquitectura/
  "Cuándo confiar en el LLM y cuándo usar código puro"

Valídalas antes de moverlas a destino final.
ENGRAMEOF
    echo "   ✅ engram-destillation/SKILL.md reemplazado (v3)"

    # 7. AÑADIR apply-progress sections en sdd-apply
    # Buscar "- type: architecture" en sdd-apply y agregar después
    if grep -q "type: architecture" "$SKILLS_SRC/sdd-apply/SKILL.md"; then
        # Insertar después de la línea "- type: architecture"
        # Aseguramos que no duplicamos si ya existe
        if ! grep -q "Deviations from Design" "$SKILLS_SRC/sdd-apply/SKILL.md" 2>/dev/null; then
            sed -i '/- type: architecture/ a\
\
The apply-progress artifact MUST include these sections — all mandatory, none optional:\
\
### Deviations from Design\
List every place where implementation deviated from design.md and the REASON why.\
If the design was wrong, say what was wrong and what the correct approach turned out to be.\
If none: "None — implementation matches design exactly."\
\
### Issues Found During Implementation\
List every unexpected problem encountered — bugs in existing code, wrong assumptions,\
missing dependencies, gotchas. Include root cause if found. If none: "None."\
\
### What Would Be Done Differently\
If you could redo this implementation, what would you change and why?\
Be honest — this is the most valuable learning.\
If none: "Nothing — approach was correct from the start."\
\
These three sections are the institutional memory of the implementation.\
The destillation agent reads them to generate architectural learnings.' "$SKILLS_SRC/sdd-apply/SKILL.md"
            echo "   ✅ sdd-apply apply-progress sections añadidos"
        else
            echo "   ⏩ sdd-apply ya tiene las sections, omitiendo"
        fi
    fi

    # 8. AÑADIR alternatives/tradeoffs en sdd-design
    # Reemplazar el bloque de decisión
    if grep -q "Alternatives considered" "$SKILLS_SRC/sdd-design/SKILL.md" 2>/dev/null && \
       ! grep -q "Trade-off accepted" "$SKILLS_SRC/sdd-design/SKILL.md" 2>/dev/null; then
        sed -i 's/\*\*Alternatives considered\*\*:.*/**Alternatives considered**: {What we rejected — MUST list at least one, never \"N\/A\"}/' "$SKILLS_SRC/sdd-design/SKILL.md"
        sed -i '/\*\*Rationale\*\*:.*/a\
\*\*Trade-off accepted\*\*: {What we give up by choosing this — every choice has a cost}' "$SKILLS_SRC/sdd-design/SKILL.md"
        echo "   ✅ sdd-design decision block actualizado"
    fi

    # Añadir rules al final de sdd-design si no existen
    if ! grep -q "Every Architecture Decision MUST have at least ONE alternative" "$SKILLS_SRC/sdd-design/SKILL.md" 2>/dev/null; then
        cat >> "$SKILLS_SRC/sdd-design/SKILL.md" << 'DESIGNEOF'

- Every Architecture Decision MUST have at least ONE alternative considered — "N/A" is not acceptable
- Every Architecture Decision MUST have a Trade-off accepted — if you can't name the cost, you don't understand the decision
DESIGNEOF
        echo "   ✅ sdd-design rules añadidas"
    fi

    # 9. AÑADIR edge case rules en sdd-spec
    if ! grep -q "Every requirement MUST have at least ONE edge case" "$SKILLS_SRC/sdd-spec/SKILL.md" 2>/dev/null; then
        cat >> "$SKILLS_SRC/sdd-spec/SKILL.md" << 'SPECEOF'

- Every requirement MUST have at least ONE edge case scenario — happy path alone is not sufficient
- Edge case scenarios MUST cover: invalid input, missing dependencies, failure states
- If you can't think of an edge case, the requirement is probably not specific enough — refine it
SPECEOF
        echo "   ✅ sdd-spec edge case rules añadidas"
    fi

    # 10. Actualizar vault master copy
    cp "$MASTER_DIR/AGENTS.md" "$VAULT/02_Cerebro/patrones/colaboracion/AGENTS_MASTER.md"
    echo "   ✅ Vault master copy sincronizado"

    # 11. Sincronizar MAESTRO con todos los backends (Gemini, OpenCode)
    echo "   📥 Sincronizando MAESTRO con backends..."
    bash "$HOME/scripts/gentleai-config.sh" sync

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  ✅ RESTORE COMPLETO Y SINCRONIZADO"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Archivos restaurados:"
    echo "  - AGENTS.md"
    echo "  - skills/tempo-{rapido,normal,profundo}/SKILL.md"
    echo "  - skills/_shared/sdd-phase-common.md"
    echo "  - git-courer/.atl/skill-registry.md"
    echo "  - skills/engram-destillation/SKILL.md (v3)"
    echo ""
    echo "  Reemplazos aplicados:"
    echo "  - sdd-apply: apply-progress sections añadidas"
    echo "  - sdd-design: Trade-off accepted en decisiones"
    echo "  - sdd-spec: edge case rules"
    echo ""
    echo "  ⚠️  Ejecutá ahora 'update-registry'"
    echo "     para sincronizar Engram con los cambios."
    echo "═══════════════════════════════════════════════"
}

# ─── HELP ───────────────────────────────────────────────────────
help() {
    echo "Uso: $0 {backup|restore|help}"
    echo ""
    echo "  backup   Guarda copia maestra de todo en ~/gentleai-backup/"
    echo "  restore  Restaura desde ~/gentleai-backup/latest"
    echo "           + aplica reemplazos específicos"
    echo ""
}

case "${1:-help}" in
    backup)  backup ;;
    restore) restore ;;
    help|*)  help ;;
esac
