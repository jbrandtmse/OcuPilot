/// <p>Pins AD-42's one retry exception for a model call (Story 10.6): a transport failure before any
/// status line arrived is retried once, on a new request object, inside the attempt count, the
/// attempt deadline and the delay budget; a second one, a break after a status line, and a break
/// with no attempt or no time left each end the call <code>PROVIDER.TRANSPORT</code>. Also pins that
/// every family's request disables keep-alive reuse (<code>SocketTimeout</code> 0).</p>
/// <p><b>Opens no socket to a provider.</b> Every leg but one runs through
/// <class>OcuPilot.Test.ProviderStub</class> and the three family stubs, which answer a queued
/// script, record instead of sleeping and advance a fake clock. The one real transport call is a
/// connect to <code>http://127.0.0.1:1/</code>, a loopback port nothing listens on: IRIS retries
/// the refused connect until the request's 5 s timeout, then answers <code>ERROR #6059</code>, and
/// no byte reaches any server. Needs nothing of the environment but a resolvable probe
/// credential, which <class>OcuPilot.Test.SecretProbe</class> supplies in process.</p>
Class OcuPilot.Test.ProviderTransportRetry Extends %UnitTest.TestCase
{

/// <p>The arithmetic whose budgets bound the retry.</p>
Parameter RETRY = "OcuPilot.Kernel.Provider.Retry";

/// <p>The class whose values, settings, messages and probe key this one drives the stubs with.</p>
Parameter DRIVER = "OcuPilot.Test.Provider";

/// <p>A loopback address nothing listens on; a connect to it fails once the request's timeout runs out.</p>
Parameter REFUSEDURL = "http://127.0.0.1:1/";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue($Parameter(..#DRIVER, "PROBEKEY"))
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Quit $$$OK
}

/// <p>Run one call through <var>pStubClass</var> with <var>pSettings</var> and hand back everything
/// it produced.</p>
Method Call(ByRef pSettings, Output pResponse, Output pFault, Output pHttpStatus, pStubClass As %String = "OcuPilot.Test.ProviderStub", ByRef pValues) As %Status
{
    If '$Data(pValues) Do $ClassMethod(..#DRIVER, "Values", .pValues)
    Do $ClassMethod(..#DRIVER, "Messages", .tMessages)
    Set tAdapter = $ClassMethod(pStubClass, "%New")
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Set tSC = tAdapter.Invoke(.pValues, .tMessages, .tTools, "", .pSettings, .pResponse, .pFault, .pHttpStatus)
    Set tAdapter = ""
    Quit tSC
}

/// <p><var>pFault</var>'s machine code, or <code>""</code> when the call produced no fault.</p>
ClassMethod FaultCode(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.code
}

/// <p>One break before a status line, then an answer: the reply is mapped, the transport was
/// entered twice on two request objects carrying the same body, and one wait of at most the
/// backoff base was taken between them.</p>
/// <p>Mutation: remove the transport-retry branch in
/// <method>OcuPilot.Kernel.Provider.Base.Attempts</method> -- the call count and the fault go red.
/// Build one request before the loop and reuse it -- the request count goes red.</p>
Method TestOneBreakIsRetriedOnANewRequest()
{
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tFault), "", "and ends with no fault")
    Do $$$AssertEquals(tResponse.StopReason, "max_tokens", "the reply the second attempt answered is mapped")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "the transport was entered twice")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).NewRequests(), 2, "on two request objects, so the retry opened a new connection")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("body", 2), ##class(OcuPilot.Test.ProviderStub).Recorded("body", 1), "carrying the same body (AD-24)")
    Set tWaits = ##class(OcuPilot.Test.ProviderStub).Waits()
    Do $$$AssertTrue((tWaits '= "") && '(tWaits [ "|"), "one wait was taken before the retry: " _ tWaits)
    Do $$$AssertTrue(+tWaits <= $Parameter(..#RETRY, "BACKOFFBASESECONDS"), "of at most the first backoff window: " _ tWaits)
}

/// <p>Two breaks before a status line: the call stops after the second, with
/// <code>PROVIDER.TRANSPORT</code> at 502, though a third attempt was allowed.</p>
/// <p>Mutation: drop the <code>tTransportRetried</code> guard -- the call count goes red at 3.</p>
Method TestTwoBreaksStopTheCall()
{
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "the break is retried once and only once")
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "and the second ends the call PROVIDER.TRANSPORT")
    Do $$$AssertEquals(tHttpStatus, 502, "answered as a gateway failure")
    Do $$$AssertEquals(tResponse.StopReason, "error", "with the error stop reason")
}

/// <p>A connection that broke after its status line arrived is not retried: the provider
/// answered, so the request may have been processed. Every family's stub answers the same.</p>
/// <p>Mutation: retry on any non-timeout error, ignoring the status -- the call count goes red.</p>
Method TestABreakAfterAStatusLineIsNotRetried()
{
    For tStub = "OcuPilot.Test.ProviderStub", "OcuPilot.Test.OpenAIStub", "OcuPilot.Test.GeminiStub", "OcuPilot.Test.CompatibleStub" {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
        Kill tValues
        Do $ClassMethod(..#DRIVER, "Values", .tValues)
        Set tValues("keySource") = $Parameter("OcuPilot.Kernel.Provider.Base", "KEYSOURCENONE")
        Do ##class(OcuPilot.Test.ProviderStub).QueueBrokenAfterStatus(200)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
        Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus, tStub, .tValues)
        Do $$$AssertStatusOK(tSC, tStub _ ": the call returns $$$OK")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, tStub _ ": the transport was entered once")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "", tStub _ ": with nothing waited")
        Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, tStub _ ": and the call ends PROVIDER.TRANSPORT")
    }
}

