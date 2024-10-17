; --------------------
; Configuration
; --------------------

; TODO:

; Issues:
; When the user quickly switches between specified process' windows, the script might still poll and decrements one of its timer. The supposed behavior is to reset the polls
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
; Solution 1: For this script to be able to activate other windows while active on a CoreWindow, "Run with UI Access" this script. Run as admin will not work as a solution.
; Solution 2: Alt + Tab to get out from the CoreWindow, then activate the target window
; ListLines(0)
global config := Map()

; POLLING_INTERVAL_MS (Milliseconds):
;   This is the interval which is how often this script monitors the processes and its windows.
;   Setting lower values means it will check more often, but can be tasking for the system.
; Default: 
; 10000 (10 seconds)
config["POLLING_INTERVAL_MS"] := 10000

; ACTIVE_WINDOW_TIMEOUT_MS (Milliseconds):
;   The amount of time the user is considered idle in a monitored window they currently have in focus.
;   When the user is found to be idle for more than or equal to this time,
;   the configured task for the process (default or override) will be performed right away.
;   If the user is still idling in that same monitored window after reaching this timeout,
;   the window will be marked as inactive, and the task is rescheduled to execute after reaching INACTIVE_WINDOW_TIMEOUT_MS.
; Default:
; 60000 (60 seconds or 1 minute)
config["ACTIVE_WINDOW_TIMEOUT_MS"] := 60000

; PROCESS_TASK (Function):
;   This is where you can write what you want the script to do once the monitored window is in focus.
;   For most games, delay of 15ms-50ms is generally enough for the the game to read simulated keypresses.
;   Having it pressed down, then a very short delay before it is released up
;   Otherwise, some of your simulated inputs may go through and sometimes not.
;   Read more about it this here:
;   https://www.reddit.com/r/AutohotkeyCheats/comments/svseph/how_to_make_ahk_work_with_games_the_basics/
;   https://www.autohotkey.com/boards/viewtopic.php?t=11084
; Default:
; config["PROCESS_TASK"] := () => (
;     Send("{Space Down}")
;     Sleep(20)
;     Send("{Space Up}")
; )
config["PROCESS_TASK"] := () => (
    Send("{Space Down}")
    Sleep(20)
    Send("{Space Up}")
)

; INACTIVE_WINDOW_TIMEOUT_MS (Milliseconds):
;   The amount of time the user is absent from the monitored window.
;   If the user is still absent from the monitored window for more than or equal to this time,
;   the script will perform its task and repeat this.
; Default:
; 180000 (180 seconds or 3 minutes)
config["INACTIVE_WINDOW_TIMEOUT_MS"] := 180000

; IS_INPUT_BLOCK (Boolean):
;   This tells the script whether you want to block any input temporarily while it shuffles
;   through the monitored windows when it performs their tasks.
;   This requires administrator permissions and is therefore disabled by default.
;   If input is not blocked, keystrokes from the user from interacting other windows
;   may 'leak' into the monitored window when the script moves it into focus.
; Default:
; false
config["IS_INPUT_BLOCK"] := false

; MONITOR_LIST (String Array):
;   This is a list of processes that the script will montior.
;   Any windows that do not belong to any of these processes will be ignored.
; Default:
; [
;     "RobloxPlayerBeta.exe",
;     "notepad.exe",
;     "wordpad.exe"
; ]
config["MONITOR_LIST"] := [
    "RobloxPlayerBeta.exe",
    "notepad.exe",
    "wordpad.exe"
]

