/// <p>AC2 and AC5 -- the provider base's never-throw template and the Anthropic adapter, driven
/// through <class>OcuPilot.Test.ProviderStub</class>'s transport seam so the whole path runs with
/// <b>no socket opened and no provider called</b>.</p>
/// <p><b>The assertion the class exists for is <code>$$$OK</code> on every failure path.</b>
/// "Never throws" is a claim about code that has been made to fail, so each failure class below is
/// forced and each asserts the status, the stop reason, the code and the absence of an exception
/// together.</p>
/// <p>The stub answers a queued script and records what the request carried; everything above the
/// seam -- the credential resolution, the key-shape gate, the body, the headers, the retry
/// arithmetic, the response mapping and the fault -- is shipped code running unchanged.</p>
Class OcuPilot.Test.Provider Extends %UnitTest.TestCase
{

/// <p>The credential the stub path resolves, shaped so it passes the probe row's prefix gate.</p>
Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>The endpoint every call below names. Public, so nothing in the egress policy is under test
/// here -- that is <class>OcuPilot.Test.Egress</class>'s and
/// <class>OcuPilot.Test.ProviderPort</class>'s.</p>
Parameter ENDPOINT = "https://api.anthropic.com/v1/messages";

/// <p>A well-formed reply carrying one text block and both usage figures.</p>
Parameter OKBODY = "{""content"":[{""type"":""text"",""text"":""hello""}],""stop_reason"":""max_tokens"",""usage"":{""input_tokens"":11,""output_tokens"":22}}";

/// <p>A provider error body in the family's own shape.</p>
Parameter ERRORBODY = "{""type"":""error"",""error"":{""type"":""authentication_error"",""message"":""invalid x-api-key""}}";

/// <p>Arm a clean stub and a resolvable credential before each method.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Quit $$$OK
}

/// <p>Leave nothing behind for the next method, or the next class, to read.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Quit $$$OK
}

/// <p>The definition values one call is made with.</p>
ClassMethod Values(Output pValues, pKeyPrefix As %String = "probe-local-")
{
    Kill pValues
    Set pValues("provider") = "probe-local"
    Set pValues("model") = "probe-local-model-1"
    Set pValues("endpointUrl") = ..#ENDPOINT
    Set pValues("markedLocal") = 0
    Set pValues("credType") = "env"
    Set pValues("envVarName") = "OCUPILOT_PROBE_LOCAL_KEY"
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = 4000
    Set pValues("temperature") = 0
    Set pValues("keyPrefix") = pKeyPrefix
    Set pValues("authVersion") = "probe-version-2"
}

/// <p>The outbound settings one call is made with, <var>pMaxAttempts</var> attempts allowed.</p>
ClassMethod Settings(Output pSettings, pMaxAttempts As %Integer = 1)
{
    Kill pSettings
    Set pSettings("proxyServer") = ""
    Set pSettings("proxyPort") = 0
    Set pSettings("proxyHttps") = 0
    Set pSettings("proxyTunnel") = 0
    Set pSettings("timeoutSeconds") = 90
    Set pSettings("maxAttempts") = pMaxAttempts
    Set pSettings("sslConfiguration") = "OcuPilotProvider"
}

/// <p>One message, which every call below sends.</p>
ClassMethod Messages(Output pMessages)
{
    Kill pMessages
    Set pMessages = 1
    Set pMessages(1, "role") = "user"
    Set pMessages(1, "content") = "what is on this screen"
}

/// <p>Run one call through the stub and hand back everything it produced.</p>
Method Call(ByRef pValues, ByRef pSettings, Output pResponse, Output pFault, Output pHttpStatus, pSystemPrompt As %String = "", ByRef pTools) As %Status
{
    Do ..Messages(.tMessages)
    Set tAdapter = ##class(OcuPilot.Test.ProviderStub).%New()
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Set tSC = tAdapter.Invoke(.pValues, .tMessages, .pTools, pSystemPrompt, .pSettings, .pResponse, .pFault, .pHttpStatus)
    Set tAdapter = ""
    Quit tSC
}

