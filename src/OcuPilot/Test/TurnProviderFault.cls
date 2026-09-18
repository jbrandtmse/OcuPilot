/// <p>Story 4.8's turn-level half: a real turn job whose provider fails, driven through the HTTP
/// routes by a least-privileged principal (AD-7, AD-39, AD-42). A scripted server error, a scripted
/// refusal and a scripted transport timeout each end the turn, name the step they stopped at, and
/// answer the progress route one well-formed envelope carrying no credential and no raw
/// <class>%Status</class>.</p>
/// <p><b>Four of the five <code>PROVIDER.*</code> failures reach a turn here.</b>
/// <code>PROVIDER.EGRESS</code> is the fifth and is not among them: the endpoint is judged before
/// the adapter runs, and a definition naming an endpoint that judgement refuses cannot be stored
/// in the first place, so no turn can carry one. It is pinned where it happens, in
/// <class>OcuPilot.Test.ProviderPort</class>.</p>
/// <p><b>It is the case the suite could not reach before.</b>
/// <class>OcuPilot.Test.TurnProvider</class> answered HTTP 200 whatever it was asked, so every
/// <code>PROVIDER.*</code> outcome was pinned through the adapter in process and none through a
/// turn: the loop's fault branch, the turn row's <code>Code</code> and <code>ErrorSeq</code>, and
/// the progress projection over them had no test of their own.</p>
/// <p><b>It creates IRIS users and a role and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> read 1.</b>
/// Only <file>scripts/ci-throwaway.sh</file> sets them. After every method no probe job is alive
/// and no probe turn, slot or stub node remains.</p>
Class OcuPilot.Test.TurnProviderFault Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "turnfault-probe";

/// <p>The class declaring the name the turn's model step carries, so it is read rather than spelled
/// here.</p>
Parameter LOOP = "OcuPilot.Kernel.Agent.Loop";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnProviderFault creates IRIS users and a role and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnProviderFault runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnProviderFault teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>Start a turn as the probe principal against the scripted answer <var>pHttpStatus</var> /
/// <var>pBody</var>, wait for it to end, and hand back the turn id, the progress view and the
/// progress route's own status and body text.</p>
Method RunFailingTurn(pHttpStatus As %Integer, pBody As %String, Output pView, Output pStatus As %Integer, Output pText As %String) As %String
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, pBody, pHttpStatus)
    Do $$$AssertStatusOK(tSC, "the provider answer is scripted")
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tConvStatus, .tConvText)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "what is on this screen", tConvId), .tStartStatus, .tStartText, .tStartHeaders)
    Do $$$AssertEquals(tStartStatus, 202, "the start is accepted: " _ tStartText)
    If tStartStatus '= 202 Quit ""
    Set tId = ##class(%DynamicObject).%FromJSON(tStartText).turnId
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "AwaitEnd", tId, tUser, ..PreparedPassword, 60, .pView), "failed", "the turn ends failed")
    Do $ClassMethod(..#FIXTURE, "Call", "GET", "/turn/" _ tId _ "/progress", tUser, ..PreparedPassword, "", .pStatus, .pText, .tHeaders)
    Quit tId
}

/// <p>The seq of the one step of <var>pView</var> whose name is the loop's model step, or
/// <code>-1</code>.</p>
ClassMethod ModelStepSeq(pView As %DynamicObject) As %Integer
{
    Set tSeq = -1
    If '$IsObject(pView) || '$IsObject(pView.steps) Quit tSeq
    Set tName = $Parameter(..#LOOP, "MODELSTEP")
    Set tIterator = pView.steps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        If (tStep.kind = "model") && (tStep.name = tName) Set tSeq = tStep.seq
    }
    Quit tSeq
}

