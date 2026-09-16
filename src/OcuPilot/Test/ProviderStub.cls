/// <p>The transport stand-in for the whole provider suite: an
/// <class>OcuPilot.Kernel.Provider.Anthropic</class> whose <method>IssueHttpsPost</method> answers
/// a queued script of canned <code>(status, body, retry-after)</code> triples instead of opening a
/// connection. <b>No test in this story opens a socket to any provider.</b></p>
/// <p>Everything above the seam -- the credential resolution, the key-shape gate, the body, the
/// headers, the retry arithmetic, the response mapping and the fault -- is the shipped code
/// running unchanged. What is replaced is exactly one method.</p>
/// <p><b>It records what the request carried.</b> The TLS configuration name, the
/// server-identity flag, the timeout, the four proxy values and the header names it was given are
/// captured per call, which is what makes AC3's configured-request assertions an observation of the
/// real request object rather than a restatement of the settings the test supplied.</p>
/// <p>The script and the recording live in <b>process-private globals</b> rather than on the
/// instance: the port constructs the adapter itself, so a test has no reference to set a property
/// on, and a process-private global is the one channel that survives that without leaking between
/// processes. Subscripts follow identifier rules -- no hyphens -- per
/// <file>.claude/rules/objectscript-basics.md</file>.</p>
Class OcuPilot.Test.ProviderStub Extends OcuPilot.Kernel.Provider.Anthropic
{

/// <p>The identity this stub reports through <method>ServedBy</method>, so a test can tell which
/// adapter class actually served a call.</p>
Parameter STUBIDENTITY = "stub";

/// <p>The headers <method>HeaderNames</method> reports the presence of, comma-separated. The two
/// the Anthropic adapter's <method>ApplyAuth</method> must set; the content type is recorded from
/// its own property, because <method>%Net.HttpRequest.SetHeader</method> diverts that one.</p>
Parameter WATCHEDHEADERS = "x-api-key,anthropic-version";

/// <p>Forget any queued script and any recording, and arm the stub for a fresh run.</p>
/// <p><b>The forced-error-log arming and its record are deliberately not cleared here.</b> A test
/// that drives several failure classes resets the script between them, and a count that reset with
/// it would read zero at the end however many entries the run actually wrote -- which is an
/// assertion over nothing wearing the shape of a passing one. <method>ResetErrorLog</method>
/// clears that half.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotProviderStub
}

/// <p>Disarm the forced error log and forget the entries it recorded.</p>
ClassMethod ResetErrorLog()
{
    Kill ^||OcuPilotProviderStubLog
}

/// <p>Queue one canned answer: the transport succeeds and reports <var>pStatus</var>,
/// <var>pBody</var> and <var>pRetryAfter</var>. Answers are consumed in the order they are
/// queued; the last one queued is repeated once the script runs out, so a test that queues one
/// 429 and asks for three attempts gets three.</p>
ClassMethod QueueAnswer(pStatus As %Integer, pBody As %String = "", pRetryAfter As %String = "")
{
    Set tIndex = $Increment(^||OcuPilotProviderStub("script"))
    Set ^||OcuPilotProviderStub("script", tIndex, "kind") = "answer"
    Set ^||OcuPilotProviderStub("script", tIndex, "status") = pStatus
    Set ^||OcuPilotProviderStub("script", tIndex, "body") = pBody
    Set ^||OcuPilotProviderStub("script", tIndex, "retryAfter") = pRetryAfter
}

/// <p>Queue one transport failure: the call returns an error <class>%Status</class> and no HTTP
/// answer at all. <var>pTimeout</var> makes it the timeout status
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> tells apart from every other transport
/// failure.</p>
ClassMethod QueueTransportFailure(pTimeout As %Boolean = 0)
{
    Set tIndex = $Increment(^||OcuPilotProviderStub("script"))
    Set ^||OcuPilotProviderStub("script", tIndex, "kind") = $Select(pTimeout: "timeout", 1: "failure")
}

