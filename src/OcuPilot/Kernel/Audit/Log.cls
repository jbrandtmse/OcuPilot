/// <p>Structured logging for OcuPilot.</p>
/// <p>One line per event, JSON payload, prefixed <code>[OcuPilot]</code> so log
/// aggregation can filter on it. Writes to the IRIS console log via the documented
/// <class>%SYS.System</class> wrapper, <method>WriteToConsoleLog</method> — not the raw,
/// undocumented <code>$ZUTIL(9,...)</code> call it wraps, and not by guessing that call's
/// positional argument order: verified against the live instance's own implementation
/// (<code>irissys/%SYS/System.cls</code>), <code>WriteToConsoleLog</code> calls
/// <code>$zu(9,"",Message,Flag,Severity,Event)</code> — <b>Flag before Severity</b>.</p>
/// <p>Every emitting method wraps in <code>Try</code>/<code>Catch</code> so a logging
/// failure never propagates to the caller — logging is informational and must not
/// affect application behavior (Consistency Conventions: Logging).</p>
Class OcuPilot.Kernel.Audit.Log Extends %RegisteredObject
{

/// <p>Emit a structured log entry at INFO level.</p>
ClassMethod Info(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("info", pSubsystem, pMessage, pData)
}

/// <p>Emit a structured log entry at WARN level.</p>
ClassMethod Warn(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("warn", pSubsystem, pMessage, pData)
}

/// <p>Emit a structured log entry at ERROR level.</p>
ClassMethod Error(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("error", pSubsystem, pMessage, pData)
}

/// <p>Emit a structured log entry at DEBUG level.</p>
ClassMethod Debug(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("debug", pSubsystem, pMessage, pData)
}

/// <p>Build the JSON log entry and write it to the IRIS console log. Never throws —
/// a failure here is swallowed rather than raised to the caller.</p>
ClassMethod Emit(pLevel As %String, pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "") [ Private ]
{
    Try {
        Set tEntry = {}
        Do tEntry.%Set("ts", ..FormatTimestamp())
        Do tEntry.%Set("level", pLevel)
        Do tEntry.%Set("subsystem", pSubsystem)
        Do tEntry.%Set("msg", pMessage)
        If $IsObject(pData) {
            Do tEntry.%Set("data", pData)
        }
        Set tLogLine = "[OcuPilot] " _ tEntry.%ToJSON()
        Do ..ResolveSeverityAndFlag(pLevel, .tSeverity, .tFlag)
        Do ##class(%SYS.System).WriteToConsoleLog(tLogLine, tFlag, tSeverity, "OcuPilot.Log")
    } Catch ex {
        ; Logging failures must never propagate.
    }
}

/// <p>Map <var>pLevel</var> to the <var>pSeverity</var> / <var>pFlag</var> pair
/// <method>%SYS.System.WriteToConsoleLog</method> expects, in <b>that argument order</b>
/// (<code>WriteToConsoleLog(Message, Flag, Severity, Event)</code>) — verified against the
/// live instance's own implementation (<code>irissys/%SYS/System.cls</code>), which calls
/// <code>$zu(9,"",Message,Flag,Severity,Event)</code>, Flag before Severity. Split out as
/// its own pure method specifically so a test can pin the mapping without writing to the
/// console log: an earlier version of <method>Emit</method> passed these two arguments to
/// <code>$ZU(9,...)</code> swapped, which put every OcuPilot log line's severity value into
/// the flag slot and hardcoded severity to 1 (Warning) for everything — a defect this
/// method's own test (<class>OcuPilot.Test.Log</class>) now pins directly.</p>
/// <p>Severity follows <code>WriteToConsoleLog</code>'s own scale (-1 Debug, 0 Information,
/// 1 Warning, 2 Severe); <code>"debug"</code> maps to Debug rather than sharing
/// Information's severity, so the four levels <class>OcuPilot.Kernel.Audit.Log</class>
/// exposes remain four distinct severities in <code>messages.log</code>, not three.
/// <var>pFlag</var> is set only for <code>warn</code>/<code>error</code>, so only those two
/// levels are echoed to the operator console as well as the log file.</p>
/// <p>Public (unlike <method>Emit</method>) specifically so <class>OcuPilot.Test.Log</class>
/// can pin this mapping directly — it is a pure, side-effect-free lookup, safe to expose.</p>
ClassMethod ResolveSeverityAndFlag(pLevel As %String, Output pSeverity As %Integer, Output pFlag As %Integer)
{
    Set pSeverity = 0
    Set pFlag = 0
    If pLevel = "debug" {
        Set pSeverity = -1
    } ElseIf pLevel = "warn" {
        Set pSeverity = 1
        Set pFlag = 1
    } ElseIf pLevel = "error" {
        Set pSeverity = 2
        Set pFlag = 1
    }
}

/// <p>ISO-8601 UTC timestamp, e.g. <code>2026-09-09T10:30:45Z</code>
/// (Consistency Conventions: Dates — <code>$ZTimeStamp</code>, never <code>$Horolog</code>
/// or raw <code>$ZDateTime</code>).</p>
ClassMethod FormatTimestamp() As %String [ Private ]
{
    Quit $Translate($ZDateTime($ZTimeStamp, 3, 1), " ", "T") _ "Z"
}

}
