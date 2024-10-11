;     /$$$$$$              /$$     /$$          /$$$$$$  /$$$$$$$$ /$$   /$$
;    /$$__  $$            | $$    |__/         /$$__  $$| $$_____/| $$  /$$/
;   | $$  \ $$ /$$$$$$$  /$$$$$$   /$$        | $$  \ $$| $$      | $$ /$$/
;   | $$$$$$$$| $$__  $$|_  $$_/  | $$ /$$$$$$| $$$$$$$$| $$$$$   | $$$$$/
;   | $$__  $$| $$  \ $$  | $$    | $$|______/| $$__  $$| $$__/   | $$  $$
;   | $$  | $$| $$  | $$  | $$ /$$| $$        | $$  | $$| $$      | $$\  $$
;   | $$  | $$| $$  | $$  |  $$$$/| $$        | $$  | $$| $$      | $$ \  $$
;   |__/  |__/|__/  |__/   \___/  |__/        |__/  |__/|__/      |__/  \__/

; ------------------------------------------------------------------------------
;                               Configuration
; ------------------------------------------------------------------------------

; POLL_INTERVAL (Integer, Seconds):
;   This is the interval which Anti-AFK checks for new windows and calculates
;   how much time is left before exisiting windows become inactve.
;   Default value
;   5
POLL_INTERVAL := 5

; WINDOW_TIMEOUT (Integer, Minutes):
;   This is the amount of time before a window is considered inactive. After
;   a window has timed out, Anti-AFK will start resetting any AFK timers.
;   Default value
;   10
WINDOW_TIMEOUT := 10

; TASK (Lambda Function):
;   This is a function that will be ran by the script in order to reset any
;   AFK timers. The target window will have focus while it is being executed.
;   You can customise this function freely - just make sure it resets the timer.
;   Default value
;   Send("{Space Down}")
;   Sleep(50)
;   Send("{Space Up}")
TASK := () => (
    Send("{Space Down}")
    Sleep(50)
    Send("{Space Up}")
)

; TASK_INTERVAL (Integer, Minutes):
;   This is the amount of time the script will wait after calling the TASK function
;   before calling it again.
;   Default value
;   15
TASK_INTERVAL := 15

; BLOCK_INPUT (Boolean):
;   This tells the script whether you want to block input whilst it shuffles
;   windows and sends input. This requires administrator permissions and is
;   therefore disabled by default. If input is not blocked, keystrokes from the
;   user may 'leak' into the window while Anti-AFK moves it into focus.
;   Default value
;   False
BLOCK_INPUT := False

; PROCESS_LIST (String Array):
;   This is a list of processes that Anti-AFK will montior. Any windows that do
;   not belong to any of these processes will be ignored.
;   Default value
;   ["notepad.exe", "wordpad.exe"]
PROCESS_LIST := ["notepad.exe", "wordpad.exe"]

; PROCESS_OVERRIDES (Associative Array):
;   This allows you to specify specific values of WINDOW_TIMEOUT, TASK_INTERVAL,
;   TASK and BLOCK_INPUT for specific processes. This is helpful if different
;   games consider you AFK at wildly different times, or if the function to
;   reset the AFK timer does not work as well across different applications.
;   Default value
;   Map(
;       "wordpad.exe", Map(
;           "WINDOW_TIMEOUT", 5,
;           "TASK_INTERVAL", 5,
;           "BLOCK_INPUT", False,
;           "TASK", () => (
;               Send("w")
;           )
;       )
;   )
PROCESS_OVERRIDES := Map(
    "wordpad.exe", Map(
        "WINDOW_TIMEOUT", 5,
        "TASK_INTERVAL", 5,
        "BLOCK_INPUT", False,
        "TASK", () => (
            Send("w")
        )
    )
)

; ------------------------------------------------------------------------------
;                                    Script
; ------------------------------------------------------------------------------
#Requires Autohotkey v2.0 64-Bit
#SingleInstance
InstallKeybdHook()
InstallMouseHook()

windowList := Map()
for _, program in PROCESS_LIST
{
    windowList[program] := Map()
}

; Check if the script is running as admin and if keystrokes need to be blocked. If it does not have admin
; privileges the user is prompted to elevate its permissions. Should they deny, the ability to block input
; is disabled and the script continues as normal.
if (!A_IsAdmin)
{
    requireAdmin := BLOCK_INPUT
    for program, override in PROCESS_OVERRIDES
    {
        if (override.Has("BLOCK_INPUT") && override["BLOCK_INPUT"])
        {
            requireAdmin := True
        }
    }

    if (requireAdmin)
    {
        try
        {
            if A_IsCompiled
            {

                RunWait '*RunAs "' A_ScriptFullPath '" /restart'
            }
            else
            {

                RunWait '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
            }
        }

        MsgBox "This requires Anti-AFK to be run as Admin`nIt has been temporarily disabled", "Cannot Block Keystrokes",
            "OK Icon!"
    }
}

