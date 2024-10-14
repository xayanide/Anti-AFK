; --------------------
; Configuration
; --------------------

global config := Map()

; POLL_INTERVAL (Seconds):
;   This is the interval which Anti-AFK checks for new windows and calculates
;   how much time is left before exisiting windows become inactve.
config["POLL_INTERVAL"] := 5

; WINDOW_TIMEOUT (Minutes):
;   This is the amount of time before a window is considered inactive. After
;   a window has timed out, Anti-AFK will start resetting any AFK timers.
config["WINDOW_TIMEOUT"] := 1

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
config["TASK_INTERVAL"] := 1

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
        "overrides", Map(
            "WINDOW_TIMEOUT", 1,
            "TASK_INTERVAL", 1,
            "IS_INPUT_BLOCK", false,
            "TASK", () => (
                Send("1")
            )
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

global states := Map(
    "Processes", Map(),
    "MonitoredWindows", Map(),
    "ManagedWindows", Map()
)

requestElevation()
{
    ; Admin already, do nothing
    if (A_IsAdmin)
    {
        return
    }
    isAdminRequire := config.Get("IS_INPUT_BLOCK")
    for , process in config.Get("PROCESS_OVERRIDES")
    {
        overrides := process.Get("overrides")
        if (overrides.Has("IS_INPUT_BLOCK") && overrides["IS_INPUT_BLOCK"])
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

createProcesses()
{
    for , process_name in config.get("PROCESSES")
    {
        process := states.Get("Processes").Set(process_name, Map()).Get(process_name)
        process.Set("windows", Map())
    }
}

performWindowTask(windowId, invokeTask, isInputBlock)
{
    
    activeWindow := "A"
    activeInfo := retrieveWindowInfo(activeWindow)
    targetInfo := retrieveWindowInfo("ahk_id " windowId)
    targetWindow := "ahk_id " targetInfo["ID"]
    OutputDebug("[" A_Now "] [" targetWindow "] @performWindowTask: Starting task ")
    oldActiveWindow := getWindow(
        activeInfo["ID"],
        activeInfo["PID"],
        activeInfo["EXE"],
        targetWindow
    )
    isTargetActivateSuccess := false
    try
    {
        OutputDebug("[" A_Now "] Active Window INFO : [CLS:" activeInfo["CLS"] "] [ID:" activeInfo["ID"] "] [PID:" activeInfo["PID"] "] [EXE:" activeInfo["EXE"] "] [Window:" oldActiveWindow "]")
        OutputDebug("[" A_Now "] Target Window INFO : [CLS:" targetInfo["CLS"] "] [ID:" targetInfo["ID"] "] [PID:" targetInfo["PID"] "] [EXE:" targetInfo["EXE"] "] [Window:" targetWindow "]")

        ; Issues:
        ; When the user quickly switches between specified process' windows, the script might still poll and decrements one of their timer. The supposed behavior is to reset the polls
        ; For CoreWindows, if these are the active windows. No other windows can be activated, the taskbar icons will flash.
        ; Not even #WinActivateForce directive can mitigate this issue, still finding a solution for this, i.e, Open the clock in Windows 10, SearchApp.exe or Notifications then wait for the window timers to perform their task.
        ; Another different issue similar to this for example like notepad.exe, if you open another Window within the same process notepad.exe. The script prior to my changes is struggling to handle it. WinWaitActive gets stuck.
        ; There are tooltips when you hover over Category buttons in wordpad.exe, those are also read as windows and get added as windows to the process windows list,
        ; they are retained there indefinitely (those created window maps) which means they're unhandled once the process' window is closed by the user, those should be cleaned up dynamically.
        ; Certain windows that appear within the same process like notepad.exe's "Save as" "Save" windows, once those are the active windows, the script is also unable to activate the main window properly.
        ; The change I implemented was only creating 1 window map for a process, if there are more windows for a certain process, it doesn't create any more maps for them, it's only a temporary workaround.
        ; There are also optimizations I implemented, like early continue and return clauses, and decluttering of variables and edge cases
        if (activeInfo["CLS"] = "Windows.UI.Core.CoreWindow")
        {
            OutputDebug("[" A_Now "] [" oldActiveWindow "] Active Window is Windows.UI.Core.CoreWindow!")
        }
        ; Activates the target window if there is no active window or the Desktop is focused.
        ; Bringing the Desktop window to the front can cause some scaling issues, so we ignore it.
        ; The Desktop's window has a class of "WorkerW" or "Progman"
        if (!activeInfo.Count || (activeInfo["CLS"] = "WorkerW" || activeInfo["CLS"] = "Progman"))
        {
            OutputDebug("[" A_Now "] [" oldActiveWindow "] Active Window is Desktop! Force activating target window...")
            activateWindow(targetWindow)
        }
        ; Perform the task directly if the target window is already active.
        if (WinActive(targetWindow))
        {
            invokeTask()
            OutputDebug("[" A_Now "] [" targetWindow "] Active Target Window successfully performed its task!")
            return
        }
        blockUserInput("On", isInputBlock)
        OutputDebug("[" A_Now "] [" targetWindow "] Inactive Target Window setting transparency to 0...")
        WinSetTransparent(0, targetWindow)
        isTargetActivateSuccess := activateWindow(targetWindow)
        if (WinActive(oldActiveWindow) || !isTargetActivateSuccess)
        {
            OutputDebug("[" A_Now "] [" targetWindow "] Inactive Target Window failed to perform its task as user is still on old window or the window failed to activate!")
            WinMoveBottom(targetWindow)
            WinSetTransparent("Off", targetWindow)
            return
        }
        invokeTask()
        OutputDebug("[" A_Now "] [" targetWindow "] Inactive Target Window successfully performed its task!")
        ; There is a condition in the try clause above that checks if the target window is active already. If I move this in the finally clause,
        ; it will bring the active target window to the bottom which isn't the intended behavior
        WinMoveBottom(targetWindow)
    }
    catch as e
    {
        MsgBox("@performWindowTask: Encountered error:`n" e.Message "`n" e.Stack "", , "OK Icon!")
    }
    finally
    {
        ; These serve as fail saves. I don't want to put them in the try clause because if something goes wrong and gets stuck, the windows should operate fine at the end
        ; and not get caught in the hang
        if (WinGetTransparent(targetWindow) = 0)
        {
            OutputDebug("[" A_Now "] [" targetWindow "] Inactive Target Window setting transparency to Off...")
            WinSetTransparent("Off", targetWindow)
        }
        if (!WinActive(oldActiveWindow))
        {
            activateWindow(oldActiveWindow)
        }
        blockUserInput("Off", isInputBlock)
        OutputDebug("[" A_Now "] [" targetWindow "] @performWindowTask: Finished task")
    }
}

blockUserInput(option, isInputBlock)
{
    if (!isInputBlock || !A_IsAdmin)
    {
        return
    }
    OutputDebug("[" A_Now "] @blockUserInput: Successfully BlockInput " option "")
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
        OutputDebug("[" A_Now "] [" window "] Window does not exist! Failed to retrieve info!")
        return windowInfo
    }
    windowInfo := Map(
        "ID", WinGetID(window),
        "CLS", WinGetClass(window),
        "PID", WinGetPID(window),
        "EXE", WinGetProcessName(window)
    )

    return windowInfo
}

activateWindow(window)
{
    if (!WinExist(window))
    {
        OutputDebug("[" A_Now "] [" window "] Window does not exist! Failed to activate!")
        return false
    }
    WinActivate(window)
    value := WinWaitActive(window, , 0.1)
    if (value = 0)
    {
        OutputDebug("[" A_Now "] [" window "] Window timed out! Failed to activate!")
        return false
    }
    OutputDebug("[" A_Now "] [" window "] Window successfully activated!")
    return true
}

; Calculate the number of polls it will take for the time (in seconds) to pass.
retrieveRemainingPolls(minutes)
{
    return Max(1, Round(minutes * 60 / config.Get("POLL_INTERVAL")))
}

; Find and return a specific attribute for a program, prioritising values in PROCESS_OVERRIDES.
; If an override has not been setup for that process, the default value for all programs will be used instead.
getAttributeValue(attributeName, process)
{
    processOverrides := config.Get("PROCESS_OVERRIDES")
    if (processOverrides.Has(process) && processOverrides[process].Has(attributeName))
    {
        return processOverrides[process][attributeName]
    }

    return config.Get(attributeName)
}

updateSystemTray()
{
    ; Count managed and monitored windows
    monitoredWindows := states.Get("MonitoredWindows")
    managedWindows := states.Get("ManagedWindows")
    processes := states.Get("Processes")
    for process_name, in processes
    {
        windows := processes.Get(process_name).Get("windows")
        monitoredCount := monitoredWindows.Set(process_name, 0).Get(process_name)
        managedCount := managedWindows.Set(process_name, 0).Get(process_name)
        for , window in windows
        {
            windowStatus := window.Get("status")
            if (windowStatus = "MonitoringStatus")
            {
                monitoredCount += 1
            }
            else if (windowStatus = "ManagingStatus")
            {
                managedCount += 1
            }
        }

        if (monitoredCount = 0)
        {
            monitoredWindows.Delete(process_name)
        }

        if (managedCount = 0)
        {
            managedWindows.Delete(process_name)
        }
    }

    ; Managing windows
    if (managedWindows.Count > 0)
    {
        TraySetIcon(A_AhkPath, 2)
        ; Managing windows and monitoring windows
        if (monitoredWindows.Count > 0)
        {
            newTip := "Managing:`n"
            for process_name, windowsCount in managedWindows
            {
                newTip := newTip process_name " - " windowsCount "`n"
            }
            newTip := newTip "`nMonitoring:`n"

            for process_name, windowsCount in monitoredWindows
            {
                newTip := newTip process_name " - " windowsCount "`n"
            }
            newTip := RTrim(newTip, "`n")
            A_IconTip := newTip
            return
        }
        ; Managing only
        newTip := "Managing:`n"
        for process_name, windowsCount in managedWindows
        {
            newTip := newTip process_name " - " windowsCount "`n"
        }

        newTip := RTrim(newTip, "`n")
        A_IconTip := newTip
        return
    }

    ; Only monitoring windows
    if (monitoredWindows.Count > 0)
    {
        TraySetIcon(A_AhkPath, 3)

        newTip := "Monitoring:`n"
        for process_name, windowsCount in monitoredWindows
        {
            newTip := newTip process_name " - " windowsCount "`n"
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
    for , process_name in config.Get("PROCESSES")
    {
        windowIds := WinGetList("ahk_exe" process_name)
        if (!windowIds)
        {
            continue
        }
        pollsLeft := retrieveRemainingPolls(getAttributeValue("WINDOW_TIMEOUT", process_name))
        for , windowId in windowIds
        {
            windows := states.get("Processes").Get(process_name).Get("windows")
            ; Process specified doesn't have a window mpap yet
            if (!windows.Has(windowId))
            {
                ; Workaround for multiple windows on one process, skip creating windows that does not have anything to do with the main window
                if (windows.Count >= 1)
                {
                    continue
                }
                ; Create a window map with task timer for this process
                windows.Set(
                    windowId, Map(
                        "status", "MonitoringStatus",
                        "pollsLeft", pollsLeft
                    )
                )
                OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Created window for process")
            }
        }
    }
}

checkWindowTaskTimers()
{
    processes := states.Get("Processes")
    for process_name, in processes
    {
        windows := processes.Get(process_name).Get("windows")
        if (windows.Count <= 0)
        {
            continue
        }
        windowTimeoutMinutes := getAttributeValue("WINDOW_TIMEOUT", process_name)
        monitorPollsLeft := retrieveRemainingPolls(windowTimeoutMinutes)
        managingPollsLeft := retrieveRemainingPolls(getAttributeValue("TASK_INTERVAL", process_name))
        taskAction := getAttributeValue("TASK", process_name)
        isInputBlock := getAttributeValue("IS_INPUT_BLOCK", process_name)
        for windowId, window in windows
        {
            if (!WinExist("ahk_id" windowId))
            {
                OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Deleted window for process as window no longer exists!")
                windows.Delete(windowId)
                continue
            }
            if (WinActive("ahk_id" windowId))
            {
                if (A_TimeIdlePhysical < (windowTimeoutMinutes * 60000))
                {
                    OutputDebug("[" A_Now "] [Window ID: " windowId "] Active Target Window: Activity detected!")
                    window := Map(
                        "status", "MonitoringStatus",
                        "pollsLeft", monitorPollsLeft
                    )
                    windows.Set(windowId, window)
                    continue
                }
                OutputDebug("[" A_Now "] [Window ID: " windowId "] Active Target Window: Inactivity detected!")
                if (window["status"] = "MonitoringStatus")
                {
                    window["pollsLeft"] = 1
                }
            }
            window["pollsLeft"] -= 1
            OutputDebug("[" A_Now "] [Window ID: " windowId "] Inactive Target Window: " window["pollsLeft"] " polls remaining ")
            if (window["pollsLeft"] <= 0)
            {
                window := Map(
                    "status", "ManagingStatus",
                    "pollsLeft", managingPollsLeft
                )
                performWindowTask(windowId, taskAction, isInputBlock)
            }
            windows.Set(windowId, window)
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
createProcesses()
; Initiate the first poll
poll()
; Poll again according to what's configured as its interval
SetTimer(poll, config.Get("POLL_INTERVAL") * 1000)
