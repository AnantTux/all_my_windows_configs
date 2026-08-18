#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce

LastActiveWindowByDesktop := Map()

; Automatically register this script to run when Windows starts
EnsureStartupShortcut()

SetTitleMatchMode(2)

; Automatically maximize newly opened Notepad windows
SetTimer(WatchNotepadWindows, 500)

; Remember the active app on every virtual desktop
SetTimer(RememberActiveWindow, 200)


; ============================================================
; APPLICATION SHORTCUTS
; ============================================================

; Win + E opens File Pilot and focuses its window
#e::OpenFilePilot()

; Win + F opens Edge in InPrivate mode
#f::Run("msedge.exe --inprivate")

; Windows + Enter opens and focuses an Alacritty window
#Enter::OpenAlacritty()


; ============================================================
; WINDOW SHORTCUTS
; ============================================================

; Alt + Shift + Q closes the active window
!+q::WinClose("A")

; Alt + Shift + A toggles fullscreen
!+a::Send("{F11}")

; Alt + Shift + M maximizes the active window
!+m::WinMaximize("A")

; Middle mouse button pastes
MButton::Send("^v")


; ============================================================
; SWITCH TO A VIRTUAL DESKTOP
;
; Win + 1-9 switches to desktops 1-9
; Win + 0 switches to desktop 10
; Missing desktops are created automatically
; ============================================================

#1::SwitchToDesktop(1)
#2::SwitchToDesktop(2)
#3::SwitchToDesktop(3)
#4::SwitchToDesktop(4)
#5::SwitchToDesktop(5)
#6::SwitchToDesktop(6)
#7::SwitchToDesktop(7)
#8::SwitchToDesktop(8)
#9::SwitchToDesktop(9)
#0::SwitchToDesktop(10)

; Keep the standard shortcuts, but restore focus after switching
^#Left::SwitchRelativeDesktop(-1)
^#Right::SwitchRelativeDesktop(1)


; ============================================================
; MOVE ACTIVE WINDOW TO A VIRTUAL DESKTOP
;
; Win + Shift + 1-9 moves the active window
; Win + Shift + 0 moves it to desktop 10
; You remain on your current desktop
; ============================================================

#+1::MoveActiveWindowToDesktop(1)
#+2::MoveActiveWindowToDesktop(2)
#+3::MoveActiveWindowToDesktop(3)
#+4::MoveActiveWindowToDesktop(4)
#+5::MoveActiveWindowToDesktop(5)
#+6::MoveActiveWindowToDesktop(6)
#+7::MoveActiveWindowToDesktop(7)
#+8::MoveActiveWindowToDesktop(8)
#+9::MoveActiveWindowToDesktop(9)
#+0::MoveActiveWindowToDesktop(10)


; ============================================================
; PRIVATE SEARCH
; ============================================================

; Alt + Shift + G searches selected text in a Zen private window
!+g::GoogleSelectedTextInZenPrivate()


; ============================================================
; STARTUP REGISTRATION
; ============================================================

EnsureStartupShortcut() {
    shortcutPath := A_Startup "\Personal AutoHotkeys.lnk"

    if A_IsCompiled {
        target := A_ScriptFullPath
        arguments := ""
    } else {
        target := A_AhkPath
        arguments := Chr(34) A_ScriptFullPath Chr(34)
    }

    try {
        FileCreateShortcut(
            target,
            shortcutPath,
            A_ScriptDir,
            arguments,
            "Personal AutoHotkey shortcuts"
        )
    } catch as error {
        MsgBox(
            "The startup shortcut could not be created:`n`n" error.Message,
            "Personal AutoHotkeys"
        )
    }
}


; ============================================================
; NOTEPAD AUTO-MAXIMIZE
; ============================================================

