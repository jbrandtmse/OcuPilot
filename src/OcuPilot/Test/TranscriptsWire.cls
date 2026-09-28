/// <p>Transcripts over HTTP (Story 14.4, AD-8, AD-33, AD-36, AD-46), driven by real principals: an
/// owner, and a reader whose second role is changed between reads -- holding nothing of OcuPilot's,
/// then <code>OcuPilotAdmin:USE</code> without <code>%Admin_Secure:USE</code>, then both. It pins
/// <code>GET /transcripts/:id</code>'s answers and refusals, the Transcripts list's scoping, and the
/// access row an administrator's read lands in their own ledger view.</p>
/// <p><b>It creates IRIS users and roles, so <method>OnBeforeAllTests</method> refuses to run unless
/// <parameter>ARMINGVARIABLE</parameter> reads 1.</b> The conversations and ledger rows are written
/// in process under the principals' names, so no turn job runs; every one is deleted after each
/// method.</p>
Class OcuPilot.Test.TranscriptsWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter APIBASE = "/api/ocupilot";

Parameter TRANSCRIPTROUTE = "/transcripts/:id";

Parameter LISTROUTE = "/screens/agent.transcripts/read";

Parameter LEDGERROUTE = "/agent/ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The pair the second turn's row records, which the reader holds only in the last leg.</p>
Parameter WITHHELDPAIR = "%Admin_Secure:USE";

Property PreparedPassword As %String;

/// <p>The conversation keys this method created, for its teardown.</p>
Property CreatedKeys As %String [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TranscriptsWire creates IRIS users and roles, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..Owner(), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..Reader(), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"), "OcuPilotAdmin:U")
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do ..ClearRows()
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TranscriptsWire teardown left:" _ tLeft)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tKey = ""
    For {
        Set tKey = $Order(..CreatedKeys(tKey))
        If tKey = "" Quit
        Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
    }
    Kill ..CreatedKeys
    Do ..ClearRows()
    Quit $$$OK
}

