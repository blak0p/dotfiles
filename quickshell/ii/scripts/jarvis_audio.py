#!/usr/bin/env python3
"""Jarvis Audio Recording & Transcription Script.

Controls audio recording via PipeWire (pw-record) in a toggle fashion and
transcribes recorded speech using the local ROCm Whisper server.

Lifecycle & Resource Management:
- On record start: Starts `whisper-server.service` in background if inactive,
  warming up GPU/VRAM while the user speaks.
- On record stop & transcribe: Transcribes audio, then schedules a 120s idle
  timer to cleanly stop `whisper-server.service`, preserving 0 VRAM at rest.
"""

import sys
import os
import signal
import time
import shutil
import subprocess
import json
import urllib.request
import argparse
import array
import math
import wave

PID_FILE = "/tmp/jarvis_recording.pid"
SESSION_PID_FILE = "/tmp/jarvis_session.pid"
TTS_PID_FILE = "/tmp/jarvis_tts.pid"
AUDIO_FILE = "/tmp/jarvis_input.wav"
DEFAULT_SERVER_URL = "http://127.0.0.1:8085/inference"
IDLE_STOP_UNIT = "whisper-idle-stop"
IDLE_TIMEOUT_SECONDS = 20


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


def get_session_pid() -> int | None:
    if not os.path.exists(SESSION_PID_FILE):
        return None
    try:
        with open(SESSION_PID_FILE, "r") as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return pid
    except (ValueError, OSError):
        try:
            os.remove(SESSION_PID_FILE)
        except OSError:
            pass
        return None


def get_tts_pid() -> int | None:
    if not os.path.exists(TTS_PID_FILE):
        return None
    try:
        with open(TTS_PID_FILE, "r") as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return pid
    except (ValueError, OSError):
        try:
            os.remove(TTS_PID_FILE)
        except OSError:
            pass
        return None


def is_active_session() -> bool:
    return get_session_pid() is not None or get_recording_pid() is not None


def is_active_tts() -> bool:
    return get_tts_pid() is not None