/// <p>Assert that a call answered <code>$$$OK</code>, reported the failure through the response and
/// the fault, and carried <var>pCode</var>.</p>
Method AssertTurnError(pSC As %Status, pResponse As OcuPilot.Kernel.Provider.Response, pFault As %DynamicObject, pCode As %String, pWhat As %String)
{
    Do $$$AssertStatusOK(pSC, pWhat _ ": the call returns $$$OK rather than raising or reporting an error status")
    Do $$$AssertTrue($IsObject(pResponse), pWhat _ ": and a response object")
    If '$IsObject(pResponse) Quit
    Do $$$AssertEquals(pResponse.StopReason, "error", pWhat _ ": whose stop reason is the failure signal")
    Do $$$AssertTrue($IsObject(pFault), pWhat _ ": and a fault")
    If '$IsObject(pFault) Quit
    Do $$$AssertEquals(pFault.code, pCode, pWhat _ ": carrying " _ pCode _ " (" _ pFault.%ToJSON() _ ")")
    Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(pFault.code), pWhat _ ": which is a well-formed machine code")
}

/// <p>The control, and AC2's other half: a call the provider answers is a call that reports a
/// reply. Without it every failure assertion below would be satisfied by an adapter that failed
/// everything.</p>
Method TestAnAnsweredCallReportsTheReply()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "a happy call returns $$$OK")
    Do $$$AssertEquals(tResponse.StopReason, "max_tokens", "the stop reason comes from the body, not from a default")
    Do $$$AssertEquals(tResponse.Text, "hello", "the text blocks are concatenated in order")
    Do $$$AssertEquals(tResponse.RequestTokens, 11, "the request tokens are the body's own figure")
    Do $$$AssertEquals(tResponse.ResponseTokens, 22, "and the response tokens")
    Do $$$AssertEquals(tResponse.HttpStatus, 200, "the HTTP status the attempt read")
    Do $$$AssertTrue('$IsObject(tFault), "and no fault at all")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "one transport call, and only one")
}

/// <p>AC2 -- the canonical body: the model, the two tuning values, the system prompt when there is
/// one, the messages, and the tools with their schemas.</p>
/// <p>Mutation: send <code>max_tokens</code> under any other key -- this goes red, and nothing
/// else does.</p>
Method TestTheBodyIsTheCanonicalShape()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings)
    Set tTools = 1
    Set tTools(1, "name") = "webapps.list.read"
    Set tTools(1, "description") = "read the web application list"
    Set tTools(1, "inputSchema") = "{""type"":""object"",""properties"":{}}"
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus, "you are a probe", .tTools)
    Do $$$AssertStatusOK(tSC, "the call with tools and a system prompt returns $$$OK")
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body"))
    Do $$$AssertTrue($IsObject(tBody), "the recorded request body parses as JSON")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.model, "probe-local-model-1", "the model is the definition's")
    Do $$$AssertEquals(+tBody."max_tokens", 4000, "the maximum tokens ride under the provider's own key")
    Do $$$AssertEquals(+tBody.temperature, 0, "and the temperature")
    Do $$$AssertEquals(tBody.system, "you are a probe", "the system prompt is sent when there is one")
    Do $$$AssertEquals(tBody.messages.%Size(), 1, "one message")
    Do $$$AssertEquals(tBody.messages.%Get(0).role, "user", "with its role")
    Do $$$AssertEquals(tBody.tools.%Size(), 1, "one tool")
    Do $$$AssertEquals(tBody.tools.%Get(0).name, "webapps.list.read", "with its name")
    Do $$$AssertEquals(tBody.tools.%Get(0)."input_schema".type, "object", "and its schema as an object rather than as text")
}

/// <p>AC2 -- a call with no system prompt and no tools omits both keys rather than sending them
/// empty: an empty system prompt is not the same request as no system prompt.</p>
Method TestAnEmptySystemPromptAndNoToolsAreOmitted()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body"))
    Do $$$AssertTrue($IsObject(tBody), "the recorded body parses")
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%IsDefined("system"), 0, "no system key at all")
    Do $$$AssertEquals(tBody.%IsDefined("tools"), 0, "and no tools key")
}

