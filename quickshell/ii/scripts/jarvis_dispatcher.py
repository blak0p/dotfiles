#!/usr/bin/env python3
"""Jarvis Unified Dispatcher.

Central orchestrator for Jarvis voice interactions. Receives transcribed speech
from audio capture (jarvis_audio) or direct CLI input, evaluates intent via
jarvis_dictation, and coordinates:
- Mode transitions (Control Mode <-> Dictation Mode) with audio feedback (Piper TTS)
- Direct text typing into focused Wayland windows (wtype)
- Forwarding user requests to the AI desktop assistant (island_ai / Quickshell IPC)

Usage:
  python3 jarvis_dispatcher.py "modo transcripción"
  python3 jarvis_dispatcher.py "hola mundo esto es un dictado"
  python3 jarvis_dispatcher.py "jarvis"
  python3 jarvis_dispatcher.py "¿qué tiempo hace hoy?"
  python3 jarvis_dispatcher.py --toggle
"""

import sys
import os
import time
import json
import shutil
import subprocess
import threading
import argparse

# Ensure local script directory is in sys.path
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

try:
    from jarvis_dictation import (
        get_state,
        set_dictation_mode,
        evaluate_transcript,
        type_to_focused_window,
    )
except ImportError:
    # If imported from outside directory
    sys.path.append(os.path.join(os.path.dirname(__file__), "..", "scripts"))
    from jarvis_dictation import (
        get_state,
        set_dictation_mode,
        evaluate_transcript,
        type_to_focused_window,
    )

try:
    from jarvis_tts import speak
except ImportError:
    def speak(text: str, **kwargs) -> bool:
        tts_script = os.path.join(SCRIPT_DIR, "jarvis_tts.py")
        if os.path.exists(tts_script):
            res = subprocess.run([sys.executable, tts_script, text], capture_output=True)
            return res.returncode == 0
        return False


