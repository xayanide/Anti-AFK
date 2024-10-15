; --------------------
; Configuration
; --------------------

; TODO:

; Issues:
; When the user quickly switches between specified process' windows, the script might still poll and decrements one of their timer. The supposed behavior is to reset the polls
; PARTIALLY FIXED: For CoreWindows, if these are the active windows. No other windows can be activated, the taskbar icons of the target windows will flash orange.
; Not even #WinActivateForce directive can mitigate this issue, still finding a solution for this, i.e, Open the clock (Date and time information) in Windows 10, SearchApp.exe or Notifications / Action Center then wait for the window timers to perform their task.
; FIXED: Another different issue similar to this for example like notepad.exe, if you open another Window within the same process notepad.exe. The script prior to my changes is struggling to handle it. WinWaitActive gets stuck.
; FIXED: There are tooltips when you hover over Category buttons in wordpad.exe, those are also read as windows and get added as windows to the process windows list,
; they are retained there indefinitely (those created window maps) which means they're unhandled once the process' window is closed by the user, those should be cleaned up dynamically.
; FIXED: Certain windows that appear within the same process like notepad.exe's "Save as" "Save" windows, once those are the active windows, the script is also unable to activate the main window properly.
; WORKAROUND REMOVED: The change I implemented was only creating 1 window map for a process, if there are more windows for a certain process, it doesn't create any more maps for them, it's only a temporary workaround.
; There are also optimizations I implemented, like early continue and return clauses, and decluttering of variables and edge cases
; Also there was a weird behavior on relaunching as admin. Debug console in VS Code refuses to work after the launch as admin UAC

; https://www.autohotkey.com/docs/v2/FAQ.htm#uac
; Solution: For this script to be able to activate other windows while active on a CoreWindow, "Run with UI Access" this script. Run as admin will not work as a solution.
; Alt Tabbing is another solution.

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
    "wordpad.exe"
]

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
        if (process["overrides"].Has("IS_INPUT_BLOCK") && process["overrides"]["IS_INPUT_BLOCK"])
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

registerProcesses(processes, monitorlist)
{
    for , process_name in monitorlist
    {
        ; User does not have this process active from the monitor list, do not set
        if (!ProcessExist(process_name))
        {
            continue
        }
        ; This process already has a map, do not set
        if (processes.has(process_name))
        {
            continue
        }
        ; In this processes map, set a map for this process name and also with an empty windows map
        processes[process_name] := Map(
            "windows", Map()
        )
        OutputDebug("[" A_Now "] [" process_name "] Created process map for process")
    }
    ; After setting the processes that have met the conditions, return the populated processes map
    return processes
}