/// <p>AC3's adapter half and AC6's -- the two authentication headers are set, and the content type
/// is the family's.</p>
/// <p>The stub records header <b>names</b> only: recording a value would put the credential into a
/// global that AC6's own assertions would then have to exempt.</p>
Method TestTheTwoAuthenticationHeadersAreSet()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "x-api-key,anthropic-version", "both authentication headers carry a value")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("contentType"), "application/json", "and the content type is the family's")
}

/// <p>AC2 -- an unresolved credential refuses <b>before any call is made</b>, and the reason names
/// the reference rather than a value.</p>
Method TestAnUnresolvedCredentialMakesNoCall()
{
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERCREDENTIAL, "an unresolved credential")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no transport call was made at all")
    Do $$$AssertTrue(tFault.reason [ "OCUPILOT_PROBE_LOCAL_KEY", "the reason names the reference the definition points at: " _ tFault.reason)
    Do $$$AssertEquals(tResponse.HttpStatus, 0, "and the response reports no HTTP status, because there was no call")
}

/// <p>AC2 -- a credential that does not match the row's prefix refuses before any call is made, and
/// the reason states no part of the resolved value.</p>
/// <p>This is the harvest's <code>EnvVarName=PATH</code> bug: an unset variable read as a value and
/// sent as a key. A shape gate turns it into a refusal naming the reference.</p>
Method TestAKeyOfTheWrongShapeMakesNoCall()
{
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("/usr/bin:/bin:/usr/sbin")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERKEYSHAPE, "a credential of the wrong shape")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and no transport call was made at all")
    Do $$$AssertEquals(tFault.reason [ "/usr/bin", 0, "and the reason carries no part of the resolved value: " _ tFault.reason)
    Do $$$AssertTrue(tFault.reason [ "probe-local-", "while it does state the prefix the row declares, so an operator is told what shape was expected: " _ tFault.reason)
}

/// <p>AC5 -- the retry arithmetic driven directly over its input range, which is the reason
/// <class>OcuPilot.Kernel.Provider.Retry</class> is a separate class at all: through the transport
/// loop alone, the ceiling, the status table and the "greater of the two" rule each have exactly
/// one case, and the delays are measured in seconds.</p>
/// <p>Mutation: replace <method>DelaySec</method>'s body with
/// <code>Quit ..ParseRetryAfter(pRetryAfter)</code> -- the mixed-draw leg goes red, because taking
/// the hint alone answers 1 every time and the backoff can exceed it. Mutation: delete the
/// <parameter>MAXRETRYAFTERSECONDS</parameter> clamp -- the 3600 leg goes red with 3600, which is
/// an hour a provider chose to block a turn for.</p>
Method TestTheRetryArithmeticOverItsWholeRange()
{
    For tStatus = 408, 409, 429, 500, 503, 529, 599 {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).IsRetryable(tStatus), 1, "HTTP " _ tStatus _ " is worth another attempt")
    }
    For tStatus = 200, 201, 400, 401, 403, 404, 422, 600 {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).IsRetryable(tStatus), 0, "HTTP " _ tStatus _ " is not")
    }
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).IsRetryable(""), 0, "and neither is a status that is not a number")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).IsRetryable("429abc"), 0, "nor one that merely starts like one")

    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).ParseRetryAfter("7"), 7, "delta-seconds are honoured")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).ParseRetryAfter("0"), 0, "including zero")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).ParseRetryAfter("3600"), 30, "a hint above the ceiling is clamped to thirty seconds, so a provider cannot choose how long a turn blocks")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).#MAXRETRYAFTERSECONDS, 30, "and the ceiling is the declared thirty")
    For tHeader = "not-a-date", "7 seconds", "-5", "", "1.5" {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).ParseRetryAfter(tHeader), 0, "anything that is neither delta-seconds nor an HTTP date is discarded rather than partly read: '" _ tHeader _ "'")
    }

    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).ExpBackoffSec(0), 0, "there is no backoff before the first attempt")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Retry).DelaySec(1, "7"), 7, "the hint wins when it exceeds the backoff window")

    ; The other direction, which the transport loop cannot reach: a hint below the window. Full
    ; jitter makes any single draw unusable as an assertion, so the claim is made over the draws --
    ; taking the hint alone answers 1 every time, and the maximum below then cannot exceed it.
    Set tMax = 0
    For tDraw = 1:1:100 {
        Set tDelay = ##class(OcuPilot.Kernel.Provider.Retry).DelaySec(5, "1")
        Do $$$AssertTrue(tDelay >= 1, "no draw is below the provider's own hint: " _ tDelay)
        Do $$$AssertTrue(tDelay <= ##class(OcuPilot.Kernel.Provider.Retry).#BACKOFFCAPSECONDS, "and none exceeds the declared cap: " _ tDelay)
        If tDelay > tMax Set tMax = tDelay
    }
    Do $$$AssertTrue(tMax > 1, "and the backoff wins when it is the greater, so the delay is not simply the hint: " _ tMax)
}

