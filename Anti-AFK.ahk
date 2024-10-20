#Requires AutoHotkey v2.0
#SingleInstance
#Warn All

; Do not list lines (Commented for now)
; ListLines(0)

; --------------------
; Configuration
;   To reduce the likelihood of facing errors after changing the configuration values,
;   read the notes of each configuration. If necessary, refer to the AutoHotkey language syntax documentation here:
;   https://www.autohotkey.com/docs/v2/Language.htm
; --------------------
global globals := Map()
globals["config"] := Map()

; POLLING_INTERVAL_MS (Integer, Milliseconds)
; Description:
;   This defines how frequently the script monitors the processes and their windows.
; Notes:
;   - Setting extremely low values means more frequent checks, which can increase CPU usage and potentially burden the system.
;   - 0 will prevent the script from running.
;   - Value must not exceed the ACTIVE_WINDOW_TIMEOUT_MS and INACTIVE_WINDOW_TIMEOUT_MS.
;   - Value must be a common factor of ACTIVE_WINDOW_TIMEOUT_MS and INACTIVE_WINDOW_TIMEOUT_MS to ensure that the polls aligns perfectly with the timeout.
;   The script will let you know about invalid values if found.
; Default:
; 5000 (5 seconds)
globals["config"]["POLLING_INTERVAL_MS"] := 5000

; ACTIVE_WINDOW_TIMEOUT_MS (Integer, Milliseconds)
; Description:
;   The amount of time the user is considered idle in a monitored window they currently have in focus.
;   When the user is found to be idle in a monitored window for more than or equal to this amount of time,
;   the configured task for the process (in config or process override) will be performed right away.
;   If the user is still idling in that same monitored window, exceeding this ACTIVE_WINDOW_TIMEOUT_MS,
;   the window will be marked as INACTIVE, and the task is rescheduled to execute after the configured INACTIVE_WINDOW_TIMEOUT_MS is met.
; Notes:
;   Setting low values less than 3000ms (3 seconds) can be very disruptive and the script will prevent you from doing that.
;   - Value must not be less than the configured POLLING_INTERVAL_MS.
;   - Value must be divisible by POLLING_INTERVAL_MS (Divides evenly)
;   The script will let you know about invalid values if found.
; Default:
; 60000 (60 seconds or 1 minute)
globals["config"]["ACTIVE_WINDOW_TIMEOUT_MS"] := 60000

; INACTIVE_WINDOW_TIMEOUT_MS (Integer, Milliseconds)
; Description:
;   The amount of time the user is absent from a monitored window.
;   When the monitored window's been inactive for more than or equal to this amount of time,
;   the script will perform its task and repeat this.
; Notes:
;   - Setting low values less than 3000ms (3 seconds) can be very disruptive and the script will prevent you from doing that.
;   - Value must not be less than the configured POLLING_INTERVAL_MS.
;   - Value must be divisible by POLLING_INTERVAL_MS (Divides evenly)
;   The script will let you know about invalid values if found.
; Default:
; 180000 (180 seconds or 3 minutes)
globals["config"]["INACTIVE_WINDOW_TIMEOUT_MS"] := 180000

; TASK_INPUT_BLOCK (Boolean)
; Description:
;   This tells the script whether you want to block any input temporarily when the tasks
;   are being performed while it shuffles through the monitored windows.
; Notes:
;   - This requires administrator permissions and is therefore disabled by default.
;   - If input is not blocked, keystrokes from the user from interacting other windows
;   may 'leak' into the monitored window when the script moves it into focus.
; Default:
; false
globals["config"]["TASK_INPUT_BLOCK"] := false

; PROCESS_TASK (Arrow Function)
; Description:
;   This is where you can write what you want the script to do once the the monitored process' window is in focus.
; Notes:
;   - For most games, delay of 15ms-50ms is generally enough for the the game to read simulated keypresses.
;   - Having it press down, then add a short delay before it is released up.
;   - Otherwise, some of your simulated inputs may go through and sometimes not.
;   - Read more about it this here:
;   https://www.reddit.com/r/AutohotkeyCheats/comments/svseph/how_to_make_ahk_work_with_games_the_basics/
;   https://www.autohotkey.com/boards/viewtopic.php?t=11084
; Default:
; config["PROCESS_TASK"] := () => (
;     Send("{Space Down}")
;     Sleep(20)
;     Send("{Space Up}")
; )
globals["config"]["PROCESS_TASK"] := () => (
    Send("{Space Down}")
    Sleep(20)
    Send("{Space Up}")
)

