/// <p>Pins <method>OcuPilot.Test.ProviderStubTransport.Transport</method>, the one scripted transport
/// <class>OcuPilot.Test.ProviderStub</class> and the three family stubs answer through, at the seam
/// itself: each stub's <code>IssueHttpsPost</code> is called directly, with no port, no catalog and
/// no adapter call above it.</p>
/// <p>The adapter-level suites reach the transport only through a whole call, where a difference the
/// adapter happens to hide stays hidden. This class asserts what each stub's answer and recording
/// are, for the canonical <class>OcuPilot.Test.ProviderStub</class> and for the three families that
/// share its body -- the script kinds, the empty-script reply, the watched headers, the key compare,
/// one recording and one clock, and the armed row move.</p>
/// <p>Opens no socket, writes no row and arms nothing. Every test passes on any instance;
/// <method>TestAnUnarmedRunForcesNoErrorLogEntryThroughAnyStub</method> can go red only where
/// <code>OCUPILOT_ALLOW_ERROR_SEED</code> reads 1, as it does on every throwaway. Every method
/// starts and ends on a reset stub, so none depends on another's leftovers.</p>
Class OcuPilot.Test.ProviderStubSeam Extends %UnitTest.TestCase
{

/// <p>The stubs, canonical first, each as <code>class:identity</code>.</p>
Parameter STUBS = "OcuPilot.Test.ProviderStub:stub,OcuPilot.Test.OpenAIStub:openaistub,OcuPilot.Test.GeminiStub:geministub,OcuPilot.Test.CompatibleStub:compatiblestub";

/// <p>The request URL every call carries (RFC 5737 TEST-NET-1; nothing connects to it).</p>
Parameter URL = "https://192.0.2.1/v1/seam";

/// <p>A fabricated key, shaped like nothing a provider issues, and the distinctive part the recording
/// walk searches for.</p>
Parameter KEY = "ocupilotseamkey-0000000000";

Parameter KEYMARK = "ocupilotseamkey";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).ResetErrorLog()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).ResetErrorLog()
    Quit $$$OK
}