; Reset the AFK timer for a particular window, blocking input if required.
; Input is sent directly to the target window if it's active; If there is no active window the target
; window is made active.
; If another window is active, its handle is stored while the target is made transparent and activated.
; Any AFK timers are reset and the target is sent to the back before being made opaque again. Focus is then
; restored to the original window.
resetTimer(windowID, resetAction, DenyInput)
{
    activeInfo := getWindowInfo("A")
    targetInfo := getWindowInfo("ahk_id " windowID)

    targetWindow := "ahk_id " targetInfo["ID"]

    ; Activates the target window if there is no active window or the Desktop is focused.
    ; Bringing the Desktop window to the front can cause some scaling issues, so we ignore it.
    ; The Desktop's window has a class of "WorkerW" or "Progman".
    if (!activeInfo.Count || (activeInfo["CLS"] = "WorkerW" || activeInfo["CLS"] = "Progman"))
    {
        activateWindow(targetWindow)
    }

    ; Send input directly if the target window is already active.
    if (WinActive(targetWindow))
    {
        resetAction()
        return
    }

    if (DenyInput && A_IsAdmin)
    {
        BlockInput("On")
    }

    WinSetTransparent(0, targetWindow)
    activateWindow(targetWindow)

    resetAction()

    WinMoveBottom(targetWindow)
    WinSetTransparent("OFF", targetWindow)

    oldActiveWindow := getWindow(
        activeInfo["ID"],
        activeInfo["PID"],
        activeInfo["EXE"],
        targetWindow
    )

    activateWindow(oldActiveWindow)

    if (DenyInput && A_IsAdmin)
    {
        BlockInput("Off")
    }
}

; Fetch the window which best matches the given criteria.
; Some windows are ephemeral and will be closed after user input. In this case we try
; increasingly vague identifiers until we find a related window. If a window is still
; not found a fallback is used instead.
getWindow(window_ID, process_ID, process_name, fallback)
{
    if (WinExist("ahk_id " window_ID))
    {
        return "ahk_id " window_ID
    }

    if (WinExist("ahk_pid " process_ID))
    {
        return "ahk_pid " process_ID
    }

    if (WinExist("ahk_exe " process_name))
    {
        return "ahk_exe " process_name
    }

    return fallback
}

; Get information about a window so that it can be found and reactivated later.
getWindowInfo(target)
{
    windowInfo := Map()

    if (!WinExist(target))
    {
        return windowInfo
    }

    windowInfo["ID"] := WinGetID(target)
    windowInfo["CLS"] := WinGetClass(target)
    windowInfo["PID"] := WinGetPID(target)
    windowInfo["EXE"] := WinGetProcessName(target)

    return windowInfo
}

; Activate a window and yield until it does so.
activateWindow(target)
{
    if (!WinExist(target))
    {
        return False
    }

    WinActivate(target)
    WinWaitActive(target)

    return True
}

; Calculate the number of polls it will take for the time (in seconds) to pass.
getTotalIterationCount(value)
{
    return Max(1, Round(value * 60 / POLL_INTERVAL))
}

; Find and return a specific attribute for a program, prioritising values in PROCESS_OVERRIDES.
; If an override has not been setup for that process, the default value for all programs will be used instead.
getProgramAttribute(value, program)
{
    if (PROCESS_OVERRIDES.Has(program) && PROCESS_OVERRIDES[program].Has(value))
    {
        return PROCESS_OVERRIDES[program][value]
    }
    ; %value% -> value: Dereferencing variables was used in older versions of AutoHotkey (v1.x), where % was required to reference a variable's value inside certain commands (like MsgBox or Send).
    return %value%
}

; Create and return an updated copy of the old window list. A new list is made from scratch and
; populated with the current windows. Timings for these windows are then copied from the old list
; if they are present, otherwise the default timeout is assigned.
updateWindowList(oldWindowList, processList)
{
    newWindowList := Map()
    for _, program in processList
    {
        newList := Map()
        for _, handle in WinGetList("ahk_exe" program)
        {
            if (oldWindowList[program].Has(handle))
            {
                newList[handle] := oldWindowList[program][handle]
            }
            else
            {
                newList[handle] := Map(
                    "value", getTotalIterationCount(getProgramAttribute("WINDOW_TIMEOUT", program)),
                    "type", "Timeout"
                )
            }
        }

        newWindowList[program] := newList
    }

    return newWindowList
}

