/// <p>Pins Story 21.19's ignore and stop-ignoring on both callers (AC1, AC6; AD-4, AD-6, AD-15, AD-22, AD-53, AD-58) against the real instance: the
/// screen's own Ignore and Stop ignoring (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.LicenseProbe</class>) each change one recommendation's flag, the page's own <code>GetRecommendations</code> reads each state back,
/// the agent's write leaves one audit marker and the person's none, a write to a row already in the state is refused 409 by both callers, and a disabled
/// key stops the agent at dispatch.</p>
/// <p>Seam legs (<class>OcuPilot.Test.AdvisorSeam</class>) drive the port's two 409s, its 404s and a flag call that takes no effect without touching the
/// instance's flags.</p>
/// <p><b>Live-safe:</b> it changes the flag of one recommendation and puts every flag back, and stores a governance policy only to restore it
/// (<method>Restore</method>, on every path). <b>What it needs from the environment:</b> OcuPilot installed and serving, and at least one recommendation
/// that is not ignored.</p>
Class OcuPilot.Test.AdvisorWrite Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.AdvisorPort";

Parameter SEAM = "OcuPilot.Test.AdvisorSeam";

Parameter ENDPOINT = "SecurityAdvisor";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.DatabaseConfirm";

Parameter SCREEN = "security.advisor";

Parameter IGNORE = "security.advisor.ignore";

Parameter UNIGNORE = "security.advisor.unignore";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>The recommendations the instance held ignored before the class ran, as <code>type|element|code</code> lines joined by <code>$Char(2)</code>.</p>
Property PreparedIgnored As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    If $ClassMethod(..#SEAM, "PaneLines", .tPane) < 0 Quit $$$ERROR($$$GeneralError, "could not read the recommendations, so no test changes one it could not put back")
    Set ..PreparedIgnored = ..IgnoredNow()
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped advisor port, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Do ..Restore()
    Do $$$AssertEquals(..IgnoredNow(), ..PreparedIgnored, "every recommendation is ignored or not as the class found it")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ..Restore()
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The recommendations the page lists as ignored now, as <code>type|element|code</code> lines joined by <code>$Char(2)</code>.</p>
ClassMethod IgnoredNow() As %String
{
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    Set tOut = ""
    For tI = 1:1:tCount {
        If $Piece(tPane(tI), "|", 4) Set tOut = tOut _ $Select(tOut = "": "", 1: $Char(2)) _ $Piece(tPane(tI), "|", 1, 3)
    }
    Quit tOut
}

/// <p>Put every flag back as <code>PreparedIgnored</code> names it, through the page's own flag call.</p>
Method Restore()
{
    Set tWanted = $ListFromString(..PreparedIgnored, $Char(2))
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    For tI = 1:1:tCount {
        Set tKey = $Piece(tPane(tI), "|", 1, 3)
        Set tWant = ''$ListFind(tWanted, tKey)
        If tWant = ''$Piece(tPane(tI), "|", 4) Continue
        Do $ClassMethod(..#SEAM, "Vendor", $Piece(tKey, "|", 1), $Piece(tKey, "|", 2), $Piece(tKey, "|", 3), tWant)
    }
}

/// <p>A recommendation the instance does not hold ignored, the general row of a type when one is, in <var>pType</var>, <var>pElement</var> and
/// <var>pCode</var>; answers its composite id, or <code>""</code> when every recommendation is ignored.</p>
ClassMethod Target(Output pType As %String, Output pElement As %String, Output pCode As %String) As %String
{
    Set (pType, pElement, pCode) = ""
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    Set tChosen = 0
    For tI = 1:1:tCount {
        If $Piece(tPane(tI), "|", 4) Continue
        If 'tChosen Set tChosen = tI
        If $Piece(tPane(tI), "|", 2) = " " {
            Set tChosen = tI
            Quit
        }
    }
    If 'tChosen Quit ""
    Set pType = $Piece(tPane(tChosen), "|", 1)
    Set pElement = $Piece(tPane(tChosen), "|", 2)
    Set pCode = $Piece(tPane(tChosen), "|", 3)
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pType, pElement, pCode))
}