WatchNotepadWindows(*) {
    static seenWindows := Map()
    closedWindows := []

    for hwnd in seenWindows {
        if !WinExist("ahk_id " hwnd)
            closedWindows.Push(hwnd)
    }

    for hwnd in closedWindows
        seenWindows.Delete(hwnd)

    for hwnd in WinGetList("ahk_exe notepad.exe") {
        if !seenWindows.Has(hwnd) {
            try {
                WinMaximize("ahk_id " hwnd)
                seenWindows[hwnd] := true
            } catch {
                ; Try again on the next timer check
            }
        }
    }
}


; ============================================================
; APPLICATION LAUNCHING AND FOCUS
; ============================================================

OpenFilePilot() {
    ; Do not launch the app until the shortcut keys are released.
    KeyWait("e")
    WaitForWinRelease()

    filePilotPath := EnvGet("LOCALAPPDATA") "\Voidstar\FilePilot\FPilot.exe"

    if !FileExist(filePilotPath) {
        MsgBox("File Pilot was not found at:`n`n" filePilotPath, "Application shortcut")
        return
    }

    LaunchAndFocusApp(
        filePilotPath,
        "ahk_exe FPilot.exe",
        true
    )
}


OpenAlacritty() {
    ; Do not let the released shortcut keys reach the terminal once it gains focus.
    KeyWait("Enter")
    WaitForWinRelease()

    alacrittyWindow := LaunchAndFocusApp(
        "alacritty.exe",
        "ahk_exe alacritty.exe",
        false
    )

    ; Alacritty can create its window before it is ready to accept focus.
    ; Retry after this hotkey handler has returned and Windows has settled.
    if alacrittyWindow
        SetTimer(ForceActivateWindow.Bind(alacrittyWindow), -250)
}

LaunchAndFocusApp(command, windowSelector, reuseExisting := false) {
    existingWindows := Map()

    for hwnd in WinGetList(windowSelector)
        existingWindows[hwnd] := true

    if (reuseExisting && existingWindows.Count > 0) {
        for hwnd in existingWindows {
            FocusWindowAcrossDesktops(hwnd)
            return hwnd
        }
    }

    try {
        Run(command)
    } catch as error {
        MsgBox(
            "The application could not be opened:`n`n" error.Message,
            "Application shortcut"
        )
        return
    }

    newWindow := WaitForNewWindow(windowSelector, existingWindows, 8000)

    if newWindow {
        FocusWindowAcrossDesktops(newWindow)
        return newWindow
    }

    ; Some single-instance applications reuse an existing window.
    windows := WinGetList(windowSelector)

    if windows.Length {
        FocusWindowAcrossDesktops(windows[1])
        return windows[1]
    }

    return 0
}


WaitForNewWindow(windowSelector, existingWindows, timeoutMs) {
    timeoutAt := A_TickCount + timeoutMs

    while (A_TickCount < timeoutAt) {
        for hwnd in WinGetList(windowSelector) {
            if !existingWindows.Has(hwnd)
                return hwnd
        }

        Sleep(50)
    }

    return 0
}


FocusWindowAcrossDesktops(hwnd) {
    try {
        getWindowDesktopProc := GetVDAProc("GetWindowDesktopNumber")
        getCurrentProc := GetVDAProc("GetCurrentDesktopNumber")
        goToDesktopProc := GetVDAProc("GoToDesktopNumber")

        windowDesktop := DllCall(
            getWindowDesktopProc,
            "Ptr", hwnd,
            "Int"
        )

        currentDesktop := DllCall(getCurrentProc, "Int")

        if (windowDesktop >= 0 && currentDesktop != windowDesktop) {
            RememberActiveWindow()

            DllCall(
                goToDesktopProc,
                "Int", windowDesktop,
                "Int"
            )

            WaitUntilDesktopIsActive(windowDesktop)
            Sleep(150)
        }
    }

    ForceActivateWindow(hwnd)
}


ForceActivateWindow(hwnd) {
    if !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        return false

    try {
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            WinRestore("ahk_id " hwnd)

        WinActivate("ahk_id " hwnd)

        if WinWaitActive("ahk_id " hwnd, , 1)
            return true

        Sleep(80)
        WinActivate("ahk_id " hwnd)

        return WinWaitActive("ahk_id " hwnd, , 1) != 0
    } catch {
        return false
    }
}