/// <p>A row that declares no prefix gates nothing, which is the right answer for a family whose
/// keys have no fixed shape. Without this the shape gate would be a rule about
/// <code>anthropic</code> rather than about the column.</p>
Method TestARowWithNoPrefixGatesNothing()
{
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("anything-at-all")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues, "")
    Do ..Settings(.tSettings)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "a call whose row declares no key prefix returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and reaches the transport")
}

/// <p>AC5 -- a retryable status is tried again, the delay is the greater of the provider's hint and
/// the backoff, and the second attempt's answer is the one reported.</p>
/// <p>Mutation: take the <code>Retry-After</code> hint instead of the greater of the two -- the
/// delay assertion goes red for the 7-second hint, whose backoff window tops out below it.</p>
Method TestARetryableStatusIsTriedAgain()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "{""type"":""error"",""error"":{""message"":""slow down""}}", 7)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 3)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the retried call returns $$$OK")
    Do $$$AssertEquals(tResponse.StopReason, "max_tokens", "and the second attempt's reply is the one reported")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "exactly two transport calls")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), 7, "and one wait, of the provider's own hint, which exceeds the backoff window: " _ ##class(OcuPilot.Test.ProviderStub).Waits())
}

/// <p>AC5 -- a <code>Retry-After</code> the arithmetic can read as neither form is discarded and the
/// exponential backoff alone is used: never parsed as a number, never a negative or huge delay.</p>
Method TestANonNumericRetryAfterIsDiscarded()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(503, "", "not-a-date")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 2)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the retried call returns $$$OK")
    Set tWait = ##class(OcuPilot.Test.ProviderStub).Waits()
    Do $$$AssertTrue((tWait >= 0) && (tWait <= ##class(OcuPilot.Kernel.Provider.Retry).#BACKOFFCAPSECONDS), "the wait is a backoff within the declared cap, not a date read as a number: " _ tWait)
}

/// <p>AC5 -- the attempt bound is the stored one, and exhausting it is
/// <code>PROVIDER.UNAVAILABLE</code> rather than an endless loop.</p>
Method TestTheAttemptBoundIsHonoured()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(529, "")
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 3)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE, "a retryable status on every attempt")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 3, "exactly the three attempts the settings allow")
    Do $$$AssertEquals($Length(##class(OcuPilot.Test.ProviderStub).Waits(), "|"), 2, "and two waits between them, never one after the last")
}

/// <p>AC2, AC5 -- a non-retryable status is <b>not</b> retried, and the provider's own message
/// rides in <code>detail.providerText</code> while its raw body does not reach the fault at
/// all.</p>
Method TestANonRetryableStatusIsNotRetried()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, ..#ERRORBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 3)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERREFUSED, "a status the provider will refuse again")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the transport seam is entered exactly once")
    Do $$$AssertEquals(tFault.detail.providerText, "invalid x-api-key", "the provider's own message rides in detail.providerText")
    Do $$$AssertEquals(tFault.%ToJSON() [ "authentication_error", 0, "and its raw body does not reach the fault: " _ tFault.%ToJSON())
    Do $$$AssertEquals(tResponse.HttpStatus, 401, "the response reports the status the attempt read")
    Do $$$AssertEquals(tHttpStatus, 502, "and the port answers a gateway failure")
}

/// <p>AC5 -- <b>a call that threw mid-flight is never retried at all</b>, however many attempts the
/// settings allow: the request may already have been processed.</p>
/// <p>Mutation: let the loop continue after a throw -- "the transport seam is entered exactly once
/// after a throw" goes red, reporting three.</p>
Method TestAThrownCallIsNeverRetried()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 3)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "a call that raised mid-flight")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the transport seam is entered exactly once after a throw")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "", "and nothing waited to try again")
}