/// <p>The transport retry's wait comes out of the same delay budget the status retries spend. A
/// 429 asking for the whole budget, then a break: the break is still retried, with nothing left to
/// wait. A break, then a 429 asking for the whole budget: the 429's wait is cut to what the break's
/// wait left, so the two together never exceed the budget.</p>
/// <p>Each leg can prove nothing on one backoff draw: the first when
/// <method>OcuPilot.Kernel.Provider.Retry.ExpBackoffSec</method>'s draw for attempt 2 is zero (one
/// time in 21), the second when its draw for attempt 1 is (one time in eleven). So both seed
/// <class>%SYSTEM.Process</class>'s random generator (<method>RandomSeed</method>), which
/// IRIS's <code>$Random</code> follows deterministically: the first leg runs under seeds 1 to 3,
/// the second under the smallest seed whose draw is non-zero, found by search against the real
/// call. The prior seed is restored once done.</p>
/// <p>Mutation: pass <code>""</code> for the remaining budget to the transport branch's
/// <method>OcuPilot.Kernel.Provider.Retry.DelaySec</method> -- the first leg's second wait is
/// drawn from the backoff window and goes red. Drop the transport branch's spent-delay increment --
/// the second leg's waits exceed the budget and go red, on every run.</p>
Method TestATransportRetrySharesTheDelayBudget()
{
    Set tBudget = $Parameter(..#RETRY, "RETRYBUDGETSECONDS")
    Set tOrigSeed = ##class(%SYSTEM.Process).RandomSeed(0)
    For tSeed = 1:1:3 {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "", tBudget)
        Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
        Do ##class(%SYSTEM.Process).RandomSeed(tSeed)
        Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
        Set tLeg = "429 then a break, seed " _ tSeed
        Do $$$AssertStatusOK(tSC, tLeg _ ": the call returns $$$OK")
        Do $$$AssertEquals(..FaultCode(tFault), "", tLeg _ ": the third attempt's answer is mapped")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 3, tLeg _ ": three calls")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), tBudget _ "|0", tLeg _ ": the break's wait is what the 429 left, nothing")
    }

    Set tSeed = 0
    Set tFirstWait = 0
    For {
        Set tSeed = tSeed + 1
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
        Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "", tBudget)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
        Do ##class(%SYSTEM.Process).RandomSeed(tSeed)
        Set tSC = ..Call(.tSettings, .tLateResponse, .tLateFault, .tLateStatus)
        Set tWaits = ##class(OcuPilot.Test.ProviderStub).Waits()
        Set tFirstWait = $Piece(tWaits, "|", 1)
        Quit:((+tFirstWait > 0) || (tSeed >= 50))
    }
    Do ##class(%SYSTEM.Process).RandomSeed(tOrigSeed)
    Do $$$AssertTrue(+tFirstWait > 0, "a seed drawing a non-zero first backoff was found within 50 tries: seed " _ tSeed)
    Do $$$AssertStatusOK(tSC, "a break then 429: the call returns $$$OK")
    Do $$$AssertEquals(..FaultCode(tLateFault), "", "a break then 429: the third attempt's answer is mapped")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 3, "a break then 429: three calls")
    Do $$$AssertEquals($Length(tWaits, "|"), 2, "a break then 429: two waits: " _ tWaits)
    Do $$$AssertEquals($Piece(tWaits, "|", 1) + $Piece(tWaits, "|", 2), tBudget, "a break then 429: together exactly the budget, never more: " _ tWaits)
}