; ============================================================
; VIRTUAL DESKTOP FOCUS MEMORY
; ============================================================

RememberActiveWindow(*) {
    global LastActiveWindowByDesktop

    try {
        hwnd := WinGetID("A")

        if !IsUsableAppWindow(hwnd)
            return

        getCurrentProc := GetVDAProc("GetCurrentDesktopNumber")
        desktopNumber := DllCall(getCurrentProc, "Int")

        if (desktopNumber >= 0)
            LastActiveWindowByDesktop[desktopNumber] := hwnd
    }
}


IsUsableAppWindow(hwnd) {
    if !hwnd
        return false

    if !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        return false

    if !DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int")
        return false

    try {
        windowClass := WinGetClass("ahk_id " hwnd)
    } catch {
        return false
    }

    ignoredClasses := Map(
        "Progman", true,
        "WorkerW", true,
        "Shell_TrayWnd", true,
        "Shell_SecondaryTrayWnd", true,
        "MultitaskingViewFrame", true
    )

    return !ignoredClasses.Has(windowClass)
}


RestoreLastActiveWindow(desktopNumber) {
    global LastActiveWindowByDesktop

    Sleep(180)

    if LastActiveWindowByDesktop.Has(desktopNumber) {
        savedWindow := LastActiveWindowByDesktop[desktopNumber]

        if (
            IsUsableAppWindow(savedWindow)
            && IsWindowOnDesktop(savedWindow, desktopNumber)
        ) {
            if ForceActivateWindow(savedWindow)
                return
        }

        LastActiveWindowByDesktop.Delete(desktopNumber)
    }

    fallbackWindow := FindTopWindowOnDesktop(desktopNumber)

    if fallbackWindow {
        LastActiveWindowByDesktop[desktopNumber] := fallbackWindow
        ForceActivateWindow(fallbackWindow)
    }
}


FindTopWindowOnDesktop(desktopNumber) {
    for hwnd in WinGetList() {
        if (
            IsUsableAppWindow(hwnd)
            && IsWindowOnDesktop(hwnd, desktopNumber)
        ) {
            return hwnd
        }
    }

    return 0
}


IsWindowOnDesktop(hwnd, desktopNumber) {
    try {
        isOnDesktopProc := GetVDAProc("IsWindowOnDesktopNumber")

        return DllCall(
            isOnDesktopProc,
            "Ptr", hwnd,
            "Int", desktopNumber,
            "Int"
        ) = 1
    } catch {
        return false
    }
}


WaitUntilDesktopIsActive(desktopNumber, timeoutMs := 2500) {
    try {
        getCurrentProc := GetVDAProc("GetCurrentDesktopNumber")
    } catch {
        return false
    }

    timeoutAt := A_TickCount + timeoutMs

    while (A_TickCount < timeoutAt) {
        if (DllCall(getCurrentProc, "Int") = desktopNumber)
            return true

        Sleep(25)
    }

    return false
}


; ============================================================
; VIRTUAL DESKTOP SWITCHING
; ============================================================

SwitchToDesktop(targetDesktop) {
    try {
        RememberActiveWindow()

        getCountProc := GetVDAProc("GetDesktopCount")
        goToDesktopProc := GetVDAProc("GoToDesktopNumber")
        desktopCount := DllCall(getCountProc, "Int")

        if (desktopCount < 1)
            throw Error("Could not read the virtual desktops.")

        WaitForWinRelease()

        if (desktopCount < targetDesktop) {
            Loop (targetDesktop - desktopCount) {
                Send("^#d")
                Sleep(350)
            }

            Sleep(200)
        }

        targetIndex := targetDesktop - 1

        result := DllCall(
            goToDesktopProc,
            "Int", targetIndex,
            "Int"
        )

        if (result = -1)
            throw Error("Windows could not switch to the desktop.")

        WaitUntilDesktopIsActive(targetIndex)
        RestoreLastActiveWindow(targetIndex)
    } catch as error {
        ShowDesktopError(error)
    }
}