/// <p>The transcript route for conversation <var>pKey</var>.</p>
ClassMethod Transcript(pKey As %String) As %String
{
    Quit $Replace(..#TRANSCRIPTROUTE, ":id", pKey)
}

ClassMethod Owner() As %String
{
    Quit $Parameter(..#FIXTURE, "USERA")
}

ClassMethod Reader() As %String
{
    Quit $Parameter(..#FIXTURE, "USERB")
}

ClassMethod ClearRows()
{
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..Owner())
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..Reader())
}

/// <p>Give the reader's second role exactly <var>pResources</var>.</p>
ClassMethod SetReaderResources(pResources As %String) As %Status
{
    Set tSC = $$$OK
    Set tRole = $Parameter(..#FIXTURE, "SECONDROLE")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Resources") = pResources
        Set tProps("GrantedRoles") = ""
        Set tSC = ##class(Security.Roles).Modify(tRole, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>A conversation of <var>pUser</var> holding two turns: the first recorded against a pair every
/// probe principal holds, the second against <parameter>WITHHELDPAIR</parameter>. Each entry carries
/// a step and a screen context.</p>
Method Seed(pUser As %String, pMessage As %String = "What runs tonight?") As %String
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", pUser, 5, .tStatus, .tConflict)
    If '$IsObject(tConvo) Quit ""
    Set tKey = tConvo.ConvKey
    Set ..CreatedKeys(tKey) = ""
    Set tContext = {"route": "tasks/schedule", "view": {"rows": []}}
    For tI = 1, 2 {
        Set tTurn = "probetranscriptwire" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
        Set tPair = $Select(tI = 1: $ListBuild("%Admin_Operate", "USE"), 1: $ListBuild($Piece(..#WITHHELDPAIR, ":", 1), $Piece(..#WITHHELDPAIR, ":", 2)))
        Do ##class(OcuPilot.Kernel.Audit.Ledger).RecordToolCall(tTurn, pUser, "tasks/schedule", "tasks.schedule.read", "", {}, $ListBuild(tPair), "", "", "ok", "", ..#LIMITS, 1, "checked")
        Set tSteps = [{"seq": 1, "kind": "tool", "name": "tasks.schedule.read", "status": "ok", "summary": "", "text": ""}]
        Do ##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, $Select(tI = 1: pMessage, 1: "And after that?"), "completed", "Reply " _ tI, "", 0, tSteps, 0, ..#LIMITS, tTurn, "", tContext.%ToJSON(), "")
    }
    Set tConvo = ""
    Quit tKey
}

Method CallAs(pUser As %String, pPath As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIBASE _ pPath, pUser, ..PreparedPassword, .pStatus, .pText, .pHeaders)
}

/// <p>The reader's access rows for conversation <var>pKey</var>, by direct SQL.</p>
ClassMethod AccessCount(pKey As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE Kind = 'access' AND %EXACT(TurnKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>AC1: the owner reads their own transcript whole -- each turn's message, reply, steps and
/// stored screen context -- and no access row is written.</p>
Method TestTheOwnerReadsTheirTranscriptWhole()
{
    Set tKey = ..Seed(..Owner())
    Do $$$AssertNotEquals(tKey, "", "a conversation is seeded")
    Do ..CallAs(..Owner(), ..Transcript(tKey), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner's read answers 200: " _ $Extract(tText, 1, 300))
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus '= 200 Quit
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tView.conversationId, tKey, "for the conversation asked for")
    Do $$$AssertEquals(tView.user, ..Owner(), "naming its owner")
    Do $$$AssertEquals(tView.own, 1, "as the caller's own")
    Do $$$AssertEquals(tView.released, 1, "released")
    Do $$$AssertEquals(tView.turns.%Size(), 2, "with both turns")
    Set tTurn = tView.turns.%Get(0)
    Do $$$AssertEquals(tTurn.message, "What runs tonight?", "each carrying its message")
    Do $$$AssertEquals(tTurn.reply, "Reply 1", "its reply")
    Do $$$AssertEquals(tTurn.steps.%Size(), 1, "its steps")
    Do $$$AssertEquals(tTurn.context.route, "tasks/schedule", "and its stored screen context")
    Do $$$AssertTrue(tTurn.appendedAt '= "", "and when it was appended")
    Do $$$AssertEquals(tTurn.%IsDefined("proposals"), 0, "and never its proposals")
    Do $$$AssertEquals(..AccessCount(tKey), 0, "the owner's read records no access row")
}

/// <p>AD-33: another user's id asked for by a caller without <code>OcuPilotAdmin:USE</code> gets the
/// same 404 body an unknown id gets, and nothing is recorded.</p>
Method TestANonAdministratorGetsTheSameNotFoundAsAnUnknownId()
{
    Set tKey = ..Seed(..Owner())
    Do $$$AssertStatusOK(..SetReaderResources(""), "the reader holds nothing of OcuPilot's")
    Do ..CallAs(..Reader(), ..Transcript(tKey), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "another user's transcript answers 404")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do ..CallAs(..Reader(), ..Transcript("no-such-conversation"), .tUnknownStatus, .tUnknownText, .tUnknownHeaders)
    Do $$$AssertEquals(tUnknownStatus, 404, "and so does an unknown id")
    Do $$$AssertEquals(tText, tUnknownText, "with the same body")
    Set tBody = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tBody.code, "TURN.CONVERSATION.NOTFOUND", "the conversation-not-found code")
    Do $$$AssertEquals(..AccessCount(tKey), 0, "and no access row is written")
}

/// <p>AC3: an administrator holding every recorded pair reads another user's transcript whole, and
/// the read is recorded, released.</p>
Method TestAnAdministratorHoldingEveryPairReadsTheTranscriptWhole()
{
    Set tKey = ..Seed(..Owner())
    Do $$$AssertStatusOK(..SetReaderResources("OcuPilotAdmin:U,%Admin_Secure:U"), "the reader holds the administrative pair and the second turn's")
    Do ..CallAs(..Reader(), ..Transcript(tKey), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the read answers 200: " _ $Extract(tText, 1, 300))
    If tStatus '= 200 Quit
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tView.own, 0, "as another user's")
    Do $$$AssertEquals(tView.released, 1, "released")
    Do $$$AssertEquals(tView.turns.%Get(1).steps.%Size(), 1, "with its steps")
    Do $$$AssertEquals(tView.turns.%Get(1).context.route, "tasks/schedule", "and its screen context")
    Do $$$AssertEquals(..AccessCount(tKey), 1, "and one access row is written")
}

/// <p>AC3: an administrator missing one recorded pair sees messages and replies only, the pair it
/// lacks is named, and the read is recorded, withheld.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Audit.Ledger.GateTurns</method> skip
/// <code>ReleasesRow</code> -- the transcript is released and this goes red.</p>
Method TestAnAdministratorMissingOnePairSeesMessagesAndRepliesOnly()
{
    Set tKey = ..Seed(..Owner())
    Do $$$AssertStatusOK(..SetReaderResources("OcuPilotAdmin:U"), "the reader holds the administrative pair alone")
    Do ..CallAs(..Reader(), ..Transcript(tKey), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the read answers 200: " _ $Extract(tText, 1, 300))
    If tStatus '= 200 Quit
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tView.released, 0, "withheld")
    Do $$$AssertEquals(tView.failedPair, ..#WITHHELDPAIR, "naming the pair the reader lacks")
    For tI = 0, 1 {
        Set tTurn = tView.turns.%Get(tI)
        Do $$$AssertEquals(tTurn.steps.%Size(), 0, "turn " _ tI _ " carries no steps")
        Do $$$AssertEquals(tTurn.%GetTypeOf("context"), "null", "and no screen context")
        Do $$$AssertTrue(tTurn.message '= "", "but its message")
        Do $$$AssertEquals(tTurn.reply, "Reply " _ (tI + 1), "and its reply")
    }
    Do $$$AssertEquals(..AccessCount(tKey), 1, "and one access row is written")
}

/// <p>AC1: the Transcripts list shows a non-administrator their own conversations only, titled; an
/// administrator sees every user's, titled only on their own.</p>
/// <p>Mutation (Rule 19): drop the owner filter in
/// <method>OcuPilot.Kernel.State.Convo.GuardedScreenRows</method> -- the non-administrator lists the
/// owner's conversation and this goes red.</p>
Method TestTheListShowsANonAdministratorTheirOwnOnly()
{
    Set tOwners = ..Seed(..Owner(), "the owner's question")
    Set tReaders = ..Seed(..Reader(), "the reader's question")
    Do $$$AssertStatusOK(..SetReaderResources(""), "the reader holds nothing of OcuPilot's")
    Do ..CallAs(..Reader(), ..#LISTROUTE, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the list reads for a non-administrator: " _ $Extract(tText, 1, 300))
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus '= 200 Quit
    Do ..RowsById(##class(%DynamicObject).%FromJSON(tText), .tRows)
    Do $$$AssertEquals($Data(tRows(tReaders)), 10, "listing the reader's own conversation")
    Do $$$AssertEquals($Get(tRows(tReaders, "title")), "the reader's question", "titled")
    Do $$$AssertEquals($Data(tRows(tOwners)), 0, "and not the owner's")

    Do $$$AssertStatusOK(..SetReaderResources("OcuPilotAdmin:U"), "the reader holds the administrative pair")
    Do ..CallAs(..Reader(), ..#LISTROUTE, .tAdminStatus, .tAdminText, .tAdminHeaders)
    Do $$$AssertEquals(tAdminStatus, 200, "the list reads for an administrator")
    If tAdminStatus '= 200 Quit
    Do ..RowsById(##class(%DynamicObject).%FromJSON(tAdminText), .tAdminRows)
    Do $$$AssertEquals($Data(tAdminRows(tOwners)), 10, "listing the owner's conversation")
    Do $$$AssertEquals($Get(tAdminRows(tOwners, "title")), "", "without its first message")
    Do $$$AssertEquals($Get(tAdminRows(tOwners, "user")), ..Owner(), "naming its user")
    Do $$$AssertEquals($Get(tAdminRows(tReaders, "title")), "the reader's question", "and the reader's own, titled")
}

/// <p><var>pAnswer</var>'s rows keyed by id: <var>pRows(id, field)</var>.</p>
ClassMethod RowsById(pAnswer As %DynamicObject, Output pRows)
{
    Kill pRows
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.rows) Quit
    Set tIterator = pAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tId = tRow.%Get("id")
        For tField = "user", "title", "turns", "started", "lastActivity" {
            Set pRows(tId, tField) = tRow.%Get(tField)
        }
    }
}

/// <p>Matrix row "Fail closed", over the route: a turn with no ledger row at all withholds the
/// whole transcript for an administrator holding every pair there is, and the read is still
/// recorded, withheld.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Audit.Ledger.GateTurns</method> answer
/// released whatever closed the gate -- this goes red.</p>
Method TestATurnWithNoLedgerRowIsWithheldOverTheRoute()
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", ..Owner(), 5, .tLoadSC, .tConflict)
    Do $$$AssertTrue($IsObject(tConvo), "a conversation is created")
    Set tKey = tConvo.ConvKey
    Set ..CreatedKeys(tKey) = ""
    Set tTurn = "probetranscriptwirenoledger" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
    Set tSteps = [{"seq": 1, "kind": "tool", "name": "tasks.schedule.read", "status": "ok", "summary": "", "text": ""}]
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "No ledger row backs this one", "completed", "Reply", "", 0, tSteps, 0, ..#LIMITS, tTurn, "", "", ""), "an entry with no ledger row is appended")
    Set tConvo = ""

    Do $$$AssertStatusOK(..SetReaderResources("OcuPilotAdmin:U,%Admin_Secure:U"), "the reader holds every pair there is")
    Do ..CallAs(..Reader(), ..Transcript(tKey), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the read answers 200: " _ $Extract(tText, 1, 300))
    If tStatus '= 200 Quit
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tView.released, 0, "withheld, failing closed on a turn with no stored row")
    Do $$$AssertEquals(tView.turns.%Get(0).steps.%Size(), 0, "no steps")
    Do $$$AssertEquals(tView.turns.%Get(0).%GetTypeOf("context"), "null", "and no screen context")
    Do $$$AssertTrue(tView.turns.%Get(0).message '= "", "but its message")
    Do $$$AssertEquals(..AccessCount(tKey), 1, "and the read is still recorded")
}

/// <p>Integration (Rule 1): the access row an administrator's read writes appears in that
/// administrator's own ledger view, the route 16.16's viewer reads, with <code>kind</code>
/// <code>access</code>.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Kernel.Audit.Ledger.RecordTranscriptAccess</method>
/// call -- the view is empty and this goes red.</p>
Method TestTheAccessRowAppearsInTheAdministratorsOwnLedgerView()
{
    Set tKey = ..Seed(..Owner())
    Do $$$AssertStatusOK(..SetReaderResources("OcuPilotAdmin:U"), "the reader holds the administrative pair")
    Do ..CallAs(..Reader(), ..Transcript(tKey), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the transcript read answers")
    Do ..CallAs(..Reader(), ..#LEDGERROUTE _ "?turnKey=" _ tKey, .tLedgerStatus, .tLedgerText, .tLedgerHeaders)
    Do $$$AssertEquals(tLedgerStatus, 200, "the reader's own ledger reads: " _ $Extract(tLedgerText, 1, 300))
    If tLedgerStatus '= 200 Quit
    Set tView = ##class(%DynamicObject).%FromJSON(tLedgerText)
    Do $$$AssertEquals(tView.rows.%Size(), 1, "one row")
    If tView.rows.%Size() = 1 {
        Do $$$AssertEquals(tView.rows.%Get(0).kind, "access", "of kind access")
        Do $$$AssertEquals(tView.rows.%Get(0).target, ..Owner(), "naming whose transcript was read")
    }
}

}
