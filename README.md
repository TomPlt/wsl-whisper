# whisper-ptt

Push-to-talk speech-to-text for WSL2. Press F12 to start recording, F12 again to stop — the transcription is automatically pasted into whatever window is focused on Windows.

Also includes `whisper`, a one-shot CLI for transcribing audio/video files with timestamps.

## Requirements

| Component | Requirement |
|-----------|-------------|
| WSL distro | Debian (or change the distro name in `whisper-ptt.ahk`) |
| WSLg | Required for PulseAudio microphone access |
| GPU | NVIDIA with CUDA accessible from WSL |
| Windows | AutoHotkey v2.0 |
| System packages | `ffmpeg`, `python3`, `python3-venv` |

## Setup

### 1. Install system packages (WSL)

```bash
sudo apt install ffmpeg python3 python3-venv
```

### 2. Create the Python virtual environment

```bash
python3 -m venv ~/.local/share/whisper-env
~/.local/share/whisper-env/bin/pip install faster-whisper nvidia-cublas-cu12
```

The `nvidia-cublas-cu12` package is required — `faster-whisper` depends on cuBLAS but doesn't bundle it, and setting `LD_LIBRARY_PATH` at runtime is too late (glibc caches it at process start). The scripts load it manually via `ctypes` before importing `faster_whisper`.

### 3. Install the scripts

Clone this repo somewhere (e.g. `~/projects/whisper-ptt`) and symlink the scripts onto your PATH:

```bash
git clone <repo-url> ~/projects/whisper-ptt
cd ~/projects/whisper-ptt
mkdir -p ~/.local/bin
ln -s "$(pwd)/whisper-ptt" ~/.local/bin/whisper-ptt
ln -s "$(pwd)/whisper"     ~/.local/bin/whisper
```

Make sure `~/.local/bin` is on your PATH (add to `~/.bashrc` if not):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Optional alias:

```bash
echo "alias ptt='whisper-ptt'" >> ~/.bashrc
```

### 4. Configure the AHK script (Windows)

Open `whisper-ptt.ahk` and check this line near the top:

```ahk
signalFile := "\\wsl$\Debian\tmp\whisper-ptt-signal"
```

and inside the `F12` hotkey block:

```ahk
Run('wsl.exe -d Debian -- touch /tmp/whisper-ptt-signal', , "Hide")
Run('wsl.exe -d Debian -- rm -f /tmp/whisper-ptt-signal', , "Hide")
```

**If your WSL distro is not named `Debian`**, change all three occurrences to your distro name (e.g. `Ubuntu`). Find your distro name with `wsl.exe --list` in a Windows terminal.

The Windows username in the done-file path is read automatically from `A_UserName` — no changes needed there.

### 5. Run

**WSL terminal:**

```bash
whisper-ptt                    # base model, auto-detect language
whisper-ptt --model small      # more accurate, slower
whisper-ptt --model large-v3   # best accuracy
whisper-ptt --language en      # skip language detection
whisper-ptt --no-clipboard     # print only, don't copy/paste
```

`whisper-ptt` will automatically re-exec itself under the venv Python — no need to activate the venv manually.

**Windows:** Double-click `whisper-ptt.ahk` (or add it to your startup folder). A tray icon will appear. Press F12 to use it.

## Usage

1. Start `whisper-ptt` in a WSL terminal — it loads the model onto the GPU once and stays running.
2. Press **F12** → tooltip shows "Recording..."
3. Speak.
4. Press **F12** again → tooltip shows "Transcribing..."
5. The transcribed text is pasted into the active Windows window automatically.

You can also toggle recording by pressing **Enter** in the WSL terminal (useful for testing without the AHK script).

## `whisper` — file transcription

One-shot transcription of audio or video files with timestamps:

```bash
whisper recording.mp3
whisper meeting.wav medium
whisper video.mp4 base en
```

```
whisper <file> [model] [language]

Models:
  tiny      fastest, least accurate
  base      fast, good accuracy (default)
  small     balanced
  medium    slower, better accuracy
  large-v3  slowest, best accuracy
```

Output includes detected language, duration, and timestamped segments.

## Troubleshooting

**No audio captured / silent recording**
- Confirm WSLg is running: `echo $PULSE_SERVER` should be non-empty, or `pactl info` should work.
- Test microphone: `ffmpeg -f pulse -i default -t 3 /tmp/test.wav && ffplay /tmp/test.wav`

**CUDA / cuBLAS errors**
- Confirm your GPU is visible: `nvidia-smi` in WSL should show your GPU.
- Confirm the pip package installed: `ls ~/.local/share/whisper-env/lib/python3.*/site-packages/nvidia/cublas/lib/libcublas.so.12`

**F12 does nothing on Windows**
- Confirm AutoHotkey v2.0 is installed (not v1.x — the script uses v2 syntax).
- Confirm the WSL distro name in `whisper-ptt.ahk` matches your actual distro (`wsl.exe --list`).
- Confirm `whisper-ptt` is running in WSL before pressing F12.

**Transcription appears but doesn't paste**
- The done-file path is `C:\Users\<username>\.whisper-ptt-done`. Confirm your Windows and WSL usernames match (WSL username is from `whoami`, Windows username is from `echo $USERNAME` in PowerShell).
- If they differ, edit `DONE_FILE` in `whisper-ptt` to use the correct Windows username.

## How it works

```
F12 press  →  AHK touches  \\wsl$\Debian\tmp\whisper-ptt-signal
           →  whisper-ptt detects file creation → starts ffmpeg recording

F12 again  →  AHK removes the signal file
           →  whisper-ptt detects file removal → stops ffmpeg → transcribes
           →  copies text to clipboard via clip.exe
           →  writes C:\Users\<user>\.whisper-ptt-done

AHK polls every 200ms → finds done file → deletes it → sends Ctrl+V
```

The model stays loaded in GPU memory between recordings, so after the first press there's no model-load delay.
