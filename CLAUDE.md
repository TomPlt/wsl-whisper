# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup (new machine)

Requirements: WSL2 (Debian), NVIDIA GPU with CUDA, WSLg (PulseAudio), AutoHotkey v2 on Windows.

```bash
# Create venv and install dependencies
python3 -m venv ~/.local/share/whisper-env
~/.local/share/whisper-env/bin/pip install faster-whisper nvidia-cublas-cu12

# Install symlinks
ln -s "$(pwd)/whisper-ptt" ~/.local/bin/whisper-ptt
ln -s "$(pwd)/whisper"     ~/.local/bin/whisper

# Optional alias in ~/.bashrc
echo "alias ptt='whisper-ptt'" >> ~/.bashrc
```

Run `whisper-ptt` via the venv python (the shebang uses `env python3`, so either activate the venv or invoke directly):

```bash
~/.local/share/whisper-env/bin/python3 whisper-ptt [--model base] [--language en] [--no-clipboard]
```

On Windows: double-click `whisper-ptt.ahk` (requires AHK v2). It auto-detects the current Windows username and the WSL distro is hardcoded to `Debian` — change in the AHK script if needed.

There are no tests, no build steps, and no linter configured.

## Architecture

This is a WSL2 ↔ Windows IPC system with two components:

**`whisper-ptt` (Python, runs in WSL)**
- Pre-loads `faster-whisper` model onto GPU once at startup (stays warm between recordings)
- Records audio via `ffmpeg -f pulse` (WSLg PulseAudio) to `/tmp/whisper-ptt-recording.wav`
- Transcribes on GPU (`device="cuda"`, `compute_type="float16"`)
- Copies result to Windows clipboard via `clip.exe`
- Two threads poll for toggle signals concurrently: stdin (Enter key) and a signal file watcher

**`whisper-ptt.ahk` (AutoHotkey v2, runs on Windows)**
- F12 creates/removes `/tmp/whisper-ptt-signal` via `wsl.exe` to signal the Python daemon
- Polls for `C:\Users\Tom\.whisper-ptt-done` (written by Python after clipboard copy), then sends Ctrl+V to paste into the active window

**IPC flow:**
```
F12 press → AHK touches /tmp/whisper-ptt-signal
         → Python watcher fires toggle_event → starts ffmpeg recording
F12 again → AHK removes /tmp/whisper-ptt-signal
         → Python watcher fires toggle_event → stops ffmpeg, transcribes, copies to clipboard
         → Python writes C:\Users\Tom\.whisper-ptt-done
         → AHK polls, finds file, deletes it, sends Ctrl+V
```

**`whisper` (bash script)**
- One-shot file transcription; loads the model fresh each run
- Shares the same cuBLAS fix via inline Python

## Critical: cuBLAS fix

`libcublas.so.12` must be pre-loaded via `ctypes.cdll.LoadLibrary()` before importing `faster_whisper`. Setting `LD_LIBRARY_PATH` from Python is too late (glibc caches it at process startup). The path is resolved relative to `sys.prefix` inside the venv where `nvidia-cublas-cu12` is pip-installed. Both `whisper-ptt` and `whisper` implement this fix.

## Hardware/environment assumptions

- WSL2 (Debian) with WSLg PulseAudio available (`-f pulse`)
- NVIDIA GPU with CUDA accessible from WSL
- Windows-side paths (`/mnt/c/...`, `clip.exe`, `wsl.exe`) assume a standard Windows layout
- `DONE_FILE` path derives the Windows username from `getpass.getuser()` at runtime (assumes WSL and Windows usernames match)
- AHK script derives the Windows username via `A_UserName` and targets the `Debian` WSL distribution (hardcoded in AHK — change if your distro differs)
