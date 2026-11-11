# sky instant replay (Medal-style clips)

Feature branch `feat/sky-instant-replay`. Adds a gpu-screen-recorder replay buffer to the sky
Quickshell shell, a save-clip shortcut, island feedback, a settings page and a clips gallery.

## Specs

- S1. "oye estaria guapo qeu en la shell haya algo como medal sabes lo qeu te digo?" — the shell keeps a replay buffer of the last N seconds (gpu-screen-recorder `-r`, RAM storage) and saves it as a clip on demand.
- S2. Scope chosen by the user: "Completo: Lo básico + galería de clips en sky (miniaturas, reproducir, borrar, copiar al portapapeles)."
- S3. "Básico" part (included by S2): "Replay buffer + atajo para guardar clip + indicador y aviso en la island + página de ajustes."
- S4. The gallery lists saved clips with thumbnails and lets the user play, delete and copy a clip to the clipboard (S2).
- S5. Settings page (S3) controls: on/off, buffer length, FPS, quality, audio, clips folder (from the proposal accepted with S2).

## Tasks

- T1 [S1,S5] `scripts/sky_replay.py` (command builder, settings writer, clip scan with thumbnails, safe delete) + `tests/test_sky_replay.py` + deps lists — inline — commit: pending
- T2 [S1,S3] `ReplayService.qml`, IPC `replay` target, global shortcuts, Hyprland keybinds, island recording dot and "clip saved" view — inline — commit: pending
- T3 [S4,S5] settings page `ReplayPage.qml` with options and clips gallery, i18n (es), README docs — inline — commit: pending
- T4 [S1-S5] verify: unit tests, i18n tests, qmllint/qs load check, live check if gpu-screen-recorder is installed — inline — commit: pending

## Log

- L1. User (original request, verbatim): "oye estaria guapo qeu en la shell haya algo como medal sabes lo qeu te digo?"
- L2. User picked scope "Completo" (value `full`): "Lo básico + galería de clips en sky (miniaturas, reproducir, borrar, copiar al portapapeles)."
- L3. Decision: backend gpu-screen-recorder (replay buffer in RAM, SIGUSR1 saves, prints saved path on stdout). It is not in the official Arch repos (AUR). The gallery lives on the settings page "Clips" (GridView), so it reuses the settings window instead of a new island submap.