def notify_quickshell_ipc(method: str, *args: str) -> None:
    """Invokes Quickshell IPC target 'jarvis' asynchronously without blocking."""
    if not shutil.which("qs"):
        return
    cmd = ["qs", "-c", "ii", "ipc", "call", "jarvis", method] + list(args)
    try:
        subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def send_notification(summary: str, body: str = "", icon: str = "dialog-information") -> None:
    """Sends desktop notification if notify-send is available."""
    if shutil.which("notify-send"):
        try:
            subprocess.Popen(
                ["notify-send", "-a", "Jarvis", "-i", icon, summary, body],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass


def speak_feedback(text: str, wait: bool = False) -> None:
    """Speaks feedback text via Piper TTS without triggering follow-up listening.

    Runs in a background daemon thread by default to keep the dispatcher responsive,
    or synchronously if wait=True.
    """
    if not text or not text.strip():
        return

    if wait:
        try:
            speak(text, followup=False)
        except Exception as e:
            print(f"TTS error: {e}", file=sys.stderr)
    else:
        t = threading.Thread(target=speak, args=(text,), kwargs={"followup": False}, daemon=True)
        t.start()


def forward_to_assistant(text: str, open_quickshell: bool = True, speak_voice: bool = True) -> bool:
    """Forwards a prompt to the AI desktop assistant (island_ai / Quickshell)."""
    if not text or not text.strip():
        return False

    # 1. Try Quickshell IPC (opens Dynamic Island AI popup)
    if open_quickshell and shutil.which("qs"):
        target_method = "askWithVoice" if speak_voice else "ask"
        try:
            res = subprocess.run(
                ["qs", "-c", "ii", "ipc", "call", "ai", target_method, text],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if res.returncode == 0:
                return True
        except Exception:
            pass

    # 2. Direct script execution fallback
    candidates = [
        os.path.join(SCRIPT_DIR, "island_ai.py"),
        "/home/alejandro/dev/dotfiles/dotfiles/dotfiles-hyprland/quickshell/ii/scripts/island_ai.py",
        "/home/alejandro/dev/dotfiles/dotfiles-hyprland/quickshell/ii/scripts/island_ai.py",
    ]
    for script_path in candidates:
        if os.path.exists(script_path):
            try:
                subprocess.Popen(
                    [sys.executable, script_path, "--prompt", text],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                return True
            except Exception:
                pass

    return False


def dispatch_transcript(
    text: str,
    speak_audio: bool = True,
    wait_tts: bool = False,
    notify: bool = True,
) -> dict:
    """Dispatches a transcribed text to the appropriate handler.

    Returns:
        dict: Execution summary with action, parameters, and results.
    """
    if not text or not text.strip():
        return {"action": "none", "text": ""}

    eval_result = evaluate_transcript(text)
    action = eval_result.get("action", "none")

    result = {
        "action": action,
        "input_text": text,
        "timestamp": time.time(),
    }

    if action == "enter_dictation":
        notify_quickshell_ipc("dictating", "true")
        msg = "Modo transcripción activado"
        result["message"] = msg
        result["dictation_mode"] = True
        result["trigger"] = eval_result.get("trigger", "")
        if notify:
            send_notification("Jarvis: Modo Transcripción", "El texto se escribirá directamente en la ventana activa", "input-keyboard")
        if speak_audio:
            speak_feedback(msg, wait=wait_tts)

    elif action == "exit_dictation":
        notify_quickshell_ipc("dictating", "false")
        msg = "Modo control activado"
        result["message"] = msg
        result["dictation_mode"] = False
        result["trigger"] = eval_result.get("trigger", "")
        if notify:
            send_notification("Jarvis: Modo Control", "Asistente listo para recibir comandos", "dialog-information")
        if speak_audio:
            speak_feedback(msg, wait=wait_tts)

        # If user spoke extra command alongside exit (e.g. "con jarvis qué tiempo hace")
        forward_cmd = eval_result.get("forward_text")
        if forward_cmd:
            result["forward_text"] = forward_cmd
            result["forwarded"] = forward_to_assistant(forward_cmd, speak_voice=speak_audio)

    elif action == "type_text":
        typed_text = eval_result.get("text", text)
        ok = type_to_focused_window(typed_text)
        result["text"] = typed_text
        result["typed"] = ok

    elif action == "forward_assistant":
        forward_text = eval_result.get("text", text)
        result["text"] = forward_text
        ok = forward_to_assistant(forward_text, speak_voice=speak_audio)
        result["forwarded"] = ok

    return result


def toggle_and_dispatch(speak_audio: bool = True, wait_tts: bool = False) -> dict:
    """Toggles audio recording via jarvis_audio and dispatches transcription on stop."""
    try:
        from jarvis_audio import get_recording_pid, start_recording, stop_recording, transcribe
    except ImportError:
        sys.path.append(SCRIPT_DIR)
        from jarvis_audio import get_recording_pid, start_recording, stop_recording, transcribe

    pid = get_recording_pid()
    if pid:
        # Currently recording -> stop, transcribe, and dispatch
        stop_recording()
        text = transcribe()
        if text:
            return dispatch_transcript(text, speak_audio=speak_audio, wait_tts=wait_tts)
        return {"action": "empty_recording", "text": ""}
    else:
        # Not recording -> start recording
        new_pid = start_recording()
        return {"action": "recording_started", "pid": new_pid}


def main():
    parser = argparse.ArgumentParser(description="Jarvis Unified Voice & Dictation Dispatcher")
    parser.add_argument("text", nargs="*", help="Transcribed text to dispatch (if empty, read stdin or use --toggle)")
    parser.add_argument("--text", "-t", dest="explicit_text", help="Explicit text to dispatch")
    parser.add_argument("--toggle", action="store_true", help="Toggle recording and dispatch transcription on stop")
    parser.add_argument("--no-tts", action="store_true", help="Disable Piper TTS voice feedback")
    parser.add_argument("--sync-tts", action="store_true", help="Wait for TTS playback synchronously")
    parser.add_argument("--no-notify", action="store_true", help="Disable desktop notifications")
    parser.add_argument("--json", action="store_true", help="Output result as JSON")

    args = parser.parse_args()

    speak_audio = not args.no_tts
    notify = not args.no_notify

    if args.toggle:
        res = toggle_and_dispatch(speak_audio=speak_audio, wait_tts=args.sync_tts)
        if args.json:
            print(json.dumps(res, indent=2))
        else:
            print(f"Action: {res.get('action')}")
            if "message" in res:
                print(res["message"])
            elif "text" in res:
                print(f"Text: {res['text']}")
        sys.exit(0)

    # Determine input text
    input_text = ""
    if args.explicit_text:
        input_text = args.explicit_text
    elif args.text:
        input_text = " ".join(args.text).strip()
    elif not sys.stdin.isatty():
        input_text = sys.stdin.read().strip()

    if not input_text:
        parser.print_help()
        sys.exit(1)

    res = dispatch_transcript(
        input_text,
        speak_audio=speak_audio,
        wait_tts=args.sync_tts,
        notify=notify,
    )

    if args.json:
        print(json.dumps(res, indent=2))
    else:
        print(f"Action: {res.get('action')}")
        if "message" in res:
            print(res["message"])
        elif "text" in res:
            print(f"Text: {res['text']}")


if __name__ == "__main__":
    main()
