# sky instant replay (Medal-style clips)

Feature branch `feat/sky-instant-replay`. Adds a gpu-screen-recorder replay buffer to the sky
Quickshell shell, a save-clip shortcut, island feedback, a settings page and a clips gallery.

## Specs

- S1. "oye estaria guapo qeu en la shell haya algo como medal sabes lo qeu te digo?" — the shell keeps a replay buffer of the last N seconds (gpu-screen-recorder `-r`, RAM storage) and saves it as a clip on demand.
- S2. Scope chosen by the user: "Completo: Lo básico + galería de clips en sky (miniaturas, reproducir, borrar, copiar al portapapeles)."
- S3. "Básico" part (included by S2): "Replay buffer + atajo para guardar clip + indicador y aviso en la island + página de ajustes."
- S4. The gallery lists saved clips with thumbnails and lets the user play, delete and copy a clip to the clipboard (S2).
- S5. Settings page (S3) controls: on/off, buffer length, FPS, quality, audio, clips folder (from the proposal accepted with S2).
- S6. "ya instale pero queiro que en la dinmic island salga algo apra saber que se guardo y eso" — saving a clip shows a visible confirmation in the island.
- S7. "y que haya varias opciones copiarlo guardarlo lo que sea" — the island confirmation offers several actions on the saved clip (copy, play, folder, gallery, delete).

## Tasks

- T1 [S1,S5] `scripts/sky_replay.py` (command builder, settings writer, clip scan with thumbnails, safe delete) + `tests/test_sky_replay.py` + deps lists — inline — commit: d86f264
- T2 [S1,S3] `ReplayService.qml`, IPC `replay` target, global shortcuts, Hyprland keybinds, island recording dot and "clip saved" view — inline — commit: c6e51b5
- T3 [S4,S5] settings page `ReplayPage.qml` with options and clips gallery, i18n (es), README docs — inline — commit: ec9f47d
- T4 [S1-S5] verify: unit tests, i18n tests, qmllint/qs load check, live check if gpu-screen-recorder is installed — inline — commit: ec9f47d (verification only)
- T5 [S6,S7] Island clip card (thumbnail, actions, hover hold, two-click delete), re-probe recorder after install, verifier advisories (intentional stop is not a crash, stable reset, symlink delete test) — inline — commit: f720409

## Log

- L1. User (original request, verbatim): "oye estaria guapo qeu en la shell haya algo como medal sabes lo qeu te digo?"
- L2. User picked scope "Completo" (value `full`): "Lo básico + galería de clips en sky (miniaturas, reproducir, borrar, copiar al portapapeles)."
- L3. Decision: backend gpu-screen-recorder (replay buffer in RAM, SIGUSR1 saves, prints saved path on stdout). It is not in the official Arch repos (AUR). The gallery lives on the settings page "Clips" (GridView), so it reuses the settings window instead of a new island submap.
- L4. Verification: python unittest 172 OK (14 new in test_sky_replay.py); node i18n/calc/displayLayout tests green; live shell reloaded with "Configuration Loaded"; `qs -c sky ipc call replay state` answers; screenshots show the Instant replay page with the gallery card (thumbnail, copy, delete) and the island pop "gpu-screen-recorder no está instalado"; copy put `text/uri-list` on the clipboard; delete removed the scratch clip.
- L5. Blocker: gpu-screen-recorder is in cachyos-extra-znver4 (6.1.7) but installing needs sudo (password). Live buffer recording and SIGUSR1 save remain unverified until `sudo pacman -S gpu-screen-recorder`.
- L6. User: "ya instale pero queiro que en la dinmic island salga algo apra saber que se guardo y eso"
- L7. User: "y que haya varias opciones copiarlo guardarlo lo que sea"
- L8. Root cause of "no feedback": ReplayService probed gpu-screen-recorder only at shell start, so after installing it `available` stayed false and enable did nothing. Fixed by re-probing on enable/save. Live check after fix: enable -> recorder running on DP-2, save -> clip in ~/Videos/Clips and island card "Clip guardado" with thumbnail and 5 actions (screenshot). Verifier (gentle-ai-verify): S1-S5 pass statically, advisories 1-4 and 6 fixed here.
- L9. Second verifier (gentle-ai-verify): S6, S7 pass; S1-S5 no regression; 176 py tests OK. Fixed its defects: stale thumbnail (clipThumb compared after assignment), island delete now checks against the clips folder, `stable` timer stops when the recorder exits, clipHold resets when the pop is hidden; added an i18n test that every replay UI string has a Spanish entry. Unverified: click/hover interactions in the card and the keybinds pressed by hand.
