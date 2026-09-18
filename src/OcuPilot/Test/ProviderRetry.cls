/// <p>Story 4.8's retry arithmetic and the two budgets that bound one provider call: the status
/// table over its whole range including the determinate-server-error carve-out, both
/// <code>Retry-After</code> forms, the backoff window, the wait truncated to the retry budget, the
/// attempt deadline, the three failure kinds the transport loop tells apart, and the relation the
/// turn-side and provider-side ceilings stand in.</p>
/// <p><b>Every number is read with <code>$Parameter</code></b> from the class that declares it --
/// <class>OcuPilot.Kernel.Provider.Retry</class>, <class>OcuPilot.Kernel.State.Egress</class> and
/// <class>OcuPilot.Kernel.Agent.Limits</class> -- so no assertion here can restate a bound and then
/// agree with itself after the bound moves.</p>
/// <p><b>Needs nothing of the environment but a resolvable probe credential.</b> The transport is
/// <class>OcuPilot.Test.ProviderStub</class>: no socket is opened, its <method>Wait</method> records
/// instead of sleeping and its <method>NowSeconds</method> answers a counter the stub advances, so
/// a five-minute deadline is driven with no real time passing. The definition values, the outbound
/// settings and the probe key come from <class>OcuPilot.Test.Provider</class>, which declares them
/// once for the whole provider suite.</p>
Class OcuPilot.Test.ProviderRetry Extends %UnitTest.TestCase
{

/// <p>The arithmetic under test.</p>
Parameter RETRY = "OcuPilot.Kernel.Provider.Retry";

/// <p>The class declaring the shipped per-call timeout and attempt bound.</p>
Parameter EGRESS = "OcuPilot.Kernel.State.Egress";

/// <p>The class declaring the turn's own bounds.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The class whose values, settings and probe key this one drives the stub with.</p>
Parameter DRIVER = "OcuPilot.Test.Provider";

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

/// <p>Run one call through the stub with <var>pSettings</var>, and hand back everything it
/// produced.</p>
Method Call(ByRef pSettings, Output pResponse, Output pFault, Output pHttpStatus) As %Status
{
    Do $ClassMethod(..#DRIVER, "Values", .tValues)
    Do $ClassMethod(..#DRIVER, "Messages", .tMessages)
    Set tAdapter = ##class(OcuPilot.Test.ProviderStub).%New()
    Set tAdapter.SecretClassName = "OcuPilot.Test.SecretProbe"
    Set tSC = tAdapter.Invoke(.tValues, .tMessages, .tTools, "", .pSettings, .pResponse, .pFault, .pHttpStatus)
    Set tAdapter = ""
    Quit tSC
}

/// <p>An IMF-fixdate <var>pSeconds</var> from now, in the shape RFC 9110 prefers -- built from
/// <code>$ZTimeStamp</code>, so the test names an offset and never a date.</p>
ClassMethod HttpDateIn(pSeconds As %Integer) As %String
{
    Set tAt = ($Piece($ZTimeStamp, ",", 1) * 86400) + ($Piece($ZTimeStamp, ",", 2) \ 1) + pSeconds
    Quit $ZDate(tAt \ 86400, 11, , , , , , , , 1) _ ", " _ $ZDateTime((tAt \ 86400) _ "," _ (tAt # 86400), 2, , , , , , , , , , 1) _ " GMT"
}

/// <p><var>pFault</var>'s machine code, or <code>""</code> when the call produced no fault at all.
/// Read through here rather than off the object, so a call that unexpectedly <i>succeeded</i>
/// reports a failed assertion naming the code it did not carry, instead of raising
/// <code>&lt;INVALID OREF&gt;</code> and hiding which assertion was the one that mattered.</p>
ClassMethod FaultCode(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.code
}

/// <p>The total of the seconds <class>OcuPilot.Test.ProviderStub</class> recorded as waits.</p>
ClassMethod TotalWaited() As %Numeric
{
    Set tWaits = ##class(OcuPilot.Test.ProviderStub).Waits()
    If tWaits = "" Quit 0
    Set tTotal = 0
    For tI = 1:1:$Length(tWaits, "|") {
        Set tTotal = tTotal + $Piece(tWaits, "|", tI)
    }
    Quit tTotal
}

/// <p>AC1 -- the status table answers what the three declared lists say, over the whole numeric
/// range rather than at a handful of spot values, and the server-error band is retryable except for
/// exactly the statuses <parameter>OcuPilot.Kernel.Provider.Retry.NONRETRYABLESERVERSTATUSES</parameter>
/// carves out.</p>
/// <p>Mutation: remove <code>501</code> from that list -- the named assertion below it goes red.
/// The parameter-driven sweep alone does not, and that is why the two named statuses are asserted
/// beside it.</p>
Method TestTheStatusTableCarvesOutTheDeterminateServerErrors()
{
    Set tRetryable = $Parameter(..#RETRY, "RETRYABLESTATUSES")
    Set tNever = $Parameter(..#RETRY, "NONRETRYABLESERVERSTATUSES")
    Set tFloor = $Parameter(..#RETRY, "SERVERERRORFLOOR")
    Set tCeiling = $Parameter(..#RETRY, "STATUSCEILING")
    Set tWrong = ""
    Set tCarved = 0
    For tStatus = 100:1:700 {
        Set tExpected = 0
        If $ListFind($ListFromString(tRetryable), tStatus) {
            Set tExpected = 1
        } ElseIf (tStatus >= tFloor) && (tStatus <= tCeiling) {
            If '$ListFind($ListFromString(tNever), tStatus) Set tExpected = 1
        }
        If (tStatus >= tFloor) && (tStatus <= tCeiling) && 'tExpected Set tCarved = tCarved + 1
        If ''$ClassMethod(..#RETRY, "IsRetryable", tStatus) '= ''tExpected Set tWrong = tWrong _ " " _ tStatus
    }
    Do $$$AssertEquals(tWrong, "", "every status from 100 to 700 answers what the declared lists say; these did not:" _ tWrong)
    Do $$$AssertEquals(tCarved, $Length(tNever, ","), "and exactly the declared list is carved out of the server-error band, nothing else in it")
    ; The two statuses AC1 names, asserted by name as well as through the list. The sweep above is
    ; driven by the parameter and so agrees with whatever the parameter says: on its own it cannot
    ; tell a carve-out that lost a status from one that never held it.
    Do $$$AssertEquals($ClassMethod(..#RETRY, "IsRetryable", 501), 0, "501 Not Implemented is a determinate refusal, so it is never tried again")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "IsRetryable", 505), 0, "and neither is 505 HTTP Version Not Supported")
    For tNeighbour = 500, 502, 503, 504, 506 {
        Do $$$AssertEquals($ClassMethod(..#RETRY, "IsRetryable", tNeighbour), 1, "while their neighbours in the band are still worth another attempt: " _ tNeighbour)
    }
    Do $$$AssertEquals($ClassMethod(..#RETRY, "IsRetryable", ""), 0, "a status that is not a number is not retryable")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "IsRetryable", "429abc"), 0, "nor one that merely starts like one")
}

/// <p>AC1 -- the backoff window starts at the declared base, widens with the attempt to the
/// declared cap and no further, and the delay is drawn from it rather than fixed.</p>
/// <p>The claims are made over two hundred draws because full jitter makes any single draw
/// unusable as an assertion.</p>
Method TestTheBackoffWindowWidensToItsCapAndIsDrawnFromWithFullJitter()
{
    Set tBase = $Parameter(..#RETRY, "BACKOFFBASESECONDS")
    Set tCap = $Parameter(..#RETRY, "BACKOFFCAPSECONDS")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ExpBackoffSec", 0), 0, "there is no backoff before the first attempt")
    Set tOutside = ""
    Set tFirstMax = 0
    Set tDeepMax = 0
    Kill tSeen
    For tDraw = 1:1:200 {
        Set tOne = $ClassMethod(..#RETRY, "ExpBackoffSec", 1)
        Set tDeep = $ClassMethod(..#RETRY, "ExpBackoffSec", 12)
        If (tOne < 0) || (tOne > tBase) Set tOutside = tOutside _ " first=" _ tOne
        If (tDeep < 0) || (tDeep > tCap) Set tOutside = tOutside _ " later=" _ tDeep
        If tOne > tFirstMax Set tFirstMax = tOne
        If tDeep > tDeepMax Set tDeepMax = tDeep
        Set tSeen(tDeep) = ""
    }
    Do $$$AssertEquals(tOutside, "", "no draw falls outside its own window:" _ tOutside)
    Do $$$AssertTrue(tFirstMax > 0, "the first attempt's window is a window and not a constant zero")
    Do $$$AssertTrue(tDeepMax > tBase, "a later attempt draws from a wider window than the first: " _ tDeepMax _ " > " _ tBase)
    Do $$$AssertTrue(tDeepMax > (tCap / 2), "which reaches most of the declared cap rather than stopping short of it: " _ tDeepMax)
    Set tDistinct = 0
    Set tKey = $Order(tSeen(""))
    While tKey '= "" {
        Set tDistinct = tDistinct + 1
        Set tKey = $Order(tSeen(tKey))
    }
    Do $$$AssertTrue(tDistinct > 1, "and the delay is drawn rather than fixed, so callers that met one outage do not return together: " _ tDistinct _ " distinct values in 200 draws")
}

/// <p>AC2 -- both forms RFC 9110 gives <code>Retry-After</code>: delta-seconds as written, an
/// IMF-fixdate resolved against the clock, a date already past and an unreadable value as no hint
/// at all, and the declared ceiling applied whichever form arrived.</p>
/// <p>The future-date leg asserts a one-second window, not an exact value:
/// <method>HttpDateIn</method> and the parser read <code>$ZTimeStamp</code> at two different
/// moments, so the answer is the offset or one less, never anything else. Both bounds are far from
/// <code>0</code>, which is what the mutation produces.</p>
/// <p>Mutation: answer <code>0</code> from <method>OcuPilot.Kernel.Provider.Retry.HttpDateDeltaSec</method>'s
/// date branch -- the future-date leg goes red with 0 against a window starting at 11.</p>
Method TestBothRetryAfterFormsAreReadAndBothAreClamped()
{
    Set tMax = $Parameter(..#RETRY, "MAXRETRYAFTERSECONDS")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ParseRetryAfter", 12), 12, "delta-seconds are taken as written")
    Set tDated = $ClassMethod(..#RETRY, "ParseRetryAfter", ..HttpDateIn(12))
    Do $$$AssertTrue((tDated = 12) || (tDated = 11), "and an HTTP date twelve seconds out resolves to the same twelve, give or take the second that passed while the test built it: " _ tDated)
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ParseRetryAfter", ..HttpDateIn(-60)), 0, "a moment already past asks for no wait at all")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ParseRetryAfter", "not-a-date"), 0, "and a value this instance cannot read leaves the backoff alone in charge")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ParseRetryAfter", "Sunday, 06-Nov-2094 08:49:37 GMT"), 0, "so does an obsolete date form, which is discarded rather than partly read")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ParseRetryAfter", "0"), 0, "zero delta-seconds is no wait, not an absent header")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ParseRetryAfter", tMax + 1), tMax, "a hint one second above the declared ceiling is clamped to it")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "ParseRetryAfter", ..HttpDateIn(tMax * 10)), tMax, "and so is a date far in the future, so the date form buys no longer block than the number form")
}

/// <p>AC1, AC3 -- the delay is the greater of the honoured hint and the backoff, and is cut to the
/// remaining budget it is given.</p>
Method TestTheDelayIsTheGreaterOfTheTwoAndIsCutToWhatIsLeft()
{
    Set tMax = $Parameter(..#RETRY, "MAXRETRYAFTERSECONDS")
    Set tBudget = $Parameter(..#RETRY, "RETRYBUDGETSECONDS")
    Set tHintAlwaysWins = 1
    Set tBackoffEverWins = 0
    Set tOverBudget = 0
    For tDraw = 1:1:200 {
        If $ClassMethod(..#RETRY, "DelaySec", 12, tMax) '= tMax Set tHintAlwaysWins = 0
        If $ClassMethod(..#RETRY, "DelaySec", 12, 1) > 1 Set tBackoffEverWins = 1
        If $ClassMethod(..#RETRY, "DelaySec", 12, tMax, 2) > 2 Set tOverBudget = 1
    }
    Do $$$AssertTrue(tHintAlwaysWins, "a hint at its own ceiling is the delay whatever the backoff drew, because it exceeds the whole window")
    Do $$$AssertTrue(tBackoffEverWins, "and a hint below the window loses to it, so the delay is not simply the hint")
    Do $$$AssertTrue('tOverBudget, "no draw exceeds the remaining budget it was handed")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "DelaySec", 12, tMax, 0), 0, "nothing left means no wait at all")
    Set tDated = $ClassMethod(..#RETRY, "DelaySec", 12, ..HttpDateIn(tMax * 10))
    Do $$$AssertEquals(tDated, tMax, "a date-form hint is compared with the backoff exactly as a number is, and the greater of the two is the delay")
    Do $$$AssertEquals($ClassMethod(..#RETRY, "DelaySec", 12, tMax, tBudget), tMax, "and a budget at least as wide as the hint does not cut it")
}

/// <p>AC3 -- the total a call may spend sleeping is
/// <parameter>OcuPilot.Kernel.Provider.Retry.RETRYBUDGETSECONDS</parameter>: a hint the budget can
/// afford is honoured whole, the next one is <b>cut to what is left</b> rather than honoured, and a
/// retryable status met with nothing left stops the call instead of sleeping again.</p>
/// <p>Two hints of different sizes, deliberately. A provider asking for the ceiling twice spends
/// the whole budget on its first wait and stops on the second, which a budget that only ever
/// <i>stopped</i> the loop would also do -- so that scenario alone cannot see the truncation.</p>
/// <p>Mutation: hand <method>OcuPilot.Kernel.Provider.Base.Wait</method> the unbounded delay
/// instead of the budget-truncated one -- the second wait and the total both go red.</p>
Method TestTheRetryBudgetBoundsTheTotalSleep()
{
    Set tMax = $Parameter(..#RETRY, "MAXRETRYAFTERSECONDS")
    Set tBudget = $Parameter(..#RETRY, "RETRYBUDGETSECONDS")
    Set tFirstHint = tBudget - (tBudget \ 3)
    Do $$$AssertTrue(tFirstHint > $Parameter(..#RETRY, "BACKOFFCAPSECONDS"), "the first hint exceeds the whole backoff window, so it and not a draw is what the wait measures: " _ tFirstHint)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "", tFirstHint)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "", tMax)
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 9)
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK rather than raising")
    Set tWaits = ##class(OcuPilot.Test.ProviderStub).Waits()
    Do $$$AssertEquals($Piece(tWaits, "|", 1), tFirstHint, "the first hint is honoured whole, because the budget could afford it: " _ tWaits)
    Do $$$AssertEquals($Piece(tWaits, "|", 2), tBudget - tFirstHint, "the second is cut to what the budget had left, not honoured at the value the provider asked for: " _ tWaits)
    Do $$$AssertEquals(..TotalWaited(), tBudget, "so the total slept is exactly the budget and never more: " _ tWaits)
    Do $$$AssertTrue(##class(OcuPilot.Test.ProviderStub).Calls() < 9, "and the call stopped on the budget rather than on its attempt bound: " _ ##class(OcuPilot.Test.ProviderStub).Calls())
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE, "the provider did not serve this call on any attempt it made")
    Do $$$AssertEquals(tHttpStatus, 502, "answered as a gateway failure")
}

/// <p>AC3, as the matrix writes it -- two consecutive 429s each hinting the ceiling: the first
/// wait is honoured whole, the second is not taken at all because the budget has nothing left, and
/// the call ends <code>PROVIDER.UNAVAILABLE</code> without sleeping again.</p>
/// <p>Kept beside the truncation case rather than folded into it: this scenario stops on the
/// budget <i>guard</i> and never exercises truncation, which is why the other method uses two
/// differently-sized hints.</p>
Method TestTwoHintsAtTheCeilingBuyOneWaitAndNotTwo()
{
    Set tMax = $Parameter(..#RETRY, "MAXRETRYAFTERSECONDS")
    Do $$$AssertEquals($Parameter(..#RETRY, "RETRYBUDGETSECONDS"), tMax, "the budget is one honoured Retry-After at its own ceiling, which is what makes this the scenario it is")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "", tMax)
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 9)
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK rather than raising")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), tMax, "exactly one wait, of the whole ceiling, and no second one: " _ ##class(OcuPilot.Test.ProviderStub).Waits())
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "so two attempts were made, not the nine the settings allow")
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE, "and the call ends PROVIDER.UNAVAILABLE")
    Do $$$AssertEquals(tHttpStatus, 502, "answered as a gateway failure")
}

/// <p>AC3 -- a stored per-call timeout large enough that two attempts pass
/// <parameter>OcuPilot.Kernel.Provider.Retry.ATTEMPTBUDGETSECONDS</parameter>: no further attempt
/// is started and the call ends <code>PROVIDER.TIMEOUT</code>, however many attempts the settings
/// still allow.</p>
/// <p>Mutation: raise that parameter to 100000 -- the call spends all nine attempts and the call
/// count and the code both go red.</p>
Method TestTheAttemptDeadlineRefusesAFurtherAttempt()
{
    Set tDeadline = $Parameter(..#RETRY, "ATTEMPTBUDGETSECONDS")
    Set tPerCall = (tDeadline \ 2) + 1
    Do ##class(OcuPilot.Test.ProviderStub).ScriptElapsed(tPerCall)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(503, "")
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 9)
    Set tSettings("timeoutSeconds") = tPerCall
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK rather than raising")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "two attempts, each taking more than half the deadline, and no third is started")
    Do $$$AssertTrue(##class(OcuPilot.Test.ProviderStub).Clock() >= tDeadline, "the clock the loop reads did pass the deadline: " _ ##class(OcuPilot.Test.ProviderStub).Clock())
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT, "and the call ends PROVIDER.TIMEOUT rather than spending its whole attempt bound")
    Do $$$AssertEquals(tHttpStatus, 504, "answered as a gateway timeout")
}

/// <p>AC4 -- a call that raised, a call that timed out and a call that failed in transport are told
/// apart by the <code>Try</code> around the seam and by
/// <method>$System.Status.Equals</method> alone, and <b>none of the three is ever retried</b>: the
/// request may already have been processed.</p>
/// <p>Mutation: continue the loop after a raise instead of leaving it -- the raised leg's call
/// count goes red, reporting three.</p>
Method TestNoFailedTransportIsEverRetried()
{
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
    Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "a call that raised mid-flight still returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and enters the transport exactly once, whatever the attempt bound allows")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "", "with nothing waited to try again")
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "a raise is PROVIDER.TRANSPORT")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
    Set tSC = ..Call(.tSettings, .tTimeoutResponse, .tTimeoutFault, .tTimeoutStatus)
    Do $$$AssertStatusOK(tSC, "a call that timed out still returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and is not retried either")
    Do $$$AssertEquals(..FaultCode(tTimeoutFault), ##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT, "a timeout status is PROVIDER.TIMEOUT")
    Do $$$AssertEquals(tTimeoutStatus, 504, "answered as a gateway timeout")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(0)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
    Set tSC = ..Call(.tSettings, .tOtherResponse, .tOtherFault, .tOtherStatus)
    Do $$$AssertStatusOK(tSC, "a call that reached no provider still returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "and is not retried either")
    Do $$$AssertEquals(..FaultCode(tOtherFault), ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, "every other transport failure is PROVIDER.TRANSPORT")
}

/// <p>AC1 -- a determinate server error reaches the transport once and is reported as a refusal,
/// which is the carve-out observed through the loop rather than through the arithmetic alone.</p>
Method TestADeterminateServerErrorIsNotRetried()
{
    Set tStatus = $Piece($Parameter(..#RETRY, "NONRETRYABLESERVERSTATUSES"), ",", 1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(tStatus, "")
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 3)
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "HTTP " _ tStatus _ " is answered once and not tried again")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "", "and nothing was waited on the way to that answer")
    Do $$$AssertEquals(..FaultCode(tFault), ##class(OcuPilot.Api.Error).#PROVIDERREFUSED, "it is reported as a refusal, not as an unavailable provider")

    ; And the refusal carries the provider's own words in detail.providerText, normalised at the
    ; port boundary rather than the raw body (AD-39).
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer($Piece($Parameter(..#RETRY, "NONRETRYABLESERVERSTATUSES"), ",", 2), "{""type"":""error"",""error"":{""message"":""unsupported protocol version""}}")
    Set tSC = ..Call(.tSettings, .tSecondResponse, .tSecondFault, .tSecondStatus)
    Do $$$AssertStatusOK(tSC, "the second determinate status returns $$$OK too")
    Do $$$AssertEquals(..FaultCode(tSecondFault), ##class(OcuPilot.Api.Error).#PROVIDERREFUSED, "and is a refusal as well")
    Do $$$AssertEquals(..ProviderText(tSecondFault), "unsupported protocol version", "carrying the provider's own message, which is what tells an operator what to change")
}

/// <p><var>pFault</var>'s <code>detail.providerText</code>, or <code>""</code>.</p>
ClassMethod ProviderText(pFault As %RawString = "") As %String
{
    If '$IsObject(pFault) Quit ""
    If '$IsObject(pFault.detail) Quit ""
    Quit pFault.detail.providerText
}

/// <p>Residual risk (frontmatter <code>deferred:</code>, not decided by this spec) --
/// <parameter>OcuPilot.Kernel.Provider.Retry.ATTEMPTBUDGETSECONDS</parameter> is read only
/// <i>between</i> attempts, so it bounds when a further attempt may <b>start</b> and not when one
/// already running must end. Nothing clamps a stored <code>timeoutSeconds</code> to it, so a
/// value many times the deadline reaches the request exactly as configured. Pinned here so this
/// worst case is a stated fact the next reader can see failing rather than one they have to
/// re-derive from <method>TestTheAttemptDeadlineRefusesAFurtherAttempt</method>, which only shows
/// the deadline stopping the <i>next</i> attempt.</p>
/// <p>Mutation: clamp <method>OcuPilot.Kernel.Provider.Base.NewRequest</method>'s
/// <code>Timeout</code> to <parameter>OcuPilot.Kernel.Provider.Retry.ATTEMPTBUDGETSECONDS</parameter>
/// -- this goes red, the recorded timeout reporting the budget instead of the configured value.</p>
Method TestAStoredTimeoutFarPastTheDeadlineReachesTheRequestWithNoClamp()
{
    Set tDeadline = $Parameter(..#RETRY, "ATTEMPTBUDGETSECONDS")
    Set tHuge = tDeadline * 10
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, $Parameter(..#DRIVER, "OKBODY"))
    Do $ClassMethod(..#DRIVER, "Settings", .tSettings, 1)
    Set tSettings("timeoutSeconds") = tHuge
    Set tSC = ..Call(.tSettings, .tResponse, .tFault, .tHttpStatus)
    Do $$$AssertStatusOK(tSC, "the call returns $$$OK")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("timeout", 1), tHuge, "the request's own socket timeout carries the configured value unclamped, ten times the attempt deadline: nothing in this loop bounds an attempt already committed to")
}

/// <p>AC13 -- the turn's declared ceiling on one provider call and the one the provider actually
/// enforces are the same number, that number is inside the turn's own wall clock, and the shipped
/// per-call defaults plus the sleep budget fit inside it. Every term is read from the class that
/// declares it.</p>
/// <p><b>The last assertion pins a relation, not the absence of compounding.</b> The two waits are
/// taken by different steps, so across one turn they add and it is
/// <parameter>OcuPilot.Kernel.Agent.Limits.WALLCLOCKSECONDS</parameter> that bounds the sum; what
/// is asserted is that neither bound on its own is the wider one by accident.</p>
/// <p>Mutation: set <parameter>OcuPilot.Kernel.Agent.Limits.PROVIDERCALLSECONDS</parameter> to 700
/// -- the first two assertions go red.</p>
Method TestTheTurnSideAndProviderSideCeilingsAgree()
{
    Set tEnforced = $Parameter(..#RETRY, "ATTEMPTBUDGETSECONDS")
    Set tDeclared = $Parameter(..#LIMITS, "PROVIDERCALLSECONDS")
    Set tWallClock = $Parameter(..#LIMITS, "WALLCLOCKSECONDS")
    Set tAttempts = $Parameter(..#EGRESS, "DEFAULTMAXATTEMPTS")
    Set tTimeout = $Parameter(..#EGRESS, "DEFAULTTIMEOUT")
    Set tBudget = $Parameter(..#RETRY, "RETRYBUDGETSECONDS")
    Do $$$AssertEquals(tDeclared, tEnforced, "the turn declares the same ceiling on one provider call that the provider enforces")
    Do $$$AssertTrue(tDeclared < tWallClock, "and it is inside the turn's own wall clock, so one call can never be the whole turn: " _ tDeclared _ " < " _ tWallClock)
    Do $$$AssertTrue(((tAttempts * tTimeout) + tBudget) <= tEnforced, "the shipped per-call defaults and the sleep budget fit inside the deadline, so it binds only a stored timeout larger than the default: " _ ((tAttempts * tTimeout) + tBudget) _ " <= " _ tEnforced)
    Do $$$AssertTrue(tBudget <= $Parameter(..#RETRY, "MAXRETRYAFTERSECONDS"), "and the sleep budget is one honoured Retry-After at its own ceiling, never two")
    Do $$$AssertTrue($Parameter(..#LIMITS, "NAVWAITSECONDS") < tDeclared, "a client-fulfilled wait and a provider call are separate steps, each bounded on its own, and the wait is the narrower of the two bounds: " _ $Parameter(..#LIMITS, "NAVWAITSECONDS") _ " < " _ tDeclared)
}

}
