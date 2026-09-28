/// <p>The transcript half of the ledger's gate (Story 14.4, AD-46):
/// <method>OcuPilot.Kernel.Audit.Ledger.GateTurns</method> over a declared set of grants
/// (<class>OcuPilot.Test.LedgerGateProbe</class>), the rows it fails closed on, the access row it
/// records, and <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s per-row answers after
/// the decision moved into <code>ReleasesRow</code>.</p>
/// <p><b>Live-safe.</b> It creates no principal and spawns nothing; every row it writes names
/// <parameter>SUBJECT</parameter> or <parameter>READER</parameter>, which name no account, and both
/// users' rows are deleted after every method, except the late-entry leg's access row, which names the
/// runner and is deleted by its own method. The 503 leg runs the handler as the test process's
/// own user and asks the real privilege gate, so it needs a runner holding
/// <code>OcuPilotAdmin:USE</code>; a runner without it reads the shared 404 and fails.</p>
Class OcuPilot.Test.TranscriptGate Extends %UnitTest.TestCase
{

Parameter SUBJECT = "OcuPilotProbeTranscriptSubject";

Parameter READER = "OcuPilotProbeTranscriptReader";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

Parameter PROBE = "OcuPilot.Test.LedgerGateProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertEquals(..RowCount(), 0, "no probe ledger row survives the method")
    Quit $$$OK
}

ClassMethod Clear()
{
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#SUBJECT)
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#READER)
}

ClassMethod RowCount() As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = ? OR %EXACT(UserName) = ?", ..#SUBJECT, ..#READER)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>A fresh probe key.</p>
ClassMethod NewKey() As %String
{
    Quit "probetranscript" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
}