/// <p>AC5 -- a turn whose provider does not answer at all: the row is <code>failed</code> carrying
/// <code>PROVIDER.TIMEOUT</code>, its <code>ErrorSeq</code> is the model step named
/// <code>provider</code>, and the poll carries that same seq with the code's one published
/// sentence.</p>
/// <p>Mutation: set <code>pOutcome("errorSeq")</code> to 0 in
/// <method>OcuPilot.Kernel.Agent.Loop</method>'s fault branch -- the step assertions go red, the
/// turn naming no step at all.</p>
Method TestAProviderTimeoutFailsTheTurnAtItsProviderStep()
{
    Set tId = ..RunFailingTurn(0, "", .tView, .tStatus, .tText)
    If tId = "" Quit
    Do $$$AssertTrue($IsObject($Get(tView)) && $IsObject(tView.error), "the failed turn's view carries an error object")
    If '$IsObject($Get(tView)) || '$IsObject(tView.error) Quit
    Set tTimeout = ##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.TurnFixture", "Field", tId, "State"), "failed", "the stored turn is failed")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.TurnFixture", "Field", tId, "Code"), tTimeout, "carrying the provider's own code")
    Set tSeq = ..ModelStepSeq(tView)
    Do $$$AssertTrue(tSeq > 0, "the turn recorded a model step named provider: seq " _ tSeq)
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.TurnFixture", "Field", tId, "ErrorSeq"), tSeq, "and the row's ErrorSeq names it")
    Do $$$AssertEquals(tStatus, 200, "the poll answers rather than failing: " _ $Extract(tText, 1, 200))
    Do $$$AssertEquals(tView.error.seq _ "|" _ tView.error.code, tSeq _ "|" _ tTimeout, "and the view's error names the same step and code")
    Do $$$AssertEquals(tView.error.reason, ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tTimeout), "with the one published sentence for that code, written on the instance")
}

/// <p>AC6 -- a turn whose provider call fails in transport without an HTTP answer ends
/// <code>PROVIDER.TRANSPORT</code>, with the same envelope shape and the same step naming as the
/// two the provider did answer. Told apart from a timeout only by the <class>%Status</class> the
/// seam returns, which is the distinction <method>OcuPilot.Kernel.Provider.Base.Attempts</method>
/// makes with <method>$System.Status.Equals</method>.</p>
Method TestATransportFailureFailsTheTurnAtItsProviderStep()
{
    Set tTransport = ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT
    Set tId = ..RunFailingTurn(-1, "", .tView, .tStatus, .tText)
    If tId = "" Quit
    Do $$$AssertTrue($IsObject($Get(tView)) && $IsObject(tView.error), "the failed turn's view carries an error object")
    If '$IsObject($Get(tView)) || '$IsObject(tView.error) Quit
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.TurnFixture", "Field", tId, "Code"), tTransport, "a transport failure that is not a timeout is PROVIDER.TRANSPORT")
    Set tSeq = ..ModelStepSeq(tView)
    Do $$$AssertTrue(tSeq > 0, "the turn recorded a model step named provider: seq " _ tSeq)
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.TurnFixture", "Field", tId, "ErrorSeq"), tSeq, "and the row's ErrorSeq names it")
    Do $$$AssertEquals(tView.error.seq _ "|" _ tView.error.code, tSeq _ "|" _ tTransport, "which the poll carries too")
    Do $$$AssertEquals(tView.error.reason, ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tTransport), "and the sentence the user actually reads names a transport failure, not just the code")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, "and a call that failed in transport is never retried")
    Do $$$AssertEquals(tText [ "ERROR #", 0, "with no raw %Status text in the body: " _ $Extract(tText, 1, 200))
}

/// <p>AC6 -- a turn whose provider answers a retryable server error on every attempt ends
/// <code>PROVIDER.UNAVAILABLE</code>, and one whose provider refuses ends
/// <code>PROVIDER.REFUSED</code>; the model step carries the same code as the turn in both.</p>
Method TestAServerErrorAndARefusalEachEndTheTurnByName()
{
    Set tUnavailable = ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE
    Set tId = ..RunFailingTurn(500, "", .tView, .tStatus, .tText)
    If tId = "" Quit
    Do $$$AssertTrue($IsObject($Get(tView)) && $IsObject(tView.error), "the failed turn's view carries an error object")
    If '$IsObject($Get(tView)) || '$IsObject(tView.error) Quit
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.TurnFixture", "Field", tId, "Code"), tUnavailable, "a retryable server error on every attempt is PROVIDER.UNAVAILABLE")
    Do $$$AssertEquals(tView.error.code, tUnavailable, "and the poll says so")
    Do $$$AssertEquals(tView.error.reason, ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tUnavailable), "with the sentence the user reads naming that the provider never served the call")
    Do $$$AssertEquals(..StepCodeAt(tView, tView.error.seq), tUnavailable, "the step the error names carries the same code, so the card and the banner cannot disagree")
    Do $$$AssertTrue(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG) > 1, "and the attempt was actually retried: " _ ##class(OcuPilot.Test.TurnProvider).Calls(..#TAG))

    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Set tRefused = ##class(OcuPilot.Api.Error).#PROVIDERREFUSED
    Set tSecond = ..RunFailingTurn(401, "{""type"":""error"",""error"":{""message"":""invalid x-api-key""}}", .tRefusedView, .tRefusedStatus, .tRefusedText)
    If tSecond = "" Quit
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.TurnFixture", "Field", tSecond, "Code"), tRefused, "a status the provider will refuse again is PROVIDER.REFUSED")
    Do $$$AssertEquals(tRefusedView.error.reason, ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tRefused), "and the poll's own sentence says the provider refused the request, not the vendor's wording -- detail.providerText is a direct-route field this turn projection does not carry")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, "reached the provider once and was not retried")
}