/// <p>AC2, AC5 -- a timeout is told apart from every other transport failure and, like a throw, is
/// never retried.</p>
Method TestATimeoutIsNamedAndNotRetried()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(1)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 3)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT, "a call that timed out")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the transport seam is entered exactly once")
    Do $$$AssertEquals(tHttpStatus, 504, "and the port answers a gateway timeout")
}

/// <p>AC2 -- a transport failure that is not a timeout is <code>PROVIDER.TRANSPORT</code>.</p>
Method TestATransportFailureIsNamed()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 1)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "a call that reached no provider")
}

/// <p>AC2 -- a 200 whose body the adapter cannot read is a failure, not an empty reply. A turn
/// handed a silent blank would report that the model said nothing.</p>
Method TestAnUnreadableSuccessBodyIsAFailure()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "not json at all")
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 1)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "a 200 carrying a body this adapter cannot read")
    Do $$$AssertEquals(tResponse.Text, "", "and no text is reported")
}

/// <p>AC2 -- a 200 whose body <b>parses</b> but is not the shape this adapter reads is a failure,
/// not an empty reply. Both bodies below satisfy <code>$IsObject</code>, which is exactly why the
/// two <code>%IsA</code> tests exist: without them the iterator walks the value, matches no block,
/// and the turn is handed a successful blank.</p>
/// <p>Probed on this build: <code>%FromJSON("[...]")</code> answers an object whose
/// <code>%IsA("%Library.DynamicObject")</code> is 0, and an object-valued <code>content</code>
/// answers <code>%IsA("%Library.DynamicArray")</code> 0.</p>
/// <p>Mutation: drop the <b>content-array</b> <code>%IsA</code> test -- the second leg goes red,
/// reporting <code>$$$OK</code> with an empty reply instead of <code>PROVIDER.TRANSPORT</code>.
/// Dropping the <b>top-level</b> test alone does <b>not</b> redden either leg, and that is a
/// measured fact rather than a gap in this method: a body that parses, is an object, and is not a
/// <code>DynamicObject</code> is a <code>DynamicArray</code>, whose <code>content</code> is
/// undefined -- so the content-array test below refuses exactly the same bodies. The top-level
/// test earns its place by naming the cause accurately in the log, not by refusing anything the
/// one below it would admit.</p>
Method TestABodyOfTheWrongJsonShapeIsAFailure()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "[{""type"":""text"",""text"":""hi""}]")
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 1)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "a 200 whose body is a JSON array rather than an object")
    Do $$$AssertEquals(tResponse.Text, "", "and no text is reported for it")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":{""type"":""text"",""text"":""hi""},""stop_reason"":""end_turn""}")
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 1)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do ..AssertTurnError(tSC, tResponse, tFault, ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "a 200 whose content is an object rather than an array")
    Do $$$AssertEquals(tResponse.Text, "", "and no text is reported for that either")
}

