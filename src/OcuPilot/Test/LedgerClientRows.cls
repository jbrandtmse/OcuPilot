/// <p>The three ledger rows a client-fulfilled call writes after it has been announced (Story 4.9,
/// AD-11 rule 3, AD-41): the announcement counted past the step cap, a turn stopped during the wait,
/// and the settle. Each is a writer in
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method> that nothing asserted, and the two
/// <code>ok</code> ones carry the same code -- so each method also pins how many steps its turn
/// actually stored, which is what tells a dropped announcement from a lapsed one.</p>
/// <p><b>Every call here runs as the process's own account</b>, because
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> refuses a call whose user is
/// not the process's (AD-31) -- so these rows name <code>$USERNAME</code> and are swept by turn key
/// rather than by a probe user name.</p>
/// <p>Driven through <class>OcuPilot.Test.LedgerClientLoopProbe</class> and
/// <class>OcuPilot.Test.LedgerClientStopProbe</class> over
/// <class>OcuPilot.Test.LedgerClientTool.Registry</class>. <b>Live-safe.</b> It spawns nothing,
/// reserves no turn, creates no principal and touches no registration; every row, step and directive
/// it writes carries a turn key starting with <parameter>KEYPREFIX</parameter>, and
/// <method>OnAfterOneTest</method> asserts none survives.</p>
Class OcuPilot.Test.LedgerClientRows Extends %UnitTest.TestCase
{

/// <p>The ledger's public face.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

/// <p>The shipped bounds, and the two narrowed ones each branch needs.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter STEPCAP = "OcuPilot.Test.LedgerStepCapLimits";

Parameter NAVWAIT = "OcuPilot.Test.LedgerNavWaitLimits";

/// <p>The prefix every turn key here carries, which is what the teardown sweeps on.</p>
Parameter KEYPREFIX = "ocupilotprobeclientrow";

/// <p>The client-fulfilled fixture tool's wire name, and the canonical name its rows carry.</p>
Parameter WIRE = "probe_ledger_clientread";

Parameter TOOLNAME = "probe.ledger.clientread";

/// <p>The stop probe, whose boundary count has to be forgotten between methods.</p>
Parameter PROBE = "OcuPilot.Test.LedgerClientStopProbe";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    ; Counted first, then swept: a method that raised before its own Forget would otherwise leave
    ; rows in the live stores and redden every later method's teardown rather than its own.
    Set tLeft = ..Remaining()
    Do ..ForgetPrefix()
    Do $$$AssertEquals(tLeft, 0, "no probe row, step or directive survives the method")
    Quit $$$OK
}

/// <p>A fresh probe turn key.</p>
ClassMethod NewTurnKey() As %String
{
    Quit ..#KEYPREFIX _ $Translate($System.Util.CreateGUID(), "-", "")
}

/// <p>Remove everything turn <var>pKey</var> left behind, in the three stores a client-fulfilled
/// call writes.</p>
ClassMethod Forget(pKey As %String)
{
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(pKey)
    Do ##class(OcuPilot.Kernel.State.Step).GuardedDeleteForTurn(pKey)
    Do ##class(OcuPilot.Kernel.State.Nav).GuardedDeleteForTurn(pKey)
}

/// <p>Remove everything any turn of this class left in the three stores, by
/// <parameter>KEYPREFIX</parameter> rather than by one key -- the teardown's sweep, which has to
/// reach a key a raised method never named.</p>
ClassMethod ForgetPrefix()
{
    Do ..DeleteWhere("DELETE FROM OcuPilot_Kernel_State.Ledger WHERE TurnKey %STARTSWITH ?")
    Do ..DeleteWhere("DELETE FROM OcuPilot_Kernel_State.Step WHERE TurnKey %STARTSWITH ?")
    Do ..DeleteWhere("DELETE FROM OcuPilot_Kernel_State.Nav WHERE TurnKey %STARTSWITH ?")
}

ClassMethod DeleteWhere(pSql As %String) [ Private ]
{
    Do ##class(%SQL.Statement).%ExecDirect(, pSql, ..#KEYPREFIX)
}

/// <p>How many rows the three stores still hold under <parameter>KEYPREFIX</parameter>, by direct
/// SQL rather than through the stores the tests are checking.</p>
ClassMethod Remaining() As %Integer
{
    ; Summed only once every part answered: CountWhere reports a failed read as -1, and a sum
    ; would let one store's failure cancel another store's leftover row and read as clean.
    Set tTotal = 0
    For tSql = "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE TurnKey %STARTSWITH ?", "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE TurnKey %STARTSWITH ?", "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Nav WHERE TurnKey %STARTSWITH ?" {
        Set tOne = ..CountWhere(tSql)
        If tOne < 0 Quit
        Set tTotal = tTotal + tOne
    }
    If $Get(tOne, 0) < 0 Quit -1
    Quit tTotal
}