/// <p>Whether the page lists the recommendation as ignored now: <code>1</code>, <code>0</code>, or <code>-1</code> when it lists none.</p>
ClassMethod StateOf(pType As %String, pElement As %String, pCode As %String) As %Integer
{
    Set tCount = $ClassMethod(..#SEAM, "PaneLines", .tPane)
    Set tState = -1
    For tI = 1:1:tCount {
        If $Piece(tPane(tI), "|", 1, 3) = (pType _ "|" _ pElement _ "|" _ pCode) {
            Set tState = +$Piece(tPane(tI), "|", 4)
            Quit
        }
    }
    Quit tState
}

/// <p>The flag calls the seam recorded, as <code>SET &lt;type&gt;|&lt;element&gt;|&lt;code&gt;|&lt;flag&gt;</code> joined by <code>;</code>, without its reads.</p>
ClassMethod SetCalls() As %String
{
    Set tCalls = $ClassMethod(..#SEAM, "Calls")
    Set tOut = ""
    For tI = 1:1:$Length(tCalls, ";") {
        Set tCall = $Piece(tCalls, ";", tI)
        If $Extract(tCall, 1, 4) = "SET " Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tCall
    }
    Quit tOut
}

/// <p>The port's <code>ROW</code> read of <var>pId</var>, answering its <code>Ignored</code> as <code>1</code> or <code>0</code>, or the HTTP status
/// when it answers no row.</p>
ClassMethod RowState(pId As %String) As %String
{
    Kill tQuery
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "ROW", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): +tRow.%Get("Ignored"), 1: tHttp)
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> through the action fixture; the parsed envelope in <var>pAnswer</var>, answering the HTTP
/// status.</p>
ClassMethod Act(pAction As %String, pId As %String, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The agent's dispatch of <var>pKey</var> for the recommendation <var>pType</var>, <var>pElement</var>, <var>pCode</var>: <code>minted</code> or
/// <code>refused</code>; the proposal's id in <var>pProposalId</var>, the turn in <var>pTurnKey</var> and the answer's content in
/// <var>pContent</var>.</p>
ClassMethod Dispatched(pKey As %String, pType As %String, pElement As %String, pCode As %String, Output pProposalId As %String, Output pTurnKey As %String, Output pContent As %String) As %String
{
    Set pProposalId = ""
    Set pContent = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tInput = {"rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("type", pType, "string")
    Do tInput.%Set("element", pElement, "string")
    Do tInput.%Set("code", pCode, "string")
    Set tUse = {"type": "tool_use", "id": "toolu_advisor"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pKey), "string")
    Do tUse.%Set("input", tInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set pContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(pContent)
    If $IsObject(tParsed) Set pProposalId = tParsed.%Get("proposalId")
    Quit $Select(pProposalId '= "": "minted", 1: "refused")
}

/// <p>Confirm the proposal <var>pProposalId</var> through the shipped confirm over the advisor port, answering <code>ok</code> or the refusal code; the
/// answer in <var>pResult</var>.</p>
ClassMethod Confirmed(pProposalId As %String, Output pResult As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#AGENT, "Confirm", pProposalId, "", $Username, .pResult, .tHttp, .tCode, .tDetail)
    Quit $Select($$$ISOK(tSC) && ($Get(tCode) = ""): "ok", 1: $Get(tHttp) _ " " _ $Get(tCode))
}

/// <p><b>AC1.</b> A person's Ignore and Stop ignoring each change the recommendation's flag: the page's own <code>GetRecommendations</code> and the
/// port's row read it ignored and then not ignored, each with a read-back that sent nothing. A second Ignore is refused 409
/// <code>ADVISOR.IGNORED</code> and a second Stop ignoring 409 <code>ADVISOR.NOTIGNORED</code>, each leaving the flag as it was; an absent row is 404.
/// The person's write emits no agent audit marker.</p>
/// <p>Mutation (Rule 19): <code>IGNORE</code> skips <method>OcuPilot.Port.AdvisorPort.SetFlag</method> in <code>Control</code> -> the ignored assertions go
/// red.</p>
Method TestAPersonIgnoresAndStopsIgnoringARowThroughItsActions()
{
    Set tId = ..Target(.tType, .tElement, .tCode)
    Do $$$AssertTrue(tId '= "", "the instance holds a recommendation that is not ignored")
    If tId = "" Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..StateOf(tType, tElement, tCode) _ "|" _ ..RowState(tId), "0|0", "it is not ignored: " _ $Translate(tId, $Char(1), "/"))
    Set tStatus = ..Act("ignore", tId, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|nothingSent", "Ignore answers 200 with a read-back that sent nothing: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..StateOf(tType, tElement, tCode) _ "|" _ ..RowState(tId), "1|1", "the page and the port read it ignored")
    Set tAgain = ..Act("ignore", tId, .tRefused)
    Do $$$AssertEquals(tAgain _ "|" _ ..Code(tRefused) _ "|" _ ..StateOf(tType, tElement, tCode), "409|ADVISOR.IGNORED|1", "a second Ignore is refused and the flag stays")
    Set tStop = ..Act("unignore", tId, .tStopped)
    Do $$$AssertEquals(tStop _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tStopped), "200|nothingSent", "Stop ignoring answers 200")
    Do $$$AssertEquals(..StateOf(tType, tElement, tCode) _ "|" _ ..RowState(tId), "0|0", "the page and the port read it not ignored")
    Set tStopAgain = ..Act("unignore", tId, .tStopRefused)
    Do $$$AssertEquals(tStopAgain _ "|" _ ..Code(tStopRefused) _ "|" _ ..StateOf(tType, tElement, tCode), "409|ADVISOR.NOTIGNORED|0", "a second Stop ignoring is refused and the flag stays")
    Set tAbsent = ..Act("ignore", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tType, tElement, "NoSuchCode")), .tNone)
    Do $$$AssertEquals(tAbsent _ "|" _ ..Code(tNone), "404|PORT.NOTFOUND", "an absent recommendation is 404")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", ..#IGNORE, .tMarker), 0, "and no agent marker is emitted for a person's action")
}

/// <p><b>AC1, AC6.</b> The agent's confirmed Ignore and Stop ignoring each change the flag once, with a read-back and one write ledger row carrying the audit
/// marker, and a second confirm of the same proposal is refused. A proposal for a recommendation already in the state the action leaves mints, and its
/// confirm is refused 409 by the port, which changes nothing.</p>
/// <p>Mutation (Rule 19): <code>IGNORE</code> skips <method>OcuPilot.Port.AdvisorPort.SetFlag</method> in <code>Control</code> -> the confirm's state
/// assertion goes red.</p>
Method TestTheAgentsConfirmIgnoresAndStopsIgnoringOnceWithOneAuditMarker()
{
    Set tId = ..Target(.tType, .tElement, .tCode)
    Do $$$AssertTrue(tId '= "", "the instance holds a recommendation that is not ignored")
    If tId = "" Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Dispatched(..#UNIGNORE, tType, tElement, tCode, .tNoneId, .tNoneTurn) _ "|" _ ..Confirmed(tNoneId, .tNoneResult) _ "|" _ ..StateOf(tType, tElement, tCode), "minted|409 ADVISOR.NOTIGNORED|0", "a Stop ignoring of a recommendation that is not ignored mints, and its confirm is refused by the port")
    Do $$$AssertEquals(..Dispatched(..#IGNORE, tType, tElement, tCode, .tProposalId, .tTurnKey, .tContent) _ "|" _ (tProposalId '= ""), "minted|1", "the baseline lets the Ignore mint a proposal: " _ tContent)
    Do $$$AssertEquals(..StateOf(tType, tElement, tCode), 0, "minting changes nothing")
    Set tOutcome = ..Confirmed(tProposalId, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ ..StateOf(tType, tElement, tCode) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "ok|1|nothingSent", "its confirm ignores the recommendation, with a read-back: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "AgentWrite", ..#IGNORE, .tMarker), 1, "and the audit log holds one agent marker for the tool")
    Do $$$AssertNotEquals(..Confirmed(tProposalId, .tSecond), "ok", "a second confirm of the same proposal is refused")
    Do $$$AssertEquals(..StateOf(tType, tElement, tCode), 1, "and changes nothing more")
    Do $$$AssertEquals(..Dispatched(..#IGNORE, tType, tElement, tCode, .tTwiceId, .tTwiceTurn) _ "|" _ ..Confirmed(tTwiceId, .tTwiceResult) _ "|" _ ..StateOf(tType, tElement, tCode), "minted|409 ADVISOR.IGNORED|1", "an Ignore of a recommendation already ignored mints, and its confirm is refused by the port")
    Do $$$AssertEquals(..Dispatched(..#UNIGNORE, tType, tElement, tCode, .tStopId, .tStopTurn) _ "|" _ (tStopId '= ""), "minted|1", "the baseline lets the Stop ignoring mint")
    Set tStopOutcome = ..Confirmed(tStopId, .tStopResult)
    Do $$$AssertEquals(tStopOutcome _ "|" _ ..StateOf(tType, tElement, tCode) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tStopResult), "ok|0|nothingSent", "its confirm stops ignoring it, with a read-back: " _ tStopOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tStopTurn, .tStopRow) _ "|" _ $Get(tStopRow("AuditMarked")), "1|" _ $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "with one audit marker of its own")
}

/// <p><b>AC1, AD-6.</b> The agent's Ignore of a recommendation the page does not list mints nothing, and a proposal minted on a listed recommendation is
/// refused at confirm as changed (<code>PROPOSAL.TARGETCHANGED</code>, the fingerprint's refusal, ahead of the port's own 409) once the flag changed after
/// the mint, leaving the flag as the other change left it.</p>
/// <p>Mutation (Rule 19): <code>AdvisorPort.Find</code> answers an unlisted recommendation as found -> the unlisted-code mint assertion goes red;
/// <code>SecurityAdvisorIgnore.FINGERPRINTSUBJECT</code> set to <code>Code</code> -> the changed-after-mint assertion goes red.</p>
Method TestTheAgentsProposalIsRefusedWhenTheRowChangedOrIsGone()
{
    Set tId = ..Target(.tType, .tElement, .tCode)
    Do $$$AssertTrue(tId '= "", "the instance holds a recommendation that is not ignored")
    If tId = "" Quit
    Do $$$AssertEquals(..Dispatched(..#IGNORE, tType, tElement, "NoSuchCodeProbe", .tGoneId, .tGoneTurn), "refused", "an Ignore of a recommendation the page does not list mints nothing")
    Do $$$AssertEquals(..Dispatched(..#IGNORE, tType, tElement, tCode, .tProposalId, .tTurnKey), "minted", "an Ignore of a listed recommendation mints")
    Do $ClassMethod(..#SEAM, "Vendor", tType, tElement, tCode, 1)
    Set tOutcome = ..Confirmed(tProposalId, .tResult)
    Do $$$AssertEquals(tOutcome, "409 PROPOSAL.TARGETCHANGED", "its confirm is refused as changed once the flag changed after the mint")
    Do $$$AssertEquals(..StateOf(tType, tElement, tCode), 1, "and the flag stays as the other change left it")
}

/// <p><b>AC6.</b> With a key stored disabled the agent's call of its tool is refused <code>GOVERNANCE.DISABLED</code> at dispatch before anything is
/// minted, for each of the two keys; with the baseline deciding again the same call mints. A person's action is not governed (AD-22): it still
/// writes with both keys stored disabled.</p>
/// <p>Mutation (Rule 19): <code>security.advisor.ignore</code> falls back to enabled whatever is stored (the key fallback in
/// <class>OcuPilot.Kernel.Governance.Policy</class>'s resolution) -> the refusal assertion goes red.</p>
Method TestADisabledKeyRefusesTheAgentAndNotThePerson()
{
    Set tId = ..Target(.tType, .tElement, .tCode)
    Do $$$AssertTrue(tId '= "", "the instance holds a recommendation that is not ignored")
    If tId = "" Quit
    Kill tSettings
    Set tSettings(..#IGNORE) = "disabled"
    Set tSettings(..#UNIGNORE) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "both keys are stored disabled")
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(..#IGNORE) _ "|" _ ##class(OcuPilot.Test.Governance).Resolved(..#UNIGNORE), "0|setting|0|setting", "they resolve disabled")
    Set tAnswer = ..Dispatched(..#IGNORE, tType, tElement, tCode, .tProposalId, .tTurnKey, .tContent)
    Do $$$AssertEquals(tAnswer _ "|" _ tContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", "the agent's Ignore is refused by the governance gate")
    Set tStopAnswer = ..Dispatched(..#UNIGNORE, tType, tElement, tCode, .tStopId, .tStopTurn, .tStopContent)
    Do $$$AssertEquals(tStopAnswer _ "|" _ tStopContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", "and so is its Stop ignoring")
    Do $$$AssertEquals(..StateOf(tType, tElement, tCode), 0, "nothing was changed")
    Set tStatus = ..Act("ignore", tId, .tPerson)
    Do $$$AssertEquals(tStatus _ "|" _ ..StateOf(tType, tElement, tCode), "200|1", "while a person's Ignore is not governed and writes")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline decides again")
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(..#UNIGNORE), "1|baseline", "the baseline ships the key enabled")
    Do $$$AssertEquals(..Dispatched(..#UNIGNORE, tType, tElement, tCode, .tOpenId, .tOpenTurn) _ "|" _ (tOpenId '= ""), "minted|1", "and the same call mints")
}

/// <p><b>AC1.</b> Armed with two rows, one ignored and one not: an Ignore of the ignored row is 409 <code>ADVISOR.IGNORED</code> and a Stop ignoring of the
/// other 409 <code>ADVISOR.NOTIGNORED</code>, each before the flag is called; an absent row and a malformed id are 404; an Ignore of the open row calls the
/// flag once and the row reads ignored, and a Stop ignoring calls it once more and the row reads open again; a flag call that changes nothing is a 500 and
/// the row stays as it was.</p>
/// <p>Mutation (Rule 19): the ignored-state refusal removed from <code>Control</code> -> the 409 rows go red, and so does the call record.</p>
Method TestARowInTheStateIsRefusedBeforeTheFlagIsCalledAndTheSeamFlagMoves()
{
    Set tIgnored = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Roles", " ", "AuditCount"))
    Set tOpen = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Users", "bob", "UserNotUsed"))
    Do $ClassMethod(..#SEAM, "Arm", [["Roles", " ", "AuditCount", 1], ["Users", "bob", "UserNotUsed", 0]])
    Kill tQuery
    Set tQuery("id") = tIgnored
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "IGNORE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Code(tFault) _ "|" _ $Select($IsObject(tFault): tFault.%Get("error"), 1: ""), "409|ADVISOR.IGNORED|conflict", "an Ignore of an ignored row is 409 on the conflict slug")
    Set tQuery("id") = tOpen
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "UNIGNORE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Code(tFault), "409|ADVISOR.NOTIGNORED", "a Stop ignoring of an open row is 409")
    For tAbsent = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Users", "bob", "NoSuchCode")), "Users" {
        Set tQuery("id") = tAbsent
        Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "IGNORE", .tQuery, "", .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ ..Code(tFault), "404|PORT.NOTFOUND", "a write to '" _ $Translate(tAbsent, $Char(1), "/") _ "' is 404")
    }
    Do $$$AssertEquals(..SetCalls(), "", "no flag was called by a refusal")
    Set tQuery("id") = tOpen
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "IGNORE", .tQuery, "", .tDone, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $IsObject(tDone) _ "|" _ ..RowStateOf(..#SEAM, tOpen), "200|1|1", "an Ignore of the open row answers and the row reads ignored")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "UNIGNORE", .tQuery, "", .tDone2, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..RowStateOf(..#SEAM, tOpen), "200|0", "and a Stop ignoring reads it open again")
    Do $$$AssertEquals(..SetCalls(), "SET Users|bob|UserNotUsed|1;SET Users|bob|UserNotUsed|0", "the flag was called once for each, with the row's own parts")
    Do $ClassMethod(..#SEAM, "NoEffect")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "IGNORE", .tQuery, "", .tNone, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Code(tFault) _ "|" _ ..RowStateOf(..#SEAM, tOpen), "500|" _ $Parameter("OcuPilot.Api.Error", "INTERNAL") _ "|0", "a flag call that changes nothing is a 500 and the row stays open")
}

/// <p>The <code>ROW</code> read of <var>pId</var> through the port class <var>pClass</var>, answering its <code>Ignored</code> as <code>1</code> or
/// <code>0</code>, or the HTTP status when it answers no row.</p>
ClassMethod RowStateOf(pClass As %String, pId As %String) As %String
{
    Kill tQuery
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(pClass, "Invoke", ..#ENDPOINT, "ROW", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): +tRow.%Get("Ignored"), 1: tHttp)
}

}