; MONITOR_LIST (String Array)
; Description:
;   This is the list of processes that the script will monitor for window activity.
; Notes:
;   - Any windows that do not belong to any of these processes will be ignored.
; Default:
; [
;     "RobloxPlayerBeta.exe",
;     "notepad.exe",
;     "wordpad.exe"
; ]
globals["config"]["MONITOR_LIST"] := [
    "RobloxPlayerBeta.exe",
    "notepad.exe",
    "wordpad.exe"
]

; PROCESS_OVERRIDES (Associative Array)
; Description:
;   This allows you to specify specific values of ACTIVE_WINDOW_TIMEOUT_MS, INACTIVE_WINDOW_TIMEOUT_MS,
;   PROCESS_TASK and TASK_INPUT_BLOCK for specific processes.
; Notes:
;   - This is helpful if different games consider you AFK at wildly different times, or if the function to
;   reset their AFK timers does not work as well across different applications.
;   - For the overrides to work, include the overriden process' name to the MONITOR_LIST.
;   - This is not the monitor list.
; Default:
; Map(
;     "RobloxPlayerBeta.exe", Map(
;         "overrides", Map(
;             ; 2 minutes
;             "ACTIVE_WINDOW_TIMEOUT_MS", 120000,
;             ; 10 minutes
;             "INACTIVE_WINDOW_TIMEOUT_MS", 600000,
;             "TASK_INPUT_BLOCK", false,
;             "PROCESS_TASK", () => (
;                 Send("{Space Down}")
;                 Sleep(20)
;                 Send("{Space Up}")
;             )
;         )
;     ),
;     "notepad.exe", Map(
;         "overrides", Map(
;             ; 20 seconds
;             "ACTIVE_WINDOW_TIMEOUT_MS", 20000,
;             ; 30 seconds
;             "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
;             "TASK_INPUT_BLOCK", false,
;             "PROCESS_TASK", () => (
;                 Send("1")
;             )
;         )
;     ),
;     "wordpad.exe", Map(
;         "overrides", Map(
;             ; 20 seconds
;             "ACTIVE_WINDOW_TIMEOUT_MS", 20000,
;             ; 30 seconds
;             "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
;             "TASK_INPUT_BLOCK", false,
;             "PROCESS_TASK", () => (
;                 Send("1")
;             )
;         )
;     )
; )
globals["config"]["PROCESS_OVERRIDES"] := Map(
    "RobloxPlayerBeta.exe", Map(
        "overrides", Map(
            ; 2 minutes
            "ACTIVE_WINDOW_TIMEOUT_MS", 120000,
            ; 10 minutes
            "INACTIVE_WINDOW_TIMEOUT_MS", 600000,
            "TASK_INPUT_BLOCK", false,
            "PROCESS_TASK", () => (
                Send("{Space Down}")
                Sleep(20)
                Send("{Space Up}")
            )
        )
    ),
    "notepad.exe", Map(
        "overrides", Map(
            ; 20 seconds
            "ACTIVE_WINDOW_TIMEOUT_MS", 20000,
            ; 30 seconds
            "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
            "TASK_INPUT_BLOCK", false,
            "PROCESS_TASK", () => (
                Send("1")
            )
        )
    ),
    "wordpad.exe", Map(
        "overrides", Map(
            ; 20 seconds
            "ACTIVE_WINDOW_TIMEOUT_MS", 20000,
            ; 30 seconds
            "INACTIVE_WINDOW_TIMEOUT_MS", 30000,
            "TASK_INPUT_BLOCK", false,
            "PROCESS_TASK", () => (
                Send("1")
            )
        )
    )
)

; --------------------
; Script
; --------------------

logDebug(formatString, params*) {
    OutputDebug(Format("[{1}] [DEBUG] {2}", A_Now, Format(formatString, params*)))
}

; The calculated excess time of the polling interval and timeouts should be zero.
; only use any polling interval that is equal to or less than the timeout,
; as long as the total duration calculated does not exceed the timeout.
calculateExcessTime(timeoutMs, pollingIntervalMs)
{
    totalDurationMs := Ceil(timeoutMs / pollingIntervalMs) * pollingIntervalMs
    totalExcessTime := totalDurationMs - timeoutMs
    logDebug("Polling Interval: {1} | Timeout: {2} | Total Excess Time: {3}", pollingIntervalMs, timeoutMs, totalExcessTime)
    if (totalExcessTime < 0)
    {
        totalExcessTime := 0
    }
    return totalExcessTime
}