performWindowTask(windowId, invokeTask, isInputBlock)
{
    activeWindow := "A"
    targetWindowInfo := getWindowInfo("ahk_id " windowId)
    OutputDebug("[" A_Now "] [" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] @performWindowTask: Starting operations...")
    targetWindow := "ahk_id " targetWindowInfo["ID"]
    OutputDebug("[" A_Now "] Target Window INFO : [CLS:" targetWindowInfo["CLS"] "] [ID:" targetWindowInfo["ID"] "] [PID:" targetWindowInfo["PID"] "] [EXE:" targetWindowInfo["EXE"] "] [Window:" targetWindow "]")
    ; User is already active on the target window, perform the task right away
    if (WinActive(targetWindow))
    {
        invokeTask()
        OutputDebug("[" A_Now "] [" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] Active Target Window task successful!")
        OutputDebug("[" A_Now "] [" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] @performWindowTask: Finished operations")
        return
    }
    ; User is not active on the target window, try to activate the window
    activeWindowInfo := getWindowInfo(activeWindow)
    oldActiveWindow := getWindow(
        activeWindowInfo,
        targetWindow
    )
    isWindowActivateSucess := false
    try
    {
        ; User is not on any active window / User is active on the Desktop
        ; Bringing the Desktop window to the front can cause some scaling issues, so we ignore it.
        ; The Desktop's window has a class of "WorkerW" or "Progman"
        if (!activeWindowInfo.Count || (activeWindowInfo["CLS"] = "WorkerW" || activeWindowInfo["CLS"] = "Progman"))
        {
            WinSetTransparent(0, targetWindow)
            isWindowActivateSucess := activateWindow(targetWindow)
            invokeTask()
            WinMoveBottom(targetWindow)
            return
        }
        OutputDebug("[" A_Now "] Active Window INFO : [CLS:" activeWindowInfo["CLS"] "] [ID:" activeWindowInfo["ID"] "] [PID:" activeWindowInfo["PID"] "] [EXE:" activeWindowInfo["EXE"] "[Window:" oldActiveWindow "]")
        ; User is active on Action center / Date and time information / Start Menu / Searchapp.exe, alt+tab the user out from those Windows as a workaround
        if (activeWindowInfo["CLS"] = "Windows.UI.Core.CoreWindow")
        {
            OutputDebug("[" A_Now "] [" activeWindowInfo["EXE"] "] [Window ID: " activeWindowInfo["ID"] "] Active Window is Windows.UI.Core.CoreWindow!")
            ; Todo: Add a check here if the script is ran with ui access to bypass this work around.
            Send("{Alt Down}{Tab Up}{Tab Down}")
            Sleep(500)
            Send("{Alt Up}")
            MsgBox("For the script to perform its operations properly, the script has Alt+Tabbed you out from the active window.`nBeing active on a window with a class name of Windows.UI.Core.CoreWindow can hinder the script from activating the monitored process' target window.`nThis pop-up box will automatically close itself in 30 seconds.", , "OK Icon! T30")
        }

        blockUserInput("On", isInputBlock)
        WinSetTransparent(0, targetWindow)
        isWindowActivateSucess := activateWindow(targetWindow)
        ; User is still the old active window after the target window activation attempt, cancel the task
        ; The active window at this point should be the target window, not the old one.
        if (WinActive(oldActiveWindow) || !isWindowActivateSucess)
        {
            OutputDebug("[" A_Now "] [" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] Inactive Target Window invokeTask() failed!")
            WinSetTransparent("Off", targetWindow)
            return
        }
        invokeTask()
        OutputDebug("[" A_Now "] [" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] Inactive Target Window task successful!")
        ; There is a condition in the try clause above that checks if the target window is active already. If I move this in the finally clause,
        ; it will also move the active target window to the bottom too which isn't the intended behavior
        WinMoveBottom(targetWindow)
    }
    finally
    {
        ; These serve as fail saves. I don't want to put them in the try clause
        ; because if something goes wrong and gets stuck,
        ; the windows will operate fine at the end and not get caught in the hang
        if (WinGetTransparent(targetWindow) = 0)
        {
            WinSetTransparent("Off", targetWindow)
        }
        if (!WinActive(oldActiveWindow))
        {
            activateWindow(oldActiveWindow)
        }
        blockUserInput("Off", isInputBlock)
        OutputDebug("[" A_Now "] [" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] @performWindowTask#finally: Finished operations")
    }
}