/// <p>AC2 -- a reply carrying tool-use blocks keeps them verbatim, and a tool-only reply is not an
/// empty one.</p>
Method TestToolUseBlocksAreKeptVerbatim()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{""content"":[{""type"":""tool_use"",""id"":""t1"",""name"":""webapps.list.read"",""input"":{}}],""stop_reason"":""tool_use"",""usage"":{""input_tokens"":3,""output_tokens"":4}}")
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 1)
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "a tool-only reply returns $$$OK")
    Do $$$AssertEquals(tResponse.StopReason, "tool_use", "with the provider's own stop reason")
    Do $$$AssertEquals(tResponse.Text, "", "no text")
    Set tCalls = ##class(%DynamicAbstractObject).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertTrue($IsObject(tCalls), "and a tool-call array that parses: " _ tResponse.ToolCallsJson)
    If '$IsObject(tCalls) Quit
    Do $$$AssertEquals(tCalls.%Size(), 1, "carrying the one block")
    Do $$$AssertEquals(tCalls.%Get(0).name, "webapps.list.read", "verbatim, in the provider's own shape")
}

/// <p>AC3's adapter half -- the request carries the settings it was given and nothing of this
/// class's own: the TLS configuration name, server-identity checking on, the timeout, and the four
/// proxy values.</p>
/// <p>Mutation: set <code>SSLCheckServerIdentity</code> to 0 where the request is built -- this
/// goes red, and it is the only assertion that does.</p>
Method TestTheRequestCarriesTheSettingsItWasGiven()
{
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Do ..Values(.tValues)
    Do ..Settings(.tSettings, 1)
    Set tSettings("timeoutSeconds") = 45
    Set tSettings("proxyServer") = "proxy.probe.invalid"
    Set tSettings("proxyPort") = 3128
    Set tSettings("proxyHttps") = 1
    Set tSettings("proxyTunnel") = 1
    Set tSC = ..Call(.tValues, .tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the configured call returns $$$OK")
    Set tStub = "OcuPilot.Test.ProviderStub"
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "sslConfiguration"), "OcuPilotProvider", "the request carries the named TLS configuration, never DefaultSSL")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "sslCheckServerIdentity"), 1, "with server-identity checking on")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "timeout"), 45, "the stored timeout, not a class parameter")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyServer"), "proxy.probe.invalid", "the stored proxy host")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyPort"), 3128, "its port")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyHttps"), 1, "whether the target is requested as https through the proxy")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "proxyTunnel"), 1, "and whether it is tunnelled")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "followRedirect"), 0, "redirects are not followed, so the judged endpoint is the only host the key reaches")
    Do $$$AssertEquals($ClassMethod(tStub, "Recorded", "url"), ..#ENDPOINT, "and the endpoint the definition names")
}

/// <p>An instance with no stored settings is served the shipped defaults rather than nothing, so a
/// clean instance makes a call with a bounded timeout and a bounded attempt count.</p>
Method TestAnInstanceWithNoStoredSettingsTakesTheDefaults()
{
    Set tSC = ##class(OcuPilot.Kernel.State.Egress).Resolve(.tSettings)
    Do $$$AssertStatusOK(tSC, "the settings resolve on an instance that stores none")
    ; Literals, and that is load-bearing: comparing against #DEFAULTTIMEOUT and #DEFAULTMAXATTEMPTS
    ; cannot fail, because changing the parameter moves the expectation with it -- the same trap
    ; OcuPilot.Test.ProviderSsl records having measured for the installer's own parameters. These
    ; two bound every provider call on an instance that stores no settings row.
    Do $$$AssertEquals(tSettings("timeoutSeconds"), 90, "the default timeout is ninety seconds")
    Do $$$AssertEquals(tSettings("maxAttempts"), 3, "the default attempt bound is three, so at most two retries")
    Do $$$AssertEquals(tSettings("sslConfiguration"), "OcuPilotProvider", "and the TLS configuration the installer creates")
    Do $$$AssertEquals(tSettings("proxyServer"), "", "with no proxy")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.State.Egress).#DEFAULTTIMEOUT, 90, "the parameter itself carries that timeout")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.State.Egress).#DEFAULTMAXATTEMPTS, 3, "and that attempt bound")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.State.Base).#SSLCONFIG, "OcuPilotProvider", "and the kernel names that configuration once")
}

}