isDivisible(dividend, divisor)
{
    if (divisor = 0)
    {
        return false
    }
    return (Mod(dividend, divisor) = 0)
}

validateConfigAndOverrides()
{
    ; TODO: Simplify logic.
    isConfigPass := true
    isOverridePass := true
    invalidsMsg := ""
    validationMsg := ""
    pollingIntervalMs := globals["config"]["POLLING_INTERVAL_MS"]
    if (pollingIntervalMs <= 0)
    {
        validationMsg .= Format("ERROR: The configured POLLING_INTERVAL_MS ({1}ms) is less than or equal to 0. The script will exit immediately.", pollingIntervalMs)
        MsgBox(validationMsg, , "OK Iconx")
        ExitApp(1)
    }

    if (pollingIntervalMs < 1000)
    {
        validationMsg .=  Format("WARNING: The configured POLLING_INTERVAL_MS ({1}ms) is below 1000ms! This can significantly increase CPU usage and put a strain on your system's resources!`nWould you like to continue?", pollingIntervalMs)
        userInput := MsgBox(validationMsg, , "YesNo Default2 Icon!")
        if (userInput = "No")
        {
            ExitApp(0)
        }
    }

    activeWindowTimeoutMs := globals["config"]["ACTIVE_WINDOW_TIMEOUT_MS"]
    configMsg := "Invalid configurations:`n"
    if (pollingIntervalMs > activeWindowTimeoutMs)
    {
        configMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) > ACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, activeWindowTimeoutMs)
        configMsg .= "Polling interval must be lower than this setting!`n`n"
        isConfigPass := false
    }

    if (activeWindowTimeoutMs < 3000)
    {
        configMsg .=  Format("- ACTIVE_WINDOW_TIMEOUT_MS ({1}ms)`n", activeWindowTimeoutMs)
        configMsg .= "Must be at least 3000ms!`n`n"
        isConfigPass := false
    }

    if (!isDivisible(activeWindowTimeoutMs, pollingIntervalMs))
    {
        configMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) is not divisible by ACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, activeWindowTimeoutMs)
        configMsg .=  Format("A monitored window can be detected {1}ms late!`n", calculateExcessTime(activeWindowTimeoutMs, pollingIntervalMs))
        configMsg .= "Consider adjusting the polling interval and timeout value`n`n"
        sConfigPass := false
    }

    inactiveWindowTimeoutMs := globals["config"]["INACTIVE_WINDOW_TIMEOUT_MS"]
    if (pollingIntervalMs > inactiveWindowTimeoutMs)
    {
        configMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) > INACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, inactiveWindowTimeoutMs)
        configMsg .= "Polling interval must be lower than this setting!`n`n"
        isConfigPass := false
    }

    if (inactiveWindowTimeoutMs < 3000)
    {
        configMsg .=  Format("- INACTIVE_WINDOW_TIMEOUT_MS ({1}ms)`n", inactiveWindowTimeoutMs)
        configMsg .= "Must be at least 3000ms!`n`n"
        isConfigPass := false
    }

    if (!isDivisible(inactiveWindowTimeoutMs, pollingIntervalMs))
    {
        configMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) is not divisible by INACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, inactiveWindowTimeoutMs)
        configMsg .=  Format("An inactive window can be detected {1}ms late!`n", calculateExcessTime(inactiveWindowTimeoutMs, pollingIntervalMs))
        configMsg .= "Consider adjusting the polling interval and timeout value`n`n"
        isConfigPass := false
    }

    overridesMsg := "Invalid overrides:`n"
    for process_name, process in globals["config"]["PROCESS_OVERRIDES"]
    {
        overrides := process["overrides"]
        overridesMsg .= "[" process_name "]`n"

        overrideActive := overrides["ACTIVE_WINDOW_TIMEOUT_MS"]
        if (overrides.Has("ACTIVE_WINDOW_TIMEOUT_MS") && (pollingIntervalMs > overrideActive))
        {
            overridesMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) > ACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, overrideActive)
            overridesMsg .= "Polling interval must be lower than this override!`n`n"
            isOverridePass := false
        }

        if (overrides.Has("ACTIVE_WINDOW_TIMEOUT_MS") && !isDivisible(overrideActive, pollingIntervalMs))
        {
            overridesMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) is not divisible by ACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, overrideActive)
            overridesMsg .=  Format("A monitored window can be detected {1}ms late!`n", calculateExcessTime(overrideActive, pollingIntervalMs))
            overridesMsg .= "Consider adjusting the polling interval and timeout value`n`n"
            isOverridePass := false
        }

        overrideInactive := overrides["INACTIVE_WINDOW_TIMEOUT_MS"]
        if (overrides.Has("INACTIVE_WINDOW_TIMEOUT_MS") && (pollingIntervalMs > overrideInactive))
        {
            overridesMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) > INACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, overrideInactive)
            overridesMsg .= "Polling interval must be lower than this override!`n`n"
            isOverridePass := false
        }

        if (overrides.Has("INACTIVE_WINDOW_TIMEOUT_MS") && !isDivisible(overrideInactive, pollingIntervalMs))
        {
            overridesMsg .=  Format("- POLLING_INTERVAL_MS ({1}ms) is not divisible by INACTIVE_WINDOW_TIMEOUT_MS ({2}ms)`n", pollingIntervalMs, overrideInactive)
            overridesMsg .=  Format("An inactive window can be detected {1}ms late!`n", calculateExcessTime(overrideInactive, pollingIntervalMs))
            overridesMsg .= "Consider adjusting the polling interval and timeout value`n`n"
            isOverridePass := false
        }

        if (isOverridePass)
        {
            overridesMsg := "Invalid overrides:`n"
        }
    }

    if (!isConfigPass)
    {
        invalidsMsg .= configMsg
    }

    if (!isOverridePass)
    {
        invalidsMsg .= overridesMsg
    }

    ; If any validation fails, show the invalid values in the message box and exit the app
    if (!isConfigPass || !isOverridePass)
    {
        validationMsg := "ERROR: Invalid values detected, the script is unable to proceed!`n"
        validationMsg .= "Please review and adjust the following values accordingly.`n`n"
        validationMsg .= invalidsMsg
        MsgBox(validationMsg, , "OK Iconx")
        ; Since this script is not that big, I don't want to make another condition for its returned values, exit right away instead
        ExitApp(1)
    }

    ; If all conditions have passed
    return true
}