; Dynamically update the System Tray icon and tooltip text, taking into consideration the number
; of windows that the script has found and the number of windows it is managing.
updateSysTray(windowList)
{
    ; Count how many windows are actively managed and how many
    ; are being monitored so we can guage the script's activity.
    managedWindows := Map()
    monitoredWindows := Map()
    for program, windows in windowList
    {
        managedWindows[program] := 0
        monitoredWindows[program] := 0

        for _, waitInfo in windows
        {
            if (waitInfo["type"] = "Timeout")
            {
                monitoredWindows[program] += 1
            }
            else if (waitInfo["type"] = "Interval")
            {
                managedWindows[program] += 1
            }
        }

        if (managedWindows[program] = 0)
        {
            managedWindows.Delete(program)
        }

        if (monitoredWindows[program] = 0)
        {
            monitoredWindows.Delete(program)
        }
    }

    ; If windows are being managed that means the script is periodically
    ; sending input. We update the SysTray to with the number of windows
    ; that are being managed.
    if (managedWindows.Count > 0)
    {
        TraySetIcon A_AhkPath, 2
        if (monitoredWindows.Count > 0)
        {
            newTip := "Managing:`n"
            for program, windows in managedWindows
            {
                newTip := newTip program " - " windows "`n"
            }
            newTip := newTip "`nMonitoring:`n"
            for program, windows in monitoredWindows
            {
                newTip := newTip program " - " windows "`n"
            }
            newTip := RTrim(newTip, "`n")
            A_IconTip := newTip
        }
        else
        {
            newTip := "Managing:`n"
            for program, windows in managedWindows
            {
                newTip := newTip program " - " windows "`n"
            }
            newTip := RTrim(newTip, "`n")
            A_IconTip := newTip
        }
        return
    }

    ; If we are not managing any windows but the script is still monitoring
    ; them in case they go inactive, the SysTray is updated with the number
    ; of windows that we are watching.
    if (monitoredWindows.Count > 0)
    {
        TraySetIcon A_AhkPath, 3
        newTip := "Monitoring:`n"
        for program, windows in monitoredWindows
        {
            newTip := newTip program " - " windows "`n"
        }
        newTip := RTrim(newTip, "`n")
        A_IconTip := newTip
        return
    }

    ; If we get to this point the script is not managing or watching any windows.
    ; Essensially the script isn't doing anything and we make sure the icon conveys
    ; this if it hasn't already.
    TraySetIcon A_AhkPath, 5
    A_IconTip := "No windows found"
}

; Iterate through each window in the list and decrement its timer.
; If the timer reaches zero the TASK function is ran and the timer is set back to its starting value.
tickWindowList(windowList)
{
    for program, windows in windowList
    {
        for handle, timeLeft in windows
        {
            if (WinActive("ahk_id" handle))
            {
                ; If the program is active and has not timed out, we set its timeout back to
                ; the limit. The user will need to interact with it to send it to the back and
                ; we use A_TimeIdlePhysical rather then our own timeout if it's in the foreground.
                if (A_TimeIdlePhysical < getProgramAttribute("WINDOW_TIMEOUT", program) * 60000)
                {
                    timeLeft := Map(
                        "type",
                        "Timeout",
                        "value",
                        getTotalIterationCount(getProgramAttribute("WINDOW_TIMEOUT", program))
                    )

                    windowList[program][handle] := timeLeft
                    continue
                }

                ; If the program has timed out we need to update the WindowList to reflect that.
                ; We can achieve this by setting the time left to one. It will be decremented immediately
                ; afterwards and the script will activate as it sees the time left has reached zero.
                if (timeLeft["type"] = "Timeout")
                {
                    timeLeft["value"] = 1
                }
            }

            ; Decrement the time left, if it reaches zero reset the AFK timer. Then reset the time
            ; left and repeat.
            timeLeft["value"] -= 1

            if (timeLeft["value"] = 0)
            {
                timeLeft := Map(
                    "type",
                    "Interval",
                    "value",
                    getTotalIterationCount(getProgramAttribute("TASK_INTERVAL", program))
                )

                resetTimer(
                    handle,
                    getProgramAttribute("TASK", program),
                    getProgramAttribute("BLOCK_INPUT", program))
            }

            windowList[program][handle] := timeLeft
        }
    }

    return windowList
}

updateScript()
{
    global windowList
    global BLOCK_INPUT
    global PROCESS_LIST
    global PROCESS_OVERRIDES

    windowList := updateWindowList(windowList, PROCESS_LIST)
    windowList := tickWindowList(windowList)

    updateSysTray(windowList)
}

; Start Anti-AFK
updateScript()
SetTimer(updateScript, POLL_INTERVAL * 1000)
