/// <p>The agent ledger's store and its read, in process (AD-9, AD-21, AD-37, AD-41, AD-46): the
/// per-turn row cap and its overflow count, the argument cut, the bounded windowed read's binding,
/// a swept turn leaving its rows behind, the self/cross-user split and its per-row gate, the two
/// refusals that record a row before dispatch, a row outliving the account it names, and an
/// unreadable store as one envelope.</p>
/// <p><b>Two siblings hold the rest</b>, and call this class's helpers by full name:
/// <class>OcuPilot.Test.LedgerRedaction</class> the two redaction layers, and
/// <class>OcuPilot.Test.LedgerPairs</class> the pair string and the bounds around it.</p>
/// <p><b>Live-safe with one exception.</b> It spawns nothing, creates no principal and touches no
/// registration. Every row it writes carries a user name starting with
/// <parameter>PROBEUSER</parameter>'s prefix and a turn key starting with
/// <parameter>KEYPREFIX</parameter>, and <method>OnAfterOneTest</method> asserts none survives. The
/// exception is <method>TestASweepRemovesTheTurnAndLeavesItsLedgerRows</method>, which runs
/// <method>OcuPilot.Kernel.State.Turn.GuardedSweep</method> -- instance-wide over every terminal
/// turn past retention, not only this class's.</p>
Class OcuPilot.Test.Ledger Extends %UnitTest.TestCase
{

/// <p>The store under test.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The ledger's public face.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

/// <p>The shipped bounds, and the narrowed ones a cap test runs under.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter NARROW = "OcuPilot.Test.LedgerLimits";

/// <p>The shipped bounds with only the reply budget narrowed.</p>
Parameter BUDGET = "OcuPilot.Test.LedgerBudgetLimits";

/// <p>The user every probe row records. It shares
/// <parameter>OcuPilot.Test.TurnFixture.PROBEPREFIX</parameter>, so a turn this class reserves is
/// removed by that fixture's own teardown.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnLedgerA";

/// <p>The prefix every probe turn key carries.</p>
Parameter KEYPREFIX = "ocupilotprobeledger";

/// <p>The declared secret's own value, which must reach no column and no view.</p>
Parameter SECRETVALUE = "s3cr3tledgervalue";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertEquals(..RowCount(), 0, "no probe ledger row survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining), "the probe turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Remove every probe row this class could have written.</p>
Method Clear()
{
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER _ "B")
}

/// <p>How many rows name this class's probe users.</p>
ClassMethod RowCount() As %Integer
{
    Quit ..RowCountFor(..#PROBEUSER)
}

/// <p>How many rows name a user starting with <var>pPrefix</var>, by direct SQL rather than through
/// the store the tests are checking. The split siblings answer their own teardown through it.</p>
ClassMethod RowCountFor(pPrefix As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE UserName %STARTSWITH ?", pPrefix)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>Every column of every row of turn <var>pTurnKey</var>, concatenated -- the serialization an
/// absence assertion is made against, read by direct SQL so it covers what is stored rather than
/// what a projection chose to show.</p>
ClassMethod RowText(pTurnKey As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT * FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", pTurnKey)
    If tRS.%SQLCODE < 0 Quit "SQLCODE=" _ tRS.%SQLCODE
    Set tMeta = tRS.%GetMetadata()
    While tRS.%Next() {
        For tI = 1:1:tMeta.columns.Count() {
            Set tText = tText _ "|" _ tRS.%GetData(tI)
        }
    }
    Quit tText
}

/// <p>Every column of every progress step of turn <var>pTurnKey</var>, concatenated -- the same
/// serialization <method>RowText</method> makes of the ledger, over the store beside it. A tool
/// step's own argument string runs the same two redaction layers a ledger row's does
/// (<method>OcuPilot.Kernel.Agent.Dispatch.StepArguments</method>), so a declared secret must be
/// absent from both or the redaction is only half wired.</p>
ClassMethod StepText(pTurnKey As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT * FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", pTurnKey)
    If tRS.%SQLCODE < 0 Quit "SQLCODE=" _ tRS.%SQLCODE
    Set tMeta = tRS.%GetMetadata()
    While tRS.%Next() {
        For tI = 1:1:tMeta.columns.Count() {
            Set tText = tText _ "|" _ tRS.%GetData(tI)
        }
    }
    Quit tText
}

/// <p>A fresh probe turn key.</p>
ClassMethod NewTurnKey() As %String
{
    Quit ..#KEYPREFIX _ $Translate($System.Util.CreateGUID(), "-", "")
}

/// <p>Record one tool call through the ledger's own public face. <var>pClassified</var> defaults to
/// 1 -- the ordinary case of a resolved tool whose declaration was read -- so a caller passing 0
/// asks for the withheld-arguments row instead.</p>
ClassMethod Record(pTurnKey As %String, pName As %String, pInput As %DynamicObject, pSecretNames As %List = "", pDeclaredPairs As %List = "", pArgumentPairs As %List = "", pLimits As %String = {..#LIMITS}, pUser As %String = {..#PROBEUSER}, pClassified As %Boolean = 1) As %Status
{
    Quit $ClassMethod(..#LEDGER, "RecordToolCall", pTurnKey, pUser, "permissions/users", pName, "target-" _ pName, pInput, pDeclaredPairs, pArgumentPairs, pSecretNames, "ok", "", pLimits, pClassified)
}

/// <p>AC4 -- past the per-turn row cap a call is counted, not stored: exactly
/// <code>LEDGERMAXROWS</code> rows are stored, one <code>overflow</code> row carries the count of
/// the rest, and the view reports it as <code>rowsDropped</code> without ever listing it as a call.
/// An argument string longer than <code>LEDGERROWMAXLENGTH</code> is cut to the bound, ends U+2026
/// and sets <code>argumentsTruncated</code>.</p>
/// <p>Mutation (Rule 19): drop the <var>pStored</var> cap check from
/// <method>OcuPilot.Kernel.State.Ledger.GuardedAppend</method> so it always saves -- four rows are
/// stored, no overflow row exists, and this goes red.</p>
Method TestTheRowCapStoresNoMoreAndCountsTheRest()
{
    Set tKey = ..NewTurnKey()
    Set tCap = +$Parameter(..#NARROW, "LEDGERMAXROWS")
    Do $$$AssertEquals(tCap, 2, "the narrowed cap is two rows")
    Set tLong = {}
    Do tLong.%Set("Name", "abcdefghijklmnopqrstuvwxyz0123456789", "string")
    For tI = 1:1:(tCap + 2) {
        Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", tLong, "", "", "", ..#NARROW), "call " _ tI _ " is recorded")
    }

    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCountForTurn", tKey, .tRows), "the turn's rows are counted")
    Do $$$AssertEquals(tRows, tCap + 1, "exactly the cap plus the one overflow row is stored")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals(tView.rowsSent, tCap, "the view lists the stored calls and not the overflow row")
    Do $$$AssertEquals(tView.rowsDropped, 2, "and reports the two that were counted instead")

    ; Newest first (the matrix's "the caller's own rows, newest first, bounded"): which rows
    ; survive the cap is decided by this order, so an inverted read would hand a busy user their
    ; oldest activity and call it truncated.
    Do $$$AssertTrue(tView.rows.%Get(0).seq > tView.rows.%Get(1).seq, "the view answers newest first: seq " _ tView.rows.%Get(0).seq _ " then " _ tView.rows.%Get(1).seq)

    Set tRow = tView.rows.%Get(0)
    Set tMax = +$Parameter(..#NARROW, "LEDGERROWMAXLENGTH")
    Do $$$AssertEquals($Length(tRow.arguments), tMax, "the argument string is cut to the bound: " _ tRow.arguments)
    Do $$$AssertEquals($Extract(tRow.arguments, tMax), $Char(8230), "ending in the truncation mark")
    Do $$$AssertEquals(tRow.argumentsTruncated, 1, "and says it was cut")
}

/// <p>AC9 (DW-448) -- the windowed read runs through
/// <method>OcuPilot.Kernel.State.Base.GuardedIdsBounded</method> with every value bound: the window
/// cutoff, the row cap and each predicate. A user name carrying SQL matches literally and returns no
/// row, and the fragment the read is built from holds no value at all.</p>
/// <p>Mutation (Rule 19): in
/// <method>OcuPilot.Kernel.State.Ledger.GuardedIdsForWindow</method>, concatenate the user into the
/// fragment instead of binding it -- the injected name returns every row and this goes red.</p>
Method TestTheBoundedHelperBindsTheWindowAndThePredicates()
{
    Set tKey = ..NewTurnKey()
    For tI = 1:1:2 {
        Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}), "row " _ tI _ " is recorded")
    }

    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedIdsForWindow", ..#PROBEUSER, 0, "", 10, .tMine, .tProblem), "the user's own windowed read runs")
    Do $$$AssertEquals(+$Get(tMine), 2, "and finds both rows")

    Set tInjected = ..#PROBEUSER _ "' OR 1=1 --"
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedIdsForWindow", tInjected, 0, "", 10, .tInjectedIds, .tProblem), "a user name carrying SQL is read the same way")
    Do $$$AssertEquals(+$Get(tInjectedIds), 0, "and matches literally, returning no row")

    ; The row cap is bound too: asking for one of two rows answers one.
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedIdsForWindow", ..#PROBEUSER, 0, "", 1, .tOne, .tProblem), "a capped read runs")
    Do $$$AssertEquals(+$Get(tOne), 1, "and is cut to the cap")

    ; And the fragment itself carries no value -- the cutoff is pushed onto the parameter array.
    Set tParams = []
    Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", 0, "LoggedAt", .tParams, .tProblem, "Seq > 0", "%EXACT(UserName) = ?")
    Do $$$AssertEquals(tFragment, "LoggedAt > ? AND (Seq > 0) AND (%EXACT(UserName) = ?)", "the fragment is placeholders only")
    Do $$$AssertEquals(tFragment [ "'", 0, "with no quoted value in it")
    Do $$$AssertEquals(tParams.%Size(), 1, "and the cutoff alone bound, at index 1")

    ; A refused window runs nothing rather than reading unbounded.
    Do $$$AssertStatusNotOK($ClassMethod(..#STORE, "GuardedIdsForWindow", ..#PROBEUSER, 99999, "", 10, .tNone, .tRefused), "a window outside the bound refuses the read")
    Do $$$AssertTrue(tRefused [ "720", "naming the bound: " _ tRefused)
}

/// <p>AC7 -- a terminal turn swept past retention takes its steps with it and leaves its ledger rows
/// behind. A ledger row is an audit record and outlives its turn (AD-37).</p>
/// <p>Mutation (Rule 19): add a <class>OcuPilot.Kernel.State.Ledger</class> arm to
/// <method>OcuPilot.Kernel.State.Turn.GuardedDelete</method>'s cascade -- the rows vanish with the
/// turn and this goes red.</p>
Method TestASweepRemovesTheTurnAndLeavesItsLedgerRows()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "model", "provider", "ok", "", "", "", ..#LIMITS, .tSeq, .tStored), "the turn has a step")
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}), "and a ledger row")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS), "the turn ends")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).Age(tKey, "EndedAt", +$Parameter(..#LIMITS, "RETENTIONSECONDS") + 60), "and is aged past retention")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedSweep(..#LIMITS), "the sweep runs")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State"), "", "the turn is gone")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).StepCount(tKey), 0, "its steps are gone")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCountForTurn", tKey, .tRows), "and its ledger rows are counted")
    Do $$$AssertEquals(tRows, 1, "which still read")
}

/// <p>AC6's store half -- a self read is ungated and a cross-user read is gated per row, so the
/// evaluation happens over the row's own recorded requirement rather than over the reader's
/// standing. The wire half, with a real least-privileged administrator, is
/// <class>OcuPilot.Test.LedgerWire</class>'s.</p>
/// <p>Both legs run through <class>OcuPilot.Test.LedgerGateProbe</class>, which holds nothing but
/// the administrative pair. The real gate cannot drive either: <code>%UnitTest</code> runs as a
/// <code>%All</code> account, for which <method>OcuPilot.Screen.Gate.HoldsPrivilege</method>
/// answers yes to every resource name, including one the instance does not define -- so a self read
/// through it reads the same whether it is gated or not.</p>
/// <p>Mutation (Rule 19): drop the <code>tCrossUser</code> condition from
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s per-row gate -- the self read starts
/// gating its owner's own rows against a resource the probe gate does not hold, and the first
/// assertion goes red.</p>
Method TestASelfReadIsUngatedAndACrossUserReadIsGatedPerRow()
{
    Set tKey = ..NewTurnKey()
    Set tPairs = $ListBuild($ListBuild("OcuPilotProbeNoSuchResource", "USE"))
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", tPairs, ""), "a row recording an unheld resource is written")

    ; Through the probe gate, which holds nothing but the administrative pair: %UnitTest runs as a
    ; %All account, for which the real check answers yes to every resource name, so a self read
    ; driven through it could not tell an ungated read from a gated one.
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tSelf, .tSelfFault), "the owner's own read runs")
    Do $$$AssertEquals($IsObject(tSelfFault), 0, "with no fault")
    Do $$$AssertEquals(tSelf.rowsSent _ "|" _ tSelf.rowsWithheld, "1|0", "and answers the row ungated (AD-46)")

    ; The same rows read as somebody else, through a gate that holds nothing: every row is withheld
    ; and counted, and none is answered with fields removed.
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tCross, .tCrossFault), "a cross-user read runs")
    Do $$$AssertEquals($IsObject(tCrossFault), 0, "with no fault, the administrative pair being held")
    Do $$$AssertEquals(tCross.rowsSent _ "|" _ tCross.rowsWithheld, "0|1", "and the row the reader cannot hold is absent and counted")
    Do $$$AssertEquals(tCross.rows.%ToJSON(), "[]", "with nothing of it on the wire at all")

    Do ##class(OcuPilot.Test.LedgerGate).Grant("OcuPilotProbeNoSuchResource", "USE")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tGranted, .tGrantedFault), "the same read runs once the reader holds the resource")
    Do $$$AssertEquals(tGranted.rowsSent _ "|" _ tGranted.rowsWithheld, "1|0", "and the row appears")

    ; A requirement that will not parse is withheld rather than read as no requirement at all.
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "StringToPairs", "notapair"), "", "a malformed requirement yields no pair")

    ; And a reader holding no administrative pair at all is refused before any row is considered,
    ; with the written sentence the envelope carries. It names the request: this is a read the
    ; caller made directly and no tool call is involved (DW-1127).
    Do ##class(OcuPilot.Test.LedgerGate).DenyAdmin()
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tDenied, .tDeniedFault), "the same read runs for a reader holding nothing")
    Do $$$AssertTrue($IsObject(tDeniedFault), "and answers a fault")
    If '$IsObject(tDeniedFault) Quit
    Do $$$AssertEquals(tDeniedFault.error _ "|" _ tDeniedFault.code, ##class(OcuPilot.Api.Error).#FORBIDDEN _ "|" _ ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "on the forbidden slug with the no-privilege code")
    Do $$$AssertEquals(tDeniedFault.reason, ##class(OcuPilot.Api.Error).#REASONAUTHNOPRIVILEGE, "carrying the written sentence: " _ tDeniedFault.reason)
    Do $$$AssertTrue(tDeniedFault.reason '[ "tool call", "which names the request, not a tool call: " _ tDeniedFault.reason)
    Do $$$AssertEquals(tDeniedFault.detail.failedPair, $ClassMethod(..#LEDGER, "AdminPair"), "and the pair that failed is unchanged")
    Do $$$AssertEquals($IsObject(tDenied), 0, "with no view at all")
}

/// <p>Matrix row "Tool refused before dispatch" -- a call the reply budget cannot answer is refused
/// without dispatch and still writes one <code>tool</code> row, carrying the refusal code and no
/// pairs at all: nothing read them, and a row claiming a requirement no check evaluated would be a
/// claim about a check that did not happen.</p>
/// <p>It also pins <property>OcuPilot.Kernel.State.Turn.ContextRoute</property>, whose only writer
/// is the <method>GuardedBegin</method> call this method makes and whose only reader today is this
/// assertion: the turn row says which screen it ran from after its progress has been swept.</p>
/// <p>The tool it refuses is the fixture that declares <code>Value</code> secret, reached through
/// <class>OcuPilot.Test.LedgerDispatchProbe</class>: no shipped tool declares one, so a refusal
/// row's layer-1 redaction would otherwise have nothing to redact.</p>
/// <p>Mutation (Rule 19): delete the <method>RecordRefusedRow</method> call at
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method>'s reply-budget branch -- no row is
/// written and this goes red. For the route: delete the
/// <property>ContextRoute</property> assignment in
/// <method>OcuPilot.Kernel.State.Turn.GuardedBegin</method> -- the added assertion goes red. For the declaration: pass <code>""</code> in place of <var>pTool</var> at
/// that same call -- the declared value reaches the row and the absence assertions go red.</p>
Method TestARefusalBeforeDispatchRecordsARowWithNoPairs()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "ContextRoute"), "permissions/users", "the turn row records the screen it was begun from")

    Set tUses = []
    Set tBlock = {"id": "toolu_budget"}
    Do tBlock.%Set("name", "probe_ledger_read", "string")
    Set tBudgetInput = {"Name": "probe"}
    Do tBudgetInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tBlock.%Set("input", tBudgetInput)
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerLoopProbe", "AnswerTools", tKey, tUser, "1", "", tUses, ..#BUDGET, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users"), "the call is answered")
    Do $$$AssertEquals(tState, "", "the turn is not stopped by the refusal")
    Do $$$AssertEquals(tLog.%Size(), 1, "and the refusal is logged once")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row was written: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.kind, "tool", "a tool row")
        Do $$$AssertEquals(tRow.name, "probe.ledger.read", "naming the tool it would have run")
        Do $$$AssertEquals(tRow.status, "error", "refused")
        Do $$$AssertEquals(tRow.code, ##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE, "with the refusal's own code")
        Do $$$AssertEquals(tRow.requiredPairs, "", "and no pairs, because nothing read them")
        Do $$$AssertEquals(tRow.route, "permissions/users", "recorded against the screen the turn ran from")
        ; A pair check that did not happen says nothing about which arguments are secret: the
        ; refusal resolved the tool, so its declaration is read and layer 1 runs (AD-3).
        Do $$$AssertEquals(tRow.arguments [ ..#SECRETVALUE, 0, "and the tool's declared secret nowhere in the row's arguments: " _ tRow.arguments)
        Do $$$AssertTrue(tRow.arguments [ "[redacted]", "which read as redacted instead")
    }
    Do $$$AssertEquals(..RowText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the stored row")
    Do $$$AssertEquals(..StepText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the tool step written beside it: " _ ..StepText(tKey))
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p>The unpinned sibling of <method>TestARefusalBeforeDispatchRecordsARowWithNoPairs</method>: a
/// stop caught at the per-call boundary itself -- distinct from the reply-budget refusal, and reached
/// through <class>OcuPilot.Test.LedgerLoopStopProbe</class>, whose <method>Boundary</method> always
/// answers stop -- still writes one <code>tool</code> row, carrying <code>TURN.STOPPED</code> and no
/// pairs, with the tool's declared secret redacted the same way.</p>
/// <p>Mutation (Rule 19): delete the <method>RecordRefusedRow</method> call at
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method>'s boundary-stop branch -- no row is
/// written and this goes red.</p>
Method TestABoundaryStopBeforeDispatchRecordsARowWithNoPairs()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tUses = []
    Set tBlock = {"id": "toolu_stop"}
    Do tBlock.%Set("name", "probe_ledger_read", "string")
    Set tStopInput = {"Name": "probe"}
    Do tStopInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tBlock.%Set("input", tStopInput)
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerLoopStopProbe", "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users"), "the call is answered")
    Do $$$AssertEquals(tState, ##class(OcuPilot.Kernel.State.Turn).#STATESTOPPED, "the boundary stops the turn")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#TURNSTOPPED, "with its own code")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row was written: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.kind, "tool", "a tool row")
        Do $$$AssertEquals(tRow.name, "probe.ledger.read", "naming the tool it would have run")
        Do $$$AssertEquals(tRow.status, "stopped", "the boundary's own status")
        Do $$$AssertEquals(tRow.code, ##class(OcuPilot.Api.Error).#TURNSTOPPED, "with the stop's own code")
        Do $$$AssertEquals(tRow.requiredPairs, "", "and no pairs, because nothing read them")
        Do $$$AssertEquals(tRow.route, "permissions/users", "recorded against the screen the turn ran from")
        Do $$$AssertEquals(tRow.arguments [ ..#SECRETVALUE, 0, "and the tool's declared secret nowhere in the row's arguments: " _ tRow.arguments)
        Do $$$AssertTrue(tRow.arguments [ "[redacted]", "which reads as redacted instead")
    }
    Do $$$AssertEquals(..RowText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the stored row")
    Do $$$AssertEquals(..StepText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the stopped step written beside it: " _ ..StepText(tKey))
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p>Matrix row "Subject user deleted" -- a row outlives the account it names. The probe user is
/// not an account this instance holds at all, so the read is the deleted-user case by construction:
/// the row still reads and its <code>user</code> is rendered as recorded, never resolved.</p>
/// <p>It also pins the caller's own name being matched case-insensitively for the self/cross-user
/// split (AC6's "a caller always sees their own rows") while the column stays <code>%EXACT</code>
/// (AD-37).</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.Ledger.GuardedRow</method> answer
/// <code>""</code> for <code>user</code> -- the name is no longer rendered as recorded and this goes
/// red. For the casing: remove the <code>$ZConvert</code> self-match from
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- the differently-cased read becomes a
/// cross-user read and answers no row.</p>
Method TestARowOutlivesTheAccountItNames()
{
    Do $$$AssertEquals(..UserExists(..#PROBEUSER), 0, ..#PROBEUSER _ " is not an account this instance holds")
    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}), "a row naming it is written")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the read runs")
    Do $$$AssertEquals($IsObject(tFault), 0, "and never fails over an unresolvable name")
    Do $$$AssertEquals(tView.rowsSent, 1, "answering the row")
    If tView.rowsSent = 1 Do $$$AssertEquals(tView.rows.%Get(0).user, ..#PROBEUSER, "with the name exactly as the row recorded it")

    ; An account name is case-insensitive on this instance, so a caller naming their own account in
    ; another case is still reading their own rows -- not refused for asking about somebody else.
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, $ZConvert(..#PROBEUSER, "L"), 0, tKey, 10, .tCased, .tCasedFault), "the same caller asking in another case is read")
    Do $$$AssertEquals($IsObject(tCasedFault), 0, "with no privilege refusal")
    Do $$$AssertEquals($Select($IsObject(tCased): tCased.rowsSent, 1: -1), 1, "and still answers their own row")
}

/// <p>Matrix row "Store unreadable" -- a guarded read that answers an error status becomes one
/// <code>LEDGER.UNAVAILABLE</code> fault on the <code>unavailable</code> slug, which is the 503 the
/// route renders, and the raw status text reaches the log alone (AD-39).</p>
/// <p>Mutation (Rule 19): return the store's raw status text as the fault's <code>reason</code> in
/// <method>OcuPilot.Kernel.Audit.Ledger.Unavailable</method> -- the probe's marker reaches the
/// envelope and this goes red.</p>
Method TestAnUnreadableStoreIsOneUnavailableEnvelope()
{
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerFaultProbe", "ViewForUser", ..#PROBEUSER, "", 0, "", 10, .tView, .tFault), "the read answers rather than raising")
    Do $$$AssertEquals($IsObject(tView), 0, "with no view at all")
    Do $$$AssertTrue($IsObject(tFault), "and one fault")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.error, ##class(OcuPilot.Api.Error).#UNAVAILABLE, "on the slug the route renders 503 from")
    Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE, "carrying the machine code")
    Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.Error).#REASONLEDGERUNAVAILABLE, "and its written sentence")
    Do $$$AssertEquals(tFault.%ToJSON() [ "ledgerprobestorefault", 0, "with none of the store's own text on the wire: " _ tFault.%ToJSON())
}

/// <p>Whether <var>pUser</var> is an account this instance holds, read in <code>%SYS</code> and the
/// namespace restored on both paths (AD-16).</p>
ClassMethod UserExists(pUser As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Users).Exists(pUser)
    } Catch ex {
        Set tExists = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>The <b>view</b>-level truncation flag (AD-24, AD-41): asked for three of four rows, the view
/// answers <code>truncated</code> true and <code>rowsSent</code> exactly the cap, and asked for more
/// rows than there are it answers false. Distinct from the row-level
/// <code>argumentsTruncated</code> and from the per-turn cap's <code>rowsDropped</code> -- this flag
/// says the <i>read</i> was cut, which is the only thing telling a caller there is more to ask
/// for.</p>
/// <p>Mutation (Rule 19): force <var>tTruncated</var> to 0 in
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- this goes red on the flag.</p>
Method TestTheViewReportsItsOwnTruncationAtTheRowCap()
{
    Set tCap = +$Parameter(..#NARROW, "LEDGERVIEWMAXROWS")
    Do $$$AssertEquals(tCap, 3, "the narrowed view cap is three rows")
    Set tKey = ..NewTurnKey()
    ; Recorded under the shipped bounds: the narrowed class's own LEDGERMAXROWS is 2, and the
    ; per-turn cap is a different bound from the one under test.
    For tI = 1:1:(tCap + 1) {
        Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}), "row " _ tI _ " is recorded")
    }

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, tCap, .tView, .tFault), "the view reads at the cap")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.truncated, 1, "and says the read was cut: " _ tView.%ToJSON())
    Do $$$AssertEquals(tView.rowsSent, tCap, "sending exactly the cap")
    Do $$$AssertEquals(tView.rows.%Size(), tCap, "and listing as many rows as it counted")
    Do $$$AssertEquals(tView.rowsDropped, 0, "with nothing dropped by the per-turn cap")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, tCap + 1, .tWhole, .tWholeFault), "the same read above the row count runs")
    Do $$$AssertEquals(tWhole.truncated, 0, "and is not truncated")
    Do $$$AssertEquals(tWhole.rowsSent, tCap + 1, "answering every row")
}

/// <p>A <code>requiredPairs</code> that will not parse is withheld from a cross-user read and
/// counted, never released as a call that required nothing (AD-46). Reached by writing the column
/// directly, because <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> cannot produce such
/// a string -- which is the point: the row is a row an older writer, a migration or a hand edit
/// could leave, and the gate must fail closed on it.</p>
/// <p>Mutation (Rule 19): remove the <code>Continue</code> from
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s unparseable-requirement branch -- the
/// row is rendered instead of withheld and this goes red.</p>
Method TestAnUnparseableRequirementIsWithheldFromACrossUserRead()
{
    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", $ListBuild($ListBuild("OcuPilotProbeNoSuchResource", "USE")), ""), "a row is written")
    Do $$$AssertEquals(..SetRequiredPairs(tKey, "notapair"), 1, "and its requirement is rewritten to a string that will not parse")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "StringToPairs", "notapair"), "", "which yields no pair at all")

    ; The reader holds the administrative pair and every resource the probe gate knows of, so a
    ; withhold here is the parse failure and not a privilege it lacks.
    Do ##class(OcuPilot.Test.LedgerGate).Grant("OcuPilotProbeNoSuchResource", "USE")
    Do ##class(OcuPilot.Test.LedgerGate).Grant("notapair", "USE")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tCross, .tCrossFault), "the cross-user read runs")
    Do $$$AssertEquals($IsObject(tCrossFault), 0, "with no fault, the administrative pair being held")
    Do $$$AssertEquals(tCross.rowsSent _ "|" _ tCross.rowsWithheld, "0|1", "and the row is absent and counted")
    Do $$$AssertEquals(tCross.rows.%ToJSON(), "[]", "with nothing of it on the wire")

    ; The owner still sees it, ungated, with the unparseable string rendered as recorded.
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tSelf, .tSelfFault), "the owner's own read runs")
    Do $$$AssertEquals(tSelf.rowsSent, 1, "and keeps the row (AD-46)")
    If tSelf.rowsSent = 1 Do $$$AssertEquals(tSelf.rows.%Get(0).requiredPairs, "notapair", "as the row recorded it")
}

