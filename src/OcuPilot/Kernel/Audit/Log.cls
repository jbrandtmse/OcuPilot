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

/// <p>The mask a redacted value is replaced with. A fixed marker rather than removal of the
/// key: a log line that silently lost a field reads as a field the caller never sent, and the
/// next reader cannot tell "no secret here" from "a secret was here".</p>
Parameter REDACTED = "[redacted]";

/// <p>The credential name pattern the backstop redactor matches a <var>pData</var> key
/// against, case-insensitively: anything whose name contains password, passwd, pwd, secret,
/// token, credential, apikey or privatekey.</p>
/// <p>Comma-separated and lower case; <method>Redact</method> folds the key before testing, so
/// <code>Password</code>, <code>refresh_token</code> and <code>ApiKey</code> all match.</p>
/// <p><b>A bare <code>key</code> is deliberately not on the list</b>, and this is the backstop's
/// known edge: <code>signingKey</code> and <code>sshKey</code> are not masked here, because
/// <code>key</code> as a substring also matches <code>keyword</code>, <code>monkey</code> and
/// every <code>*Keys</code> count, and masking those would hide the ordinary values a reader
/// needs while adding no protection a descriptor-driven rule will not give properly (FR-21,
/// Epic 4). A field that is secret because its descriptor says so is that layer's job.</p>
Parameter CREDENTIALNAMES = "password,passwd,pwd,secret,token,credential,apikey,privatekey";

/// <p>Build the JSON log entry and write it to the IRIS console log. Never throws —
/// a failure here is swallowed rather than raised to the caller.</p>
/// <p><var>pData</var> passes through <method>Redact</method> first (Consistency Conventions:
/// Secrets — "secrets redacted before emission"). That is a <b>backstop</b>, and the
/// Conventions say so outright: a field is secret because its descriptor says so (FR-21), and
/// the schema-driven layer that knows which fields those are is Epic 4's. A name-pattern
/// matcher can only add redaction, never remove it, and it cannot see a wallet secret stored in
/// a field called <code>Value</code>. It is here because this class serializes whatever a
/// caller hands it — including, since Story 1.13, a vendor status's full raw text — and
/// <b>every OcuPilot log line is later rendered on OcuPilot's own log screens and read by the
/// agent</b> (AD-35, AD-46), which closes the loop this row exists to break.</p>
ClassMethod Emit(pLevel As %String, pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "") [ Private ]
{
    Try {
        Set tEntry = {}
        Do tEntry.%Set("ts", ..FormatTimestamp())
        Do tEntry.%Set("level", pLevel)
        Do tEntry.%Set("subsystem", pSubsystem)
        Do tEntry.%Set("msg", pMessage)
        If $IsObject(pData) {
            Do tEntry.%Set("data", ..Redact(pData))
        }
        Set tLogLine = "[OcuPilot] " _ tEntry.%ToJSON()
        Do ..ResolveSeverityAndFlag(pLevel, .tSeverity, .tFlag)
        Do ..WriteConsole(tLogLine, tFlag, tSeverity, "OcuPilot.Log")
    } Catch ex {
        ; Logging failures must never propagate.
    }
}

/// <p>A copy of <var>pData</var> with every value whose key matches the credential name
/// pattern replaced by <parameter>REDACTED</parameter>, at every depth.</p>
/// <p><b>A copy, never the caller's object.</b> The caller still holds <var>pData</var> after
/// this returns, and a redactor that masked in place would delete a value the caller may still
/// need — turning a logging concern into a data loss. Nested objects and arrays are rebuilt the
/// same way, because a credential does not stop being one for sitting inside a
/// <code>detail</code> object.</p>
/// <p><b>A nested array stays an array, at its own indices.</b> Rebuilding one as an object
/// would re-key it by its own subscripts — <code>["a","b"]</code> emitted as
/// <code>{"0":"a","1":"b"}</code> — so the log line would report a shape the caller never sent.
/// That is a live path, not a hypothetical:
/// <method>OcuPilot.Install.Installer.Uninstall</method> logs its remaining inventory rows as a
/// pushed array. Each member is written back at the index it arrived on rather than appended,
/// because <method>%GetNext</method> skips a sparse array's unassigned holes and
/// <method>%Push</method> would close them up: <code>["a",,,"z"]</code> came out as
/// <code>["a","z"]</code>, dropping two members and moving the last one from index 3 to index 1.
/// An array has no member names, so nothing inside one is matched by name; its objects are still
/// walked.</p>
/// <p>Public so <class>OcuPilot.Test.Log</class> can pin the rule directly rather than only
/// through a captured line, and because it is a pure, side-effect-free transform.</p>
/// @param pData The object or array to redact
/// @return A new value of the same JSON kind, with matching values masked
ClassMethod Redact(pData As %DynamicAbstractObject) As %DynamicAbstractObject
{
    Set tOut = ..EmptyLike(pData)
    Try {
        If '$IsObject(pData) Quit
        Set tIsArray = ..IsArray(pData)
        Set tIter = pData.%GetIterator()
        While tIter.%GetNext(.tKey, .tValue) {
            If 'tIsArray, ..IsCredentialName(tKey) {
                Do tOut.%Set(tKey, ..#REDACTED, "string")
                Continue
            }
            If $IsObject(tValue) {
                Do tOut.%Set(tKey, ..Redact(tValue))
                Continue
            }
            ; The type is carried across rather than re-inferred: a value that arrived as a
            ; JSON number, boolean or null must not be re-typed as a string on its way to the
            ; log, or a reader would be told the caller sent something it did not.
            Do tOut.%Set(tKey, tValue, pData.%GetTypeOf(tKey))
        }
    } Catch ex {
        ; A redactor that throws would emit nothing, which is worse than emitting the mask:
        ; an empty value of the same kind is the safe answer, because it can carry no secret.
        Set tOut = ..EmptyLike(pData)
    }
    Quit tOut
}

