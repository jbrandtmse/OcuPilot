/// <p>The transport stand-in for the whole provider suite: an
/// <class>OcuPilot.Kernel.Provider.Anthropic</class> whose <method>IssueHttpsPost</method> answers
/// a queued script of canned <code>(status, body, retry-after)</code> triples instead of opening a
/// connection. <b>No test in this story opens a socket to any provider.</b></p>
/// <p>Everything above the seam -- the credential resolution, the key-shape gate, the body, the
/// headers, the retry arithmetic, the response mapping and the fault -- is the shipped code
/// running unchanged. What is replaced is the transport and the two seams that would otherwise
/// make the suite wait: <method>OcuPilot.Kernel.Provider.Base.Wait</method>, which records instead
/// of sleeping, and <method>OcuPilot.Kernel.Provider.Base.NowSeconds</method>, which answers a
/// counter this class advances by every recorded wait and by
/// <method>ScriptElapsed</method>'s per-call duration -- so the retry budget and the five-minute
/// attempt deadline are both driven with no real time passing.</p>
/// <p><b>It records what the request carried.</b> The TLS configuration name, the
/// server-identity flag, the timeout, the keep-alive socket timeout, the four proxy values and the
/// header names it was given are
/// captured per call, which is what makes AC3's configured-request assertions an observation of the
/// real request object rather than a restatement of the settings the test supplied.</p>
/// <p>The scripted body is <method>OcuPilot.Test.ProviderStubTransport.Transport</method>'s, which
/// the other three families' stubs call too: this class holds the arming, the reading back and the
/// two seams, and <method>IssueHttpsPost</method> is one call into it.</p>
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

/// <p>The headers <method>OcuPilot.Test.ProviderStubTransport.HeaderNames</method> reports the
/// presence of, comma-separated. The two the Anthropic adapter's <method>ApplyAuth</method> must
/// set; the content type is recorded from its own property, because
/// <method>%Net.HttpRequest.SetHeader</method> diverts that one.</p>
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