SwitchRelativeDesktop(direction) {
    try {
        RememberActiveWindow()

        getCountProc := GetVDAProc("GetDesktopCount")
        getCurrentProc := GetVDAProc("GetCurrentDesktopNumber")
        goToDesktopProc := GetVDAProc("GoToDesktopNumber")

        desktopCount := DllCall(getCountProc, "Int")
        currentDesktop := DllCall(getCurrentProc, "Int")
        targetDesktop := currentDesktop + direction

        WaitForCtrlWinRelease()

        if (targetDesktop < 0 || targetDesktop >= desktopCount)
            return

        result := DllCall(
            goToDesktopProc,
            "Int", targetDesktop,
            "Int"
        )

        if (result = -1)
            throw Error("Windows could not switch to the desktop.")

        WaitUntilDesktopIsActive(targetDesktop)
        RestoreLastActiveWindow(targetDesktop)
    } catch as error {
        ShowDesktopError(error)
    }
}


; ============================================================
; MOVE WINDOW FUNCTION
; ============================================================

MoveActiveWindowToDesktop(targetDesktop, followWindow := false) {
    try {
        activeWindow := WinGetID("A")

        getCountProc := GetVDAProc("GetDesktopCount")
        getCurrentProc := GetVDAProc("GetCurrentDesktopNumber")
        moveWindowProc := GetVDAProc("MoveWindowToDesktopNumber")
        goToDesktopProc := GetVDAProc("GoToDesktopNumber")

        desktopCount := DllCall(getCountProc, "Int")
        originalDesktop := DllCall(getCurrentProc, "Int")

        if (desktopCount < 1 || originalDesktop < 0)
            throw Error("Could not read the virtual desktops.")

        WaitForWinAndShiftRelease()
        createdDesktops := false

        if (desktopCount < targetDesktop) {
            Loop (targetDesktop - desktopCount) {
                Send("^#d")
                Sleep(350)
            }

            createdDesktops := true
            Sleep(200)
        }

        targetIndex := targetDesktop - 1

        result := DllCall(
            moveWindowProc,
            "Ptr", activeWindow,
            "Int", targetIndex,
            "Int"
        )

        if (result = -1)
            throw Error("Windows could not move this window.")

        global LastActiveWindowByDesktop
        LastActiveWindowByDesktop[targetIndex] := activeWindow

        if followWindow {
            DllCall(
                goToDesktopProc,
                "Int", targetIndex,
                "Int"
            )

            WaitUntilDesktopIsActive(targetIndex)
            ForceActivateWindow(activeWindow)
        } else if createdDesktops {
            Sleep(150)

            DllCall(
                goToDesktopProc,
                "Int", originalDesktop,
                "Int"
            )

            WaitUntilDesktopIsActive(originalDesktop)
            RestoreLastActiveWindow(originalDesktop)
        }

        ToolTip("Moved window to desktop " targetDesktop)
        SetTimer(HideDesktopToolTip, -1200)
    } catch as error {
        ShowDesktopError(error)
    }
}


; ============================================================
; VIRTUAL DESKTOP DLL
; ============================================================

GetVDAProc(functionName) {
    static dllHandle := 0
    static procedures := Map()

    if procedures.Has(functionName)
        return procedures[functionName]

    if !dllHandle {
        dllPath := A_ScriptDir "\VirtualDesktopAccessor.dll"

        if !FileExist(dllPath) {
            throw Error(
                "VirtualDesktopAccessor.dll was not found.`n`n"
                . "Place it in the same folder as this script."
            )
        }

        dllHandle := DllCall(
            "Kernel32\LoadLibraryW",
            "Str", dllPath,
            "Ptr"
        )

        if !dllHandle
            throw Error("VirtualDesktopAccessor.dll could not be loaded.")
    }

    procedure := DllCall(
        "Kernel32\GetProcAddress",
        "Ptr", dllHandle,
        "AStr", functionName,
        "Ptr"
    )

    if !procedure
        throw Error("The DLL does not support " functionName ".")

    procedures[functionName] := procedure
    return procedure
}