/// <p>One tool row of turn <var>pTurnKey</var> as the subject, requiring <var>pPairs</var>, checked.</p>
ClassMethod Record(pTurnKey As %String, pPairs As %List) As %Status
{
    Quit $ClassMethod(..#LEDGER, "RecordToolCall", pTurnKey, ..#SUBJECT, "tasks/schedule", "tasks.schedule.read", "", {}, pPairs, "", "", "ok", "", ..#LIMITS, 1, $ClassMethod(..#LEDGER, "SenseChecked"))
}

/// <p>The reader's access rows for conversation <var>pConvKey</var>, as <code>kind|name|target|pairs|sense|arguments</code>.</p>
ClassMethod AccessRows(pConvKey As %String) As %String
{
    Set tOut = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Kind, Name, Target, RequiredPairs, PairsSense, Arguments FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = ? AND %EXACT(TurnKey) = ?", ..#READER, pConvKey)
    While tRS.%Next() {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tRS.%GetData(1) _ "|" _ tRS.%GetData(2) _ "|" _ tRS.%GetData(3) _ "|" _ tRS.%GetData(4) _ "|" _ tRS.%GetData(5) _ "|" _ tRS.%GetData(6)
    }
    Quit tOut
}

/// <p>AC3: a transcript whose every row the reader holds is released, and the read is recorded as
/// one access row naming the subject, keyed by the conversation, carrying the administrative pair
/// checked.</p>
Method TestATranscriptIsReleasedWhenEveryRowPassesAndTheReadIsRecorded()
{
    Set tConv = ..NewKey()
    Set tTurnA = ..NewKey()
    Set tTurnB = ..NewKey()
    Do $$$AssertStatusOK(..Record(tTurnA, $ListBuild($ListBuild("%Admin_Operate", "USE"))), "turn A's row is recorded")
    Do $$$AssertStatusOK(..Record(tTurnB, $ListBuild($ListBuild("%Admin_Task", "USE"))), "turn B's row is recorded")
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Task", "USE")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "GateTurns", ..#READER, ..#SUBJECT, tConv, $ListBuild(tTurnA, tTurnB), .tReleased, .tFailed, .tFault), "the gate runs")
    Do $$$AssertEquals($IsObject(tFault), 0, "without a fault")
    Do $$$AssertEquals(tReleased, 1, "and releases the transcript")
    Do $$$AssertEquals(tFailed, "", "naming no pair")
    Do $$$AssertEquals(..AccessRows(tConv), "access|transcript|" _ ..#SUBJECT _ "|OcuPilotAdmin:USE|checked|{""conversationId"":""" _ tConv _ """,""released"":true}", "and records one access row")
}

/// <p>AC3: one row whose pair the reader does not hold withholds the whole transcript, names that
/// pair, and is still recorded, released false.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Audit.Ledger.GateTurns</method> skip
/// <code>ReleasesRow</code> -- the transcript is released and this goes red.</p>
Method TestOneRowTheReaderLacksWithholdsTheTranscript()
{
    Set tConv = ..NewKey()
    Set tTurnA = ..NewKey()
    Set tTurnB = ..NewKey()
    Do $$$AssertStatusOK(..Record(tTurnA, $ListBuild($ListBuild("%Admin_Operate", "USE"))), "turn A's row is recorded")
    Do $$$AssertStatusOK(..Record(tTurnB, $ListBuild($ListBuild("%Admin_Secure", "USE"))), "turn B's row is recorded")
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Operate", "USE")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "GateTurns", ..#READER, ..#SUBJECT, tConv, $ListBuild(tTurnA, tTurnB), .tReleased, .tFailed, .tFault), "the gate runs")
    Do $$$AssertEquals(tReleased, 0, "the transcript is withheld")
    Do $$$AssertEquals(tFailed, "%Admin_Secure:USE", "naming the pair the reader lacks")
    Do $$$AssertTrue(..AccessRows(tConv) [ """released"":false", "and the read is recorded as withheld: " _ ..AccessRows(tConv))
}

/// <p>The gate fails closed: no turn, a legacy <code>""</code> key, a turn with no row, a row whose
/// pair set was cut, and a turn with a call counted and not stored each withhold the transcript
/// even though the reader holds every pair named.</p>
Method TestTheGateFailsClosed()
{
    Set tHeld = $ListBuild($ListBuild("%Admin_Operate", "USE"))
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Operate", "USE")
    Set tGood = ..NewKey()
    Do $$$AssertStatusOK(..Record(tGood, tHeld), "a passing row is recorded")

    For tCase = "none", "legacy", "empty", "cut", "dropped" {
        Set tConv = ..NewKey()
        Set tKeys = ""
        If tCase = "legacy" Set tKeys = $ListBuild(tGood, "")
        If tCase = "empty" Set tKeys = $ListBuild(tGood, ..NewKey())
        If tCase = "cut" {
            Set tCut = ..NewKey()
            Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedAppend", tCut, ..#SUBJECT, "", "tool", "probe", "", "", "", 0, "ok", "", 0, 0, "%Admin_Operate:USE", ..#LIMITS, .tSeq, .tStored, 1, "checked"), "a row whose pair set was cut is stored")
            Set tKeys = $ListBuild(tGood, tCut)
        }
        If tCase = "dropped" {
            Set tDropped = ..NewKey()
            Do $$$AssertStatusOK(..Record(tDropped, tHeld), "a passing row is stored")
            Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCountOverflow", tDropped, ..#SUBJECT, "", .tCount), "and a call is counted past the cap")
            Set tKeys = $ListBuild(tGood, tDropped)
        }
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "GateTurns", ..#READER, ..#SUBJECT, tConv, tKeys, .tReleased, .tFailed, .tFault), tCase _ ": the gate runs")
        Do $$$AssertEquals(tReleased, 0, tCase _ ": withheld")
        Do $$$AssertTrue(..AccessRows(tConv) [ """released"":false", tCase _ ": and recorded as withheld")
    }
}

/// <p>A reader without the administrative pair is refused before anything is read, and nothing is
/// recorded; the owner asking about their own conversation is released and nothing is recorded.</p>
Method TestNoAdministrativePairIsRefusedAndAnOwnReadRecordsNothing()
{
    Set tConv = ..NewKey()
    Set tTurn = ..NewKey()
    Do $$$AssertStatusOK(..Record(tTurn, $ListBuild($ListBuild("%Admin_Operate", "USE"))), "a row is recorded")
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.LedgerGate).DenyAdmin()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "GateTurns", ..#READER, ..#SUBJECT, tConv, $ListBuild(tTurn), .tReleased, .tFailed, .tFault), "the gate runs")
    Do $$$AssertTrue($IsObject(tFault), "and refuses")
    If $IsObject(tFault) Do $$$AssertEquals(tFault.code, "AUTH.NOPRIVILEGE", "for the missing administrative pair")
    Do $$$AssertEquals(tReleased, 0, "releasing nothing")
    Do $$$AssertEquals(..AccessRows(tConv), "", "and recording nothing")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "GateTurns", ..#SUBJECT, $ZConvert(..#SUBJECT, "L"), tConv, $ListBuild(tTurn), .tOwn, .tOwnFailed, .tOwnFault), "the owner's own read runs")
    Do $$$AssertEquals(tOwn, 1, "and is released whatever the administrative pair")
    Do $$$AssertEquals($IsObject(tOwnFault), 0, "without a fault")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE Kind = 'access' AND %EXACT(TurnKey) = ?", tConv)
    Do $$$AssertTrue(tRS.%Next() && (tRS.%GetData(1) = 0), "and no access row is written under any name")
}

/// <p><method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s per-row answers are unchanged by
/// the extraction: a cut set, an unparseable set, an empty set nobody read and a set the reader
/// lacks are withheld; an empty set whose writer found none and a set the reader holds are
/// released.</p>
Method TestTheLedgerViewKeepsItsPerRowAnswers()
{
    Set tTurn = ..NewKey()
    Set tCases = $ListBuild($ListBuild("%Admin_Operate:USE", 1, "checked"), $ListBuild("notapair", 0, "checked"), $ListBuild("", 0, ""), $ListBuild("", 0, "none"), $ListBuild("%Admin_Secure:USE", 0, "checked"), $ListBuild("%Admin_Operate:USE", 0, "checked"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedAppend", tTurn, ..#SUBJECT, "", "tool", "probe" _ tI, "", "", "", 0, "ok", "", 0, 0, $List(tCase, 1), ..#LIMITS, .tSeq, .tStored, $List(tCase, 2), $List(tCase, 3)), "row " _ tI _ " is stored")
    }
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Operate", "USE")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ViewForUser", ..#READER, ..#SUBJECT, 0, tTurn, 50, .tView, .tFault), "the cross-user read runs")
    Do $$$AssertEquals(tView.rowsSent, 2, "the empty set whose writer found none and the held pair are released")
    Do $$$AssertEquals(tView.rowsWithheld, 4, "and the cut, unparseable, unread-empty and lacked rows are withheld")
    Kill tNames
    For tI = 0:1:tView.rows.%Size() - 1 {
        Set tNames(tView.rows.%Get(tI).name) = ""
    }
    Do $$$AssertEquals($Data(tNames("probe4")) + $Data(tNames("probe6")), 2, "naming exactly those two rows")
}

/// <p>Integration (Rule 1): the access row a cross-user transcript read writes is one the reader's
/// own ledger view lists, with <code>kind</code> <code>access</code>.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Kernel.Audit.Ledger.RecordTranscriptAccess</method>
/// call from <method>OcuPilot.Kernel.Audit.Ledger.GateTurns</method> -- the reader's view is empty and
/// this goes red.</p>
Method TestTheAccessRowAppearsInTheReadersOwnLedgerView()
{
    Set tConv = ..NewKey()
    Set tTurn = ..NewKey()
    Do $$$AssertStatusOK(..Record(tTurn, $ListBuild($ListBuild("%Admin_Operate", "USE"))), "a row is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "GateTurns", ..#READER, ..#SUBJECT, tConv, $ListBuild(tTurn), .tReleased, .tFailed, .tFault), "the gate runs")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#READER, "", 0, tConv, 10, .tView, .tViewFault), "the reader's own view reads")
    Do $$$AssertEquals(tView.rows.%Size(), 1, "one row")
    If tView.rows.%Size() = 1 {
        Do $$$AssertEquals(tView.rows.%Get(0).kind, "access", "of kind access")
        Do $$$AssertEquals(tView.rows.%Get(0).target, ..#SUBJECT, "naming whose transcript was read")
    }
}

/// <p>DW-1751: the route's 503 leg. When the ledger store cannot be read,
/// <method>OcuPilot.Api.Transcripts.HandleRead</method> maps <code>GateTurns</code>'s
/// <code>LEDGER.UNAVAILABLE</code> fault to HTTP 503 -- not the shared 404 an unknown or refused
/// id gets.</p>
/// <p>Driven in process through <class>OcuPilot.Test.Dispatch</class> against
/// <class>OcuPilot.Test.TranscriptsRouteProbe</class>: the router names
/// <class>OcuPilot.Api.Transcripts</class> by class, so a fixture subclass has no route of its
/// own to arrive on -- the same precedent <class>OcuPilot.Test.LedgerRouteProbe</class> exists
/// for.</p>
/// <p>Mutation (Rule 19): map <code>LEDGER.UNAVAILABLE</code> to the shared 404 in
/// <method>OcuPilot.Api.Transcripts.HandleRead</method> -- the status assertion goes red.</p>
Method TestAnUnreadableStoreRendersA503OverTheRoute()
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", ..#SUBJECT, 5, .tLoadSC, .tConflict)
    Do $$$AssertTrue($IsObject(tConvo), "a conversation is created")
    Set tKey = tConvo.ConvKey
    Set tTurn = ..NewKey()
    Set tSteps = [{"seq": 1, "kind": "tool", "name": "tasks.schedule.read", "status": "ok", "summary": "", "text": ""}]
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "probe message", "completed", "probe reply", "", 0, tSteps, 0, ..#LIMITS, tTurn, "", "", ""), "an entry naming the turn is appended")
    Set tConvo = ""

    Do $$$AssertStatusOK(##class(OcuPilot.Test.Dispatch).InvokeHandlerWithRequest(##class(%CSP.Request).%New(), "OcuPilot.Test.TranscriptsRouteProbe", "HandleRead", tKey, .tBody, .tStatus), "the handler answers rather than raising")
    Do $$$AssertEquals(tStatus, 503, "on the unavailable status: " _ tBody)
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tAnswer = ""
    }
    Do $$$AssertTrue($IsObject(tAnswer), "which parses as one JSON object: " _ tBody)
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.error, ##class(OcuPilot.Api.Error).#UNAVAILABLE, "carrying the slug")
        Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE, "the ledger-unavailable machine code, not the conversation-not-found code the 404 carries")
    }
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
}

/// <p>AC3, over the route: an entry appended after the gate read the conversation's turn keys --
/// the owner's turn finishing mid-read -- carries no steps and no context to an administrator,
/// even when the gate released every turn it saw, which keep theirs.</p>
/// <p>Mutation (Rule 19): release every row on the gate's answer in
/// <method>OcuPilot.Api.Transcripts.HandleRead</method> -- the late turn carries its steps and this
/// goes red.</p>
Method TestATurnAppendedAfterTheGateIsWithheld()
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", ..#SUBJECT, 5, .tLoadSC, .tConflict)
    Do $$$AssertTrue($IsObject(tConvo), "a conversation is created")
    If '$IsObject(tConvo) Quit
    Set tKey = tConvo.ConvKey
    Set tTurn = ..NewKey()
    Set tSteps = [{"seq": 1, "kind": "tool", "name": "tasks.schedule.read", "status": "ok", "summary": "", "text": ""}]
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "probe message", "completed", "probe reply", "", 0, tSteps, 0, ..#LIMITS, tTurn, "", "{""route"":""tasks/schedule""}", ""), "an entry naming the turn is appended")
    Set tConvo = ""
    Do $$$AssertStatusOK(..Record(tTurn, $ListBuild($ListBuild("%Admin_Operate", "USE"))), "its ledger row is recorded")
    Do ##class(OcuPilot.Test.LedgerGate).Grant("%Admin_Operate", "USE")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.Dispatch).InvokeHandlerWithRequest(##class(%CSP.Request).%New(), "OcuPilot.Test.TranscriptsAppendRouteProbe", "HandleRead", tKey, .tBody, .tStatus), "the handler answers rather than raising")
    Do $$$AssertEquals(tStatus, 200, "with the transcript: " _ tBody)
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tAnswer = ""
    }
    Do $$$AssertTrue($IsObject(tAnswer), "which parses as one JSON object: " _ tBody)
    If $IsObject(tAnswer) {
        Do $$$AssertEquals(tAnswer.released, 1, "the gate released every turn it saw")
        Do $$$AssertEquals(tAnswer.turns.%Size(), 2, "and the late entry is listed")
        If tAnswer.turns.%Size() = 2 {
            Do $$$AssertEquals(tAnswer.turns.%Get(0).steps.%Size(), 1, "the gated turn keeps its steps")
            Do $$$AssertEquals(tAnswer.turns.%Get(0).%GetTypeOf("context"), "object", "and its context")
            Do $$$AssertEquals(tAnswer.turns.%Get(1).steps.%Size(), 0, "the late turn carries no steps")
            Do $$$AssertEquals(tAnswer.turns.%Get(1).%GetTypeOf("context"), "null", "and no context")
            Do $$$AssertEquals(tAnswer.turns.%Get(1).reply, "late reply", "while its reply is still sent")
        }
    }
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Ledger WHERE Kind = 'access' AND %EXACT(TurnKey) = ?", tKey)
}

}
