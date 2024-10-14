; --------------------
; Configuration
; --------------------

global config := Map()

; POLL_INTERVAL (Seconds):
;   This is the interval which Anti-AFK checks for new windows and calculates
;   how much time is left before exisiting windows become inactve.
config["POLL_INTERVAL"] := 1

; WINDOW_TIMEOUT (Minutes):
;   This is the amount of time before a window is considered inactive. After
;   a window has timed out, Anti-AFK will start resetting any AFK timers.
config["WINDOW_TIMEOUT"] := 0.18

; TASK (Function):
;   This is a function that will be ran by the script in order to reset any
;   AFK timers. The target window will have focus while it is being executed.
;   You can customise this function freely - just make sure it resets the timer.
config["TASK"] := () => (
    ; Send("{Space Down}")
    ; Sleep(1)
    ; Send("{Space Up}")
    Send("1")
)

; TASK_INTERVAL (Minutes):
;   This is the amount of time the script will wait after calling the TASK function
;   before calling it again.
config["TASK_INTERVAL"] := 0.18

; IS_INPUT_BLOCK (Boolean):
;   This tells the script whether you want to block input whilst it shuffles
;   windows and sends input. This requires administrator permissions and is
;   therefore disabled by default. If input is not blocked, keystrokes from the
;   user may 'leak' into the window while Anti-AFK moves it into focus.
config["IS_INPUT_BLOCK"] := false

; PROCESSES (Array):
;   This is a list of processes that Anti-AFK will montior. Any windows that do
;   not belong to any of these processes will be ignored.
config["PROCESSES"] := [
    "RobloxPlayerBeta.exe",
    "notepad.exe",
    "wordpad.exe"
]

; PROCESS_OVERRIDES (Associative Array):
;   This allows you to specify specific values of WINDOW_TIMEOUT, TASK_INTERVAL,
;   TASK and IS_INPUT_BLOCK for specific processes. This is helpful if different
;   games consider you AFK at wildly different times, or if the function to
;   reset the AFK timer does not work as well across different applications.
config["PROCESS_OVERRIDES"] := Map(
    "wordpad.exe", Map(
        "WINDOW_TIMEOUT", 0.18,
        "TASK_INTERVAL", 0.18,
        "IS_INPUT_BLOCK", false,
        "TASK", () => (
            Send("1")
        )
    )
)

; --------------------
; Script
; --------------------
#Requires AutoHotkey v2.0
#SingleInstance
#Warn

InstallKeybdHook()
InstallMouseHook()
KeyHistory(0)

global states := Map()
states["ProcessList"] := Map()
states["MonitoredWindows"] := Map()
states["ManagedWindows"] := Map()

