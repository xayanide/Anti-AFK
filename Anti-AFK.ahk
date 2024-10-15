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
config["WINDOW_TIMEOUT"] := 10

; TASK (Function):
;   This is a function that will be ran by the script in order to reset any
;   AFK timers. The target window will have focus while it is being executed.
;   You can customise this function freely - just make sure it resets the timer.
config["TASK"] := () => (
    Send("{Space Down}")
    Sleep(1)
    Send("{Space Up}"))

; TASK_INTERVAL (Minutes):
;   This is the amount of time the script will wait after calling the TASK function
;   before calling it again.
config["TASK_INTERVAL"] := 10

; IS_INPUT_BLOCK (Boolean):
;   This tells the script whether you want to block input whilst it shuffles
;   windows and sends input. This requires administrator permissions and is
;   therefore disabled by default. If input is not blocked, keystrokes from the
;   user may 'leak' into the window while Anti-AFK moves it into focus.
config["IS_INPUT_BLOCK"] := false

; MONITOR_LIST (Array):
;   This is a list of processes that Anti-AFK will montior. Any windows that do
;   not belong to any of these processes will be ignored.
config["MONITOR_LIST"] := [
    "RobloxPlayerBeta.exe",
    "notepad.exe",
    "wordpad.exe"]

; PROCESS_OVERRIDES (Associative Array):
;   This allows you to specify specific values of WINDOW_TIMEOUT, TASK_INTERVAL,
;   TASK and IS_INPUT_BLOCK for specific processes. This is helpful if different
;   games consider you AFK at wildly different times, or if the function to
;   reset the AFK timer does not work as well across different applications.
config["MONITOR_OVERRIDES"] := Map(
    "wordpad.exe", Map(
        "overrides", Map(
            "WINDOW_TIMEOUT", 0.18,
            "TASK_INTERVAL", 0.18,
            "IS_INPUT_BLOCK", false,
            "TASK", () => (
                Send("1")))),
    "notepad.exe", Map(
        "overrides", Map(
            "WINDOW_TIMEOUT", 0.18,
            "TASK_INTERVAL", 0.18,
            "IS_INPUT_BLOCK", false,
            "TASK", () => (
                Send("1")))))

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
    "ManagedWindows", Map(),
    "lastIconNumber", 0,
    "lastIconTooltipText", ""
)

