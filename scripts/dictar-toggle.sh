#!/usr/bin/env bash
# ~/scripts/dictar-toggle.sh

PIDFILE="/tmp/dictar.pid"
AUDIOFILE="/tmp/dictar-audio.wav"
DOTOOL="$HOME/.local/bin/dotool"
source "$HOME/.secrets/groq.sh"
GROQ_KEY="${GROQ_API_KEY}"

if [ -f "$PIDFILE" ]; then
    kill -INT "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    sleep 0.3

    TEXT=$(curl -s https://api.groq.com/openai/v1/audio/transcriptions \
      -H "Authorization: Bearer $GROQ_KEY" \
      -F "file=@$AUDIOFILE" \
      -F "model=whisper-large-v3" \
      -F "response_format=text" \
      -F "prompt=Hoy voy a hacer un commit en la branch main con un merge y un rebase. Voy a hacer push y pull del repo remoto en GitHub. También voy a crear un PR con un issue y un milestone. Uso distrobox con axiom y zellij para mis entornos. Trabajo con fish y bash en la terminal. Escribo funciones con structs, interfaces, goroutines y channels en Go. Uso API endpoints con JSON payloads y middleware handlers. Trabajo con queries y schemas en PostgreSQL. Despliego con Docker en contenedores y hago deploy con CI pipelines. Sigo arquitectura hexagonal con SOLID y TDD." 2>/dev/null | tr -d '\n')

    if [ -n "$TEXT" ]; then
        CLEAN=$(curl -s https://api.groq.com/openai/v1/chat/completions \
          -H "Authorization: Bearer $GROQ_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"llama-3.1-8b-instant\",\"messages\":[{\"role\":\"system\",\"content\":\"Eres un corrector de transcripciones de voz para programación. Corrige solo homófonos técnicos (comit->commit, strash->stash, etc.), puntuación y mayúsculas. NO traduzcas. NO añadas nada. Devuelve SOLO el texto corregido.\"},{\"role\":\"user\",\"content\":\"$TEXT\"}],\"max_tokens\":256}" 2>/dev/null | grep -o '"content":"[^"]*"' | head -1 | sed 's/"content":"//;s/"$//')

        if [ -n "$CLEAN" ]; then
            printf "typedelay 50\ntype %s\n" "$CLEAN" | "$DOTOOL"
        else
            printf "typedelay 50\ntype %s\n" "$TEXT" | "$DOTOOL"
        fi
    fi
else
    pw-record --target alsa_input.usb-HP__Inc_HyperX_SoloCast-00.pro-input-0 "$AUDIOFILE" &
    echo $! > "$PIDFILE"
fi
