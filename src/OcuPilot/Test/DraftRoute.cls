/// <p>The copy-out draft's route over HTTP and its kernel entry (AD-59): <code>POST
/// /proposal/:id/draft</code> answers the script of a live proposal and closes it
/// <code>canceled</code> reason <code>draft</code>, sends nothing, and refuses every row of the I/O
/// matrix it must refuse. Statuses, content types and bodies are read off real responses from the
/// shipped router; the turn caller and the missing script form are driven through
/// <class>OcuPilot.Kernel.Proposal.Draft</class> itself, because neither is reachable over the
/// wire.</p>
/// <p><b>What it needs from the environment:</b> the OcuPilot web application on this instance's
/// own web-server port, an account holding <code>%All</code>, and a throwaway armed with
/// <code>OCUPILOT_ALLOW_PRINCIPALS</code>: the happy path reads a web application
/// <class>OcuPilot.Test.ProposalFixture</class> creates and removes, to prove it unchanged. Every
/// row hangs off a turn <method>OcuPilot.Test.ProposalFixture.SeedTurn</method> created, which is
/// what <method>OnAfterOneTest</method> removes them by.</p>
Class OcuPilot.Test.DraftRoute Extends %UnitTest.TestCase
{

Parameter APIBASE = "/api/ocupilot";

Parameter DRAFT = "OcuPilot.Kernel.Proposal.Draft";

/// <p>The web application the prohibited leg proposes to repoint: OcuPilot's own API.</p>
Parameter OWNAPP = "/api/ocupilot";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>One request to the proposal routes as the test account.</p>
ClassMethod Call(pSuffix As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, "", "application/json")
}

