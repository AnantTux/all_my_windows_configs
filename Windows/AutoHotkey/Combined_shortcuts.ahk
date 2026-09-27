#Requires AutoHotkey v2.0
#SingleInstance Force
#WinActivateForce

LastActiveWindowByDesktop := Map()
DesktopTransitionDepth := 0

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

; Win + E opens File Pilot. If it is already running, duplicate its current
; tab into a new File Pilot window instead of trying to switch to it.
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

    ; Keep an existing correct shortcut, but repair missing/stale shortcuts.
    try {
        FileGetShortcut(shortcutPath, &existingTarget, &existingDir, &existingArgs)
        if (existingTarget = target && existingDir = A_ScriptDir && existingArgs == arguments)
            return
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
    ; Do not send Ctrl+N until the shortcut keys are released.
    KeyWait("e")
    WaitForWinRelease()

    filePilotPath := EnvGet("LOCALAPPDATA") "\Voidstar\FilePilot\FPilot.exe"

    if !FileExist(filePilotPath) {
        MsgBox("File Pilot was not found at:`n`n" filePilotPath, "Application shortcut")
        return
    }

    ; File Pilot's Ctrl+N command duplicates the active tab into a new window.
    ; Avoid FocusWindowAcrossDesktops here: its virtual-desktop transition is
    ; the path that can leave File Pilot in the unusable task-switcher state.
    ; File Pilot can leave a maximized window parked off-screen. Windows then
    ; shows it as a black Alt+Tab thumbnail even though it cannot be activated.
    ; Hide only those parked windows; normal File Pilot windows are untouched.
    HideParkedFilePilotWindows()
    mainWindow := FindOnScreenFilePilotWindow()

    if mainWindow {
        windowsBeforeNew := Map()

        for hwnd in WinGetList("ahk_exe FPilot.exe")
            windowsBeforeNew[hwnd] := true

        if ForceActivateWindow(mainWindow) {
            Sleep(100)
            Send("^n")

            newWindow := WaitForNewWindow(
                "ahk_exe FPilot.exe",
                windowsBeforeNew,
                2500
            )

            if newWindow
                ForceActivateWindow(newWindow)

            return
        }
    }

    ; First launch, or a recovery fallback if the running window cannot be
    ; activated. File Pilot will handle the second invocation itself.
    LaunchAndFocusApp(filePilotPath, "ahk_exe FPilot.exe", false)
}


FindOnScreenFilePilotWindow() {
    for hwnd in WinGetList("ahk_exe FPilot.exe") {
        try {
            WinGetPos(&x, &y, &width, &height, "ahk_id " hwnd)

            ; Windows parks virtual-desktop/failed windows near -16000. Keep
            ; support for a real monitor positioned to the left or above 0.
            if (width > 0 && height > 0 && x > -15000 && y > -15000)
                return hwnd
        }
    }

    return 0
}


HideParkedFilePilotWindows() {
    for hwnd in WinGetList("ahk_exe FPilot.exe") {
        try {
            WinGetPos(&x, &y, &width, &height, "ahk_id " hwnd)

            if (width > 0 && height > 0 && x <= -15000 && y <= -15000)
                WinHide("ahk_id " hwnd)
        }
    }
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

    ; Alacritty can expose its window before its renderer and input surface are
    ; ready. Retry activation only while it remains inactive.
    if alacrittyWindow
        SetTimer(ActivateAlacrittyWhenReady.Bind(alacrittyWindow), -180)
}


ActivateAlacrittyWhenReady(hwnd, attempt := 1) {
    if !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        return false

    ; Zellij may create its first tab after the outer Alacritty window has
    ; initially reported itself active. Keep checking briefly and reactivate it
    ; only if Windows has moved focus away during that startup window.
    if !WinActive("ahk_id " hwnd)
        ForceActivateWindow(hwnd)

    ; The first Alacritty/Zellij launch after Windows starts can take longer
    ; than the usual renderer startup. Keep the retry window short and bounded
    ; while still restoring focus if startup briefly steals it.
    if (attempt < 7) {
        retryDelay := 120 + (attempt * 160)
        SetTimer(ActivateAlacrittyWhenReady.Bind(hwnd, attempt + 1), -retryDelay)
    }

    return WinActive("ahk_id " hwnd) != 0
}

