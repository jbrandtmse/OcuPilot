/// <p>The two proposal routes over HTTP (Story 5.3, AD-12, AD-39): <code>POST
/// /proposal/:id/confirm</code> and <code>POST /proposal/:id/cancel</code>. Every status, content
/// type and body below is read off a real response from the shipped router.</p>
/// <p><b>No confirmed write is issued from here.</b> The wire tests drive the refusals and the
/// cancel: an unknown id, a key outside the closed channel, a target the instance does not carry,
/// and the framework's own 405. A successful confirmed write end to end is
/// <file>ui/browser/proposal-confirm.browser-spec.mjs</file>'s, against a throwaway, because it is
/// the only assertion that needs a real application to write to.</p>
/// <p><b>What it needs from the environment:</b> the OcuPilot web application reachable on this
/// instance's own web-server port, and an account holding <code>%All</code>. Every row it seeds
/// hangs off a turn <method>OcuPilot.Test.ProposalFixture.SeedTurn</method> created, which is what
/// <method>OnAfterOneTest</method> removes them by.</p>
Class OcuPilot.Test.ConfirmRoute Extends %UnitTest.TestCase
{

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The seeded rows carry no conversation: the conversation gate is
/// <class>OcuPilot.Test.ProposalConfirm</class>'s to drive, and a row naming a conversation this
/// account does not own would be refused there rather than at the gate each test is about.</p>
Parameter PROBECONV = "";

/// <p>A target this instance does not carry, so the fresh re-read behind a confirm finds nothing
/// and the row closes without a write being attempted.</p>
Parameter TARGET = "/csp/ocupilotprobenosuchapp";

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>One request to the proposal routes as the test account.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/proposal" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>Seed one completed turn and one live proposal on it, for the account the requests are made
/// as, and answer the proposal's id.</p>
Method Seed() As %String
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tTurnSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tTurnSC, "a probe turn is seeded")
    If $$$ISERR(tTurnSC) Quit ""
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", ..#TARGET, .tTargetRef)
    Kill tValues
    Set tValues("user") = tUser
    Set tValues("convKey") = ..#PROBECONV
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = "webapp.list.update"
    Set tValues("targetRef") = tTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = "{}"
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>The two routes are declared in the shipped router, above the shorter conversation routes they
/// would otherwise be matched after.</p>
Method TestTheRoutesAreDeclaredInTheShippedRouter()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    Do $$$AssertTrue($IsObject(tXData), "the router's UrlMap is readable")
    If '$IsObject(tXData) Quit
    Do tXData.Data.Rewind()
    Set tMap = tXData.Data.Read(32000)
    Do $$$AssertTrue(tMap [ "<Route Url=""/proposal/:id/confirm"" Method=""POST""", "the router declares the confirm route")
    Do $$$AssertTrue(tMap [ "<Route Url=""/proposal/:id/cancel"" Method=""POST""", "and the cancel route")
    Do $$$AssertTrue($Find(tMap, "/proposal/:id/confirm") < $Find(tMap, """/conversation/:id"""), "both before the two-segment routes that follow them")
}

/// <p>A confirm of an id nothing carries is 404 with the proposal family's own code, in one
/// well-formed JSON envelope.</p>
Method TestAnUnknownProposalIsRefusedOverTheWire()
{
    Set tSC = ..Call("POST", "/ocupilotprobenosuchproposal/confirm", "{}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 404, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(tBody [ "}{", 0, "in exactly one envelope")
    Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "carrying the unknown-proposal code")
    Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#NOTFOUND, "under the coarse slug the enum already declares")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Write).Codes(), tEnvelope.%Get("code")) > 0, "and a code from the declared set")
    Do $$$AssertNotEquals(tEnvelope.%Get("reason"), "", "with a written sentence beside it")
}

/// <p>AC2 over the wire: a body key the channel is not open to is refused, and the row stays
/// live.</p>
Method TestAKeyOutsideTheClosedChannelIsRefusedOverTheWire()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Set tSC = ..Call("POST", "/" _ tKey _ "/confirm", "{""Description"":""from the request""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#CLOSEDCHANNEL, "with the closed-channel code")
    Do $$$AssertEquals(tEnvelope.%Get("error"), ##class(OcuPilot.Api.Error).#BADREQUEST, "under the bad-request slug")
    Do $$$AssertEquals(tBody [ "from the request", 0, "and the refusal names nothing of the value")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row was not claimed")
}

/// <p>A confirm whose target the instance no longer holds closes the row <code>target-changed</code>
/// and answers 409 -- the fingerprint refusal, over the wire, with no write attempted.</p>
Method TestAConfirmOnAMissingTargetIsRefusedAndClosesTheRow()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Set tSC = ..Call("POST", "/" _ tKey _ "/confirm", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 409, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tEnvelope = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tEnvelope.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "with the target-changed code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "canceled", "the row closes")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "target-changed", "with the reason the card renders")
}

/// <p>The cancel route answers 200 with the closed row, and a second cancel of the same id is 404 --
/// a row already terminal and an id nobody minted read the same.</p>
Method TestTheCancelRouteClosesTheRow()
{
    Set tKey = ..Seed()
    If tKey = "" Quit
    Set tSC = ..Call("POST", "/" _ tKey _ "/cancel", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(tBody [ "}{", 0, "in exactly one envelope")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.%Get("proposalId"), tKey, "naming the proposal")
    Do $$$AssertEquals(tAnswer.%Get("state"), "canceled", "in its terminal state")
    Do $$$AssertEquals(tAnswer.%Get("closedReason"), "you", "with the reason the card renders")

    Set tSC = ..Call("POST", "/" _ tKey _ "/cancel", "", .tSecondStatus, .tSecondBody, .tSecondHeaders)
    Do $$$AssertStatusOK(tSC, "a second cancel completes")
    Do $$$AssertEquals(tSecondStatus, 404, "and is refused")
    Do $$$AssertEquals($ZConvert($Get(tSecondHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tSecondBody).%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "with the same code an unknown id earns")
}

/// <p>Both routes are <code>POST</code> only: every other verb is the framework's own 405, with the
/// <code>Allow</code> header naming what the path does take.</p>
Method TestAnotherVerbOnEitherRouteIs405()
{
    Set tSC = ..Call("GET", "/ocupilotprobenosuchproposal/confirm", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(tStatus, 405, "and is refused: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).%Get("code"), ##class(OcuPilot.Api.Error).#ROUTEMETHODNOTALLOWED, "with the framework's own code")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("ALLOW")), "U") [ "POST", 1, "and an Allow header naming POST: " _ $Get(tHeaders("ALLOW")))

    Set tSC = ..Call("DELETE", "/ocupilotprobenosuchproposal/cancel", "", .tCancelStatus, .tCancelBody, .tCancelHeaders)
    Do $$$AssertStatusOK(tSC, "the cancel request completes")
    Do $$$AssertEquals(tCancelStatus, 405, "and is refused too")
    Do $$$AssertEquals($ZConvert($Get(tCancelHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tCancelBody).%Get("code"), ##class(OcuPilot.Api.Error).#ROUTEMETHODNOTALLOWED, "with the same code")
}

}