requestElevation()
{
    ; Admin already, do nothing
    if (A_IsAdmin)
    {
        return
    }
    isAdminRequire := config["IS_INPUT_BLOCK"]
    for , process in config["MONITOR_OVERRIDES"]
    {
        overrides := process["overrides"]
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

createProcessesAndWindowsMap()
{
    for , process_name in config["MONITOR_LIST"]
    {
        states["Processes"][process_name] := Map(
            "windows", Map())
    }
}

performWindowTask(windowId, invokeTask, isInputBlock)
{
    activeWindow := "A"
    targetInfo := getWindowInfo("ahk_id " windowId)
    OutputDebug("[" A_Now "] [" targetInfo["EXE"] "] [Window ID: " targetInfo["ID"] "] @performWindowTask: Starting operations...")
    targetWindow := "ahk_id " targetInfo["ID"]
    OutputDebug("[" A_Now "] Target Window INFO : [CLS:" targetInfo["CLS"] "] [ID:" targetInfo["ID"] "] [PID:" targetInfo["PID"] "] [EXE:" targetInfo["EXE"] "] [Window:" targetWindow "]")
    ; Perform the task directly if the target window is already active.
    if (WinActive(targetWindow))
    {
        invokeTask()
        OutputDebug("[" A_Now "] [" targetInfo["EXE"] "] [Window ID: " targetInfo["ID"] "] Active Target Window task successful!")
        OutputDebug("[" A_Now "] [" targetInfo["EXE"] "] [Window ID: " targetInfo["ID"] "] @performWindowTask: Finished operations")
        return
    }
    activeInfo := getWindowInfo(activeWindow)
    oldActiveWindow := getWindow(
        activeInfo,
        targetWindow
    )
    isTargetActivateSuccess := false
    ; Target window is not active, try to activate it then perform the task after that.
    try
    {
        ; Activates the target window if there is no active window or the Desktop is focused.
        ; Bringing the Desktop window to the front can cause some scaling issues, so we ignore it.
        ; The Desktop's window has a class of "WorkerW" or "Progman"
        if (!activeInfo.Count || (activeInfo["CLS"] = "WorkerW" || activeInfo["CLS"] = "Progman"))
        {
            WinSetTransparent(0, targetWindow)
            isTargetActivateSuccess := activateWindow(targetWindow)
            invokeTask()
            WinMoveBottom(targetWindow)
            return
        }

        OutputDebug("[" A_Now "] Active Window INFO : [CLS:" activeInfo["CLS"] "] [ID:" activeInfo["ID"] "] [PID:" activeInfo["PID"] "] [EXE:" activeInfo["EXE"] "[Window:" oldActiveWindow "]")
        ; Issues:
        ; When the user quickly switches between specified process' windows, the script might still poll and decrements one of their timer. The supposed behavior is to reset the polls
        ; For CoreWindows, if these are the active windows. No other windows can be activated, the taskbar icons of the target windows will flash orange.
        ; Not even #WinActivateForce directive can mitigate this issue, still finding a solution for this, i.e, Open the clock (Date and time information) in Windows 10, SearchApp.exe or Notifications / Action Center then wait for the window timers to perform their task.
        ; Another different issue similar to this for example like notepad.exe, if you open another Window within the same process notepad.exe. The script prior to my changes is struggling to handle it. WinWaitActive gets stuck.
        ; There are tooltips when you hover over Category buttons in wordpad.exe, those are also read as windows and get added as windows to the process windows list,
        ; they are retained there indefinitely (those created window maps) which means they're unhandled once the process' window is closed by the user, those should be cleaned up dynamically.
        ; Certain windows that appear within the same process like notepad.exe's "Save as" "Save" windows, once those are the active windows, the script is also unable to activate the main window properly.
        ; The change I implemented was only creating 1 window map for a process, if there are more windows for a certain process, it doesn't create any more maps for them, it's only a temporary workaround.
        ; There are also optimizations I implemented, like early continue and return clauses, and decluttering of variables and edge cases
        ; Also there was a weird behavior on relaunching as admin. Debug console in VS Code refuses to work after the launch as admin UAC

        ; https://www.autohotkey.com/docs/v2/FAQ.htm#uac
        ; Solution: For this script to be able to activate other windows while active on a CoreWindow, "Run with UI Access" this script. Run as admin will not work as a solution.
        ; Alt Tabbing is another solution.
        if (activeInfo["CLS"] = "Windows.UI.Core.CoreWindow")
        {
            OutputDebug("[" A_Now "] [" activeInfo["EXE"] "] [Window ID: " activeInfo["ID"] "] Active Window is Windows.UI.Core.CoreWindow!")
            ; Todo: Add a check here if the script is ran with ui access to bypass this work around.
            Send("{Alt Down}{Tab Up}{Tab Down}")
            Sleep(500)
            Send("{Alt Up}")
            MsgBox("For the script to perform its operations properly, the script has Alt+Tabbed you out from the active window.`nBeing active on a window with a class name of Windows.UI.Core.CoreWindow can hinder the script from activating the monitored process' target window.`nThis pop-up box will automatically close itself in 30 seconds.", , "OK Icon! T30")
        }

        blockUserInput("On", isInputBlock)
        WinSetTransparent(0, targetWindow)
        isTargetActivateSuccess := activateWindow(targetWindow)
        ; The active window at this point should be the target window, not the old one.
        ; If it is still the old active window, cancel the task
        if (WinActive(oldActiveWindow) || !isTargetActivateSuccess)
        {
            OutputDebug("[" A_Now "] [" targetInfo["EXE"] "] [Window ID: " targetInfo["ID"] "] isOldWindow? " WinActive(oldActiveWindow) ? "Yes" : "No" ", isActivateSuccess? " isTargetActivateSuccess "")
            OutputDebug("[" A_Now "] [" targetInfo["EXE"] "] [Window ID: " targetInfo["ID"] "] Inactive Target Window invokeTask() failed (canceled)")
            WinSetTransparent("Off", targetWindow)
            return
        }
        invokeTask()
        OutputDebug("[" A_Now "] [" targetInfo["EXE"] "] [Window ID: " targetInfo["ID"] "] Inactive Target Window task successful!")
        ; There is a condition in the try clause above that checks if the target window is active already. If I move this in the finally clause,
        ; it will bring the active target window to the bottom which isn't the intended behavior
        WinMoveBottom(targetWindow)
    }
    finally
    {
        ; These serve as fail saves. I don't want to put them in the try clause because if something goes wrong and gets stuck, the windows should operate fine at the end
        ; and not get caught in the hang
        if (WinGetTransparent(targetWindow) = 0)
        {
            WinSetTransparent("Off", targetWindow)
        }
        if (!WinActive(oldActiveWindow))
        {
            activateWindow(oldActiveWindow)
        }
        blockUserInput("Off", isInputBlock)
        OutputDebug("[" A_Now "] [" targetInfo["EXE"] "] [Window ID: " targetInfo["ID"] "] @performWindowTask#finally: Finished operations")
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
getWindow(windowInfo, fallbackWindow)
{
    if (windowInfo.Count < 1)
    {
        return fallbackWindow
    }
    windowId := "ahk_id " windowInfo["ID"]
    process_id := "ahk_pid " windowInfo["PID"]
    process_name := "ahk_exe " windowInfo["EXE"]

    if (WinExist(windowId))
    {
        return windowId
    }

    if (WinExist(process_id))
    {
        return process_id
    }

    if (WinExist(process_name))
    {
        return process_name
    }
    return fallbackWindow
}

; Get information about a window so that it can be found and reactivated later.
getWindowInfo(window)
{
    windowInfo := Map()

    if (!WinExist(window))
    {
        OutputDebug("[" A_Now "] [" window "] Failed to get info! Window does not exist! ")
        return windowInfo
    }

    windowInfo := Map(
        "ID", WinGetID(window),
        "CLS", WinGetClass(window),
        "PID", WinGetPID(window),
        "EXE", WinGetProcessName(window))

    return windowInfo
}

activateWindow(window)
{
    if (!WinExist(window))
    {
        OutputDebug("[" A_Now "] [" window "] Failed to activate! Window does not exist! ")
        return false
    }
    if (!isTargetableWindow(WinExist(window)))
    {
        OutputDebug("[" A_Now "] [" window "] Failed to activate! Window is not targetable!")
        return false
    }
    WinActivate(window)
    value := WinWaitActive(window)
    if (value = 0)
    {
        OutputDebug("[" A_Now "] [" window "] Failed to activate! Window timed out! ")
        return false
    }
    OutputDebug("[" A_Now "] [" window "] Window successfully activated!")
    return true
}

; Calculate the number of polls it will take for the time (in seconds) to pass.
getTotalPolls(minutes)
{
    return Max(1, Round(minutes * 60 / config["POLL_INTERVAL"]))
}

; Find and return a specific attribute for a program, prioritising values in PROCESS_OVERRIDES.
; If an override has not been setup for that process, the default value for all programs will be used instead.
getAttributeValue(attributeName, process_name)
{
    monitorOverrides := config["MONITOR_OVERRIDES"]
    if (monitorOverrides.Has(process_name))
    {
        if (monitorOverrides[process_name]["overrides"].Has(attributeName))
        {
            return monitorOverrides[process_name]["overrides"][attributeName]
        }
    }
    return config[attributeName]
}

updateSystemTray(processes)
{
    monitoredWindows := states["MonitoredWindows"]
    managedWindows := states["ManagedWindows"]
    ; Initialize counts for each process
    for process_name, process in processes
    {
        windows := process["windows"]
        if (windows.Count > 0)
        {
            monitoredWindows[process_name] := 0
            managedWindows[process_name] := 0
            ; Iterate over the windows of the process
            ; Count managed and monitored windows
            for , window in windows
            {
                windowStatus := window["status"]
                if (windowStatus = "MonitoringStatus")
                {
                    monitoredWindows[process_name] += 1
                }
                else if (windowStatus = "ManagingStatus")
                {
                    managedWindows[process_name] += 1
                }
            }

            ; Remove entries with zero windows
            if (monitoredWindows[process_name] = 0)
            {
                monitoredWindows.Delete(process_name)
            }
            if (managedWindows[process_name] = 0)
            {
                managedWindows.Delete(process_name)
            }
        }
    }

    ; Determine the appropriate icon and tooltip
    ; Managing windows
    if (managedWindows.Count > 0)
    {
        iconNumber := 2
        ; Managing and Monitoring
        if (monitoredWindows.Count > 0)
        {
            tooltipText := "Managing:`n"
            for process_name, windowsCount in managedWindows
            {
                tooltipText .= process_name " - " windowsCount "`n"
            }

            tooltipText .= "`nMonitoring:`n"
            for process_name, windowsCount in monitoredWindows
            {
                tooltipText .= process_name " - " windowsCount "`n"
            }

            tooltipText := RTrim(tooltipText, "`n")
        }
        ; Managing only
        else
        {
            tooltipText := "Managing:`n"
            for process_name, windowsCount in managedWindows
            {
                tooltipText .= process_name " - " windowsCount "`n"
            }

            tooltipText := RTrim(tooltipText, "`n")
        }
    }
    ; Monitoring only
    else if (monitoredWindows.Count > 0)
    {
        iconNumber := 3
        tooltipText := "Monitoring:`n"
        for process_name, windowsCount in monitoredWindows
        {
            tooltipText .= process_name " - " windowsCount "`n"
        }

        tooltipText := RTrim(tooltipText, "`n")
    }
    ; Neither managing nor monitoring
    else
    {
        iconNumber := 5
        tooltipText := "No windows found"
    }

    ; Update the tray icon only if it has changed
    if (iconNumber != states["lastIconNumber"])
    {
        TraySetIcon(A_AhkPath, iconNumber)
        states["lastIconNumber"] := iconNumber
    }

    ; Update the tooltip only if it has changed
    if (tooltipText != states["lastIconTooltipText"])
    {
        A_IconTip := tooltipText
        states["lastIconTooltip"] := tooltipText
    }
}

registerWindowIds(windows, windowIds, process_name)
{
    if (windowIds.Length < 1)
    {
        return windows
    }
    pollsLeft := getTotalPolls(getAttributeValue("WINDOW_TIMEOUT", process_name))
    for , windowId in windowIds
    {
        if (!isTargetableWindow(WinExist("ahk_id " windowId)))
        {
            ; OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Ignored window for process as it cannot be targeted!")
            continue
        }
        if (windows.Has(windowId))
        {
            continue
        }
        ; In this process' windows map, set a map for this window id
        windows[windowId] := Map(
            "status", "MonitoringStatus",
            "pollsLeft", pollsLeft
        )
        OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Created window for process")
    }
    return windows
}

; Checks if a window is targetable
; tysm! https://stackoverflow.com/questions/35971452/what-is-the-right-way-to-send-alt-tab-in-ahk/36008086#36008086
; It is missing ignoring windows that are like Save and Save as
isTargetableWindow(HWND)
{
    ; https://www.autohotkey.com/docs/v2/misc/Styles.htm
    windowStyle := WinGetStyle("ahk_id " HWND)
    ; Windows with the WS_POPUP style (0x80000000)
    if (windowStyle & 0x80000000)
    {
        ; OutputDebug("[" A_Now "] " HWND " is not targetable due to 0x80000000")
        return false
    }
    ; Windows with the WS_DISABLED style (0x08000000)
    ; These windows are disabled and not interactive (grayed-out windows)
    if (windowStyle & 0x08000000)
    {
        ; OutputDebug("[" A_Now "] " HWND " is not targetable due to 0x08000000")
        return false
    }
    ; Windows that do not have the WS_VISIBLE style (0x10000000)
    ; These are invisible windows, not suitable for interaction
    if (!windowStyle & 0x10000000)
    {
        ; OutputDebug("[" A_Now "] " HWND " is not targetable due to 0x10000000")
        return false
    }
    windowExtendedStyle := WinGetExStyle("ahk_id " HWND)
    ; Windows with WS_EX_TOOLWINDOW (0x00000080)
    ; https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
    ; Tool windows are often small floating windows (like toolbars) and are usually not primary windows
    if (windowExtendedStyle & 0x00000080)
    {
        ; OutputDebug("[" A_Now "] " HWND " is not targetable due to 0x00000080")
        return false
    }
    cls := WinGetClass("ahk_id " HWND)
    ; Windows with the class "TApplication"
    ; These are often Delphi or VCL-based windows, typically representing non-primary windows
    if (cls = "TApplication")
    {
        ; OutputDebug("[" A_Now "] " HWND " is not targetable due to " cls "")
        return false
    }
    ; Common class for dialog boxes or dialog windows
    ; https://learn.microsoft.com/en-us/windows/win32/winmsg/about-window-classes
    ; Windows with the class "#32770"
    ; This class represents dialog boxes, such as 'Open' or 'Save As' dialogs
    if (cls = "#32770")
    {
        ; OutputDebug("[" A_Now "] " HWND " is not targetable because it is a dialog window")
        return false
    }
    ; Windows with the class "ComboLBox"
    ; This class represents the dropdown list portion of a combo box
    ; These are not standalone windows and are part of other UI elements
    if (cls = "ComboLBox")
    {
        ; OutputDebug("[" A_Now "] " HWND " is not targetable because it is a dialog window")
        return false
    }
    ; Windows with the class "Windows.UI.Core.CoreWindow"
    ; The action center, date and time info, searching feature of Windows' start menu all belongs to this class.
    ; These should not be interacted by the script in any way
    if (cls = "Windows.UI.Core.CoreWindow")
    {
        return false
    }
    return true
}

monitorWindows(windows, process_name)
{
    windowTimeoutMinutes := getAttributeValue("WINDOW_TIMEOUT", process_name)
    windowTotalPolls := getTotalPolls(windowTimeoutMinutes)
    intervalTotalPolls := getTotalPolls(getAttributeValue("TASK_INTERVAL", process_name))
    invokeTask := getAttributeValue("TASK", process_name)
    isInputBlock := getAttributeValue("IS_INPUT_BLOCK", process_name)
    for windowId, window in windows
    {
        if (!WinExist("ahk_id " windowId))
        {
            OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Deleted window for process as it was closed by the user!")
            windows.Delete(windowId)
            continue
        }
        if (WinActive("ahk_id " windowId))
        {
            if (A_TimeIdlePhysical < (windowTimeoutMinutes * 60000))
            {
                OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Active Target Window: Activity detected! Polls reset!")
                window := Map(
                    "status", "MonitoringStatus",
                    "pollsLeft", windowTotalPolls
                )
                windows[windowId] := window
                continue
            }
            OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Active Target Window: Inactivity detected! Polling...")
            if (window["status"] = "MonitoringStatus")
            {
                window["pollsLeft"] := 1
            }
        }
        window["pollsLeft"] -= 1
        OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Target Window: " window["pollsLeft"] " polls remaining")
        if (window["pollsLeft"] < 1)
        {
            window := Map(
                "status", "ManagingStatus",
                "pollsLeft", intervalTotalPolls
            )
            performWindowTask(windowId, invokeTask, isInputBlock)
        }
        windows[windowId] := window
    }
}

monitorProcesses()
{
    processes := states["Processes"]
    if (processes.Count > 0)
    {
        for process_name, process in processes
        {
            windows := registerWindowIds(process["windows"], WinGetList("ahk_exe " process_name), process_name)
            if (windows.Count > 0)
            {
                monitorWindows(windows, process_name)
            }
            ; Poll again according to what's configured as its interval
            SetTimer(monitorProcesses, config["POLL_INTERVAL"] * 1000)
        }
    }
    updateSystemTray(processes)
}

requestElevation()
; Do not include this function in the polling function. The maps should only be set once.
createProcessesAndWindowsMap()
; Initiate the first poll
monitorProcesses()
