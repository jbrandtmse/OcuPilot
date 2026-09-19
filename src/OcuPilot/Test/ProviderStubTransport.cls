/// <p>The scripted, recording transport as class methods, for a stub that cannot inherit it.</p>
/// <p><class>OcuPilot.Test.ProviderStub</class> carries the same transport as an instance method
/// on an <class>OcuPilot.Kernel.Provider.Anthropic</class> subclass, so every stub below it gets
/// it for free. <class>OcuPilot.Test.OpenAIStub</class> and
/// <class>OcuPilot.Test.GeminiStub</class> extend the two <b>shipped</b> adapters instead --
/// which is the whole point of them, since it is the shipped adapter's own body, headers and
/// response mapping that are under test -- so they reach it here.</p>
/// <p><b>Same script, same recording, same fake clock -- and no arming legs.</b> The forced
/// error-log entry and the mid-flight row move <class>OcuPilot.Test.ProviderStub</class> takes
/// inside its own transport are absent here, so a test that arms either of them is asserting about
/// the canonical family alone. This class reads and writes
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
