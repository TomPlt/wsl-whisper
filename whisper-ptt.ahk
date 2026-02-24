#Requires AutoHotkey v2.0
#SingleInstance Force

recording := false
doneFile := "C:\Users\" . A_UserName . "\.whisper-ptt-done"

F12:: {
    global recording
    if (!recording) {
        recording := true
        ToolTip("Recording...")
        Run('wsl.exe -d Debian -- touch /tmp/whisper-ptt-signal', , "Hide")
    } else {
        recording := false
        ToolTip("Transcribing...")
        Run('wsl.exe -d Debian -- rm -f /tmp/whisper-ptt-signal', , "Hide")
        SetTimer(CheckDone, 200)
    }
}

CheckDone() {
    global doneFile
    if FileExist(doneFile) {
        try FileDelete(doneFile)
        ToolTip()
        Sleep(100)
        Send("^v")
        SetTimer(CheckDone, 0)
    }
}