/// <p>Issue <var>pRequest</var> through a fresh instance of <var>pStubClass</var>.</p>
Method Issue(pStubClass As %String, pRequest As %Net.HttpRequest, Output pStatus As %Integer, Output pBody As %String, Output pRetryAfter As %String) As %Status
{
    Set tStub = $ClassMethod(pStubClass, "%New")
    Set tSC = tStub.IssueHttpsPost(pRequest, ..#URL, .pStatus, .pBody, .pRetryAfter)
    Set tStub = ""
    Quit tSC
}

/// <p>A request carrying the headers <var>pStubClass</var>'s own <code>ApplyAuth</code> writes for
/// <var>pKey</var>, with the Anthropic version header's value set the way a real call sets it.</p>
Method AuthenticatedRequest(pStubClass As %String, pKey As %String) As %Net.HttpRequest
{
    Set tStub = $ClassMethod(pStubClass, "%New")
    Set tStub.ApiKey = pKey
    Set tStub.AuthVersion = "2023-06-01"
    Set tRequest = ##class(%Net.HttpRequest).%New()
    Do tStub.ApplyAuth(tRequest)
    Set tStub = ""
    Quit tRequest
}

/// <p><b>An empty script answers 200, and what the body is depends on the family.</b> The canonical
/// stub answers a minimal well-formed Anthropic reply, which its own
/// <method>OcuPilot.Kernel.Provider.Anthropic.MapResponse</method> reads. The other three answer an
/// empty body, which no family's <code>MapResponse</code> can read, so a test that queues nothing is
/// asserting about the request and cannot pass by reading a reply it never queued.</p>
/// <p>Mutation: have <code>Transport</code> answer the Anthropic reply for every family -- the three
/// empty-body legs go red; answer <code>""</code> for the canonical one -- the canonical legs go
/// red.</p>
Method TestAnEmptyScriptAnswersTheCanonicalFamilyAReplyAndTheOthersNone()
{
    For tI = 1:1:$Length(..#STUBS, ",") {
        Set tClass = $Piece($Piece(..#STUBS, ",", tI), ":", 1)
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Set tSC = ..Issue(tClass, ##class(%Net.HttpRequest).%New(), .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertStatusOK(tSC, tClass _ ": an empty script answers rather than fails")
        Do $$$AssertEquals(tStatus, 200, tClass _ ": with a 200")
        Do $$$AssertEquals(tRetryAfter, "", tClass _ ": and no retry-after")
        Set tStub = $ClassMethod(tClass, "%New")
        Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
        Set tMapSC = tStub.MapResponse(tBody, tResponse)
        If tI = 1 {
            Do $$$AssertNotEquals(tBody, "", tClass _ ": the canonical family's reply is not empty")
            Do $$$AssertStatusOK(tMapSC, tClass _ ": and its own mapper reads it")
            Do $$$AssertEquals(tResponse.Text, "ok", tClass _ ": as the text ok")
            Do $$$AssertEquals(tResponse.StopReason, "end_turn", tClass _ ": ending the turn")
        } Else {
            Do $$$AssertEquals(tBody, "", tClass _ ": every other family's reply is empty")
            Do $$$AssertStatusNotOK(tMapSC, tClass _ ": which its own mapper cannot read")
        }
        Set tStub = ""
    }
}

/// <p><b>Every stub serves every script kind the same way</b>: a queued answer's status, body and
/// retry-after are passed through; a failure, a timeout and a connect that never opened are error
/// statuses of their own codes with no status line; a break after a status line carries that status
/// beside its error; a throw raises rather than returns; and a streamed answer with no chunk reader
/// attached is returned as the body.</p>
/// <p>Mutation: drop a non-stream kind's branch from <code>Transport</code> -- that kind falls
/// through to the answer path, and its legs go red on all four stubs. With no chunk reader the
/// stream leg reads the same status and body either way, so dropping the stream branch reddens
/// <method>TestAnArmedRowMoveIsKeptThroughACallThatDoesNotAnswerAndSpentByOneThatDoes</method>'s
/// stream leg instead.</p>
Method TestEveryStubServesEveryScriptKindTheSameWay()
{
    For tI = 1:1:$Length(..#STUBS, ",") {
        Set tClass = $Piece($Piece(..#STUBS, ",", tI), ":", 1)
        Set tRequest = ##class(%Net.HttpRequest).%New()

        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "slow down", 7)
        Set tSC = ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertStatusOK(tSC, tClass _ " answer: the transport succeeds")
        Do $$$AssertEquals(tStatus _ "|" _ tBody _ "|" _ tRetryAfter, "429|slow down|7", tClass _ " answer: status, body and retry-after as queued")

        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure()
        Set tSC = ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertStatusNotOK(tSC, tClass _ " failure: an error status")
        Set tCode = $System.Status.Equals(tSC, $$$ERRORCODE($$$GeneralError))
        Do $$$AssertTrue(tCode, tClass _ " failure: of the general code")
        Do $$$AssertEquals(tStatus _ "|" _ tBody, "0|", tClass _ " failure: with no status line and no body")

        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(1)
        Set tSC = ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Set tCode = $System.Status.Equals(tSC, $$$ERRORCODE($$$CSPTimeout))
        Do $$$AssertTrue(tCode, tClass _ " timeout: the timeout code")
        Do $$$AssertEquals(tStatus, 0, tClass _ " timeout: with no status line")

        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueConnectRefused()
        Set tSC = ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Set tCode = $System.Status.Equals(tSC, $$$ERRORCODE($$$HttpRequestConnect))
        Do $$$AssertTrue(tCode, tClass _ " connect refused: the connect code")
        Do $$$AssertEquals(tStatus _ "|" _ tBody, "0|", tClass _ " connect refused: with no status line and no body")

        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueBrokenAfterStatus(503)
        Set tSC = ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Set tCode = $System.Status.Equals(tSC, $$$ERRORCODE($$$TCPIPError))
        Do $$$AssertTrue(tCode, tClass _ " broken after status: the TCP/IP error code")
        Do $$$AssertEquals(tStatus, 503, tClass _ " broken after status: carrying the status line that did arrive")

        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
        Set tThrew = 0
        Set tThrown = ""
        Try {
            Set tSC = ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        } Catch tEx {
            Set tThrew = 1
            Set tThrown = $System.Status.GetErrorText(tEx.AsStatus())
        }
        Do $$$AssertEquals(tThrew, 1, tClass _ " throw: raises rather than returns")
        Do $$$AssertTrue(tThrown [ "raised mid-flight", tClass _ " throw: with the stand-in's own text: " _ tThrown)

        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, "data: one" _ $Char(10) _ $Char(10))
        Set tSC = ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertStatusOK(tSC, tClass _ " stream: the transport succeeds")
        Do $$$AssertEquals(tStatus _ "|" _ tBody, "200|data: one" _ $Char(10) _ $Char(10), tClass _ " stream: with no chunk reader the stream is the body")
    }
}

/// <p><b>Each stub reports the presence of its own watched headers, and only those.</b> The headers
/// are the ones the stub's own <code>ApplyAuth</code> wrote, so the recording is an observation of the
/// shipped adapter's request: the canonical stub reports <code>x-api-key,anthropic-version</code>,
/// the two OpenAI-shaped stubs <code>Authorization</code>, the Gemini stub <code>x-goog-api-key</code>.
/// A bare request reports none, and the content type is recorded from its own property.</p>
/// <p>Mutation: pass the canonical stub's watched list without <code>anthropic-version</code> -- the
/// canonical leg goes red; have <code>HeaderNames</code> report every watched name whether or not
/// it carries a value -- the bare-request legs go red on all four.</p>
Method TestEachStubReportsItsOwnWatchedHeadersAndNoOthers()
{
    Set tExpected("OcuPilot.Test.ProviderStub") = "x-api-key,anthropic-version"
    Set tExpected("OcuPilot.Test.OpenAIStub") = "Authorization"
    Set tExpected("OcuPilot.Test.GeminiStub") = "x-goog-api-key"
    Set tExpected("OcuPilot.Test.CompatibleStub") = "Authorization"
    For tI = 1:1:$Length(..#STUBS, ",") {
        Set tClass = $Piece($Piece(..#STUBS, ",", tI), ":", 1)
        Set tRequest = ..AuthenticatedRequest(tClass, ..#KEY)
        Set tRequest.ContentType = "application/json"
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), tExpected(tClass), tClass _ ": exactly the watched headers its own ApplyAuth wrote")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("contentType"), "application/json", tClass _ ": and the content type from its own property")
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ..Issue(tClass, ##class(%Net.HttpRequest).%New(), .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "", tClass _ ": a bare request reports no header")
    }
    Set tPartial = ##class(%Net.HttpRequest).%New()
    Do tPartial.SetHeader("anthropic-version", "2023-06-01")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ..Issue("OcuPilot.Test.ProviderStub", tPartial, .tStatus, .tBody, .tRetryAfter)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("headerNames"), "anthropic-version", "the canonical stub reports the one it was given, without the other")
}

/// <p><b>The key compare records an equality and never the key.</b> Armed with the expected text, the
/// canonical stub records <code>keyMatches</code> 1 for a request whose <code>x-api-key</code> equals
/// it and 0 for one that does not; unarmed it records nothing; and a family whose stub names no key
/// header records nothing even when armed. No recording anywhere holds the key, as a subscript or a
/// value.</p>
/// <p>Mutation: record <code>keyMatches</code> as 1 whatever the header holds -- the mismatch leg goes
/// red; record the header's value under another subscript -- the walk goes red; pass no key header
/// from the canonical stub -- the match leg goes red.</p>
Method TestTheKeyCompareRecordsAnEqualityAndNeverTheKey()
{
    Do ##class(OcuPilot.Test.ProviderStub).ArmKeyCompare(..#KEY)
    Do ..Issue("OcuPilot.Test.ProviderStub", ..AuthenticatedRequest("OcuPilot.Test.ProviderStub", ..#KEY), .tStatus, .tBody, .tRetryAfter)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("keyMatches", 1), 1, "a request carrying the expected key records a match")
    Do ..Issue("OcuPilot.Test.ProviderStub", ..AuthenticatedRequest("OcuPilot.Test.ProviderStub", "another-key-entirely"), .tStatus, .tBody, .tRetryAfter)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("keyMatches", 2), 0, "a request carrying another key records a mismatch, as 0 rather than as nothing")
    Do ..Issue("OcuPilot.Test.ProviderStub", ##class(%Net.HttpRequest).%New(), .tStatus, .tBody, .tRetryAfter)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("keyMatches", 3), 0, "and one carrying no key records a mismatch too")
    For tI = 2:1:$Length(..#STUBS, ",") {
        Set tClass = $Piece($Piece(..#STUBS, ",", tI), ":", 1)
        Do ..Issue(tClass, ..AuthenticatedRequest(tClass, ..#KEY), .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("keyMatches", 3 + tI - 1), "", tClass _ ": a family whose stub names no key header compares nothing, although armed")
    }
    Do $$$AssertEquals(..RecordingsHolding(..#KEYMARK), "", "no recording holds the key, in a subscript or a value")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ..Issue("OcuPilot.Test.ProviderStub", ..AuthenticatedRequest("OcuPilot.Test.ProviderStub", ..#KEY), .tStatus, .tBody, .tRetryAfter)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("keyMatches"), "", "an unarmed stub records no comparison")
}

/// <p>The first node of the stubs' process-private recordings, subscripts and values both, that
/// contains <var>pText</var>, written out; <code>""</code> when none does. The error-log record is
/// searched too. The armed expectation is the one node left out: it is the text the compare is
/// given, not something a call recorded.</p>
ClassMethod RecordingsHolding(pText As %String) As %String
{
    Set tFound = ""
    Set tRoots = $ListBuild("^||OcuPilotProviderStub", "^||OcuPilotProviderStubLog")
    For tI = 1:1:$ListLength(tRoots) {
        Set tRoot = $List(tRoots, tI)
        Set tRef = tRoot
        If ($Data(@tRoot) # 2) && (@tRoot [ pText) Set tFound = tRoot
        While (tFound = "") && (tRef '= "") {
            Set tRef = $Query(@tRef)
            If tRef = "" Quit
            If tRef = "^||OcuPilotProviderStub(""keyExpected"")" Continue
            If (tRef [ pText) || (@tRef [ pText) Set tFound = tRef
        }
        If tFound '= "" Quit
    }
    Quit tFound
}

/// <p><b>One recording and one clock serve every stub</b>, in call order: the call count, each call's
/// served-by identity, URL and request body, the last identity, the waits and the fake clock all
/// belong to the one run, whichever stub served each call, and a subclass of the canonical stub
/// reports its own identity rather than its parent's.</p>
/// <p>Mutation: record the literal <code>"stub"</code> for the identity -- the subclass leg goes red;
/// advance the clock in <code>Transport</code> by nothing -- the clock legs go red.</p>
Method TestOneRecordingAndOneClockServeEveryStub()
{
    Set tClasses = $ListBuild("OcuPilot.Test.ProviderStub", "OcuPilot.Test.OpenAIStub", "OcuPilot.Test.GeminiStub", "OcuPilot.Test.CompatibleStub", "OcuPilot.Test.ProviderStubAlt")
    Set tIdentities = $ListBuild("stub", "openaistub", "geministub", "compatiblestub", "stubalt")
    Do ##class(OcuPilot.Test.ProviderStub).ScriptElapsed(5)
    For tI = 1:1:$ListLength(tClasses) {
        Set tClass = $List(tClasses, tI)
        Set tRequest = ##class(%Net.HttpRequest).%New()
        Set tRequest.EntityBody = ##class(%Stream.TmpCharacter).%New()
        Do tRequest.EntityBody.Write("body of call " _ tI)
        Do ..Issue(tClass, tRequest, .tStatus, .tBody, .tRetryAfter)
        Set tStub = $ClassMethod(tClass, "%New")
        Do tStub.Wait(tI)
        Set tStub = ""
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("servedBy", tI), $List(tIdentities, tI), "call " _ tI _ " was served by " _ tClass)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("url", tI), ..#URL, "call " _ tI _ " recorded its URL")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Recorded("body", tI), "body of call " _ tI, "call " _ tI _ " recorded its entity body")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 5, "five calls counted, whichever stub served each")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), "stubalt", "and the last identity is the last stub's")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Waits(), "1|2|3|4|5", "every stub's waits land in one list")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Clock(), 5 * 5 + 15, "and on one clock: five calls of 5 seconds and the waits")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStubTransport).NowSeconds(), 40, "which the shared transport's own clock reads too")
}

/// <p><b>An armed row move survives every call that does not serve a queued answer and is spent by
/// the first that does.</b> The edit is meant to land mid-flight on an answered call, so a failure,
/// a timeout, a refused connect, a break, a throw, a stream and a call with no script leave it
/// armed; the first queued answer performs it and disarms, on the canonical stub and on another
/// family's. The id armed here names no row, so the edit itself finds nothing to move: only the
/// arming is observed, which
/// <method>OcuPilot.Test.AgentConnection.TestARowMovedDuringTheCallRefusesTheVerification</method>
/// pairs with the edit itself.</p>
/// <p>Mutation: perform the move before the script kinds are read -- each scripted non-answer leg
/// goes red; drop the disarming <code>Kill</code> -- both answer legs go red.</p>
Method TestAnArmedRowMoveIsKeptThroughACallThatDoesNotAnswerAndSpentByOneThatDoes()
{
    Set tRequest = ##class(%Net.HttpRequest).%New()
    Set tKinds = $ListBuild("failure", "timeout", "connectrefused", "brokenafterstatus", "throw", "stream", "unscripted")
    For tI = 1:1:$ListLength(tKinds) {
        Set tKind = $List(tKinds, tI)
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        If tKind = "failure" Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure()
        If tKind = "timeout" Do ##class(OcuPilot.Test.ProviderStub).QueueTransportFailure(1)
        If tKind = "connectrefused" Do ##class(OcuPilot.Test.ProviderStub).QueueConnectRefused()
        If tKind = "brokenafterstatus" Do ##class(OcuPilot.Test.ProviderStub).QueueBrokenAfterStatus(503)
        If tKind = "throw" Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
        If tKind = "stream" Do ##class(OcuPilot.Test.ProviderStub).QueueStream(200, "data: x")
        Do ##class(OcuPilot.Test.ProviderStub).ArmRowMove(-1, "unused-model")
        Try {
            Do ..Issue("OcuPilot.Test.ProviderStub", tRequest, .tStatus, .tBody, .tRetryAfter)
        } Catch tEx {
        }
        Do $$$AssertEquals($Data(^||OcuPilotProviderStub("rowMove", "id")) # 2, 1, tKind _ ": the call leaves the move armed")
    }
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{}")
    Do ##class(OcuPilot.Test.ProviderStub).ArmRowMove(-1, "unused-model")
    Do ..Issue("OcuPilot.Test.ProviderStub", tRequest, .tStatus, .tBody, .tRetryAfter)
    Do $$$AssertEquals($Data(^||OcuPilotProviderStub("rowMove")), 0, "an answered call performs the move and disarms it")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, "{}")
    Do ##class(OcuPilot.Test.ProviderStub).ArmRowMove(-1, "unused-model")
    Do ..Issue("OcuPilot.Test.OpenAIStub", tRequest, .tStatus, .tBody, .tRetryAfter)
    Do $$$AssertEquals($Data(^||OcuPilotProviderStub("rowMove")), 0, "and so does an answered call on another family's stub")
}

/// <p><b>A run nothing armed forces no application-error entry</b>, through any stub: an
/// authenticated request, a refusal and a mid-flight raise on each leave the forced-entry count at
/// zero. On an instance that is not armed for an application-error write nothing could be forced
/// anyway; on the throwaway, where the instance is armed, this is what shows the run's own arming is
/// the other half of the guard.</p>
/// <p>Mutation: drop the armed check from <code>Transport</code>'s <code>ForceErrorLog</code> -- on
/// the throwaway every stub's refusal leg writes an entry and the count goes red.</p>
Method TestAnUnarmedRunForcesNoErrorLogEntryThroughAnyStub()
{
    For tI = 1:1:$Length(..#STUBS, ",") {
        Set tClass = $Piece($Piece(..#STUBS, ",", tI), ":", 1)
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, "refused")
        Do ..Issue(tClass, ..AuthenticatedRequest(tClass, ..#KEY), .tStatus, .tBody, .tRetryAfter)
        Do $$$AssertEquals(tStatus, 401, tClass _ ": the refusal was served")
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
        Try {
            Do ..Issue(tClass, ..AuthenticatedRequest(tClass, ..#KEY), .tStatus, .tBody, .tRetryAfter)
        } Catch tEx {
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ErrorLogCount(), 0, tClass _ ": and no entry was forced by either call")
    }
}

}