/// <p>Queue one mid-flight raise: the call throws rather than returning at all, which is what the
/// adapter must never retry.</p>
ClassMethod QueueThrow()
{
    Set tIndex = $Increment(^||OcuPilotProviderStub("script"))
    Set ^||OcuPilotProviderStub("script", tIndex, "kind") = "throw"
}

/// <p>Arm the transport to <b>move agent definition <var>pId</var> while it is in flight</b>: on
/// the next call and no other, the stub edits that definition through the ordinary update path
/// before answering.</p>
/// <p>It exists so a test can stand where a second administrator would: the window a conditional
/// write closes is the one between a handler's read and its save, and on Test connection that
/// window is exactly the provider round trip. Nothing else in this suite can get inside it.</p>
/// <p><b>The edit is an ordinary one</b> -- the model, which is not a security field -- so what
/// the definition's next writer meets is a row that moved, not a row a test corrupted.</p>
ClassMethod ArmRowMove(pId As %String, pModel As %String)
{
    Set ^||OcuPilotProviderStub("rowMove", "id") = pId
    Set ^||OcuPilotProviderStub("rowMove", "model") = pModel
}

/// <p>Perform the armed edit, once, and disarm. Answers 0 when nothing was armed.</p>
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

/// <p>Force a real application-error entry (<code>$$LOG^%ETN()</code>) on every call from now on,
/// raised from <b>two</b> frames of the adapter's own call stack: inside
/// <method>ApplyAuth</method>, and inside <method>IssueHttpsPost</method>.</p>
/// <p><b>What the two legs cover, and what no leg can cover.</b> An <code>^%ETN</code> entry records
/// every local at every <i>live</i> stack level, so what an entry can see is the chain from
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> down to wherever it was raised. Both legs
/// therefore cover <method>Invoke</method> and <method>Attempts</method> -- which is where the
/// credential is resolved and where the call spends its time, and so where a leak would actually
/// be. The <method>ApplyAuth</method> leg additionally fires on a run whose transport raises before
/// reaching its own leg, so the mid-flight-throw case still writes an entry.</p>
/// <p><b>A local inside <method>OcuPilot.Kernel.Provider.Anthropic.ApplyAuth</method> is not
/// reachable from here</b>, and saying so is the point: that method has returned by the time either
/// leg runs, and this stub's own override is a different frame from the one it calls. Verified by
/// mutation on a throwaway: holding the key in a local there leaves this class green, while holding
/// it in a local in <method>Invoke</method> turns it red at every entry. The vendor's own
/// <method>%Net.HttpRequest.SetHeader</method> binds the value to a parameter for the length of that
/// one call too, which no design can avoid. The guarantee this class proves is the achievable one:
/// no frame that is live while OcuPilot is doing provider work holds the credential.</p>
/// <p><b>Guarded on its own</b>, not only by the calling class:
/// <code>OCUPILOT_ALLOW_ERROR_SEED</code> must read 1, or nothing is armed and the call reports so
/// through <var>pArmed</var>. An application error cannot be un-logged -- the delete is Epic 5's.</p>
ClassMethod ArmErrorLog(Output pArmed As %Boolean)
{
    Set pArmed = ($System.Util.GetEnviron("OCUPILOT_ALLOW_ERROR_SEED") = 1)
    If 'pArmed Quit
    Set ^||OcuPilotProviderStubLog("armed") = 1
}

/// <p>Write the two authentication headers, then raise and log one application error <b>in this
/// frame</b> when armed, so the entry captures whatever <method>ApplyAuth</method> and its callers
/// are holding.</p>
Method ApplyAuth(pRequest As %Net.HttpRequest)
{
    Do ##super(pRequest)
    If '+$Get(^||OcuPilotProviderStubLog("armed")) Quit
    Do ..ForceErrorLog()
}

/// <p>How many times the transport seam was entered. <b>The count AC5 is about</b>: a call that
/// threw must leave this at 1 however many attempts the settings allow.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotProviderStub("calls"))
}