; ============================================================
; ZEN PRIVATE SEARCH
; ============================================================

GoogleSelectedTextInZenPrivate() {
    ; Do not copy while the Alt+Shift+G shortcut modifiers are still down.
    KeyWait("g")
    WaitForAltShiftRelease()

    savedClipboard := ClipboardAll()
    A_Clipboard := ""

    Send("^c")

    if !ClipWait(1) {
        A_Clipboard := savedClipboard
        ToolTip("Select some text first")
        SetTimer(HideDesktopToolTip, -1200)
        return
    }

    selectedText := Trim(A_Clipboard)
    A_Clipboard := savedClipboard

    if (selectedText = "") {
        ToolTip("Select some text first")
        SetTimer(HideDesktopToolTip, -1200)
        return
    }

    searchURL := "https://www.google.com/search?q=" UriEncode(selectedText)
    zenPath := FindZenBrowser()
    existingWindows := Map()

    for hwnd in WinGetList("ahk_exe zen.exe")
        existingWindows[hwnd] := true

    try {
        ; Passing the URL at launch avoids a focus race with Ctrl+L/SendText.
        Run(Chr(34) zenPath Chr(34) " -private-window " Chr(34) searchURL Chr(34))
    } catch as error {
        MsgBox(
            "Zen Browser could not be opened:`n`n" error.Message,
            "Zen private search"
        )
        return 0
    }

    newWindow := WaitForNewWindow(
        "ahk_exe zen.exe",
        existingWindows,
        8000
    )

    if !newWindow {
        MsgBox(
            "Zen opened, but its new private window could not be detected.",
            "Zen private search"
        )
        return
    }

    FocusWindowAcrossDesktops(newWindow)

    WinWaitActive("ahk_id " newWindow, , 3)
}


FindZenBrowser() {
    localAppData := EnvGet("LOCALAPPDATA")

    possiblePaths := [
        A_ProgramFiles "\Zen Browser\zen.exe",
        localAppData "\Programs\Zen Browser\zen.exe",
        localAppData "\Zen Browser\zen.exe"
    ]

    for browserPath in possiblePaths {
        if FileExist(browserPath)
            return browserPath
    }

    return "zen.exe"
}


UriEncode(text) {
    requiredSize := StrPut(text, "UTF-8")
    utf8Buffer := Buffer(requiredSize)
    StrPut(text, utf8Buffer, "UTF-8")
    encodedText := ""

    Loop (requiredSize - 1) {
        byte := NumGet(utf8Buffer, A_Index - 1, "UChar")

        if (
            (byte >= 0x41 && byte <= 0x5A)
            || (byte >= 0x61 && byte <= 0x7A)
            || (byte >= 0x30 && byte <= 0x39)
            || byte = 0x2D
            || byte = 0x2E
            || byte = 0x5F
            || byte = 0x7E
        ) {
            encodedText .= Chr(byte)
        } else {
            encodedText .= "%" Format("{:02X}", byte)
        }
    }

    return encodedText
}


; ============================================================
; HELPER FUNCTIONS
; ============================================================

WaitForWinRelease() {
    KeyWait("LWin")
    KeyWait("RWin")
}


WaitForCtrlWinRelease() {
    KeyWait("LWin")
    KeyWait("RWin")
    KeyWait("LControl")
    KeyWait("RControl")
}


WaitForAltShiftRelease() {
    KeyWait("LAlt")
    KeyWait("RAlt")
    KeyWait("LShift")
    KeyWait("RShift")
}


WaitForWinAndShiftRelease() {
    KeyWait("LWin")
    KeyWait("RWin")
    KeyWait("LShift")
    KeyWait("RShift")
}


HideDesktopToolTip(*) {
    ToolTip()
}


ShowDesktopError(error) {
    MsgBox(
        "Virtual desktop action failed:`n`n" error.Message,
        "Virtual desktop shortcut"
    )
}