/// <p>Arm the stub to compare each call's <code>x-api-key</code> header, the key header of the
/// <code>anthropic</code> family and its canary row, with <var>pExpected</var>, and to record only whether
/// they are equal (<code>keyMatches</code>, <method>Recorded</method>). The request's key is read inside the comparison
/// and never named, and no recording holds it. <method>Reset</method> disarms it.</p>
ClassMethod ArmKeyCompare(pExpected As %String)
{
    Set ^||OcuPilotProviderStub("keyExpected") = pExpected
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

/// <p>Queue one streamed answer (Story 11.7): with a chunk reader attached, the raw UTF-8 bytes of
/// <var>pSse</var> are fed into its <method>%Net.ChunkedReader.ReadChunk</method> in slices of
/// <var>pSliceBytes</var>, and the transport answers <var>pStatus</var> with no body -- the real
/// transport's shape. <var>pBreakAfterBytes</var> above 0 stops after that many bytes and answers
/// the <code>&lt;READ&gt;</code> error a dropped connection produces, with <var>pStatus</var> as the
/// status line's code. With no reader attached, <var>pSse</var> is answered as the body.</p>
ClassMethod QueueStream(pStatus As %Integer, pSse As %String, pSliceBytes As %Integer = 7, pBreakAfterBytes As %Integer = 0)
{
    Set tIndex = $Increment(^||OcuPilotProviderStub("script"))
    Set ^||OcuPilotProviderStub("script", tIndex, "kind") = "stream"
    Set ^||OcuPilotProviderStub("script", tIndex, "status") = pStatus
    Set ^||OcuPilotProviderStub("script", tIndex, "body") = pSse
    Set ^||OcuPilotProviderStub("script", tIndex, "slice") = pSliceBytes
    Set ^||OcuPilotProviderStub("script", tIndex, "break") = pBreakAfterBytes
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

/// <p>Queue one connect that never opened: the call returns the <code>ERROR #6059</code>
/// <class>%Net.HttpRequest</class> answers for a refused or unanswered connect, with no status
/// line -- the shape <method>OcuPilot.Test.ProviderTransportRetry.TestARefusedConnectAnswersNoStatus</method>
/// reads off the real transport.</p>
ClassMethod QueueConnectRefused()
{
    Set tIndex = $Increment(^||OcuPilotProviderStub("script"))
    Set ^||OcuPilotProviderStub("script", tIndex, "kind") = "connectrefused"
}

/// <p>Queue one connection that broke <b>after</b> a status line arrived: the call returns the
/// <code>ERROR #6097 &lt;READ&gt;</code> a dropped read produces, with <var>pStatus</var> reported
/// as the status line's code. What the adapter must not retry, because the provider did
/// answer.</p>
ClassMethod QueueBrokenAfterStatus(pStatus As %Integer)
{
    Set tIndex = $Increment(^||OcuPilotProviderStub("script"))
    Set ^||OcuPilotProviderStub("script", tIndex, "kind") = "brokenafterstatus"
    Set ^||OcuPilotProviderStub("script", tIndex, "status") = pStatus
}

/// <p>Queue one mid-flight raise: the call throws rather than returning at all, which is what the
/// adapter must never retry.</p>
ClassMethod QueueThrow()
{
    Set tIndex = $Increment(^||OcuPilotProviderStub("script"))
    Set ^||OcuPilotProviderStub("script", tIndex, "kind") = "throw"
}

/// <p>Make every transport call from now on advance the fake clock by <var>pSeconds</var>, standing
/// in for the time the call itself spent. Unset -- the default -- a call takes no time, which is
/// what every test that is not about the attempt deadline wants.</p>
/// <p>It is the other half of <method>NowSeconds</method>: with it a test drives
/// <parameter>OcuPilot.Kernel.Provider.Retry.ATTEMPTBUDGETSECONDS</parameter> -- five minutes -- to
/// its end without any real time passing.</p>
ClassMethod ScriptElapsed(pSeconds As %Numeric)
{
    Set ^||OcuPilotProviderStub("elapsed") = +pSeconds
}

/// <p>The fake clock's value, in the seconds <method>OcuPilot.Kernel.Provider.Base.NowSeconds</method>
/// answers. It starts at zero on a <method>Reset</method> and advances only by what this class is
/// told to advance it by: every <method>Wait</method> amount, and
/// <method>ScriptElapsed</method>'s per-call duration.</p>
ClassMethod Clock() As %Numeric
{
    Quit +$Get(^||OcuPilotProviderStub("clock"))
}

/// <p>Answer the fake clock instead of the process's, so an attempt deadline measured in minutes is
/// exercised in no time at all.</p>
Method NowSeconds() As %Numeric
{
    Quit ..Clock()
}

/// <p>Arm the transport to <b>move agent definition <var>pId</var> while it is in flight</b>: on
/// the next call that serves a queued answer, and no other,
/// <method>OcuPilot.Test.ProviderStubTransport.Transport</method> edits that definition through the
/// ordinary update path before answering. A call that fails, times out, raises, streams or finds
/// no script leaves the move armed.</p>
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

/// <p>Force a real application-error entry (<code>$$LOG^%ETN()</code>) on every call from now on,
/// raised from <b>two</b> frames of the adapter's own call stack: inside
/// <method>ApplyAuth</method>, and under <method>IssueHttpsPost</method>, in
/// <method>OcuPilot.Test.ProviderStubTransport.Transport</method>.</p>
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

/// <p>How many request objects the shipped <method>OcuPilot.Kernel.Provider.Base.NewRequest</method>
/// built through this stub, so a test can tell a retry on a new request from one that re-sent the
/// same object.</p>
ClassMethod NewRequests() As %Integer
{
    Quit +$Get(^||OcuPilotProviderStub("newRequests"))
}

/// <p>Count the request, then build it with the shipped method unchanged.</p>
Method NewRequest(ByRef pSettings) As %Net.HttpRequest
{
    Do $Increment(^||OcuPilotProviderStub("newRequests"))
    Quit ##super(.pSettings)
}

/// <p>What the request carried on call <var>pCall</var>, for <var>pKey</var>: one of
/// <code>sslConfiguration</code>, <code>sslCheckServerIdentity</code>, <code>timeout</code>,
/// <code>proxyServer</code>, <code>proxyPort</code>, <code>proxyHttps</code>,
/// <code>proxyTunnel</code>, <code>followRedirect</code>, <code>socketTimeout</code>,
/// <code>url</code>, <code>body</code>, <code>headerNames</code>, <code>contentType</code>,
/// <code>servedBy</code>, <code>acceptGzip</code>, <code>readRawMode</code>,
/// <code>streamReader</code> (1 when a chunk reader was attached) or <code>keyMatches</code> (1 when
/// <method>ArmKeyCompare</method> was armed and the key header equalled its text).</p>
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

/// <p>Record the wait and advance the fake clock by it rather than taking it, so the retry path runs
/// at full speed and still costs the attempt deadline what a real sleep would. The recording is
/// <method>OcuPilot.Test.ProviderStubTransport.Wait</method>'s, which every stub shares.</p>
Method Wait(pSeconds As %Numeric)
{
    Do ##class(OcuPilot.Test.ProviderStubTransport).Wait(pSeconds)
}

/// <p>Answer the next queued triple instead of issuing the request, through
/// <method>OcuPilot.Test.ProviderStubTransport.Transport</method>: this stub's
/// <parameter>STUBIDENTITY</parameter> and <parameter>WATCHEDHEADERS</parameter>, and
/// <code>x-api-key</code> as the header <method>ArmKeyCompare</method> compares.</p>
/// <p>An empty script answers a 200 with a minimal well-formed reply, so a test that only cares
/// about the configured request does not have to queue one.</p>
Method IssueHttpsPost(pRequest As %Net.HttpRequest, pUrl As %String, Output pStatus As %Integer, Output pBody As %String, Output pRetryAfter As %String) As %Status
{
    Quit ##class(OcuPilot.Test.ProviderStubTransport).Transport(..#STUBIDENTITY, ..#WATCHEDHEADERS, pRequest, pUrl, .pStatus, .pBody, .pRetryAfter, "{""content"":[{""type"":""text"",""text"":""ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":1}}", "x-api-key")
}

/// <p>Raise and log one application error through
/// <method>OcuPilot.Test.ProviderStubTransport.ForceErrorLog</method>, which holds the shape and
/// both guards, with this method's caller live on the stack. <method>ApplyAuth</method> and
/// <class>OcuPilot.Test.ProviderStubShapeLeak</class> call it here.</p>
Method ForceErrorLog() [ Private ]
{
    Do ##class(OcuPilot.Test.ProviderStubTransport).ForceErrorLog()
}

/// <p>How many <code>^ERRORS</code> entries the run forced, through any stub: every entry
/// <method>OcuPilot.Test.ProviderStubTransport.ForceErrorLog</method> wrote.</p>
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

}