/// <p>Whether <var>pData</var> is a JSON array rather than an object. Compared on the class
/// name because that is what distinguishes the two dynamic types at run time.</p>
ClassMethod IsArray(pData As %DynamicAbstractObject) As %Boolean
{
    If '$IsObject(pData) Quit 0
    Quit $ClassName(pData) = "%Library.DynamicArray"
}

/// <p>An empty value of the same JSON kind as <var>pData</var> — the accumulator
/// <method>Redact</method> fills, and the safe answer it falls back to.</p>
ClassMethod EmptyLike(pData As %DynamicAbstractObject) As %DynamicAbstractObject [ Private ]
{
    If ..IsArray(pData) Quit []
    Quit {}
}

/// <p>Whether <var>pKey</var> names something that may hold a credential, matched
/// case-insensitively against <parameter>CREDENTIALNAMES</parameter> as a substring.</p>
/// <p>Substring, not equality: the names that carry secrets in this tree's own payloads are
/// compounds — <code>refresh_token</code>, <code>ApiKey</code>, <code>ClientSecret</code> —
/// and a matcher that only caught the bare word would catch none of them. Over-matching is the
/// safe direction for a backstop: a masked field that held nothing secret costs a reader one
/// look at the code, where the other way costs a credential.</p>
ClassMethod IsCredentialName(pKey As %String) As %Boolean
{
    Set tMatches = 0
    Set tFolded = $ZConvert(pKey, "L")
    Set tNames = ..#CREDENTIALNAMES
    For tI = 1:1:$Length(tNames, ",") {
        Set tName = $Piece(tNames, ",", tI)
        If (tName '= "") && (tFolded [ tName) {
            Set tMatches = 1
            Quit
        }
    }
    Quit tMatches
}

/// <p>The single console-write seam. Exists as its own overridable method for one
/// reason: the argument order below is the exact thing that was once wrong here — an
/// earlier version passed Severity where Flag belongs, straight into
/// <code>$ZU(9,...)</code> — and a mapping test over
/// <method>ResolveSeverityAndFlag</method> alone cannot catch that, because the swap
/// lives at the call site, not in the lookup. <class>OcuPilot.Test.LogProbe</class>
/// overrides this method to capture the four arguments exactly as <method>Emit</method>
/// passes them, so <class>OcuPilot.Test.Log</class> can assert the order itself.</p>
/// <p>Production never overrides this. Argument order is
/// <code>WriteToConsoleLog(Message, Flag, Severity, Event)</code> — verified against
/// <code>irissys/%SYS/System.cls</code>, which calls
/// <code>$zu(9,"",Message,Flag,Severity,Event)</code>.</p>
/// @param pMessage The formatted log line
/// @param pFlag Whether to echo to the operator console (0 or 1)
/// @param pSeverity WriteToConsoleLog's severity scale (-1 Debug, 0 Information, 1 Warning, 2 Severe)
/// @param pEvent The console-log event name
ClassMethod WriteConsole(pMessage As %String, pFlag As %Integer, pSeverity As %Integer, pEvent As %String)
{
    Do ##class(%SYS.System).WriteToConsoleLog(pMessage, pFlag, pSeverity, pEvent)
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
