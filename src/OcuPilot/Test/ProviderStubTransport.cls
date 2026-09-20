/// <p>The scripted, recording transport as class methods, for a stub that cannot inherit it.</p>
/// <p><class>OcuPilot.Test.ProviderStub</class> carries the same transport as an instance method
/// on an <class>OcuPilot.Kernel.Provider.Anthropic</class> subclass, so every stub below it gets
/// it for free. <class>OcuPilot.Test.OpenAIStub</class> and
/// <class>OcuPilot.Test.GeminiStub</class> extend the two <b>shipped</b> adapters instead --
/// which is the whole point of them, since it is the shipped adapter's own body, headers and
/// response mapping that are under test -- so they reach it here.</p>
/// <p><b>Same script, same recording, same fake clock, and the same two arming legs.</b> A run
/// armed through <method>OcuPilot.Test.ProviderStub.ArmErrorLog</method> forces its application
/// error here as well, so AD-48's forced-error-log sweep reaches the two families whose stubs
/// cannot inherit it. The row-move leg is present for parity and <b>no test arms it through this
/// class</b> -- the only caller of <method>OcuPilot.Test.ProviderStub.ArmRowMove</method> drives
/// the canonical stub -- so it is capability here, not coverage. This class reads and writes
/// <class>OcuPilot.Test.ProviderStub</class>'s own process-private globals, so a test arms the run
/// with <method>OcuPilot.Test.ProviderStub.Reset</method>,
/// <method>OcuPilot.Test.ProviderStub.QueueAnswer</method>,
/// <method>OcuPilot.Test.ProviderStub.QueueThrow</method> and
/// <method>OcuPilot.Test.ProviderStub.ScriptElapsed</method>, and reads it back with
/// <method>OcuPilot.Test.ProviderStub.Calls</method>,
/// <method>OcuPilot.Test.ProviderStub.Recorded</method>,
/// <method>OcuPilot.Test.ProviderStub.Waits</method>,
/// <method>OcuPilot.Test.ProviderStub.ServedBy</method> and
/// <method>OcuPilot.Test.ProviderStub.Clock</method>, whichever stub served the call.</p>
/// <p><b>No socket is opened by anything here.</b></p>
Class OcuPilot.Test.ProviderStubTransport Extends %RegisteredObject
{

/// <p>Answer the next queued triple instead of issuing <var>pRequest</var>, having first recorded
/// what it carried under <var>pIdentity</var> -- the calling stub's own
/// <code>STUBIDENTITY</code>, which is what lets a test tell which adapter class served a
/// call.</p>
/// <p><var>pWatchedHeaders</var> is the comma-separated header list
/// <method>HeaderNames</method> reports the presence of, so each family watches its own.</p>
/// <p>An empty script answers a 200 with an empty body, which is a body no family's
/// <method>OcuPilot.Kernel.Provider.Base.MapResponse</method> can read: a test that cares about
/// the reply queues one, and a test that queues none is asserting about the request.</p>
ClassMethod Transport(pIdentity As %String, pWatchedHeaders As %String, pRequest As %Net.HttpRequest, pUrl As %String, Output pStatus As %Integer, Output pBody As %String, Output pRetryAfter As %String) As %Status
{
    Set pStatus = 0
    Set pBody = ""
    Set pRetryAfter = ""
    Set tCall = $Increment(^||OcuPilotProviderStub("calls"))
    Do ..Advance($Get(^||OcuPilotProviderStub("elapsed")))
    Set ^||OcuPilotProviderStub("servedBy") = pIdentity
    Set ^||OcuPilotProviderStub("call", tCall, "servedBy") = pIdentity
    Set ^||OcuPilotProviderStub("call", tCall, "url") = pUrl
    Set ^||OcuPilotProviderStub("call", tCall, "sslConfiguration") = pRequest.SSLConfiguration
    Set ^||OcuPilotProviderStub("call", tCall, "sslCheckServerIdentity") = ''pRequest.SSLCheckServerIdentity
    Set ^||OcuPilotProviderStub("call", tCall, "timeout") = pRequest.Timeout
    Set ^||OcuPilotProviderStub("call", tCall, "proxyServer") = pRequest.ProxyServer
    Set ^||OcuPilotProviderStub("call", tCall, "proxyPort") = pRequest.ProxyPort
    Set ^||OcuPilotProviderStub("call", tCall, "proxyHttps") = ''pRequest.ProxyHTTPS
    Set ^||OcuPilotProviderStub("call", tCall, "proxyTunnel") = ''pRequest.ProxyTunnel
    ; Recorded raw rather than normalized with '', as the inherited stub records it: an unset
    ; FollowRedirect reads "" and ''"" is 0, which would make "nobody set it" and "set to 0
    ; deliberately" the same recorded value.
    Set ^||OcuPilotProviderStub("call", tCall, "followRedirect") = $Select(pRequest.FollowRedirect = "": "unset", 1: ''pRequest.FollowRedirect)
    Set ^||OcuPilotProviderStub("call", tCall, "headerNames") = ..HeaderNames(pRequest, pWatchedHeaders)
    Set ^||OcuPilotProviderStub("call", tCall, "contentType") = pRequest.ContentType
    Set ^||OcuPilotProviderStub("call", tCall, "body") = ..BodyOf(pRequest)
    Set tIndex = tCall
    If tIndex > +$Get(^||OcuPilotProviderStub("script")) Set tIndex = +$Get(^||OcuPilotProviderStub("script"))
    If tIndex < 1 {
        Set pStatus = 200
        Quit $$$OK
    }
    Set tKind = $Get(^||OcuPilotProviderStub("script", tIndex, "kind"))
    If tKind = "throw" {
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the stand-in transport raised mid-flight"))
    }
    If tKind = "timeout" {
        Quit $$$ERROR($$$CSPTimeout)
    }
    If tKind = "failure" {
        Quit $$$ERROR($$$GeneralError, "the stand-in transport could not reach the provider")
    }
    Do ..ForceErrorLog()
    ; Mid-flight by construction: the caller is inside its own read-then-write window while this
    ; runs, which is the only place a second writer can stand.
    Do ..MoveArmedRow()
    Set pStatus = +$Get(^||OcuPilotProviderStub("script", tIndex, "status"))
    Set pBody = $Get(^||OcuPilotProviderStub("script", tIndex, "body"))
    Set pRetryAfter = $Get(^||OcuPilotProviderStub("script", tIndex, "retryAfter"))
    Quit $$$OK
}

/// <p>Record the wait and advance the fake clock by it rather than taking it, so the retry path
/// runs at full speed and still costs the attempt deadline what a real sleep would.
/// <method>OcuPilot.Test.ProviderStub.Waits</method> reads the recording back.</p>
ClassMethod Wait(pSeconds As %Numeric)
{
    Set ^||OcuPilotProviderStub("waits") = $Get(^||OcuPilotProviderStub("waits")) _ $Select($Get(^||OcuPilotProviderStub("waits")) = "": "", 1: "|") _ +pSeconds
    Do ..Advance(pSeconds)
}

/// <p>The fake clock's value, which is
/// <method>OcuPilot.Test.ProviderStub.Clock</method>'s -- one clock for every stub, so a run that
/// mixes them still measures one call.</p>
ClassMethod NowSeconds() As %Numeric
{
    Quit ##class(OcuPilot.Test.ProviderStub).Clock()
}

/// <p>Advance the fake clock by <var>pSeconds</var>.</p>
ClassMethod Advance(pSeconds As %Numeric) [ Private ]
{
    Set ^||OcuPilotProviderStub("clock") = +$Get(^||OcuPilotProviderStub("clock")) + +pSeconds
}

/// <p>Raise one genuine, controlled runtime error in this frame and log it to this namespace's
/// <code>^ERRORS</code>, when <method>OcuPilot.Test.ProviderStub.ArmErrorLog</method> armed the
/// run; a no-op otherwise. The entry is recorded where that class records its own, so
/// <method>OcuPilot.Test.ProviderStub.ErrorLogCount</method> and
/// <method>OcuPilot.Test.ProviderStub.ErrorLogEntry</method> read every entry a run wrote
/// whichever stub served the call.</p>
/// <p>The shape is <method>OcuPilot.Test.ProviderStub.ForceErrorLog</method>'s: a real
/// <code>&lt;DIVIDE&gt;</code> rather than a <code>Throw</code>, because a <code>Throw</code>
/// leaves <code>$ZError</code> empty and records the useless <code>&lt;LOG ENTRY&gt;</code>
/// placeholder; the divisor comes out of a variable because the compiler folds the literal
/// form.</p>
/// <p><b>Public, and a class method, so a stub's own <method>ApplyAuth</method> can call it</b> as
/// well as <method>Transport</method> -- which is what puts an entry on a run whose transport
/// raises before reaching its own leg. That is the only reason it is not
/// <code>[ Private ]</code> as its twin on <class>OcuPilot.Test.ProviderStub</class> is.
/// <b>Guarded here as well as at its arming point</b>:
/// <code>OCUPILOT_ALLOW_ERROR_SEED</code> must read 1, because a class-level check protects the
/// class that declares it and not a caller that reached this another way. An application error
/// cannot be un-logged.</p>
ClassMethod ForceErrorLog()
{
    If '+$Get(^||OcuPilotProviderStubLog("armed")) Quit
    If $System.Util.GetEnviron("OCUPILOT_ALLOW_ERROR_SEED") '= 1 Quit
    Try {
        Set tZero = 0
        Set tUnreachable = 1 / tZero
    } Catch inner {
        Set ^||OcuPilotProviderStubLog("entry", $Increment(^||OcuPilotProviderStubLog("entry"))) = $$LOG^%ETN()
    }
}

/// <p>Perform the edit <method>OcuPilot.Test.ProviderStub.ArmRowMove</method> armed, once, and
/// disarm. Answers 0 when nothing was armed.</p>
/// <p>The edit goes through the ordinary update path, so what the definition's next writer meets
/// is a row that moved rather than a row a test corrupted.</p>
ClassMethod MoveArmedRow() As %Boolean [ Private ]
{
    Set tId = $Get(^||OcuPilotProviderStub("rowMove", "id"))
    If tId = "" Quit 0
    Set tModel = $Get(^||OcuPilotProviderStub("rowMove", "model"))
    Kill ^||OcuPilotProviderStub("rowMove")
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit 0
    Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
    Set tRow.Model = tModel
    Set tMoveSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
    Set tRow = ""
    Quit $$$ISOK(tMoveSC)
}

/// <p>The header names <var>pRequest</var> was given a non-empty value for, out of the
/// comma-separated <var>pWatchedHeaders</var>, in that order.</p>
/// <p><b>Names only, and no value is ever bound to a variable.</b> The credential is a header
/// value: <method>%Net.HttpRequest.ReturnHeaders</method> would answer a string carrying it, and
/// assigning that to a local would put the key into the symbol table an <code>^%ETN</code> entry
/// captures. Each value is therefore tested inside the comparison and never named.</p>
ClassMethod HeaderNames(pRequest As %Net.HttpRequest, pWatchedHeaders As %String) As %String [ Private ]
{
    Set tNames = ""
    Try {
        For tI = 1:1:$Length(pWatchedHeaders, ",") {
            Set tHeader = $Piece(pWatchedHeaders, ",", tI)
            If tHeader = "" Continue
            If pRequest.GetHeader(tHeader) = "" Continue
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tHeader
        }
    } Catch ex {
        Set tNames = ""
    }
    Quit tNames
}

/// <p><var>pRequest</var>'s entity body as a string, so a test can assert the shape the adapter
/// built.</p>
ClassMethod BodyOf(pRequest As %Net.HttpRequest) As %String [ Private ]
{
    Set tBody = ""
    Try {
        If '$IsObject(pRequest.EntityBody) Quit
        Do pRequest.EntityBody.Rewind()
        While 'pRequest.EntityBody.AtEnd {
            Set tBody = tBody _ pRequest.EntityBody.Read(32000)
        }
    } Catch ex {
        Set tBody = ""
    }
    Quit tBody
}

}
