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

/// <p>The backstop redactor: a <var>pData</var> key matching the credential name pattern is
/// masked in the line that would have been written, and every other value survives untouched.</p>
/// <p>Asserted against the <b>emitted line</b> through <class>OcuPilot.Test.LogProbe</class>,
/// not against <method>OcuPilot.Kernel.Audit.Log.Redact</method>'s return value: the claim is
/// that the secret does not reach <code>messages.log</code>, and a redactor wired to nothing
/// would satisfy a direct check of the transform.</p>
/// <p>Mutation: delete the <method>Redact</method> call from
/// <method>OcuPilot.Kernel.Audit.Log.Emit</method> — the transform stays correct, its own
/// direct pin below stays green, and this goes red with the secret in the line.</p>
Method TestCredentialValuesAreMaskedInTheEmittedLine()
{
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tData = {}
    Do tData.%Set("password", "hunter2")
    Do tData.%Set("refresh token", "rt-abcdef")
    Do tData.%Set("ApiKey", "sk-live-xyz")
    Do tData.%Set("user", "_SYSTEM")
    Do tData.%Set("attempts", 3)
    Do ##class(OcuPilot.Test.LogProbe).Error("port", "a call failed", tData)

    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue((tLine '[ "hunter2"), "a password value never reaches the line")
    Do $$$AssertTrue((tLine '[ "rt-abcdef"), "nor a token value")
    Do $$$AssertTrue((tLine '[ "sk-live-xyz"), "nor an API key value")
    Do $$$AssertTrue((tLine [ "[redacted]"), "each is replaced by the mask, so the field is not silently dropped")
    Do $$$AssertTrue((tLine [ "_SYSTEM"), "and an ordinary value is untouched")
    Do $$$AssertTrue((tLine [ "attempts"), "as is a non-string one")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

/// <p>The transform itself, directly: which names match, that a nested object is redacted too,
/// that a non-string value keeps its JSON type, and that the caller's own object is not
/// modified.</p>
/// <p>The last of those is the one a captured-line assertion cannot see. A redactor that masked
/// in place would pass every row of the test above and would have deleted the caller's value —
/// turning a logging concern into data loss in whatever code logged before using the field.</p>
Method TestRedactCopiesRatherThanMasksInPlace()
{
    Set tData = {}
    Do tData.%Set("ClientSecret", "s3cr3t")
    Do tData.%Set("count", 7)
    Do tData.%Set("enabled", 1, "boolean")
    Set tNested = {}
    Do tNested.%Set("Password", "inner")
    Do tNested.%Set("name", "kept")
    Do tData.%Set("detail", tNested)

    Set tOut = ##class(OcuPilot.Kernel.Audit.Log).Redact(tData)

    Do $$$AssertEquals(tOut.ClientSecret, "[redacted]", "a compound credential name matches")
    Do $$$AssertEquals(tOut.detail.Password, "[redacted]", "and one nested inside a detail object does too")
    Do $$$AssertEquals(tOut.detail.name, "kept", "an ordinary nested value survives")
    Do $$$AssertEquals(tOut.count, 7, "a number survives")
    Do $$$AssertEquals(tOut.%GetTypeOf("count"), "number", "and keeps its JSON type rather than becoming a string")
    Do $$$AssertEquals(tOut.%GetTypeOf("enabled"), "boolean", "as does a boolean")

    ; The caller's own object is untouched.
    Do $$$AssertEquals(tData.ClientSecret, "s3cr3t", "the caller still holds its value")
    Do $$$AssertEquals(tData.detail.Password, "inner", "including inside a nested object")
}

/// <p>A nested array stays an array, and its members keep their JSON types.</p>
/// <p>The redactor rebuilds every container it walks, and rebuilding an array as an object
/// re-keys it by its own subscripts: <code>["a","b"]</code> emitted as
/// <code>{"0":"a","1":"b"}</code>, so the log line reports a shape the caller never sent. This
/// is a live path, not a hypothetical --
/// <method>OcuPilot.Install.Installer.Uninstall</method> logs its remaining inventory rows as a
/// pushed array under <code>left</code> — and the earlier test above cannot see it, because it
/// passes only scalars and one nested object.</p>
/// <p>Mutation: replace <method>OcuPilot.Kernel.Audit.Log.EmptyLike</method>'s body with
/// <code>Quit {}</code> — the array rows go red with an object in their place.</p>
Method TestRedactKeepsAnArrayAnArray()
{
    Set tRows = []
    Do tRows.%Push({"kind": "webapp", "name": "/ocupilot", "state": "left"})
    Do tRows.%Push({"kind": "database", "name": "OCUPILOTDEMO", "password": "hunter2"})
    Set tData = {}
    Do tData.%Set("profile", "demo")
    Do tData.%Set("left", tRows)
    Do tData.%Set("count", 2)

    Set tOut = ##class(OcuPilot.Kernel.Audit.Log).Redact(tData)

    Do $$$AssertEquals($ClassName(tOut.left), "%Library.DynamicArray", "the array is still an array")
    Do $$$AssertEquals(tOut.left.%Size(), 2, "with both members")
    Do $$$AssertEquals(tOut.left.%Get(0).name, "/ocupilot", "an ordinary member survives")
    Do $$$AssertEquals(tOut.left.%Get(1).password, "[redacted]", "and a credential inside one is still masked")
    Do $$$AssertEquals(tOut.count, 2, "a sibling scalar is untouched")
    Do $$$AssertEquals(tOut.%GetTypeOf("count"), "number", "and keeps its JSON type")

    ; The emitted line is what actually reaches messages.log, so the shape is asserted there too.
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Warn("install", "uninstall stopped", tData)
    Set tLine = ##class(OcuPilot.Test.LogProbe).Captured("message")
    Do $$$AssertTrue((tLine [ """left"":["), "the emitted line carries a JSON array, not an object")
    Do $$$AssertTrue((tLine '[ """0"":"), "so no member is re-keyed by its own subscript")
    Do $$$AssertTrue((tLine '[ "hunter2"), "and the credential inside it never reaches the line")
    Do ##class(OcuPilot.Test.LogProbe).Clear()

    ; The caller's own array is untouched, exactly as its object is.
    Do $$$AssertEquals(tData.left.%Get(1).password, "hunter2", "the caller still holds its value")
}

/// <p>A <b>sparse</b> array keeps its holes and its indices. The dense case above cannot see
/// this: <method>%GetIterator</method> skips an array's unassigned elements, so a redactor that
/// rebuilt one with <method>%Push</method> closed the gaps up and moved every surviving member
/// down — <code>["a",,,"z"]</code> came back as <code>["a","z"]</code>, which is the same "the
/// log line reports a shape the caller never sent" the array rule exists to prevent, one level
/// further in. Reproduced on the instance before the fix.</p>
/// <p>Mutation (Rule 19): write the array branch back as
/// <code>Do tOut.%Push(tValue, pData.%GetTypeOf(tKey))</code> → the size and index assertions
/// below go red while <method>TestRedactKeepsAnArrayAnArray</method> stays green.</p>
Method TestRedactKeepsASparseArraySparse()
{
    Set tSparse = []
    Do tSparse.%Push("a")
    Do tSparse.%Set(3, "z")
    Set tData = {}
    Do tData.%Set("left", tSparse)

    Set tOut = ##class(OcuPilot.Kernel.Audit.Log).Redact(tData)

    Do $$$AssertEquals($ClassName(tOut.left), "%Library.DynamicArray", "still an array")
    Do $$$AssertEquals(tOut.left.%Size(), 4, "and still four elements long, holes included")
    Do $$$AssertEquals(tOut.left.%Get(0), "a", "the first member keeps index 0")
    Do $$$AssertEquals(tOut.left.%Get(3), "z", "and the last keeps index 3 rather than moving to 1")
    Do $$$AssertEquals(tOut.%ToJSON(), tData.%ToJSON(), "a payload with no credential in it round-trips unchanged")
}

/// <p>The name pattern, row by row. Substring and case-insensitive, because the names that
/// carry secrets in this tree's own payloads are compounds — a matcher that only caught the
/// bare word would catch none of them.</p>
Method TestCredentialNameMatching()
{
    Set tMatch = $ListBuild("password", "Password", "PASSWORD", "passwd", "pwd", "userPwd", "secret", "ClientSecret", "token", "refresh_token", "credential", "X509Credential", "apikey", "ApiKey", "privatekey")
    For tI = 1:1:$ListLength(tMatch) {
        Set tName = $List(tMatch, tI)
        Do $$$AssertTrue(##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName), "'" _ tName _ "' is treated as a credential name")
    }
    Set tPlain = $ListBuild("user", "name", "count", "status", "route", "namespace", "code", "subsystem")
    For tI = 1:1:$ListLength(tPlain) {
        Set tName = $List(tPlain, tI)
        Do $$$AssertTrue('##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName), "'" _ tName _ "' is not")
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