LaunchAndFocusApp(command, windowSelector, reuseExisting := false) {
    existingWindows := Map()

    for hwnd in WinGetList(windowSelector)
        existingWindows[hwnd] := true

    if (reuseExisting && existingWindows.Count > 0) {
        for hwnd in existingWindows {
            ; Do not assume an activation succeeded.  Some applications expose
            ; an auxiliary top-level window; if it cannot be foregrounded,
            ; re-running the application lets its own single-instance handler
            ; bring the real window forward.
            if FocusWindowAcrossDesktops(hwnd)
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
        FocusWindowAcrossDesktops(newWindow, &desktopSwitchFailed)
        return desktopSwitchFailed ? 0 : newWindow
    }

    ; Some single-instance applications reuse an existing window.
    windows := WinGetList(windowSelector)

    if windows.Length {
        FocusWindowAcrossDesktops(windows[1], &desktopSwitchFailed)
        return desktopSwitchFailed ? 0 : windows[1]
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


FocusWindowAcrossDesktops(hwnd, &desktopSwitchFailed := false) {
    desktopSwitchFailed := false
    BeginDesktopTransition()
    try {
        switchRequested := false
        try {
            getWindowDesktopProc := GetVDAProc("GetWindowDesktopNumber")
            getCurrentProc := GetVDAProc("GetCurrentDesktopNumber")
            goToDesktopProc := GetVDAProc("GoToDesktopNumber")

            windowDesktop := DllCall(getWindowDesktopProc, "Ptr", hwnd, "Int")
            currentDesktop := DllCall(getCurrentProc, "Int")

            if (windowDesktop >= 0 && currentDesktop != windowDesktop) {
                switchRequested := true
                result := DllCall(goToDesktopProc, "Int", windowDesktop, "Int")
                if (result = -1)
                    throw Error("Windows could not switch to the desktop.")

                RequireDesktopIsActive(windowDesktop)
                Sleep(150)
            }
        } catch as error {
            if switchRequested {
                desktopSwitchFailed := true
                ShowDesktopError(error)
                return false
            }
        }

        return ForceActivateWindow(hwnd)
    } finally {
        EndDesktopTransition()
    }
}


ForceActivateWindow(hwnd) {
    if !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        return false

    try {
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            WinRestore("ahk_id " hwnd)

        WinShow("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        DllCall("User32\SetForegroundWindow", "Ptr", hwnd)

        if WinWaitActive("ahk_id " hwnd, , 1)
            return true

        Sleep(80)
        WinActivate("ahk_id " hwnd)
        DllCall("User32\SetForegroundWindow", "Ptr", hwnd)

        return WinWaitActive("ahk_id " hwnd, , 1) != 0
    } catch {
        return false
    }
}


; ============================================================
; VIRTUAL DESKTOP FOCUS MEMORY
; ============================================================

BeginDesktopTransition() {
    global DesktopTransitionDepth

    ; Only this short state update is critical; desktop waits remain interruptible.
    previousCritical := Critical("On")
    try {
        RememberActiveWindow()
        DesktopTransitionDepth += 1
    } finally {
        Critical(previousCritical)
    }
}


EndDesktopTransition() {
    global DesktopTransitionDepth
    DesktopTransitionDepth -= 1
}


RememberActiveWindow(*) {
    global LastActiveWindowByDesktop, DesktopTransitionDepth

    ; Prevent a partially completed sample from resuming after a desktop switch.
    previousCritical := Critical("On")
    try {
        if DesktopTransitionDepth
            return

        hwnd := WinGetID("A")

        if !IsUsableAppWindow(hwnd)
            return

        getCurrentProc := GetVDAProc("GetCurrentDesktopNumber")
        desktopNumber := DllCall(getCurrentProc, "Int")

        if (desktopNumber >= 0)
            LastActiveWindowByDesktop[desktopNumber] := hwnd
    } catch {
        ; No active app or desktop API available; keep the previous sample.
    } finally {
        Critical(previousCritical)
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

    static ignoredClasses := Map(
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


RequireDesktopIsActive(desktopNumber) {
    if !WaitUntilDesktopIsActive(desktopNumber)
        throw Error("Timed out waiting for desktop " (desktopNumber + 1) ".")
}


EnsureDesktopCount(targetDesktop, desktopCount) {
    if (desktopCount >= targetDesktop)
        return false

    Loop (targetDesktop - desktopCount) {
        Send("^#d")
        Sleep(350)
    }

    Sleep(200)
    return true
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
    BeginDesktopTransition()
    try {
        getCountProc := GetVDAProc("GetDesktopCount")
        goToDesktopProc := GetVDAProc("GoToDesktopNumber")
        desktopCount := DllCall(getCountProc, "Int")

        if (desktopCount < 1)
            throw Error("Could not read the virtual desktops.")

        WaitForWinRelease()

        EnsureDesktopCount(targetDesktop, desktopCount)

        targetIndex := targetDesktop - 1

        result := DllCall(
            goToDesktopProc,
            "Int", targetIndex,
            "Int"
        )

        if (result = -1)
            throw Error("Windows could not switch to the desktop.")

        RequireDesktopIsActive(targetIndex)
        RestoreLastActiveWindow(targetIndex)
    } catch as error {
        ShowDesktopError(error)
    } finally {
        EndDesktopTransition()
    }
}


SwitchRelativeDesktop(direction) {
    BeginDesktopTransition()
    try {
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

        RequireDesktopIsActive(targetDesktop)
        RestoreLastActiveWindow(targetDesktop)
    } catch as error {
        ShowDesktopError(error)
    } finally {
        EndDesktopTransition()
    }
}


; ============================================================
; MOVE WINDOW FUNCTION
; ============================================================

MoveActiveWindowToDesktop(targetDesktop, followWindow := false) {
    BeginDesktopTransition()
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
        createdDesktops := EnsureDesktopCount(targetDesktop, desktopCount)

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

            RequireDesktopIsActive(targetIndex)
            ForceActivateWindow(activeWindow)
        } else if createdDesktops {
            Sleep(150)

            DllCall(
                goToDesktopProc,
                "Int", originalDesktop,
                "Int"
            )

            RequireDesktopIsActive(originalDesktop)
            RestoreLastActiveWindow(originalDesktop)
        }

        ToolTip("Moved window to desktop " targetDesktop)
        SetTimer(HideDesktopToolTip, -1200)
    } catch as error {
        ShowDesktopError(error)
    } finally {
        EndDesktopTransition()
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

    FocusWindowAcrossDesktops(newWindow, &desktopSwitchFailed)
    if !desktopSwitchFailed
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