requestElevation()
{
    ; Admin already, do nothing
    if (A_IsAdmin)
    {
        return
    }
    isAdminRequire := config["IS_INPUT_BLOCK"]
    for process, attributes in config["PROCESS_OVERRIDES"]
    {
        if (attributes.Has("IS_INPUT_BLOCK") && attributes["IS_INPUT_BLOCK"])
        {
            isAdminRequire := true
        }
    }
    ; Admin not required
    if (!isAdminRequire)
    {
        return
    }
    try
    {
        if (A_IsCompiled)
        {
            RunWait('*RunAs "' A_ScriptFullPath '" /restart')
        }
        else
        {
            RunWait('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        }
    }
    MsgBox("This requires Anti-AFK to be ran as administrator to block inputs!`nBLOCK_INPUT has been temporarily disabled.",
        "Unable to block keystrokes",
        "OK Icon!"
    )
}

createProcessList()
{
    for , process in config["PROCESSES"]
    {
        states["ProcessList"][process] := Map()
    }
}

performWindowTask(windowId, invokeTask, isInputBlock)
{
    OutputDebug("" A_Now " @performWindowTask: Started")
    activeWindow := "A"
    activeInfo := retrieveWindowInfo(activeWindow)
    targetInfo := retrieveWindowInfo("ahk_id " windowId)
    targetWindow := "ahk_id " targetInfo["ID"]
    oldActiveWindow := getWindow(
        activeInfo["ID"],
        activeInfo["PID"],
        activeInfo["EXE"],
        targetWindow
    )
    try
    {
        OutputDebug("" A_Now " Active Window INFO : [CLS:" activeInfo["CLS"] "] [ID:" activeInfo["ID"] "] [PID:" activeInfo["PID"] "] [EXE:" activeInfo["EXE"] "] [Window:" oldActiveWindow "]")
        OutputDebug("" A_Now " Target Window INFO : [CLS:" targetInfo["CLS"] "] [ID:" targetInfo["ID"] "] [PID:" targetInfo["PID"] "] [EXE:" targetInfo["EXE"] "] [Window:" targetWindow "]")

        ; Activates the target window if there is no active window or the Desktop is focused.
        ; Bringing the Desktop window to the front can cause some scaling issues, so we ignore it.
        ; The Desktop's window has a class of "WorkerW" or "Progman"
        ; Handles no window / explorer.exe / Desktop /
        if (activeInfo["CLS"] = "Windows.UI.Core.CoreWindow")
        {
            OutputDebug("" A_Now " Active Window [" oldActiveWindow "] is Windows.UI.Core.CoreWindow!")
        }
        if (!activeInfo.Count || (activeInfo["CLS"] = "WorkerW" || activeInfo["CLS"] = "Progman"))
        {
            OutputDebug("" A_Now " Active Window [" oldActiveWindow "] is Desktop! Force activating target window...")
            activateWindow(targetWindow)
        }
        ; Perform action directly if the target window is already active.
        if (WinActive(targetWindow))
        {
            invokeTask()
            OutputDebug("" A_Now " Active Target Window [" targetWindow "] successfully performed its task!")
            return
        }
        blockUserInput("On", isInputBlock)
        OutputDebug("" A_Now " Inactive Target Window [" targetWindow "] Setting transparency as 0...")
        WinSetTransparent(0, targetWindow)
        isActivateSuccess := activateWindow(targetWindow)
        if (WinActive(oldActiveWindow) || !isActivateSuccess)
        {
            OutputDebug("" A_Now " Inactive Target Window [" targetWindow "] failed to perform its task as user is still on old window or the window failed to activate!")
            WinMoveBottom(targetWindow)
            WinSetTransparent("Off", targetWindow)
            return
        }
        invokeTask()
        OutputDebug("" A_Now " Inactive Target Window [" targetWindow "] successfully performed its task!")
        WinMoveBottom(targetWindow)
    }
    catch as e
    {
        MsgBox("@performWindowTask: Encountered error:`n" e.Message "", , "OK Icon!")
    }
    finally
    {
        if (WinGetTransparent(targetWindow) = 0)
        {
            OutputDebug("" A_Now " Inactive Target Window [" targetWindow "] Setting transparency as Off...")
            WinSetTransparent("Off", targetWindow)
        }
        if (!WinActive(oldActiveWindow))
        {
            OutputDebug("" A_Now " Old Window [" oldActiveWindow "] is not active! Activating...")
            activateWindow(oldActiveWindow)
        }
        blockUserInput("Off", isInputBlock)
        OutputDebug("" A_Now " @performWindowTask: Finished its operations")
    }
}

blockUserInput(option, isInputBlock)
{
    if (!isInputBlock || !A_IsAdmin)
    {
        return
    }
    OutputDebug("" A_Now " Successfully BlockInput " option "")
    BlockInput(option)
}

; Fetch the window which best matches the given criteria.
; Some windows are ephemeral and will be closed after user input. In this case we try
; increasingly vague identifiers until we find a related window. If a window is still
; not found a fallback is used instead.
getWindow(window_ID, process_ID, process_name, fallbackWindow)
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

    return fallbackWindow
}

; Retrieve information about a window so that it can be found and reactivated later.
retrieveWindowInfo(window)
{
    windowInfo := Map()

    if (!WinExist(window))
    {
        OutputDebug("" A_Now " Window [" window "] does not exist! Failed to retrieve its info!")
        return windowInfo
    }

    windowInfo["ID"] := WinGetID(window)
    windowInfo["CLS"] := WinGetClass(window)
    windowInfo["PID"] := WinGetPID(window)
    windowInfo["EXE"] := WinGetProcessName(window)

    return windowInfo
}

activateWindow(window)
{
    if (!WinExist(window))
    {
        OutputDebug("" A_Now " Window [" window "] does not exist! Unable to activate!")
        return false
    }
    WinActivate(window)
    value := WinWaitActive(window, , 0.25)
    if (value = 0)
    {
        OutputDebug("" A_Now " Window [" window "] failed to activate!")
        return false
    }
    OutputDebug("" A_Now " Window [" window "] activated!")
    return true
}

; Calculate the number of polls it will take for the time (in seconds) to pass.
retrieveRemainingPolls(minutes)
{
    return Max(1, Round(minutes * 60 / config["POLL_INTERVAL"]))
}

; Find and return a specific attribute for a program, prioritising values in PROCESS_OVERRIDES.
; If an override has not been setup for that process, the default value for all programs will be used instead.
getAttributeValue(attributeName, process)
{
    processOverrides := config["PROCESS_OVERRIDES"]
    if (processOverrides.Has(process) && processOverrides[process].Has(attributeName))
    {
        return processOverrides[process][attributeName]
    }

    return config[attributeName]
}

updateSystemTray()
{
    ; Count managed and monitored windows
    managed := states["ManagedWindows"]
    monitor := states["MonitoredWindows"]
    for process, windows in states["ProcessList"]
    {
        managed[process] := 0
        monitor[process] := 0

        for , window in windows
        {
            if (window["status"] = "MonitoringStatus")
            {
                monitor[process] += 1
            }
            else if (window["status"] = "ManagingStatus")
            {
                managed[process] += 1
            }
        }

        if (managed[process] = 0)
        {
            managed.Delete(process)
        }

        if (monitor[process] = 0)
        {
            monitor.Delete(process)
        }
    }

    ; Managing windows
    if (managed.Count > 0)
    {
        TraySetIcon(A_AhkPath, 2)
        ; Managing windows and monitoring windows
        if (monitor.Count > 0)
        {
            newTip := "Managing:`n"
            for process, windows in managed
            {
                newTip := newTip process " - " windows "`n"
            }
            newTip := newTip "`nMonitoring:`n"

            for process, windows in monitor
            {
                newTip := newTip process " - " windows "`n"
            }
            newTip := RTrim(newTip, "`n")
            A_IconTip := newTip
            return
        }
        ; Managing only
        newTip := "Managing:`n"
        for process, windows in managed
        {
            newTip := newTip process " - " windows "`n"
        }

        newTip := RTrim(newTip, "`n")
        A_IconTip := newTip
        return
    }

    ; Only monitoring windows
    if (monitor.Count > 0)
    {
        TraySetIcon(A_AhkPath, 3)

        newTip := "Monitoring:`n"
        for process, windows in monitor
        {
            newTip := newTip process " - " windows "`n"
        }
        newTip := RTrim(newTip, "`n")
        A_IconTip := newTip
        return
    }

    ; Not monitoring nor managing windows
    TraySetIcon(A_AhkPath, 5)
    A_IconTip := "No windows found"
}

generateWindowTimers()
{
    for , process in config["PROCESSES"]
    {
        pollsLeft := retrieveRemainingPolls(getAttributeValue("WINDOW_TIMEOUT", process))
        for , windowId in WinGetList("ahk_exe" process)
        {
            ; Process doesn't have a window task timer yet
            if (!states["ProcessList"][process].Has(windowId))
            {
                OutputDebug("" A_Now " Creating window task timer for process " process " [Window ID: " windowId "]...")
                ; Create a map for this process' window task timer
                states["ProcessList"][process][windowId] := Map(
                    "status", "MonitoringStatus",
                    "pollsLeft", pollsLeft
                )
            }
        }
    }
}

checkWindowTaskTimers()
{
    for process, windows in states["ProcessList"]
    {
        windowTimeoutMinutes := getAttributeValue("WINDOW_TIMEOUT", process)
        monitorPollsLeft := retrieveRemainingPolls(windowTimeoutMinutes)
        managingPollsLeft := retrieveRemainingPolls(getAttributeValue("TASK_INTERVAL", process))
        taskAction := getAttributeValue("TASK", process)
        isInputBlock := getAttributeValue("IS_INPUT_BLOCK", process)

        for windowId, window in windows
        {
            if (!WinExist("ahk_id" windowId))
            {
                OutputDebug("" A_Now " Process " process " Window doesn't exist anymore! (Deleted Window Task Timer) [Window ID: " windowId "]")
                states["ProcessList"][process].Delete(windowId)
                continue
            }
            if (WinActive("ahk_id" windowId))
            {
                if (A_TimeIdlePhysical < (windowTimeoutMinutes * 60000))
                {
                    OutputDebug("" A_Now " Active Target Window: Activity detected! [Window ID:" windowId "]")
                    window := Map(
                        "status", "MonitoringStatus",
                        "pollsLeft", monitorPollsLeft
                    )
                    states["ProcessList"][process][windowId] := window
                    continue
                }
                OutputDebug("" A_Now " Active Target Window: Inactivity detected! [Window ID:" windowId "]")
                if (window["status"] = "MonitoringStatus")
                {
                    window["pollsLeft"] = 1
                }
            }
            window["pollsLeft"] -= 1
            OutputDebug("" A_Now " Inactive Target Window: " window["pollsLeft"] " polls remaining " "[Window ID:" windowId "]")
            if (window["pollsLeft"] <= 0)
            {
                window := Map(
                    "status", "ManagingStatus",
                    "pollsLeft", managingPollsLeft
                )
                performWindowTask(windowId, taskAction, isInputBlock)
            }
            states["ProcessList"][process][windowId] := window
        }
    }
}

poll()
{
    generateWindowTimers()
    checkWindowTaskTimers()
    updateSystemTray()
}

requestElevation()
createProcessList()
; Initiate the first poll
poll()
; Poll again according to what's configured as its interval
SetTimer(poll, config["POLL_INTERVAL"] * 1000)