ClassMethod CountWhere(pSql As %String) As %Integer [ Private ]
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, ..#KEYPREFIX)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>How many progress steps turn <var>pKey</var> stored.</p>
ClassMethod StepCount(pKey As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>Answer one <parameter>WIRE</parameter> call of turn <var>pKey</var> through <var>pLoop</var>
/// under <var>pLimits</var>, and hand back the turn state and code it settled on.</p>
ClassMethod AnswerOneCall(pLoop As %String, pKey As %String, pLimits As %String, Output pState As %String, Output pCode As %String) As %Status
{
    Set tBlock = {"id": "toolu_clientrow"}
    Do tBlock.%Set("name", ..#WIRE, "string")
    Do tBlock.%Set("input", {"Name": "probe"})
    Set tUses = []
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Quit $ClassMethod(pLoop, "AnswerTools", pKey, $Username, "1", "", tUses, pLimits, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .pState, .pCode, 0, "permissions/users")
}

/// <p>The one row turn <var>pKey</var> wrote, as
/// <code>&lt;kind&gt;|&lt;name&gt;|&lt;status&gt;|&lt;code&gt;</code>, or a sentence naming what went
/// wrong instead -- so a failure reads as itself rather than as a mismatched status.</p>
ClassMethod OneRow(pKey As %String) As %String
{
    Set tSC = $ClassMethod(..#LEDGER, "ViewForUser", $Username, "", 0, pKey, 10, .tView, .tFault)
    If $$$ISERR(tSC) Quit "the view did not read: " _ $System.Status.GetErrorText(tSC)
    If $IsObject(tFault) Quit "the view answered a fault: " _ tFault.%ToJSON()
    If '$IsObject(tView) Quit "the view answered nothing"
    If tView.rowsSent '= 1 Quit "the call wrote " _ tView.rowsSent _ " rows: " _ tView.%ToJSON()
    Set tRow = tView.rows.%Get(0)
    Quit tRow.kind _ "|" _ tRow.name _ "|" _ tRow.status _ "|" _ tRow.code
}

/// <p>An announcement the step cap counted rather than stored lapses the call as an ordinary tool
/// result and records one <code>ok</code> row carrying <code>NAV.UNAVAILABLE</code>; the turn is
/// unharmed. Told from the settle below by the step count: the announce step was never stored, so
/// the turn holds only the tool step its caller appended.</p>
/// <p>Mutation (Rule 19): remove the <method>RecordClientRow</method> call from
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method>'s drop branch -- this goes red and
/// the other two methods stay green.</p>
Method TestAnAnnouncementPastTheStepCapRecordsOneOkRow()
{
    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK(..AnswerOneCall("OcuPilot.Test.LedgerClientLoopProbe", tKey, ..#STEPCAP, .tState, .tCode), "the call is answered")
    Do $$$AssertEquals(tState _ "|" _ tCode, "|", "the turn is unharmed by the drop")
    Do $$$AssertEquals(..StepCount(tKey), 1, "and the announcement was counted rather than stored")
    Do $$$AssertEquals(..OneRow(tKey), "tool|" _ ..#TOOLNAME _ "|ok|" _ ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE, "one ok row carrying the unavailable code")
    Do ..Forget(tKey)
}

/// <p>A turn stopped <b>during the wait</b> -- after the announcement exists -- records one
/// <code>stopped</code> row carrying the boundary's own code, and the turn reports the stop.</p>
/// <p>The boundary is asked twice: once per call before dispatch, and again on the wait's first
/// pass. <class>OcuPilot.Test.LedgerLoopStopProbe</class> stops on the first question, so it refuses
/// the call before it is announced and never reaches this writer at all.</p>
/// <p>Mutation (Rule 19): remove the <method>RecordClientRow</method> call from that method's
/// in-wait boundary branch -- this goes red and the other two methods stay green.</p>
Method TestAStopDuringTheWaitRecordsOneStoppedRow()
{
    Set tKey = ..NewTurnKey()
    Do $ClassMethod(..#PROBE, "Reset")
    Do $$$AssertStatusOK(..AnswerOneCall(..#PROBE, tKey, ..#LIMITS, .tState, .tCode), "the call is answered")
    Do $$$AssertEquals(tState, ##class(OcuPilot.Kernel.State.Turn).#STATESTOPPED, "the boundary stops the turn")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#TURNSTOPPED, "with its own code")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Asked") >= 2, "and was asked inside the wait, not only before the call: " _ $ClassMethod(..#PROBE, "Asked"))
    Do $$$AssertEquals(..StepCount(tKey), 3, "the announcement was stored before the stop, and the stop appended its own step")
    Do $$$AssertEquals(..OneRow(tKey), "tool|" _ ..#TOOLNAME _ "|stopped|" _ ##class(OcuPilot.Api.Error).#TURNSTOPPED, "one stopped row carrying the stop's code")
    Do ..Forget(tKey)
}

/// <p>A call that settles -- here by lapsing, which no browser answering is the only outcome a test
/// without a browser can reach -- records one <code>ok</code> row carrying the announce outcome's
/// code. The lapse is an ordinary tool result, not an error (AD-11 rule 3).</p>
/// <p>Mutation (Rule 19): remove the <method>RecordClientRow</method> call from that method's settle
/// -- this goes red and the other two methods stay green.</p>
Method TestACallThatSettlesRecordsOneOkRow()
{
    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK(..AnswerOneCall("OcuPilot.Test.LedgerClientLoopProbe", tKey, ..#NAVWAIT, .tState, .tCode), "the call is answered")
    Do $$$AssertEquals(tState _ "|" _ tCode, "|", "the turn is unharmed by the lapse")
    Do $$$AssertEquals(..StepCount(tKey), 2, "the announcement was stored, which is what makes this the settle and not the drop")
    Do $$$AssertEquals(..OneRow(tKey), "tool|" _ ..#TOOLNAME _ "|ok|" _ ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE, "one ok row carrying the lapse's code")
    Do ..Forget(tKey)
}

}