def cancel_all():
    """Cancels any active recording session, TTS playback, or follow-up listener."""
    sess_pid = get_session_pid()
    if sess_pid and sess_pid != os.getpid():
        try:
            os.kill(sess_pid, signal.SIGTERM)
        except OSError:
            pass

    rec_pid = get_recording_pid()
    if rec_pid and rec_pid != os.getpid():
        try:
            os.kill(rec_pid, signal.SIGTERM)
        except OSError:
            pass

    tts_pid = get_tts_pid()
    if tts_pid and tts_pid != os.getpid():
        try:
            os.kill(tts_pid, signal.SIGTERM)
        except OSError:
            pass

    for p in (SESSION_PID_FILE, PID_FILE, TTS_PID_FILE):
        if os.path.exists(p):
            try:
                os.remove(p)
            except OSError:
                pass

    notify_quickshell_ipc("idle")
    if shutil.which("qs"):
        try:
            subprocess.Popen(
                ["qs", "-c", "ii", "ipc", "call", "ai", "close"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass
    schedule_idle_timer(IDLE_TIMEOUT_SECONDS)


def cancel_idle_timer():
    """Cancels any pending idle shutdown timer."""
    subprocess.run(
        ["systemctl", "--user", "stop", f"{IDLE_STOP_UNIT}.timer"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def schedule_idle_timer(seconds: int = IDLE_TIMEOUT_SECONDS):
    """Schedules an automatic shutdown of whisper-server after inactivity."""
    cancel_idle_timer()
    subprocess.run(
        [
            "systemd-run",
            "--user",
            f"--unit={IDLE_STOP_UNIT}",
            f"--on-active={seconds}s",
            "systemctl",
            "--user",
            "stop",
            "whisper-server.service",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def ensure_whisper_started():
    """Starts whisper-server.service in background if not already running."""
    cancel_idle_timer()
    res = subprocess.run(
        ["systemctl", "--user", "is-active", "--quiet", "whisper-server.service"]
    )
    if res.returncode != 0:
        subprocess.Popen(
            ["systemctl", "--user", "start", "whisper-server.service"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def ensure_llama_started():
    """Starts llama-server.service in background if not already running."""
    res = subprocess.run(
        ["systemctl", "--user", "is-active", "--quiet", "llama-server.service"]
    )
    if res.returncode != 0:
        subprocess.Popen(
            ["systemctl", "--user", "start", "llama-server.service"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def wait_for_whisper_ready(server_url: str = DEFAULT_SERVER_URL, timeout: float = 6.0) -> bool:
    """Waits until whisper-server HTTP endpoint is responding."""
    start_time = time.time()
    base_url = server_url.rsplit("/", 1)[0] if "/inference" in server_url else server_url
    while time.time() - start_time < timeout:
        try:
            req = urllib.request.Request(base_url, method="HEAD")
            with urllib.request.urlopen(req, timeout=0.8) as resp:
                if resp.status == 200:
                    return True
        except Exception:
            time.sleep(0.15)
    return False


def get_recording_pid() -> int | None:
    if not os.path.exists(PID_FILE):
        return None
    try:
        with open(PID_FILE, "r") as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return pid
    except (ValueError, OSError):
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
        return None


def start_recording(audio_path: str = AUDIO_FILE) -> int:
    existing_pid = get_recording_pid()
    if existing_pid:
        return existing_pid

    # Notify visual island immediately for zero perceptible UI latency
    notify_quickshell_ipc("listening")

    # Warm up Whisper and LLaMA servers in parallel while user speaks
    ensure_whisper_started()
    ensure_llama_started()

    # Clean previous audio file
    if os.path.exists(audio_path):
        try:
            os.remove(audio_path)
        except OSError:
            pass

    # Launch pw-record in a detached session (16kHz 16-bit mono PCM)
    proc = subprocess.Popen(
        [
            "pw-record",
            "--rate", "16000",
            "--channels", "1",
            "--format", "s16",
            audio_path,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )

    with open(PID_FILE, "w") as f:
        f.write(str(proc.pid))

    return proc.pid


def stop_recording(audio_path: str = AUDIO_FILE) -> bool:
    pid = get_recording_pid()
    if not pid:
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except OSError:
                pass
        return False

    notify_quickshell_ipc("transcribing")

    try:
        # SIGINT signals pw-record to finish and write headers cleanly
        os.kill(pid, signal.SIGINT)
    except OSError:
        pass

    deadline = time.time() + 2.0
    while time.time() < deadline:
        try:
            os.kill(pid, 0)
            time.sleep(0.05)
        except OSError:
            break
    else:
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass

    if os.path.exists(PID_FILE):
        try:
            os.remove(PID_FILE)
        except OSError:
            pass

    return True


def transcribe(
    audio_path: str = AUDIO_FILE,
    server_url: str = DEFAULT_SERVER_URL,
    language: str = "es",
    auto_stop_idle: bool = True,
) -> str:
    try:
        if not os.path.exists(audio_path):
            return ""

        if os.path.getsize(audio_path) < 500:
            return ""

        # Ensure server is running and ready before posting audio
        ensure_whisper_started()
        wait_for_whisper_ready(server_url, timeout=8.0)

        cmd = [
            "curl", "-s",
            "-F", f"file=@{audio_path}",
            "-F", "response_format=json",
            "-F", f"language={language}",
            server_url,
        ]

        text = ""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0 and result.stdout:
                data = json.loads(result.stdout)
                text = data.get("text", "").strip()
            else:
                print(f"Whisper server error: {result.stderr}", file=sys.stderr)
        except Exception as e:
            print(f"Error during transcription: {e}", file=sys.stderr)

        return text
    finally:
        # Schedule shutdown after inactivity
        if auto_stop_idle:
            schedule_idle_timer(IDLE_TIMEOUT_SECONDS)


def listen_with_vad(
    audio_path: str = AUDIO_FILE,
    server_url: str = DEFAULT_SERVER_URL,
    language: str = "es",
    auto_stop_idle: bool = True,
    initial_timeout: float = 5.0,
    silence_duration: float = 1.1,
    max_duration: float = 15.0,
) -> str:
    """Listens with Voice Activity Detection (VAD) and auto-stops on silence.

    Arms recording immediately, waits for voice within initial_timeout.
    Once speech starts, keeps recording until silence_duration is observed or max_duration.
    Transcribes audio and returns text. If no voice detected, returns "".
    """
    existing_pid = get_recording_pid()
    if existing_pid:
        return ""

    notify_quickshell_ipc("listening")
    ensure_whisper_started()
    ensure_llama_started()

    # Clean previous audio file
    if os.path.exists(audio_path):
        try:
            os.remove(audio_path)
        except OSError:
            pass

    with open(SESSION_PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    proc = subprocess.Popen(
        [
            "pw-record",
            "--rate", "16000",
            "--channels", "1",
            "--format", "s16",
            "-",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )

    with open(PID_FILE, "w") as f:
        f.write(str(proc.pid))

    cancelled = False

    def sig_handler(signum, frame):
        nonlocal cancelled
        cancelled = True
        try:
            proc.terminate()
        except Exception:
            pass

    old_sigterm = signal.signal(signal.SIGTERM, sig_handler)
    old_sigint = signal.signal(signal.SIGINT, sig_handler)

    pcm_buffer = bytearray()
    chunk_size = 3200  # 100ms chunks at 16kHz 16-bit mono

    has_voice = False
    voice_chunks = 0
    silence_time = 0.0
    start_time = time.time()

    try:
        # 1. Calibrate ambient baseline over first 300ms
        baseline_samples = []
        for _ in range(3):
            if cancelled:
                break
            chunk = proc.stdout.read(chunk_size)
            if not chunk:
                break
            pcm_buffer.extend(chunk)
            shorts = array.array("h")
            shorts.frombytes(chunk)
            if shorts:
                baseline_samples.append(math.sqrt(sum(s * s for s in shorts) / len(shorts)))

        baseline = sum(baseline_samples) / max(len(baseline_samples), 1) if baseline_samples else 300.0
        # Dynamic voice threshold: 25% above baseline, with sensitive floor
        vad_threshold = max(baseline * 1.25, 420.0)
        if baseline >= 550.0:
            has_voice = True

        while not cancelled:
            chunk = proc.stdout.read(chunk_size)
            if not chunk:
                break
            pcm_buffer.extend(chunk)

            shorts = array.array("h")
            shorts.frombytes(chunk)
            rms = math.sqrt(sum(s * s for s in shorts) / len(shorts)) if shorts else 0.0

            if not has_voice:
                if rms >= vad_threshold:
                    voice_chunks += 1
                    if voice_chunks >= 2:  # 200ms sustained sound
                        has_voice = True
                        silence_time = 0.0
                else:
                    voice_chunks = 0
                    if time.time() - start_time >= initial_timeout:
                        break
            else:
                if rms < vad_threshold:
                    silence_time += 0.1
                    if silence_time >= silence_duration:
                        # User stopped speaking!
                        break
                else:
                    silence_time = 0.0

                if time.time() - start_time >= max_duration:
                    break
    finally:
        signal.signal(signal.SIGTERM, old_sigterm)
        signal.signal(signal.SIGINT, old_sigint)

        try:
            if proc.stdout:
                proc.stdout.close()
            proc.terminate()
            proc.wait(timeout=1.0)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass

        for p in (PID_FILE, SESSION_PID_FILE):
            if os.path.exists(p):
                try:
                    os.remove(p)
                except OSError:
                    pass

    if cancelled or not has_voice or len(pcm_buffer) < 3200 * 4:
        notify_quickshell_ipc("idle")
        if auto_stop_idle:
            schedule_idle_timer(IDLE_TIMEOUT_SECONDS)
        return ""

    # Write buffered PCM frames to WAV file
    try:
        with wave.open(audio_path, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(16000)
            wf.writeframes(pcm_buffer)
    except Exception as e:
        print(f"Error writing WAV file: {e}", file=sys.stderr)
        notify_quickshell_ipc("idle")
        return ""

    notify_quickshell_ipc("transcribing")
    return transcribe(audio_path, server_url, language, auto_stop_idle)


def follow_up_listen(
    audio_path: str = AUDIO_FILE,
    server_url: str = DEFAULT_SERVER_URL,
    language: str = "es",
    auto_stop_idle: bool = True,
    initial_timeout: float = 4.0,
    silence_duration: float = 0.8,
    max_duration: float = 15.0,
) -> str:
    """Listens automatically for user follow-up with VAD."""
    return listen_with_vad(
        audio_path=audio_path,
        server_url=server_url,
        language=language,
        auto_stop_idle=auto_stop_idle,
        initial_timeout=initial_timeout,
        silence_duration=silence_duration,
        max_duration=max_duration,
    )


def main():
    parser = argparse.ArgumentParser(description="Jarvis audio recorder & Whisper transcriber")
    parser.add_argument(
        "action",
        nargs="?",
        default="toggle",
        choices=["toggle", "start", "stop", "status", "transcribe", "server-stop", "follow-up", "cancel"],
        help="Action to perform (default: toggle)",
    )
    parser.add_argument("-f", "--file", default=AUDIO_FILE, help="Audio file path")
    parser.add_argument("-s", "--server", default=DEFAULT_SERVER_URL, help="Whisper server URL")
    parser.add_argument("-l", "--language", default="es", help="Transcription language (default: es)")
    parser.add_argument("--json", action="store_true", help="Output result as JSON")
    parser.add_argument("--no-idle-stop", action="store_true", help="Do not schedule auto-stop after transcription")
    parser.add_argument("--dispatch", action="store_true", help="Dispatch transcript to Jarvis dispatcher on stop/transcribe")
    parser.add_argument("--follow-up", action="store_true", help="Run VAD auto-listening follow-up")

    args = parser.parse_args()
    auto_stop = not args.no_idle_stop
    if args.follow_up:
        args.action = "follow-up"

    # Fast-path cancellation: if cancel requested or toggle clicked while active
    if args.action == "cancel":
        cancel_all()
        if args.json:
            print(json.dumps({"status": "cancelled"}))
        else:
            print("cancelled")
        sys.exit(0)

    if args.action == "toggle" and (is_active_session() or is_active_tts()):
        cancel_all()
        if args.json:
            print(json.dumps({"status": "cancelled"}))
        else:
            print("cancelled")
        sys.exit(0)

    if args.action in ("toggle", "start", "stop", "transcribe", "follow-up"):
        try:
            import fcntl
            lock_fd = open("/tmp/jarvis_audio.lock", "w")
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, OSError):
            if args.json:
                print(json.dumps({"status": "ignored", "reason": "concurrent_action"}))
            sys.exit(0)

    def handle_dispatch(transcribed_text: str):
        if not args.dispatch or not transcribed_text:
            return None
        try:
            from jarvis_dispatcher import dispatch_transcript
            return dispatch_transcript(transcribed_text)
        except Exception as e:
            print(f"Error during dispatch: {e}", file=sys.stderr)
            return None

    if args.action == "server-stop":
        cancel_idle_timer()
        notify_quickshell_ipc("idle")
        subprocess.run(["systemctl", "--user", "stop", "whisper-server.service"])
        if args.json:
            print(json.dumps({"status": "stopped"}))
        else:
            print("whisper-server stopped")
        sys.exit(0)

    elif args.action == "status":
        pid = get_recording_pid()
        sess_pid = get_session_pid()
        tts_pid = get_tts_pid()
        whisper_active = (
            subprocess.run(
                ["systemctl", "--user", "is-active", "--quiet", "whisper-server.service"]
            ).returncode
            == 0
        )
        if args.json:
            print(
                json.dumps(
                    {
                        "recording": pid is not None or sess_pid is not None,
                        "session_pid": sess_pid,
                        "recording_pid": pid,
                        "tts_active": tts_pid is not None,
                        "whisper_active": whisper_active,
                    }
                )
            )
        else:
            if pid or sess_pid:
                print("listening")
            elif tts_pid:
                print("speaking")
            else:
                print("idle")
        sys.exit(0)

    elif args.action == "start":
        pid = start_recording(args.file)
        if args.json:
            print(json.dumps({"status": "recording", "pid": pid}))
        else:
            print(f"RECORDING:{pid}")
        sys.exit(0)

    elif args.action == "stop":
        stopped = stop_recording(args.file)
        text = transcribe(args.file, args.server, args.language, auto_stop) if stopped else ""
        dispatch_res = handle_dispatch(text)
        notify_quickshell_ipc("idle")
        if args.json:
            out = {"status": "transcribed", "text": text}
            if dispatch_res is not None:
                out["dispatch"] = dispatch_res
            print(json.dumps(out))
        else:
            print(text)
        sys.exit(0)

    elif args.action == "transcribe":
        notify_quickshell_ipc("transcribing")
        text = transcribe(args.file, args.server, args.language, auto_stop)
        dispatch_res = handle_dispatch(text)
        notify_quickshell_ipc("idle")
        if args.json:
            out = {"status": "transcribed", "text": text}
            if dispatch_res is not None:
                out["dispatch"] = dispatch_res
            print(json.dumps(out))
        else:
            print(text)
        sys.exit(0)

    elif args.action == "toggle":
        text = listen_with_vad(
            audio_path=args.file,
            server_url=args.server,
            language=args.language,
            auto_stop_idle=auto_stop,
            initial_timeout=4.0,
            silence_duration=0.8,
            max_duration=15.0,
        )
        if text:
            dispatch_res = handle_dispatch(text)
        else:
            dispatch_res = None
            notify_quickshell_ipc("idle")

        if args.json:
            out = {"status": "transcribed" if text else "timeout", "text": text}
            if dispatch_res is not None:
                out["dispatch"] = dispatch_res
            print(json.dumps(out))
        else:
            print(text)
        sys.exit(0)

    elif args.action == "follow-up":
        text = follow_up_listen(args.file, args.server, args.language, auto_stop)
        if text:
            dispatch_res = handle_dispatch(text)
        else:
            dispatch_res = None
            notify_quickshell_ipc("idle")

        if args.json:
            out = {"status": "transcribed" if text else "timeout", "text": text}
            if dispatch_res is not None:
                out["dispatch"] = dispatch_res
            print(json.dumps(out))
        else:
            print(text)
        sys.exit(0)


if __name__ == "__main__":
    main()