/// <p>A break with no attempt left, as Test connection's single attempt has, or after the attempt
/// deadline has passed, is not retried and ends <code>PROVIDER.TRANSPORT</code>, not
/// <code>PROVIDER.TIMEOUT</code>.</p>
/// <p>Mutation: drop <code>tAttempt &lt; tMaxAttempts</code> from the retry condition -- the
/// single-attempt leg records a wait and goes red. Drop the deadline test -- the deadline leg ends
/// <code>PROVIDER.TIMEOUT</code> and goes red.</p>
Method TestABreakWithNoAttemptLeftIsNotRetried()
{
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "a single-attempt call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and enters the transport once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "", "with nothing waited, since no attempt remains")
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "ending PROVIDER.TRANSPORT")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).ScriptElapsed($Parameter(..#RETRY, "ATTEMPTBUDGETSECONDS"))
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
    Set tSC = ..Call(.tSettings, .tLateResponse, .tLateFault, .tLateStatus)
    Do $$$AssertStatusOK(tSC, "a call past its deadline returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and enters the transport once")
    Do $$$AssertEquals(..FaultCode(tLateFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "ending PROVIDER.TRANSPORT, not PROVIDER.TIMEOUT")
    Do $$$AssertEquals(tLateStatus, 502, "answered as a gateway failure")
}

/// <p>AC2: the request every family builds carries <code>SocketTimeout</code> 0, which disables
/// keep-alive reuse (AD-42).</p>
/// <p>Mutation: delete the <code>SocketTimeout</code> line from
/// <method>OcuPilot.Kernel.Provider.Base.NewRequest</method> -- every leg goes red at 115.</p>
Method TestEveryFamilyDisablesKeepAlive()
{
    For tStub = "OcuPilot.Test.ProviderStub", "OcuPilot.Test.OpenAIStub", "OcuPilot.Test.GeminiStub", "OcuPilot.Test.CompatibleStub" {
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 1)
        Kill tValues
        Do $ClassMethod(..#DRIVER, "Values", .tValues)
        Set tValues("keySource") = $Parameter("OcuPilot.Kernel.Provider.Base", "KEYSOURCENONE")
        Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus, tStub, .tValues)
        Do $$$AssertStatusOK(tSC, tStub _ ": the call returns $$$OK")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, tStub _ ": the transport was reached")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("socketTimeout", 1), 0, tStub _ ": the request's SocketTimeout is 0")
    }
}

/// <p>The shipped <method>OcuPilot.Kernel.Provider.Base.IssueHttpsPost</method>, against a
/// refused loopback connect, answers an error status and a <var>pStatus</var> of 0 -- the
/// classification the retry keys on, observed on the real transport rather than a stub.</p>
Method TestARefusedConnectAnswersNoStatus()
{
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 1)
    Set tSettings("sslConfiguration") = ""
    Set tSettings("timeoutSeconds") = 5
    Set tAdapter = ##class(OcuPilot.Kernel.Provider.Anthropic).%New()
    Set tRequest = tAdapter.NewRequest(.tSettings)
    Do $$$AssertEquals(tRequest.SocketTimeout, 0, "the real request disables keep-alive reuse")
    Set tStatus = -1
    Set tSC = tAdapter.IssueHttpsPost(tRequest, ..#REFUSEDURL, .tStatus, .tBody, .tRetryAfter)
    Set tRequest = ""
    Set tAdapter = ""
    Do $$$AssertStatusNotOK(tSC, "a refused connect answers an error status")
    Do $$$AssertTrue('$System.Status.Equals(tSC, $$$ERRORCODE($$$CSPTimeout)), "which is not a timeout: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tStatus, 0, "and no status line, so the loop may retry it")
}

/// <p>The shipped <method>OcuPilot.Kernel.Provider.Base.IssueHttpsPost</method> classifies a read
/// that broke by whether its status line arrived: after <code>HTTP/1.1 200 OK</code> it answers
/// <var>pStatus</var> 200, before any status line it answers 0, and both answer an error status.
/// <class>OcuPilot.Test.BrokenReadRequest</class> stands in for the socket.</p>
/// <p>Mutation: delete the status-line block from
/// <method>OcuPilot.Kernel.Provider.Base.IssueHttpsPost</method> -- the after-a-status-line leg
/// answers 0 and goes red.</p>
Method TestABrokenReadIsClassifiedByItsStatusLine()
{
    Set tAdapter = ##class(OcuPilot.Kernel.Provider.Anthropic).%New()
    For tLine = "HTTP/1.1 200 OK", "" {
        Set tRequest = ##class(OcuPilot.Test.BrokenReadRequest).%New()
        Set tRequest.BrokenStatusLine = tLine
        Set tStatus = -1
        Set tSC = tAdapter.IssueHttpsPost(tRequest, ..#REFUSEDURL, .tStatus, .tBody, .tRetryAfter)
        Set tRequest = ""
        Set tLeg = $Select(tLine = "": "before a status line", 1: "after " _ tLine)
        Do $$$AssertStatusNotOK(tSC, "a read that broke " _ tLeg _ " answers an error status")
        Do $$$AssertEquals(tStatus, $Select(tLine = "": 0, 1: 200), "and pStatus names what arrived " _ tLeg)
    }
    Set tAdapter = ""
}

}
