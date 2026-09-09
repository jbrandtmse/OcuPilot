/// <p>Direct test host for <class>OcuPilot.Kernel.Audit.Log</class> — until this story,
/// the class had none: every existing call to it (from <class>OcuPilot.Api.Error</class>'s
/// <method>RenderInternal</method>) is exercised only indirectly, and nothing asserted
/// against <class>OcuPilot.Kernel.Audit.Log</class> itself. Pins the class's own stated
/// contract — "never throwing and never failing its caller" — for all four levels, with
/// and without a structured <var>pData</var> object, plus the exact Severity/Flag mapping
/// <method>OcuPilot.Kernel.Audit.Log.ResolveSeverityAndFlag</method> hands to
/// <code>%SYS.System.WriteToConsoleLog</code> (mutation: an earlier version of
/// <method>OcuPilot.Kernel.Audit.Log.Emit</method> passed these two arguments swapped
/// directly into <code>$ZU(9,...)</code>, which hardcoded every log line's severity to 1
/// (Warning); <method>TestSeverityAndFlagMapping</method> below goes red against that
/// specific mutation — swap the two <code>Set</code> targets in
/// <method>ResolveSeverityAndFlag</method> back and watch it fail).</p>
Class OcuPilot.Test.Log Extends %UnitTest.TestCase
{

/// <p>Pins the exact (severity, flag) pair for each of the four levels — the specific
/// mapping whose two halves were once passed to the underlying console-log call swapped.
/// Debug is asserted separately from Info specifically because an earlier version of
/// <method>OcuPilot.Kernel.Audit.Log.Emit</method> gave both the same severity, collapsing
/// two of the class's four levels into one in <code>messages.log</code>.</p>
Method TestSeverityAndFlagMapping()
{
    Do ##class(OcuPilot.Kernel.Audit.Log).ResolveSeverityAndFlag("info", .tSeverity, .tFlag)
    Do $$$AssertEquals(tSeverity, 0, "info maps to Severity=0 (Information)")
    Do $$$AssertEquals(tFlag, 0, "info is not echoed to the operator console")

    Do ##class(OcuPilot.Kernel.Audit.Log).ResolveSeverityAndFlag("debug", .tSeverity, .tFlag)
    Do $$$AssertEquals(tSeverity, -1, "debug maps to Severity=-1 (Debug), distinct from info's 0")
    Do $$$AssertEquals(tFlag, 0, "debug is not echoed to the operator console")

    Do ##class(OcuPilot.Kernel.Audit.Log).ResolveSeverityAndFlag("warn", .tSeverity, .tFlag)
    Do $$$AssertEquals(tSeverity, 1, "warn maps to Severity=1 (Warning)")
    Do $$$AssertEquals(tFlag, 1, "warn is echoed to the operator console")

    Do ##class(OcuPilot.Kernel.Audit.Log).ResolveSeverityAndFlag("error", .tSeverity, .tFlag)
    Do $$$AssertEquals(tSeverity, 2, "error maps to Severity=2 (Severe)")
    Do $$$AssertEquals(tFlag, 1, "error is echoed to the operator console")
}

/// <p>Pins the <b>call site</b>, not the lookup: asserts the values
/// <method>OcuPilot.Kernel.Audit.Log.Emit</method> actually hands to
/// <code>%SYS.System.WriteToConsoleLog</code>, in
/// <code>(Message, Flag, Severity, Event)</code> order, captured through
/// <class>OcuPilot.Test.LogProbe</class>'s override of the
/// <method>OcuPilot.Kernel.Audit.Log.WriteConsole</method> seam.</p>
/// <p><b>Why this test exists separately from
/// <method>TestSeverityAndFlagMapping</method>:</b> the original defect was Flag and
/// Severity passed to the console call swapped. Re-applying that swap at the call site
/// (<code>Emit</code>'s <code>WriteConsole</code> line) leaves the mapping test — and the
/// entire rest of the suite — green, because the mapping itself is still correct. Only an
/// assertion on the arguments as passed can fail against it. Mutation: swap
/// <var>tFlag</var> and <var>tSeverity</var> in
/// <method>OcuPilot.Kernel.Audit.Log.Emit</method>'s <code>WriteConsole</code> call and
/// the error and warn assertions below go red.</p>
Method TestEmitPassesFlagAndSeverityInThatOrder()
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Error("router", "an error line")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("flag"), 1, "error passes Flag=1 in the Flag position")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), 2, "error passes Severity=2 in the Severity position")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("event"), "OcuPilot.Log", "the console event name is OcuPilot.Log")
    Do $$$AssertTrue((##class(OcuPilot.Test.LogProbe).Captured("message") [ "[OcuPilot] "), "the message carries the [OcuPilot] line prefix")

    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Warn("router", "a warn line")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("flag"), 1, "warn passes Flag=1 in the Flag position")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), 1, "warn passes Severity=1 in the Severity position")

    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Debug("router", "a debug line")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("flag"), 0, "debug passes Flag=0 in the Flag position")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), -1, "debug passes Severity=-1 in the Severity position")

    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>Every level, called with only the required arguments, returns without throwing.</p>
Method TestAllLevelsNeverThrowWithoutData()
{
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Log).Info("test", "info message, no data")
        Do ##class(OcuPilot.Kernel.Audit.Log).Warn("test", "warn message, no data")
        Do ##class(OcuPilot.Kernel.Audit.Log).Error("test", "error message, no data")
        Do ##class(OcuPilot.Kernel.Audit.Log).Debug("test", "debug message, no data")
        Do $$$AssertTrue(1, "all four levels returned without throwing")
    } Catch ex {
        Do $$$AssertTrue(0, "a logging call must never throw: " _ ex.DisplayString())
    }
}

/// <p>Every level, called with a structured <var>pData</var> object, still returns without
/// throwing — the class's own contract ("never failing its caller") holds regardless of
/// whether a caller supplies detail, matching how <method>OcuPilot.Api.Error.RenderInternal</method>
/// calls <method>Error</method> with a <class>%DynamicObject</class> detail payload.</p>
Method TestAllLevelsNeverThrowWithData()
{
    Set tData = {"detail": ("some exception text"), "n": (42)}
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Log).Info("test", "info message, with data", tData)
        Do ##class(OcuPilot.Kernel.Audit.Log).Warn("test", "warn message, with data", tData)
        Do ##class(OcuPilot.Kernel.Audit.Log).Error("test", "error message, with data", tData)
        Do ##class(OcuPilot.Kernel.Audit.Log).Debug("test", "debug message, with data", tData)
        Do $$$AssertTrue(1, "all four levels returned without throwing when given structured data")
    } Catch ex {
        Do $$$AssertTrue(0, "a logging call with data must never throw: " _ ex.DisplayString())
    }
}

/// <p>A pathological subsystem/message (embedded quotes, backslashes, non-ASCII) must not
/// make <method>Emit</method> throw — the JSON-building and console-log-writing steps must
/// both tolerate arbitrary caller text, since <method>RenderInternal</method> feeds it
/// exception text it does not control.</p>
Method TestPathologicalMessageNeverThrows()
{
    Set tMsg = "quote:" _ """" _ " backslash:\ newline:" _ $Char(10) _ " café"
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Log).Error("router", tMsg)
        Do $$$AssertTrue(1, "a pathological message returned without throwing")
    } Catch ex {
        Do $$$AssertTrue(0, "a pathological message must never throw: " _ ex.DisplayString())
    }
}

}