requestElevation()
{
    ; Ran as admin already, do nothing
    if (A_IsAdmin)
    {
        return
    }

    isAdminRequire := globals["config"]["TASK_INPUT_BLOCK"]
    for , process in globals["config"]["PROCESS_OVERRIDES"]
    {
        if (process["overrides"].Has("TASK_INPUT_BLOCK") && process["overrides"]["TASK_INPUT_BLOCK"])
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
    MsgBox("Unable to block keystrokes. This requires Anti-AFK to be ran as administrator to block inputs!`nBLOCK_INPUT has been temporarily disabled.",
        ,
        "OK Icon!"
    )
}

updateSystemTray(processes)
{
    monitoredWindows := globals["states"]["tray"]["counters"]["monitored"]
    managedWindows := globals["states"]["tray"]["counters"]["managed"]
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
                ; Count how many of those are are active and inactive
                for , window in windows
                {
                    windowStatus := window["status"]
                    if (windowStatus = "ACTIVE")
                    {
                        monitoredWindows[process_name] += 1
                    }
                    else if (windowStatus = "INACTIVE")
                    {
                        managedWindows[process_name] += 1
                    }
                }

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
    ; None of the monitored processes are running, clear all the counters
    else
    {
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
            for process_name, counter in managedWindows
            {
                tooltipText .= Format("{1} - {2} windows(s)`n", process_name, counter)
            }

            tooltipText .= "`nMonitoring:`n"
            for process_name, counter in monitoredWindows
            {
                tooltipText .= Format("{1} - {2} windows(s)`n", process_name, counter)
            }

            tooltipText := RTrim(tooltipText, "`n")
        }
        ; There are only managed windows
        else
        {
            tooltipText := "Managing:`n"
            for process_name, counter in managedWindows
            {
                tooltipText .= Format("{1} - {2} windows(s)`n", process_name, counter)
            }

            tooltipText := RTrim(tooltipText, "`n")
        }
    }
    ; There are only monitored windows
    else if (monitoredWindows.Count > 0)
    {
        iconNumber := 3
        tooltipText := "Monitoring:`n"
        for process_name, counter in monitoredWindows
        {
            tooltipText .= Format("{1} - {2} windows(s)`n", process_name, counter)
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
    if (iconNumber != globals["states"]["tray"]["lastIconNumber"])
    {
        TraySetIcon(A_AhkPath, iconNumber)
        globals["states"]["tray"]["lastIconNumber"] := iconNumber
    }

    ; Update the tooltip only if it has changed
    if (tooltipText != globals["states"]["tray"]["lastIconTooltipText"])
    {
        A_IconTip := tooltipText
        globals["states"]["tray"]["lastIconTooltipText"] := tooltipText
    }
}

blockUserInput(option, isInputBlock)
{
    if (!isInputBlock || !A_IsAdmin)
    {
        return
    }

    BlockInput(option)
    logDebug("@blockUserInput: {1} successful!", option)
}

getWindow(windowInfo, fallbackWindow)
{
    ; Window info is empty, use the fallbackWindow right away
    if (!windowInfo.Count || !windowInfo)
    {
        return fallbackWindow
    }

    windowId := Format("ahk_id {1}", windowInfo["ID"])
    process_id := Format("ahk_pid {1}", windowInfo["PID"])
    process_name := Format("ahk_exe {1}", windowInfo["EXE"])
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
        logDebug("[Window: {1}] Failed to retrieve window info! Window does not exist!", window)
        return windowInfo
    }

    windowInfo["ID"] := WinGetID(window)
    windowInfo["CLS"] := WinGetClass(window)
    windowInfo["PID"] := WinGetPID(window)
    windowInfo["EXE"] := WinGetProcessName(window)
    windowInfo["TITLE"] := WinGetTitle(window)
    return windowInfo
}

activateWindow(window)
{
    if (!WinExist(window))
    {
        logDebug("[Window: {1}] Failed to activate! Window does not exist!", window)
        return false
    }

    if (!isWindowTargetable(window))
    {
        logDebug("[Window: {1}] Failed to activate! Window is not targetable!", window)
        return false
    }

    WinActivate(window)
    value := WinWaitActive(window, , 0.30)
    if (value = 0)
    {
        logDebug("[Window: {1}] Failed to activate! Window timed out!", window)
        return false
    }

    logDebug("[Window: {1}] Window successfully activated!", window)
    return true
}

; Find and return a specific attribute for a process, prioritising values in PROCESS_OVERRIDES.
; If an override has not been setup for that process, the default value from the configuration for all processes will be used instead.
getAttributeValue(attributeName, process_name)
{
    processOverrides := globals["config"]["PROCESS_OVERRIDES"]
    if (processOverrides.Has(process_name))
    {
        if (processOverrides[process_name]["overrides"].Has(attributeName))
        {
            return processOverrides[process_name]["overrides"][attributeName]
        }
    }
    return globals["config"][attributeName]
}

; Checks if a window is targetable
; tysm! https://stackoverflow.com/questions/35971452/what-is-the-right-way-to-send-alt-tab-in-ahk/36008086#36008086
; Helps filtering out the windows the script should not interact with
isWindowTargetable(window)
{
    ; https://www.autohotkey.com/docs/v2/misc/Styles.htm
    windowStyle := WinGetStyle(window)
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

    windowExtendedStyle := WinGetExStyle(window)
    ; Windows with WS_EX_TOOLWINDOW (0x00000080)
    ; https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
    ; Tool windows are often small floating windows (like toolbars) and are usually not primary windows
    if (windowExtendedStyle & 0x00000080)
    {
        return false
    }

    windowCLS := WinGetClass(window)
    ; Windows with the class "TApplication"
    ; These are often Delphi or VCL-based windows, typically representing non-primary windows
    if (windowCLS = "TApplication")
    {
        return false
    }

    ; Common class for dialog boxes or dialog windows
    ; https://learn.microsoft.com/en-us/windows/win32/winmsg/about-window-classes
    ; Windows with the class "#32770"
    ; This class represents dialog boxes, such as 'Open' or 'Save As' dialogs
    if (windowCLS = "#32770")
    {
        return false
    }

    ; Windows with the class "ComboLBox"
    ; This class represents the dropdown list portion of a combo box
    ; These are not standalone windows and are part of other UI elements
    if (windowCLS = "ComboLBox")
    {
        return false
    }

    ; Windows with the class "Windows.UI.Core.CoreWindow"
    ; The action center, date and time info, start menu, and search all belong on this class
    ; These should not be interacted by the script in any way
    if (windowCLS = "Windows.UI.Core.CoreWindow")
    {
        return false
    }

    return true
}

showTraytip(text, title, options, duration)
{
    TrayTip(text, title, options)
    SetTimer(TrayTip, duration)
}

performProcessTask(windowId, invokeProcessTask, isInputBlock)
{
    isWindowActivateSucess := false
    activeWindow := "A"
    monitoredWindowInfo := getWindowInfo(Format("ahk_id {1}", windowId))
    logDebug("[{1}] [Window ID: {2}] @performProcessTask: STARTED", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
    monitoredWindow := Format("ahk_id {1}", monitoredWindowInfo["ID"])
    logDebug("[Monitored Window INFO] : [CLS: {1}] [ID: {2}] [PID: {3}] [EXE: {4}]", monitoredWindowInfo["CLS"], monitoredWindowInfo["PID"], monitoredWindowInfo["ID"], monitoredWindowInfo["EXE"])

    ; User is PRESENT on the monitored window, perform the task right away
    if (WinActive(monitoredWindow))
    {
        invokeProcessTask()
        logDebug("[{1}] [Window ID: {2}] Active Monitored Window invokeProcessTask() successful!", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
        logDebug("[{1}] [Window ID: {2}] @performProcessTask: FINISHED", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
        return
    }

    activeWindowInfo := getWindowInfo(activeWindow)
    oldActiveWindow := !activeWindowInfo.Count ? "" : getWindow(
        activeWindowInfo,
        monitoredWindow
    )
    try
    {
        ; User is ABSENT on any window / User is PRESENT on the Desktop.
        ; Bringing the Desktop window back to the front can cause some scaling issues, so we ignore it.
        ; The Desktop's window has a class of "WorkerW" or "Progman"
        if (!activeWindowInfo.Count || (activeWindowInfo["CLS"] = "WorkerW" || activeWindowInfo["CLS"] = "Progman"))
        {
            WinSetTransparent(0, monitoredWindow)
            isWindowActivateSucess := activateWindow(monitoredWindow)
            if (!isWindowActivateSucess)
            {
                logDebug("[{1}] [Window ID: {2}] Inactive Monitored Window invokeProcessTask() failed!", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
                showTraytip(Format("The script has failed to perform a task to {1}'s monitored window: '{2}' ({3})", monitoredWindowInfo["EXE"], monitoredWindowInfo["TITLE"], monitoredWindowInfo["ID"]), "Anti-AFK has failed to perform a process' task", "Iconx", -35000)
                return
            }
            invokeProcessTask()
            WinMoveBottom(monitoredWindow)
            logDebug("[{1}] [Window ID: {2}] Inactive Monitored Window invokeProcessTask() successful!", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
            return
        }

        logDebug("[Active Window INFO] : [CLS: {1}] [ID: {2}] [PID: {3}] [EXE: {4}]", activeWindowInfo["CLS"], activeWindowInfo["PID"], activeWindowInfo["ID"], activeWindowInfo["EXE"])

        ; User is PRESENT on these kind of Windows: Action center / Date and time information / Start Menu / Search
        ; Simply activating the monitored window will not work, the taskbar icons of the monitored window will flash, indicating that it's not activated.
        ; The script needs to be ran with UI access to activate other windows while the user is active on those Windows UI Core windows.
        if (activeWindowInfo["CLS"] = "Windows.UI.Core.CoreWindow")
        {
            logDebug("[{1}] [Window ID: {2}] Active Window is a Windows UI Core window", activeWindowInfo["EXE"], activeWindowInfo["ID"])
            ; Todo: Add a statement to check if the script is ran with UI access or not to skip this work around.
            ; Alt + Tab the user out from those kind of Windows as a workaround
            Send("{Alt Down}{Tab Up}{Tab Down}")
            Sleep(500)
            Send("{Alt Up}")
            showTraytip(Format("For the monitored windows to activate, Anti-AFK has Alt + Tabbed you out from a Windows UI Core window: '{1}' ({2})", activeWindowInfo["TITLE"], activeWindowInfo["ID"]), "Anti-AFK has Alt + Tabbed you out from a Windows UI Core window", "Icon!", -35000)
            showTraytip("Being active on a Windows UI Core window while the script performs a task can hinder the activation of the monitored window.", "Anti-AFK Notice", "Iconi", -35000)
        }

        ; User is ABSENT on the monitored window
        ; Try to activate the monitored window before performing the task
        blockUserInput("On", isInputBlock)
        WinSetTransparent(0, monitoredWindow)
        isWindowActivateSucess := activateWindow(monitoredWindow)

        ; User is still PRESENT on the old active window
        ; after the monitored window activation attempt,
        ; do not perform the task as the input from the task can leak
        ; into whatever the user is currently doing on other windows
        if (WinActive(oldActiveWindow) || !isWindowActivateSucess)
        {
            logDebug("[{1}] [Window ID: {2}] Inactive Monitored Window invokeProcessTask() failed!", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
            WinSetTransparent("Off", monitoredWindow)
            showTraytip(Format("The script has failed to perform a task to {1}'s monitored window: '{2}' ({3})", monitoredWindowInfo["EXE"], monitoredWindowInfo["TITLE"], monitoredWindowInfo["ID"]), "Anti-AFK has failed to perform a process' task", "Iconx", -35000)
            return
        }

        invokeProcessTask()
        WinMoveBottom(monitoredWindow)
        logDebug("[{1}] [Window ID: {2}] Inactive Monitored Window invokeProcessTask() successful!", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
    }
    finally
    {
        ; These serve as fail saves. I don't want to put them in the try clause
        ; because if something goes wrong and gets stuck,
        ; the windows will operate fine at the end and not get caught in the hang
        if (WinGetTransparent(monitoredWindow) = 0)
        {
            WinSetTransparent("Off", monitoredWindow)
        }

        if ((oldActiveWindow != "") && !WinActive(oldActiveWindow))
        {
            activateWindow(oldActiveWindow)
        }

        blockUserInput("Off", isInputBlock)
        logDebug("[{1}] [Window ID: {2}] @performProcessTask#finally: FINISHED", monitoredWindowInfo["EXE"], monitoredWindowInfo["ID"])
    }
}

getTimeoutpolls(timeoutMs)
{
    return Max(1, Ceil(timeoutMs / globals["config"]["POLLING_INTERVAL_MS"]))
}

setNewWindowStatus(window, status, polls, pollsOnly := false)
{
    if (pollsOnly)
    {
        window["polls"] := polls
        return
    }
    window["status"] := status
    window["polls"] := polls
}

registerWindows(windows, process_name)
{
    monitoredProcess := Format("ahk_exe {1}", process_name)
    ; No windows found under this process, return the windows map immediately as empty in that case
    if (WinGetCount(monitoredProcess) < 1)
    {
        return windows
    }

    inactiveWindowTimeoutPolls := getTimeoutpolls(getAttributeValue("INACTIVE_WINDOW_TIMEOUT_MS", process_name))
    ; Retrieve all found unique ids (HWNDs) for this process' windows
    windowIds := WinGetList(monitoredProcess)
    ; For every window id found under this process
    for , windowId in windowIds
    {
        ; This window is not targetable, do not set a map for this window id, skip it
        if (!isWindowTargetable(Format("ahk_id {1}", windowId)))
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
        logDebug("[{1}] [Window ID: {2}] Created window map", process_name, windowId)
        ; Initially mark it as CREATED
        setNewWindowStatus(windows[windowId], "CREATED", inactiveWindowTimeoutPolls)
    }

    ; After setting up all windows that have met the conditions, return the populated windows map
    return windows
}

monitorWindows(windows, process_name)
{
    inactiveWindowTimeoutPolls := getTimeoutpolls(getAttributeValue("INACTIVE_WINDOW_TIMEOUT_MS", process_name))
    activeWindowTimeoutMs := getAttributeValue("ACTIVE_WINDOW_TIMEOUT_MS", process_name)
    invokeProcessTask := getAttributeValue("PROCESS_TASK", process_name)
    isInputBlock := getAttributeValue("TASK_INPUT_BLOCK", process_name)

    ; For every window in this process' windows
    for windowId, window in windows
    {
        monitoredWindow := Format("ahk_id {1}", windowId)
        ; This monitored window no longer exists, most likely closed by the user, delete it from the windows map
        if (!WinExist(monitoredWindow))
        {
            logDebug("[{1}] [Window ID: {2}] Deleted window map as it was closed by the user!", process_name, windowId)
            windows.Delete(windowId)
            continue
        }

        isWindowActive := WinActive(monitoredWindow)
        ; User is PRESENT in this monitored window
        ; User is NOT IDLING in this monitored window for less than or equal to the configured ACTIVE_WINDOW_TIMEOUT_MS
        if (isWindowActive && (A_TimeIdlePhysical <= activeWindowTimeoutMs))
        {
            ; User is present on an ACTIVE marked window's 
            ; and its polls has already been reset, reset only its polls
            if ((window["polls"] = inactiveWindowTimeoutPolls) && (window["status"] = "ACTIVE"))
            {
                setNewWindowStatus(window, "ACTIVE", inactiveWindowTimeoutPolls, true)
                continue
            }
            ; User is present on an INACTIVE marked window or its polls is not yet reset
            ; Reset its polls and mark it as ACTIVE again
            setNewWindowStatus(window, "ACTIVE", inactiveWindowTimeoutPolls)
            logDebug("[{1}] [Window ID: {2}] Active Monitored Window: User is NOT IDLE!", process_name, windowId)
            continue
        }

        ; User is PRESENT in this monitored window
        ; User is IDLING in this monitored window for more than or equal to the configured ACTIVE_WINDOW_TIMEOUT_MS
        if (isWindowActive && (window["status"] = "ACTIVE"))
        {
            setNewWindowStatus(window, "INACTIVE", 1, true)
            logDebug("[{1}] [Window ID: {2}] Active Monitored Window: User is IDLE!", process_name, windowId)
        }

        ; User is ABSENT in this monitored window, they're present in a different window
        window["polls"] -= 1
        logDebug("[{1}] [Window ID: {2}] {3} / {4} polls remaining", process_name, windowId, window["polls"], inactiveWindowTimeoutPolls)

        ; This monitored window's been inactive for more than or equal to the configured INACTIVE_WINDOW_TIMEOUT_MS
        if (window["polls"] = 0)
        {
            setNewWindowStatus(window, "INACTIVE", inactiveWindowTimeoutPolls)
            performProcessTask(windowId, invokeProcessTask, isInputBlock)
        }
    }
    ; Monitoring operations END here
}

registerProcesses(processes, monitorList)
{
    ; For every process name configured by the user in the monitor list
    for , process_name in monitorList
    {
        ; User is not running this process from the monitor list, do not reset
        if (!ProcessExist(process_name))
        {
            continue
        }

        ; This process already has a map, do not reset
        if (processes.has(process_name))
        {
            continue
        }

        ; In the processes map, set a new map for this process name
        processes[process_name] := Map()
        ; and also with an empty windows map
        processes[process_name]["windows"] := Map()
        logDebug("[{1}] Created process map", process_name)
    }

    ; After setting up the processes that have met the conditions, return the populated processes map
    return processes
}

monitorProcesses()
{
    ; Monitoring operations START here
    processes := registerProcesses(globals["states"]["processes"], globals["config"]["MONITOR_LIST"])
    if (processes.Count > 0)
    {
        for process_name, process in processes
        {
            ; This monitored process no longer exists, most likely closed by the user, delete it from the processes map
            if (!ProcessExist(process_name))
            {
                logDebug("[{1}] Deleted process map as it was closed by the user!", process_name)
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
; Both of these exist for the simulated key presses in the task to not interfere with the script's timers.
; One of those timers is A_TimeIdlePhysical
InstallKeybdHook(true)
InstallMouseHook(true)
KeyHistory(0)
globals["states"] := Map()
globals["states"]["processes"] := Map()
globals["states"]["tray"] := Map()
globals["states"]["tray"]["lastIconNumber"] := 0
globals["states"]["tray"]["lastIconTooltipText"] := ""
globals["states"]["tray"]["counters"] := Map()
globals["states"]["tray"]["counters"]["monitored"] := Map()
globals["states"]["tray"]["counters"]["managed"] := Map()
; Initiate the first poll
monitorProcesses()
; Monitor the processes again according to what's configured as its polling interval
SetTimer(monitorProcesses, globals["config"]["POLLING_INTERVAL_MS"])
