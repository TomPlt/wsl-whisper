#Requires AutoHotkey v2.0
#SingleInstance Force

doneFile := "C:\Users\" . A_UserName . "\.whisper-ptt-done"
signalFile := "\\wsl$\Debian\tmp\whisper-ptt-signal"

F12:: {
    global signalFile, doneFile
    if !FileExist(signalFile) {
        ToolTip("Recording...")
        Run('wsl.exe -d Debian -- touch /tmp/whisper-ptt-signal', , "Hide")
    } else {
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