/// <p>Write <var>pText</var> into turn <var>pTurnKey</var>'s rows' <code>RequiredPairs</code> column
/// by direct SQL -- the only way to store a string
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> refuses to produce. Answers how many
/// rows it changed, so a caller reddens on a write that did nothing rather than on the read
/// after it.</p>
ClassMethod SetRequiredPairs(pTurnKey As %String, pText As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Ledger SET RequiredPairs = ? WHERE %EXACT(TurnKey) = ?", pText, pTurnKey)
    If tRS.%SQLCODE < 0 Quit -1
    Quit +tRS.%ROWCOUNT
}

/// <p>Matrix row "Store unreadable", over the route: driven in process through
/// <class>OcuPilot.Test.LedgerRouteProbe</class> with <class>%CSP.Request</class> /
/// <class>%CSP.Response</class> stubs, the handler answers <b>HTTP 503</b> in one envelope carrying
/// the landed <code>LEDGER.UNAVAILABLE</code> code and none of the store's own text.</p>
/// <p>In process rather than over the wire: <method>OcuPilot.Api.Router</method>'s
/// <code>UrlMap</code> names <class>OcuPilot.Api.Ledger</class> by class, so a fixture subclass has
/// no route to arrive on -- the precedent <class>OcuPilot.Test.Dispatch</class> exists for.</p>
/// <p>Mutation (Rule 19): map the <code>LEDGER.UNAVAILABLE</code> leg of
/// <method>OcuPilot.Api.Ledger.RenderFault</method> to 500 -- the status assertion goes red while
/// the code and slug assertions stay green.</p>
Method TestAnUnreadableStoreRendersA503OverTheRoute()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Dispatch).InvokeHandler("OcuPilot.Test.LedgerRouteProbe", "Handle", , .tBody, .tStatus), "the handler answers rather than raising")
    Do $$$AssertEquals(tStatus, 503, "on the unavailable status: " _ tBody)
    Do $$$AssertEquals(tBody [ "}{", 0, "in exactly one envelope: " _ tBody)
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tAnswer = ""
    }
    Do $$$AssertTrue($IsObject(tAnswer), "which parses as one JSON object: " _ tBody)
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.error, ##class(OcuPilot.Api.Error).#UNAVAILABLE, "carrying the slug")
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE, "and the machine code")
    Do $$$AssertEquals(tAnswer.reason, ##class(OcuPilot.Api.Error).#REASONLEDGERUNAVAILABLE, "and its written sentence")
    Do $$$AssertEquals(tBody [ "ledgerprobestorefault", 0, "with none of the store's own text on the wire")
}

}