; A simple wrapper for BlockInput
blockUserInput(option, isInputBlock)
{
    if (!isInputBlock || !A_IsAdmin)
    {
        return
    }
    OutputDebug("[" A_Now "] @blockUserInput: Successfully BlockInput " option "")
    BlockInput(option)
}

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
    if (!isWindowTargetable(WinExist(window)))
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
; If an override has not been setup for that process, the default value from the configuration for all programs will be used instead.
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
    ; Only iterate when there are processes
    if (processes.Count > 0)
    {
        for process_name, process in processes
        {
            windows := process["windows"]
            ; Only iterate when there are windows for this process
            if (windows.Count > 0)
            {
                monitoredWindows[process_name] := 0
                managedWindows[process_name] := 0
                ; For every window in this process' windows map
                ; Count how many of those are are managed and monitored
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

                ; No windows were found to have the conditioned statuses
                ; Remove this process entry from the monitored and managed windows
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
    }
    else
    {
        ; No processes are active on the user, clear all the counters
        monitoredWindows.Clear()
        managedWindows.Clear()
    }

    ; There are managed windows
    if (managedWindows.Count > 0)
    {
        iconNumber := 2
        ; There are also monitored windows
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
        ; There are only managed windows
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
    ; There are only monitored windows
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
    ; Neither managed nor monitored windows were found
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
        states["lastIconTooltipText"] := tooltipText
    }
}

registerWindowIds(windows, process_name)
{
    ; Retrieve all found unique window ids for this process
    windowIds := WinGetList("ahk_exe " process_name)
    ; There are no open windows for this process, return the windows map as empty in that case
    if (windowIds.Length < 1)
    {
        return windows
    }
    pollsLeft := getTotalPolls(getAttributeValue("WINDOW_TIMEOUT", process_name))
    ; For every window id found under the process, set a window map for that process' windows map
    ; only if it meets certain conditions
    for , windowId in windowIds
    {
        ; If this window is not targetable, do not set a map for this window id
        if (!isWindowTargetable(WinExist("ahk_id " windowId)))
        {
            continue
        }
        ; If this window id already exists in the windows map, do not reset a map for it
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
    ; After setting all windows that have met the conditions, return the populated windows map
    return windows
}

; Checks if a window is targetable
; tysm! https://stackoverflow.com/questions/35971452/what-is-the-right-way-to-send-alt-tab-in-ahk/36008086#36008086
; Helps filtering out the windows the script should not interact with
isWindowTargetable(HWND)
{
    ; https://www.autohotkey.com/docs/v2/misc/Styles.htm
    windowStyle := WinGetStyle("ahk_id " HWND)
    ; Windows with the WS_POPUP style (0x80000000)
    if (windowStyle & 0x80000000)
    {
        return false
    }
    ; Windows with the WS_DISABLED style (0x08000000)
    ; These windows are disabled and not interactive (grayed-out windows)
    if (windowStyle & 0x08000000)
    {
        return false
    }
    ; Windows that do not have the WS_VISIBLE style (0x10000000)
    ; These are invisible windows, not suitable for interaction
    if (!windowStyle & 0x10000000)
    {
        return false
    }
    windowExtendedStyle := WinGetExStyle("ahk_id " HWND)
    ; Windows with WS_EX_TOOLWINDOW (0x00000080)
    ; https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
    ; Tool windows are often small floating windows (like toolbars) and are usually not primary windows
    if (windowExtendedStyle & 0x00000080)
    {
        return false
    }
    cls := WinGetClass("ahk_id " HWND)
    ; Windows with the class "TApplication"
    ; These are often Delphi or VCL-based windows, typically representing non-primary windows
    if (cls = "TApplication")
    {
        return false
    }
    ; Common class for dialog boxes or dialog windows
    ; https://learn.microsoft.com/en-us/windows/win32/winmsg/about-window-classes
    ; Windows with the class "#32770"
    ; This class represents dialog boxes, such as 'Open' or 'Save As' dialogs
    if (cls = "#32770")
    {
        return false
    }
    ; Windows with the class "ComboLBox"
    ; This class represents the dropdown list portion of a combo box
    ; These are not standalone windows and are part of other UI elements
    if (cls = "ComboLBox")
    {
        return false
    }
    ; Windows with the class "Windows.UI.Core.CoreWindow"
    ; The action center, date and time info, start menu, and searchapp all belong on this class
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
    ; For every window in this process
    for windowId, window in windows
    {
        ; This window no longer exists, delete it from the windows map
        if (!WinExist("ahk_id " windowId))
        {
            OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Deleted window for process as it was closed by the user!")
            windows.Delete(windowId)
            continue
        }
        ; The user is currently active on this window
        if (WinActive("ahk_id " windowId))
        {
            ; User is not idling on this window, reset the polls
            if (A_TimeIdlePhysical < (windowTimeoutMinutes * 60000))
            {
                OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Active Target Window: Activity detected! Polls has been reset!")
                window := Map(
                    "status", "MonitoringStatus",
                    "pollsLeft", windowTotalPolls
                )
                windows[windowId] := window
                continue
            }
            ; User is now considered idling on this window, set the polls left as 1 for it to be decremented to 0 below.
            ; After that, perform the task right away
            OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Active Target Window: Inactivity detected! Polling...")
            if (window["status"] = "MonitoringStatus")
            {
                window["pollsLeft"] := 1
            }
        }
        ; Decrement 1 in each poll
        window["pollsLeft"] -= 1
        OutputDebug("[" A_Now "] [" process_name "] [Window ID: " windowId "] Target Window: " window["pollsLeft"] " polls remaining")
        ; No more polls remaining, time to do the task
        if (window["pollsLeft"] < 1)
        {
            ; Reset the poll with the calculated total polls from TASK_INTERVAL instead of from WINDOWS_TIMEOUT
            window := Map(
                "status", "ManagingStatus",
                "pollsLeft", intervalTotalPolls
            )
            ; Perform this window's task set by the user for this process
            performWindowTask(windowId, invokeTask, isInputBlock)
        }
        ; Set the newly updated window map to the windows map for this process
        windows[windowId] := window
    }
    ; End of operation here, nothing else to do.
}

monitorProcesses()
{
    processes := registerProcesses(states["Processes"], config["MONITOR_LIST"])
    if (processes.Count > 0)
    {
        for process_name, process in processes
        {
            ; User no longer has this process and was closed, delete it from the processes map
            if (!ProcessExist(process_name))
            {
                OutputDebug("[" A_Now "] [" process_name "] Deleted process map for process as it was closed by the user!")
                processes.Delete(process_name)
                continue
            }
            windows := registerWindowIds(process["windows"], process_name)
            ; User does not have any windows open for this process, do not monitor the window
            if (windows.Count < 1)
            {
                continue
            }
            monitorWindows(windows, process_name)
        }
    }
    updateSystemTray(processes)
    ; Monitor the processes again according to what's configured as its polling interval
    SetTimer(monitorProcesses, config["POLL_INTERVAL"] * 1000)
}

requestElevation()
; Initiate the first poll
monitorProcesses()