/// <p>What the request carried on call <var>pCall</var>, for <var>pKey</var>: one of
/// <code>sslConfiguration</code>, <code>sslCheckServerIdentity</code>, <code>timeout</code>,
/// <code>proxyServer</code>, <code>proxyPort</code>, <code>proxyHttps</code>,
/// <code>proxyTunnel</code>, <code>followRedirect</code>, <code>url</code>, <code>body</code>,
/// <code>headerNames</code>, <code>contentType</code> or <code>servedBy</code>.</p>
ClassMethod Recorded(pKey As %String, pCall As %Integer = 1) As %String
{
    Quit $Get(^||OcuPilotProviderStub("call", pCall, pKey))
}

/// <p>The seconds each wait between attempts was asked for, <code>"|"</code>-separated, so a test
/// can assert the delay without spending it.</p>
ClassMethod Waits() As %String
{
    Quit $Get(^||OcuPilotProviderStub("waits"))
}

/// <p>Which adapter class served the most recent call -- the stub's own
/// <parameter>STUBIDENTITY</parameter>, read through <code>..</code> dispatch so a subclass
/// answers its own.</p>
ClassMethod ServedBy() As %String
{
    Quit $Get(^||OcuPilotProviderStub("servedBy"))
}

/// <p>Record the wait rather than taking it, so the retry path runs at full speed.</p>
Method Wait(pSeconds As %Numeric)
{
    Set ^||OcuPilotProviderStub("waits") = $Get(^||OcuPilotProviderStub("waits")) _ $Select($Get(^||OcuPilotProviderStub("waits")) = "": "", 1: "|") _ +pSeconds
}

/// <p>Answer the next queued triple instead of issuing the request, having first recorded what
/// <var>pRequest</var> carried.</p>
/// <p>An empty script answers a 200 with a minimal well-formed reply, so a test that only cares
/// about the configured request does not have to queue one.</p>
Method IssueHttpsPost(pRequest As %Net.HttpRequest, pUrl As %String, Output pStatus As %Integer, Output pBody As %String, Output pRetryAfter As %String) As %Status
{
    Set pStatus = 0
    Set pBody = ""
    Set pRetryAfter = ""
    Set tCall = $Increment(^||OcuPilotProviderStub("calls"))
    Set ^||OcuPilotProviderStub("servedBy") = ..#STUBIDENTITY
    Set ^||OcuPilotProviderStub("call", tCall, "servedBy") = ..#STUBIDENTITY
    Set ^||OcuPilotProviderStub("call", tCall, "url") = pUrl
    Set ^||OcuPilotProviderStub("call", tCall, "sslConfiguration") = pRequest.SSLConfiguration
    Set ^||OcuPilotProviderStub("call", tCall, "sslCheckServerIdentity") = ''pRequest.SSLCheckServerIdentity
    Set ^||OcuPilotProviderStub("call", tCall, "timeout") = pRequest.Timeout
    Set ^||OcuPilotProviderStub("call", tCall, "proxyServer") = pRequest.ProxyServer
    Set ^||OcuPilotProviderStub("call", tCall, "proxyPort") = pRequest.ProxyPort
    Set ^||OcuPilotProviderStub("call", tCall, "proxyHttps") = ''pRequest.ProxyHTTPS
    Set ^||OcuPilotProviderStub("call", tCall, "proxyTunnel") = ''pRequest.ProxyTunnel
    ; Recorded raw rather than normalized with '': %Net.HttpRequest declares FollowRedirect with no
    ; InitialExpression, so an unset property reads "" and ''"" is 0 -- which would make "nobody set
    ; it" and "set to 0 deliberately" the same recorded value, and the assertion on it vacuous.
    Set ^||OcuPilotProviderStub("call", tCall, "followRedirect") = $Select(pRequest.FollowRedirect = "": "unset", 1: ''pRequest.FollowRedirect)
    Set ^||OcuPilotProviderStub("call", tCall, "headerNames") = ..HeaderNames(pRequest)
    Set ^||OcuPilotProviderStub("call", tCall, "contentType") = pRequest.ContentType
    Set ^||OcuPilotProviderStub("call", tCall, "body") = ..BodyOf(pRequest)
    Set tIndex = tCall
    If tIndex > +$Get(^||OcuPilotProviderStub("script")) Set tIndex = +$Get(^||OcuPilotProviderStub("script"))
    If tIndex < 1 {
        Set pStatus = 200
        Set pBody = "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":1}}"
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
    If +$Get(^||OcuPilotProviderStubLog("armed")) {
        Do ..ForceErrorLog()
    }
    ; Mid-flight by construction: the caller is inside its own read-then-write window while this
    ; runs, which is the only place a second writer can stand.
    Do ..MoveArmedRow()
    Set pStatus = +$Get(^||OcuPilotProviderStub("script", tIndex, "status"))
    Set pBody = $Get(^||OcuPilotProviderStub("script", tIndex, "body"))
    Set pRetryAfter = $Get(^||OcuPilotProviderStub("script", tIndex, "retryAfter"))
    Quit $$$OK
}