/// <p>Seed one live proposal of <var>pTool</var> against <var>pType</var>/<var>pId</var> for
/// <var>pUser</var> (the test account when empty) with the stored <var>pPayload</var>,
/// <var>pDiff</var> and <var>pArguments</var>, and answer its id.</p>
Method Seed(pTool As %String, pType As %String, pId As %String, pPayload As %String, pDiff As %String = "[]", pArguments As %String = "{}", pUser As %String = "") As %String
{
    Set tUser = $Select(pUser '= "": pUser, 1: ##class(OcuPilot.Test.Http).GetTestUsername())
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(pType, "instance", pId, .tTargetRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    Kill tValues
    Set tValues("user") = tUser
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = pTool
    Set tValues("targetRef") = tTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = pArguments
    Set tValues("payload") = pPayload
    Set tValues("diff") = pDiff
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>POST a draft of <var>pKey</var> and answer the parsed body, asserting one JSON envelope at
/// <var>pExpected</var>.</p>
Method Take(pKey As %String, pExpected As %Integer, Output pBody As %DynamicObject) As %Integer
{
    Set pBody = ""
    Set tSC = ..Call("/" _ pKey _ "/draft", .tStatus, .tText, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, pExpected, "and answers " _ pExpected _ ": " _ tText)
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(tText [ "}{", 0, "in exactly one envelope")
    Try {
        Set pBody = ##class(%DynamicObject).%FromJSON(tText)
    } Catch {
        Set pBody = {}
    }
    Quit tStatus
}

/// <p>Every step's text of a draft answer, joined by line feeds.</p>
ClassMethod Text(pAnswer As %DynamicObject) As %String
{
    Set tText = ""
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("draft") '= "object") Quit tText
    Set tIterator = pAnswer.%Get("draft").%Get("steps").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tText = tText _ $Select(tText = "": "", 1: $Char(10)) _ tStep.%Get("kind") _ ": " _ tStep.%Get("text")
    }
    Quit tText
}

/// <p>The rows in the agent ledger, and the OcuPilot audit rows written since <var>pSince</var>.</p>
ClassMethod Counts(pSince As %String, Output pLedger As %Integer, Output pMarkers As %Integer)
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger")
    Set pLedger = $Select(tRS.%Next(): tRS.%GetData(1), 1: -1)
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ?", pSince, ##class(OcuPilot.Kernel.Audit.Event).Source())
    Set pMarkers = $Select(tRS.%Next(): tRS.%GetData(1), 1: -1)
}

Method TestTheRouteIsDeclaredBesideConfirmAndCancel()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    Do $$$AssertTrue($IsObject(tXData), "the router's UrlMap is readable")
    If '$IsObject(tXData) Quit
    Do tXData.Data.Rewind()
    Set tMap = tXData.Data.Read(32000)
    Do $$$AssertTrue(tMap [ "<Route Url=""/proposal/:id/draft"" Method=""POST"" Call=""ProposalDraft""/>", "the router declares POST /proposal/:id/draft")
}

/// <p>AC1, the matrix's merge write: a live <code>webapp.list.update</code> proposal answers 200
/// with the script of its complete stored payload and closes <code>canceled</code>/<code>draft</code>,
/// while the application reads back unchanged and neither the ledger nor the audit trail moves.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Draft.Take</method> issue the write
/// through <method>OcuPilot.Kernel.Proposal.Operation.Apply</method> before answering -- the
/// application's description reads back changed and this goes red.</p>
Method TestAMergeWriteAnswersItsScriptAndChangesNothing()
{
    Set tTarget = ##class(OcuPilot.Test.ProposalFixture).#WRITETARGET
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget(, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe application is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Kill tQuery
    Set tQuery("name") = tTarget
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the application reads")
    If $$$ISERR(tSC) Quit
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Description")
    Do tFresh.%Set("Description", "changed by the draft probe", "string")
    Set tDiff = [{"field": "Description", "before": (tBefore), "after": "changed by the draft probe"}]
    Set tArguments = {"Name": (tTarget), "Description": "changed by the draft probe"}
    Set tKey = ..Seed("webapp.list.update", "web-application", tTarget, tFresh.%ToJSON(), tDiff.%ToJSON(), tArguments.%ToJSON())
    If tKey = "" Quit
    Set tSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Do ..Counts(tSince, .tLedgerBefore, .tMarkersBefore)
    Do $$$AssertTrue((tLedgerBefore >= 0) && (tMarkersBefore >= 0), "the ledger and the audit trail are counted: " _ tLedgerBefore _ " " _ tMarkersBefore)

    Do ..Take(tKey, 200, .tAnswer)
    Do $$$AssertEquals(tAnswer.%Get("state"), "canceled", "the answer carries the closed state")
    Do $$$AssertEquals(tAnswer.%Get("closedReason"), "draft", "with the draft reason")
    Set tText = ..Text(tAnswer)
    Do $$$AssertTrue(tText [ ("rest: curl -u '" _ ##class(OcuPilot.Test.Http).GetTestUsername() _ "' -X PUT "), "the script is the caller's own PUT: " _ tText)
    Do $$$AssertTrue(tText [ ("'http://" _ ##class(OcuPilot.Test.Http).GetTestServer() _ ":" _ ##class(OcuPilot.Test.Http).GetTestPort() _ "/api/admin/v2/web-app?name=" _ tTarget), "against the application's route on the origin the request reached")
    Do $$$AssertTrue(tText [ """Description"":""changed by the draft probe""", "carrying the stored change")
    Do $$$AssertTrue(tText [ """NameSpace"":", "inside the complete stored property set")
    Do $$$AssertEquals(tAnswer.%Get("draft").%Get("placeholders").%Size(), 0, "with no secret to fill in")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "canceled", "the row closes")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "draft", "with the draft reason a later poll reads")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and its token unspent")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Description"), tBefore, "the application reads back unchanged")
    Do ..Counts(tSince, .tLedgerAfter, .tMarkersAfter)
    Do $$$AssertEquals(tLedgerAfter, tLedgerBefore, "no ledger row was written")
    Do $$$AssertEquals(tMarkersAfter, tMarkersBefore, "and no OcuPilot audit row")

    ; The race: the row is no longer live, so a second draft is the unknown-proposal refusal.
    Do ..Take(tKey, 404, .tAgain)
    Do $$$AssertEquals(tAgain.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "a second draft of the closed row is refused")
}

/// <p>The matrix's secret-only body (AD-56): the password write's script carries
/// <code>&lt;Password&gt;</code> under the vendor's own key, names it as a placeholder, and is
/// followed by the change-on-login step.</p>
Method TestASecretOnlyBodyReadsAsAPlaceholder()
{
    Set tKey = ..Seed("permissions.users.password", "user", "ocupilotprobedraftnosuchuser", "{""Enabled"":true}")
    If tKey = "" Quit
    Do ..Take(tKey, 200, .tAnswer)
    Set tText = ..Text(tAnswer)
    Do $$$AssertTrue(tText [ "/api/admin/v2/security/user/password?name=ocupilotprobedraftnosuchuser", "the script is the vendor's password route: " _ tText)
    Do $$$AssertTrue(tText [ "-d '{""NewPassword"":""<Password>""}'", "carrying the placeholder under the vendor's key")
    Do $$$AssertEquals(tAnswer.%Get("draft").%Get("placeholders").%ToJSON(), "[""Password""]", "and naming it")
    Do $$$AssertTrue(tText [ "objectscript: " && (tText [ "##class(Security.Users).Modify(""ocupilotprobedraftnosuchuser"", .tProps)"), "followed by the change-on-login step")
}

/// <p>The matrix's <code>%SYS</code> completion (AD-48): an application-error delete is one
/// <code>SYS.ApplicationError.DeleteByError</code> call per date of the enumerated entries.</p>
Method TestAnApplicationErrorDeleteIsTheSysCall()
{
    Set tPayload = {"namespace": "USER", "entries": [{"date": "2026-09-20", "errorNumber": 4}, {"date": "2026-09-20", "errorNumber": 7}, {"date": "2026-09-21", "errorNumber": 1}]}
    Set tKey = ..Seed("logs.applicationerrors.delete", "application-error", "USER", tPayload.%ToJSON())
    If tKey = "" Quit
    Do ..Take(tKey, 200, .tAnswer)
    Set tText = ..Text(tAnswer)
    Do $$$AssertTrue(tText [ "objectscript: ", "the script is ObjectScript: " _ tText)
    Do $$$AssertTrue(tText [ "##class(SYS.ApplicationError).DeleteByError(""USER"", ""2026-09-20"", ""4,7"")", "one call for the first date")
    Do $$$AssertTrue(tText [ "##class(SYS.ApplicationError).DeleteByError(""USER"", ""2026-09-21"", ""1"")", "and one for the second")
}

/// <p>The matrix's create (AD-54): the script sends the id as the caller typed it.</p>
Method TestACreateSendsTheIdAsTyped()
{
    Set tKey = ..Seed("webapp.list.create", "web-application", "/csp/ocupilotprobedraftcreate", "{""NameSpace"":""USER"",""Description"":""draft create probe""}", "[{""field"":""NameSpace"",""before"":"""",""after"":""USER""},{""field"":""Description"",""before"":"""",""after"":""draft create probe""}]", "{""Name"":""/CSP/OcuPilotProbeDraftCreate""}")
    If tKey = "" Quit
    Do ..Take(tKey, 200, .tAnswer)
    Set tText = ..Text(tAnswer)
    Do $$$AssertTrue(tText [ "/api/admin/v2/web-app?name=/CSP/OcuPilotProbeDraftCreate'", "the create names the target as typed: " _ tText)
    Do $$$AssertTrue(tText '[ "Security.Applications).Get(", "and reads no type to keep, since nothing is there yet")
}

/// <p>The matrix's not-takeable rows: an unknown id, an expired row, a terminal row and another
/// user's row are each 404 <code>PROPOSAL.UNKNOWN</code>, with no script and the row unchanged.</p>
Method TestARowThatIsNotTakeableIsRefused()
{
    Do ..Take("ocupilotprobenosuchproposal", 404, .tAnswer)
    Do $$$AssertEquals(tAnswer.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "an unknown id is refused")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("draft"), "unassigned", "with no script")

    Set tExpired = ..Seed("webapp.list.update", "web-application", "/csp/ocupilotprobedraftexpired", "{}")
    Do ##class(OcuPilot.Test.ProposalFixture).AgeExpiry(tExpired, 60)
    Do ..Take(tExpired, 404, .tAnswer)
    Do $$$AssertEquals(tAnswer.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "an expired row is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tExpired, "State"), "expired", "and reads expired")

    Set tTerminal = ..Seed("webapp.list.update", "web-application", "/csp/ocupilotprobedraftterminal", "{}")
    Do ##class(OcuPilot.Test.ProposalFixture).SetState(tTerminal, "confirmed")
    Do ..Take(tTerminal, 404, .tAnswer)
    Do $$$AssertEquals(tAnswer.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "a terminal row is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tTerminal, "State"), "confirmed", "and keeps its state")

    Set tOther = ..Seed("webapp.list.update", "web-application", "/csp/ocupilotprobedraftother", "{}", "[]", "{}", ##class(OcuPilot.Test.ProposalFixture).#PROBEPREFIX _ "Other")
    Do ..Take(tOther, 404, .tAnswer)
    Do $$$AssertEquals(tAnswer.%Get("code"), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "another user's row is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOther, "State"), "live", "and stays live")
}

/// <p>The matrix's prohibited effect (AD-10): a draft of a write that would repoint OcuPilot's own
/// API is refused with the confirm path's code and reason, and the row stays live.</p>
Method TestAProhibitedEffectIsRefusedAndTheRowStaysLive()
{
    Kill tQuery
    Set tQuery("name") = ..#OWNAPP
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "OcuPilot's own API reads")
    If $$$ISERR(tSC) Quit
    Set tBefore = tFresh.%Get("DispatchClass")
    Do tFresh.%Set("DispatchClass", "OcuPilot.Test.DraftRoute", "string")
    Set tDiff = [{"field": "DispatchClass", "before": (tBefore), "after": "OcuPilot.Test.DraftRoute"}]
    Set tKey = ..Seed("webapp.list.update", "web-application", ..#OWNAPP, tFresh.%ToJSON(), tDiff.%ToJSON())
    If tKey = "" Quit
    Do ..Take(tKey, 403, .tAnswer)
    Do $$$AssertEquals($Extract(tAnswer.%Get("code"), 1, 11), "PROHIBITED.", "the prohibited set's own code: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.%Get("reason"), ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(tAnswer.%Get("code")), "with the confirm path's reason")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("draft"), "unassigned", "and no script")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "the row stays live")
}

/// <p>The matrix's turn caller (AD-40): a draft from a process acting for the model is 403
/// <code>PROPOSAL.FROMTURN</code>, and the row stays live.</p>
Method TestADraftFromATurnIsRefused()
{
    Set tKey = ..Seed("webapp.list.update", "web-application", "/csp/ocupilotprobedraftturn", "{}", "[]", "{}", $Username)
    If tKey = "" Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set("ocupilotprobedraftturn")
    Set tSC = $ClassMethod(..#DRAFT, "Take", tKey, $Username, "http://localhost", .tAnswer, .tHttp, .tCode)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusNotOK(tSC, "the draft is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#FROMTURN, "as a turn's call")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and the row stays live")
}

/// <p>The matrix's race: a draft that loses the conditional close to another request answers 404
/// <code>PROPOSAL.UNKNOWN</code> and discards its script.</p>
/// <p>Mutation (Rule 19): delete the <code>If 'tClosed</code> refusal in
/// <method>OcuPilot.Kernel.Proposal.Draft.Take</method> -- the loser answers its script and this
/// goes red.</p>
Method TestADraftThatLosesTheCloseIsRefused()
{
    Set tKey = ..Seed("webapp.list.update", "web-application", "/csp/ocupilotprobedraftrace", "{""Name"":""/csp/ocupilotprobedraftrace""}", "[]", "{}", $Username)
    If tKey = "" Quit
    Set tSC = ##class(OcuPilot.Test.DraftLoser).Take(tKey, $Username, "http://localhost", .tAnswer, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the losing draft is refused")
    Do $$$AssertEquals(tHttp, 404, "at 404")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "as the unknown proposal")
    Do $$$AssertTrue('$IsObject(tAnswer), "and answers no script")
}

/// <p>The matrix's missing script form: a port that answers no form for the tool's request type is
/// 409 <code>PROPOSAL.NODRAFT</code>, and the row stays live.</p>
Method TestAToolWithNoScriptFormIsRefused()
{
    Set tKey = ..Seed("webapp.list.update", "web-application", "/csp/ocupilotprobedraftnoform", "{""Name"":""/csp/ocupilotprobedraftnoform""}", "[]", "{}", $Username)
    If tKey = "" Quit
    Set tSC = ##class(OcuPilot.Test.DraftNoForm).Take(tKey, $Username, "http://localhost", .tAnswer, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "the draft is refused")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#NODRAFT, "as a write with no script form")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "and the row stays live")
}

}
