#!/usr/bin/env python3
"""Jarvis Piper TTS runner.

Synthesizes speech using local Piper TTS and plays it directly via PipeWire (pw-play) or PulseAudio (paplay).
Accepts input text as command line arguments or via stdin.
"""

import sys
import os
import shutil
import subprocess
import argparse

DEFAULT_VOICE = os.path.expanduser("~/.local/share/piper-voices/es_ES-davefx-medium.onnx")
PIPER_BIN = "/usr/bin/piper-tts"
DEFAULT_VOLUME = float(os.environ.get("JARVIS_TTS_VOLUME", "0.25"))
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


TTS_PID_FILE = "/tmp/jarvis_tts.pid"


def is_farewell_text(text: str) -> bool:
    """Detects if text contains a farewell or polite interaction closing phrase."""
    if not text:
        return False
    lower = text.lower()
    farewells = [
        "hasta luego", "adiós", "adios", "chao", "chau",
        "de nada", "un placer", "a tu disposición", "a tu disposicion",
        "que tengas un buen", "que tengas un lindo", "nos vemos",
        "hasta la próxima", "hasta la proxima", "hasta pronto",
    ]
    return any(f in lower for f in farewells)


def is_question_text(text: str) -> bool:
    """Detects if text contains a question or prompts for a user answer."""
    if not text:
        return False
    lower = text.lower()
    if "?" in text or "¿" in text:
        return True
    prompt_indicators = [
        "cuál prefieres", "cuál quieres", "cuál deseas",
        "qué prefieres", "qué quieres", "qué deseas",
        "elijas", "elige", "dime cuál", "confirma",
    ]
    return any(p in lower for p in prompt_indicators)


def notify_quickshell_ipc(method: str, *args: str) -> None:
    """Notifies Quickshell Jarvis IPC target without blocking."""
    if not shutil.which("qs"):
        return
    cmd = ["qs", "-c", "ii", "ipc", "call", "jarvis", method] + list(args)
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def speak(
    text: str,
    voice: str = DEFAULT_VOICE,
    output_wav: str = None,
    speed: float = 1.0,
    volume: float = DEFAULT_VOLUME,
    followup: bool = True,
    followup_if_question: bool = None,
) -> bool:
    if not text or not text.strip():
        return False

    if followup_if_question is False:
        followup = False

    piper_exe = PIPER_BIN if os.path.isfile(PIPER_BIN) and os.access(PIPER_BIN, os.X_OK) else shutil.which("piper-tts")
    if not piper_exe:
        print("Error: piper-tts binary not found", file=sys.stderr)
        return False

    voice_path = os.path.expanduser(voice)
    if not os.path.isfile(voice_path):
        print(f"Error: Voice model not found at {voice_path}", file=sys.stderr)
        return False

    piper_cmd = [
        piper_exe,
        "--model", voice_path,
        "-q",
    ]

    if speed != 1.0 and speed > 0:
        # length_scale is phoneme length multiplier (smaller = faster)
        piper_cmd.extend(["--length_scale", str(1.0 / speed)])

    if output_wav:
        output_path = os.path.expanduser(output_wav)
        piper_cmd.extend(["--output_file", output_path])
        try:
            proc = subprocess.Popen(piper_cmd, stdin=subprocess.PIPE)
            proc.communicate(input=text.encode("utf-8"))
            return proc.returncode == 0
        except Exception as e:
            print(f"Error executing piper-tts: {e}", file=sys.stderr)
            return False

    # Direct playback via pw-play or paplay
    piper_cmd.extend(["--output_file", "-"])
    player_bin = shutil.which("pw-play") or shutil.which("paplay")
    if not player_bin:
        print("Error: neither pw-play nor paplay found for playback", file=sys.stderr)
        return False

    clamped_vol = max(0.0, min(1.0, volume))
    if player_bin.endswith("pw-play"):
        player_cmd = [player_bin, "--volume", f"{clamped_vol:.2f}", "-"]
    elif player_bin.endswith("paplay"):
        pa_vol = int(clamped_vol * 65536)
        player_cmd = [player_bin, f"--volume={pa_vol}", "-"]
    else:
        player_cmd = [player_bin, "-"]

    try:
        notify_quickshell_ipc("speaking")
        with open(TTS_PID_FILE, "w") as f:
            f.write(str(os.getpid()))

        piper_proc = subprocess.Popen(
            piper_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        player_proc = subprocess.Popen(
            player_cmd,
            stdin=piper_proc.stdout,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE
        )
        # Allow piper_proc to receive SIGPIPE if player_proc terminates early
        piper_proc.stdout.close()

        piper_proc.communicate(input=text.encode("utf-8"))
        player_proc.wait()

        # Follow-up auto listening: keep conversation alive unless disabled or farewell
        jarvis_audio_script = os.path.join(SCRIPT_DIR, "jarvis_audio.py")
        if followup and not is_farewell_text(text) and os.path.exists(jarvis_audio_script):
            subprocess.Popen(
                [sys.executable, jarvis_audio_script, "follow-up", "--dispatch"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        else:
            notify_quickshell_ipc("idle")

        return player_proc.returncode == 0
    except Exception as e:
        print(f"Error during TTS playback: {e}", file=sys.stderr)
        notify_quickshell_ipc("idle")
        return False
    finally:
        if os.path.exists(TTS_PID_FILE):
            try:
                os.remove(TTS_PID_FILE)
            except OSError:
                pass


def main():
    parser = argparse.ArgumentParser(description="Jarvis Piper TTS runner")
    parser.add_argument("text", nargs="*", help="Text to speak. If empty, reads from stdin.")
    parser.add_argument("-v", "--voice", default=DEFAULT_VOICE, help="Path to piper ONNX model")
    parser.add_argument("-o", "--output", default=None, help="Save to WAV file instead of playing")
    parser.add_argument("-s", "--speed", type=float, default=1.0, help="Speech speed multiplier (default: 1.0)")
    parser.add_argument("--volume", type=float, default=DEFAULT_VOLUME, help="Speech volume (0.0 to 1.0, default: 0.25)")
    parser.add_argument("--no-followup", action="store_true", help="Disable automatic follow-up listening")

    args = parser.parse_args()

    if args.text:
        text = " ".join(args.text).strip()
    else:
        text = sys.stdin.read().strip()

    if not text:
        sys.exit(0)

    success = speak(
        text,
        voice=args.voice,
        output_wav=args.output,
        speed=args.speed,
        volume=args.volume,
        followup=not args.no_followup,
    )
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