; PROCESS_OVERRIDES (Associative Array):
;   This allows you to specify specific values of ACTIVE_WINDOW_TIMEOUT_MS, INACTIVE_WINDOW_TIMEOUT_MS,
;   PROCESS_TASK and IS_INPUT_BLOCK for specific processes. This is helpful if different
;   games consider you AFK at wildly different times, or if the function to
;   reset the AFK timer does not work as well across different applications.
;   For the overrides to work, include the overriden process' name to the MONITOR_LIST.
;   This is not the monitor list.
; Default:
; Map(
;     "RobloxPlayerBeta.exe", Map(
;         "overrides", Map(
;             ; 2 minutes
;             "ACTIVE_WINDOW_TIMEOUT_MS", 120000,
;             ; 10 minutes
;             "INACTIVE_WINDOW_TIMEOUT_MS", 600000,
;             "IS_INPUT_BLOCK", false,
;             "PROCESS_TASK", () => (
;                 Send("{Space Down}")
;                 Sleep(20)
;                 Send("{Space Up}")
;             )
;         )
;     ),
;     "notepad.exe", Map(
;         "overrides", Map(
;             ; 15 seconds
;             "ACTIVE_WINDOW_TIMEOUT_MS", 15000,
;             ; 30 seconds
;             "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
;             "IS_INPUT_BLOCK", false,
;             "PROCESS_TASK", () => (
;                 Send("1")
;             )
;         )
;     ),
;     "wordpad.exe", Map(
;         "overrides", Map(
;             ; 15 seconds
;             "ACTIVE_WINDOW_TIMEOUT_MS", 15000,
;             ; 30 seconds
;             "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
;             "IS_INPUT_BLOCK", false,
;             "PROCESS_TASK", () => (
;                 Send("1")
;             )
;         )
;     )
; )
config["PROCESS_OVERRIDES"] := Map(
    "RobloxPlayerBeta.exe", Map(
        "overrides", Map(
            ; 2 minutes
            "ACTIVE_WINDOW_TIMEOUT_MS", 120000,
            ; 10 minutes
            "INACTIVE_WINDOW_TIMEOUT_MS", 600000,
            "IS_INPUT_BLOCK", false,
            "PROCESS_TASK", () => (
                Send("{Space Down}")
                Sleep(20)
                Send("{Space Up}")
            )
        )
    ),
    "notepad.exe", Map(
        "overrides", Map(
            ; 15 seconds
            "ACTIVE_WINDOW_TIMEOUT_MS", 15000,
            ; 30 seconds
            "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
            "IS_INPUT_BLOCK", false,
            "PROCESS_TASK", () => (
                Send("1")
            )
        )
    ),
    "wordpad.exe", Map(
        "overrides", Map(
            ; 15 seconds
            "ACTIVE_WINDOW_TIMEOUT_MS", 15000,
            ; 30 seconds
            "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
            "IS_INPUT_BLOCK", false,
            "PROCESS_TASK", () => (
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

; Both of these exist for the simulated key presses in the task to not interfere with the script's timers
; one of those timers is A_TimeIdlePhysical
InstallKeybdHook(true)
InstallMouseHook(true)

KeyHistory(0)

; Returns false if any config or override value is invalid, returns true if everything looks good
validateConfigAndOverrides()
{
    invalidValuesMsg := ""
    isConfigPass := true
    isOverridePass := true

    ; Check if POLLING_INTERVAL_MS is less than or equal to 0
    if (config["POLLING_INTERVAL_MS"] <= 0)
    {
        MsgBox("ERROR: The configured polling rate is less than or equal to 0. The script will exit immediately.", , "OK Iconx")
        ExitApp(1)
    }

    ; Validate the main configuration settings
    if (config["POLLING_INTERVAL_MS"] > config["INACTIVE_WINDOW_TIMEOUT_MS"])
    {
        invalidValuesMsg .= "[Config]`nPOLLING_INTERVAL_MS (" config["POLLING_INTERVAL_MS"] "ms) > INACTIVE_WINDOW_TIMEOUT_MS (" config["INACTIVE_WINDOW_TIMEOUT_MS"] "ms)`nPolling rate must be lower than this setting!`n`n"
        isConfigPass := false
    }
    if (config["POLLING_INTERVAL_MS"] > config["ACTIVE_WINDOW_TIMEOUT_MS"])
    {
        invalidValuesMsg .= "[Config]`nPOLLING_INTERVAL_MS (" config["POLLING_INTERVAL_MS"] "ms) > ACTIVE_WINDOW_TIMEOUT_MS (" config["ACTIVE_WINDOW_TIMEOUT_MS"] "ms)`nPolling rate must be lower than this setting!`n`n"
        isConfigPass := false
    }

    ; Check if ACTIVE_WINDOW_TIMEOUT_MS or INACTIVE_WINDOW_TIMEOUT_MS are less than 3000 ms
    if (config["ACTIVE_WINDOW_TIMEOUT_MS"] < 3000)
    {
        invalidValuesMsg .= "[Config]`nACTIVE_WINDOW_TIMEOUT_MS (" config["ACTIVE_WINDOW_TIMEOUT_MS"] "ms)`nMust be at least 3000ms! Because anything lower can be disruptive!`n`n"
        isConfigPass := false
    }
    if (config["INACTIVE_WINDOW_TIMEOUT_MS"] < 3000)
    {
        invalidValuesMsg .= "[Config]`nINACTIVE_WINDOW_TIMEOUT_MS (" config["INACTIVE_WINDOW_TIMEOUT_MS"] "ms)`nMust be at least 3000ms! Because anything lower can be disruptive!`n`n"
        isConfigPass := false
    }

    ; Validate monitor override settings
    for process_name, process in config["PROCESS_OVERRIDES"]
    {
        overrides := process["overrides"]
        if (overrides.Has("INACTIVE_WINDOW_TIMEOUT_MS") && config["POLLING_INTERVAL_MS"] > overrides["INACTIVE_WINDOW_TIMEOUT_MS"])
        {
            invalidValuesMsg .= "[Override of " process_name "]`nPOLLING_INTERVAL_MS (" config["POLLING_INTERVAL_MS"] "ms) > INACTIVE_WINDOW_TIMEOUT_MS (" overrides["INACTIVE_WINDOW_TIMEOUT_MS"] "ms)`nPolling rate must be lower than this override!`n`n"
            isOverridePass := false
        }
        if (overrides.Has("ACTIVE_WINDOW_TIMEOUT_MS") && config["POLLING_INTERVAL_MS"] > overrides["ACTIVE_WINDOW_TIMEOUT_MS"])
        {
            invalidValuesMsg .= "[Override of " process_name "]`nPOLLING_INTERVAL_MS (" config["POLLING_INTERVAL_MS"] "ms) > ACTIVE_WINDOW_TIMEOUT_MS (" overrides["ACTIVE_WINDOW_TIMEOUT_MS"] "ms)`nPolling rate must be lower than this override!`n"
            isOverridePass := false
        }

        ; Stop further checks if any override is invalid
        if (!isOverridePass)
        {
            break
        }
    }

    ; If any validation fails, show the invalid values in the message box and exit the app
    if (!isConfigPass || !isOverridePass)
    {
        MsgBox("ERROR: Invalid configuration detected, cannot launch script!`nFor the script to operate properly, please review and adjust the following values accordingly.`n`n" invalidValuesMsg "", , "OK Iconx")
        ; Since this script is not that big, I don't want to make another condition for its returned values, exit right away instead
        ExitApp(1)
    }
    ; If all conditions have passed
    return true
}

global states := Map()
states["Processes"] := Map()
states["MonitoredWindows"] := Map()
states["ManagedWindows"] := Map()
states["lastIconNumber"] := 0
states["lastIconTooltipText"] := ""

logDebug(str) 
{
    OutputDebug("[" A_Now "] [DEBUG] " str "`n")
}

requestElevation()
{
    ; Admin already, do nothing
    if (A_IsAdmin)
    {
        return
    }
    isAdminRequire := config["IS_INPUT_BLOCK"]
    for , process in config["PROCESS_OVERRIDES"]
    {
        if (process["overrides"].Has("IS_INPUT_BLOCK") && process["overrides"]["IS_INPUT_BLOCK"])
        {
            isAdminRequire := true
        }
    }
    ; Admin not required, do nothing
    if (!isAdminRequire)
    {
        return
    }
    ; Attempt to relaunch the scipt with elevated permissions, showing a UAC prompt to the user
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
    ; User canceled the UAC prompt
    MsgBox("This requires Anti-AFK to be ran as administrator to block inputs!`nBLOCK_INPUT has been temporarily disabled.",
        "Unable to block keystrokes",
        "OK Icon!"
    )
}

blockUserInput(option, isInputBlock)
{
    if (!isInputBlock || !A_IsAdmin)
    {
        return
    }
    logDebug("@blockUserInput: Successfully BlockInput " option "")
    BlockInput(option)
}

getWindow(windowInfo, fallbackWindow)
{
    ; Window info is empty, use the fallbackWindow right away
    if (!windowInfo.Count || !windowInfo)
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
        logDebug("[" window "] Failed to get info! Window does not exist!")
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
        logDebug("[" window "] Failed to activate! Window does not exist!")
        return false
    }
    if (!isWindowTargetable(WinExist(window)))
    {
        logDebug("[" window "] Failed to activate! Window is not targetable!")
        return false
    }
    WinActivate(window)
    value := WinWaitActive(window, , 0.50)
    if (value = 0)
    {
        logDebug("[" window "] Failed to activate! Window timed out!")
        return false
    }
    logDebug("[" window "] Window successfully activated!")
    return true
}

; Find and return a specific attribute for a process, prioritising values in PROCESS_OVERRIDES.
; If an override has not been setup for that process, the default value from the configuration for all processes will be used instead.
getAttributeValue(attributeName, process_name)
{
    processOverrides := config["PROCESS_OVERRIDES"]
    if (processOverrides.Has(process_name))
    {
        if (processOverrides[process_name]["overrides"].Has(attributeName))
        {
            return processOverrides[process_name]["overrides"][attributeName]
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
                    if (windowStatus = "ActiveWindow")
                    {
                        monitoredWindows[process_name] += 1
                    }
                    else if (windowStatus = "InactiveWindow")
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

performProcessTask(windowId, invokeTask, isInputBlock)
{
    isWindowActivateSucess := false
    activeWindow := "A"
    targetWindowInfo := getWindowInfo("ahk_id " windowId)
    logDebug("[" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] @performProcessTask: Starting operations...")
    targetWindow := "ahk_id " targetWindowInfo["ID"]
    logDebug("Target Window INFO : [CLS:" targetWindowInfo["CLS"] "] [ID:" targetWindowInfo["ID"] "] [PID:" targetWindowInfo["PID"] "] [EXE:" targetWindowInfo["EXE"] "] [Window:" targetWindow "]")
    ; User is PRESENT on the target window, perform the task right away
    if (WinActive(targetWindow))
    {
        invokeTask()
        logDebug("[" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] Active Target Window task successful!")
        logDebug("[" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] @performProcessTask: Finished operations")
        return
    }
    activeWindowInfo := getWindowInfo(activeWindow)
    oldActiveWindow := !activeWindowInfo.Count ? "" : getWindow(
        activeWindowInfo,
        targetWindow
    )
    ; User is ABSENT on the target window, try to activate the target window
    try
    {
        ; User is PRESENT on any window / User is PRESENT on the Desktop
        ; Bringing the Desktop window back to the front can cause some scaling issues, so we ignore it.
        ; The Desktop's window has a class of "WorkerW" or "Progman"
        if (!activeWindowInfo.Count || (activeWindowInfo["CLS"] = "WorkerW" || activeWindowInfo["CLS"] = "Progman"))
        {
            WinSetTransparent(0, targetWindow)
            isWindowActivateSucess := activateWindow(targetWindow)
            if (!isWindowActivateSucess)
            {
                logDebug("[" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] Inactive Target Window invokeTask() failed!")
                WinSetTransparent("Off", targetWindow)
                return
            }
            invokeTask()
            WinMoveBottom(targetWindow)
            return
        }
        logDebug("Active Window INFO : [CLS:" activeWindowInfo["CLS"] "] [ID:" activeWindowInfo["ID"] "] [PID:" activeWindowInfo["PID"] "] [EXE:" activeWindowInfo["EXE"] "[Window:" oldActiveWindow "]")
        ; User is PRESENT on these kind of Windows: Action center / Date and time information / Start Menu / Searchapp.exe
        ; Simply activating the target window will not work, the taskbar icons of the target window will flash, indicating that it's not activated.
        ; The script will need to be ran with UI access to activate other windows while the user is active on those system CoreWindow class windows.
        if (activeWindowInfo["CLS"] = "Windows.UI.Core.CoreWindow")
        {
            logDebug("[" activeWindowInfo["EXE"] "] [Window ID: " activeWindowInfo["ID"] "] Active Window is Windows.UI.Core.CoreWindow!")
            isWindowActivateSucess := activateWindow(targetWindow)
            ; Todo: Add a check here if the script is ran with ui access to bypass this work around.
            ; Alt + Tab the user out from those kind of Windows as a workaround
            Send("{Alt Down}{Tab Up}{Tab Down}")
            Sleep(500)
            Send("{Alt Up}")
            MsgBox("For the script to perform its operations properly, the script has Alt + Tabbed you out from the active window.`nBeing active on a window with a class name of Windows.UI.Core.CoreWindow can hinder the script from activating the monitored process' target window.`nThis pop-up box will automatically close itself in 30 seconds.", , "OK Icon! T30")
        }

        blockUserInput("On", isInputBlock)
        WinSetTransparent(0, targetWindow)
        isWindowActivateSucess := activateWindow(targetWindow)
        ; User is still PRESENT on the old active window after the target window activation attempt,
        ; do not perform the task as the input from the task can leak into whatever the user is currently doing
        ; on other windows
        if (WinActive(oldActiveWindow) || !isWindowActivateSucess)
        {
            logDebug("[" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] Inactive Target Window invokeTask() failed!")
            WinSetTransparent("Off", targetWindow)
            return
        }
        invokeTask()
        logDebug("[" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] Inactive Target Window task successful!")
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
        if (oldActiveWindow != "" && !WinActive(oldActiveWindow))
        {
            activateWindow(oldActiveWindow)
        }
        blockUserInput("Off", isInputBlock)
        logDebug("[" targetWindowInfo["EXE"] "] [Window ID: " targetWindowInfo["ID"] "] @performProcessTask#finally: Finished operations")
    }
}

registerWindows(windows, process_name)
{
    ; No open windows for this process, return the windows map as empty in that case
    if (WinGetCount("ahk_exe " process_name) < 1)
    {
        return windows
    }
    ; Retrieve all found unique ids (HWNDs) for this process' windows
    windowIds := WinGetList("ahk_exe " process_name)
    ; For every window id found under the process, set a window map for that process' windows map
    ; only if it meets certain conditions
    for , windowId in windowIds
    {
        ; This window is not targetable, do not set a map for this window id, skip it
        if (!isWindowTargetable(WinExist("ahk_id " windowId)))
        {
            continue
        }
        ; This window already exists in the windows map, do not reset its map, skip it
        if (windows.Has(windowId))
        {
            continue
        }
        ; In this process' windows map, set a new map for this window id
        windows[windowId] := Map()
        windows[windowId]["status"] := "ActiveWindow"
        windows[windowId]["lastInactiveTick"] := A_TickCount
        windows[windowId]["elapsedInactivityTime"] := 0
        logDebug("[" process_name "] [Window ID: " windowId "] Created window for process")
    }
    ; After setting all windows that have met the conditions, return the populated windows map
    return windows
}

monitorWindows(windows, process_name)
{
    inactiveWindowTimeoutMs := getAttributeValue("INACTIVE_WINDOW_TIMEOUT_MS", process_name)
    activeWindowTimeoutMs := getAttributeValue("ACTIVE_WINDOW_TIMEOUT_MS", process_name)
    invokeTask := getAttributeValue("PROCESS_TASK", process_name)
    isInputBlock := getAttributeValue("IS_INPUT_BLOCK", process_name)

    ; For every window in this process' windows
    for windowId, window in windows
    {
        ; This monitored window no longer exists, most likely closed by the user, delete it from the windows map
        if (!WinExist("ahk_id " windowId))
        {
            logDebug("[" process_name "] [Window ID: " windowId "] Deleted window for process as it was closed by the user!")
            windows.Delete(windowId)
            continue
        }
        ; User is PRESENT in this monitored window
        if (WinActive("ahk_id " windowId))
        {
            ; User is NOT IDLING in this monitored window
            if (A_TimeIdlePhysical <= activeWindowTimeoutMs)
            {
                ; Elapsed time is already reset, do not reset other properties except A_TickCount
                if (window["elapsedInactivityTime"] = 0)
                {
                    window["lastInactiveTick"] := A_TickCount
                    continue
                }
                window["status"] := "ActiveWindow"
                window["lastInactiveTick"] := A_TickCount
                window["elapsedInactivityTime"] := 0
                logDebug("[" process_name "] [Window ID: " windowId "] Active Target Window: User is NOT IDLE!")
                continue
            }
            ; User is IDLING in this monitored window for more than or equal to the configured ACTIVE_WINDOW_TIMEOUT_MS
            if (window["status"] = "ActiveWindow")
            {
                logDebug("[" process_name "] [Window ID: " windowId "] Active Target Window: User is IDLE!")
                ; Perform this window's task set by the user for this process
                performProcessTask(windowId, invokeTask, isInputBlock)
                ; Once the task is done, reset its properties then mark it as InactiveWindow
                window["status"] := "InactiveWindow"
                window["lastInactiveTick"] := A_TickCount
                window["elapsedInactivityTime"] := 0
                continue
            }
        }
        ; The user is ABSENT in this monitored window, they're present in a different window
        window["elapsedInactivityTime"] := A_TickCount - window["lastInactiveTick"]
        logDebug("[" process_name "] [Window ID: " windowId "] Window is inactive for: " window["elapsedInactivityTime"] "ms / " inactiveWindowTimeoutMs "ms")
        ; This monitored window's been inactive for more than or equal to the configured INACTIVE_WINDOW_TIMEOUT_MS
        if (window["elapsedInactivityTime"] >= inactiveWindowTimeoutMs)
        {
            ; Perform the configured task for this monitored window's process.
            performProcessTask(windowId, invokeTask, isInputBlock)
            ; Once the task is done, reset its properties then mark it as InactiveWindow
            window["status"] := "InactiveWindow"
            window["lastInactiveTick"] := A_TickCount
            window["elapsedInactivityTime"] := 0
        }
    }
    ; Monitoring operations END here
}

registerProcesses(processes, monitorList)
{
    for , process_name in monitorList
    {
        ; User does is not running this process from the monitor list, do not set
        if (!ProcessExist(process_name))
        {
            continue
        }
        ; This process already has a map, do not set
        if (processes.has(process_name))
        {
            continue
        }
        ; In this processes map, set a map for this process name
        processes[process_name] := Map()
        ; and also with an empty windows map
        processes[process_name]["windows"] := Map()
        logDebug("[" process_name "] Created process map for process")
    }
    ; After setting the processes that have met the conditions, return the populated processes map
    return processes
}

monitorProcesses()
{
    ; Monitoring operations START here
    processes := registerProcesses(states["Processes"], config["MONITOR_LIST"])
    if (processes.Count > 0)
    {
        for process_name, process in processes
        {
            ; User is no longer running process and was most likely closed, delete it from the processes map
            if (!ProcessExist(process_name))
            {
                logDebug("[" process_name "] Deleted process map for process as it was closed by the user!")
                processes.Delete(process_name)
                continue
            }
            windows := registerWindows(process["windows"], process_name)
            ; No windows were found for this process, do not monitor this process' windows, skip it
            if (windows.Count < 1)
            {
                continue
            }
            monitorWindows(windows, process_name)
        }
    }
    ; Reflect in the user's system tray the currently monitored processes and their windows
    updateSystemTray(processes)
}

validateConfigAndOverrides()
requestElevation()
; Initiate the first poll
monitorProcesses()
; Monitor the processes again according to what's configured as its polling interval
SetTimer(monitorProcesses, config["POLLING_INTERVAL_MS"])