/// <p>Raise one genuine, controlled runtime error inside this frame and log it to this namespace's
/// <code>^ERRORS</code>. The shape is
/// <method>OcuPilot.Test.ErrorLogSeed.SeedInto</method>'s: a real <code>&lt;DIVIDE&gt;</code>
/// rather than a <code>Throw</code>, because a <code>Throw</code> leaves <code>$ZError</code> empty
/// and records the useless <code>&lt;LOG ENTRY&gt;</code> placeholder; the divisor comes out of a
/// variable because the compiler folds the literal form.</p>
/// <p><b>Guarded here as well as at its queue point</b>: a class-level check protects the class
/// that declares it, not a caller that reached this another way.</p>
Method ForceErrorLog() [ Private ]
{
    If $System.Util.GetEnviron("OCUPILOT_ALLOW_ERROR_SEED") '= 1 Quit
    Try {
        Set tZero = 0
        Set tUnreachable = 1 / tZero
    } Catch inner {
        Set ^||OcuPilotProviderStubLog("entry", $Increment(^||OcuPilotProviderStubLog("entry"))) = $$LOG^%ETN()
    }
}

/// <p>How many <code>^ERRORS</code> entries <method>ForceErrorLog</method> wrote.</p>
ClassMethod ErrorLogCount() As %Integer
{
    Quit +$Get(^||OcuPilotProviderStubLog("entry"))
}

/// <p>The identity of entry <var>pIndex</var>, as the <code>$ListBuild(day, number)</code> the trap
/// answered, or <code>""</code>.</p>
ClassMethod ErrorLogEntry(pIndex As %Integer = 1) As %String
{
    Quit $Get(^||OcuPilotProviderStubLog("entry", pIndex))
}

/// <p>The header names the request was given a non-empty value for, out of
/// <parameter>WATCHEDHEADERS</parameter>, comma-separated in that order.</p>
/// <p><b>Names only, and no value is ever bound to a variable.</b> The credential is a header
/// value: <method>%Net.HttpRequest.ReturnHeaders</method> would answer a string carrying it, and
/// assigning that to a local would put the key into the symbol table an <code>^%ETN</code> entry
/// captures -- in the very class AC6 uses to prove it is not there. Each value is therefore tested
/// inside the comparison and never named.</p>
ClassMethod HeaderNames(pRequest As %Net.HttpRequest) As %String [ Private ]
{
    Set tNames = ""
    Try {
        For tI = 1:1:$Length(..#WATCHEDHEADERS, ",") {
            Set tHeader = $Piece(..#WATCHEDHEADERS, ",", tI)
            If pRequest.GetHeader(tHeader) = "" Continue
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tHeader
        }
    } Catch ex {
        Set tNames = ""
    }
    Quit tNames
}

/// <p><var>pRequest</var>'s entity body as a string, so a test can assert the canonical shape the
/// adapter built.</p>
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