/// <p>The code carried by the step of <var>pView</var> at <var>pSeq</var>, or <code>""</code>.</p>
ClassMethod StepCodeAt(pView As %DynamicObject, pSeq As %Integer) As %String
{
    Set tCode = ""
    If '$IsObject(pView) || '$IsObject(pView.steps) Quit tCode
    Set tIterator = pView.steps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        If tStep.seq = pSeq Set tCode = tStep.code
    }
    Quit tCode
}

/// <p>AC6 -- every provider failure a turn can reach answers the poll <b>one</b> well-formed
/// envelope and never an exception: one JSON document, no second one glued to it, no part of the
/// stored credential and no raw <class>%Status</class> text anywhere in the body (AD-35, AD-39).
/// The raw text reaches the log alone.</p>
/// <p>The HTTP status the direct routes answer each code with is asserted from
/// <method>OcuPilot.Kernel.Provider.Base.HttpFor</method> itself, because the progress route
/// answers 200 with a failed view -- a failed turn is a turn that ran, not a failed request.</p>
/// <p>Mutation: let <method>OcuPilot.Kernel.Provider.Base.Fault</method> pass the raw
/// <class>%Status</class> text through as the reason -- the no-raw-status assertion goes red.</p>
Method TestEveryProviderFailureAnswersOneWellFormedEnvelope()
{
    Set tKey = $Parameter(..#FIXTURE, "PROBEKEY")
    For tLeg = "0|", "-1|", "500|", "401|{""type"":""error"",""error"":{""message"":""invalid x-api-key""}}" {
        Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
        Set tId = ..RunFailingTurn($Piece(tLeg, "|", 1), $Piece(tLeg, "|", 2, *), .tView, .tStatus, .tText)
        If tId = "" Continue
        Do $$$AssertEquals(tStatus, 200, "HTTP " _ $Piece(tLeg, "|", 1) _ ": the poll answers, never a 500 with a stack: " _ $Extract(tText, 1, 200))
        Do $$$AssertEquals(tText [ "}{", 0, "HTTP " _ $Piece(tLeg, "|", 1) _ ": exactly one document, with no second envelope glued to it")
        Do $$$AssertTrue($IsObject($Get(tView)) && $IsObject(tView.error), "HTTP " _ $Piece(tLeg, "|", 1) _ ": the view carries an error object")
        Do $$$AssertEquals(tText [ tKey, 0, "HTTP " _ $Piece(tLeg, "|", 1) _ ": no part of the credential is in the body")
        Do $$$AssertEquals(tText [ "ERROR #", 0, "HTTP " _ $Piece(tLeg, "|", 1) _ ": and no raw %Status text either, which goes to the log alone")
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tView.error.code), "HTTP " _ $Piece(tLeg, "|", 1) _ ": the code is well formed: " _ tView.error.code)
    }
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Base).HttpFor(##class(OcuPilot.Api.Error).#PROVIDERTIMEOUT), 504, "a provider that did not answer in time is a gateway timeout on the direct routes")
    For tCode = ##class(OcuPilot.Api.Error).#PROVIDERUNAVAILABLE, ##class(OcuPilot.Api.Error).#PROVIDERREFUSED, ##class(OcuPilot.Api.Error).#PROVIDERTRANSPORT, ##class(OcuPilot.Api.Error).#PROVIDEREGRESS {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Base).HttpFor(tCode), 502, tCode _ " is a gateway failure on the direct routes")
    }
}

}
