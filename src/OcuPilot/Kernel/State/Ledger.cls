/// <p>One durable row per provider call and per tool answer of a turn (AD-9, AD-37, AD-41): who
/// asked, when, on which screen, with which redacted arguments, under which resources, and at what
/// token cost. Held in OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods.</p>
/// <p><b>A row outlives its turn and its user.</b> Nothing here is reached from
/// <method>OcuPilot.Kernel.State.Turn.GuardedDelete</method>'s cascade and nothing here is swept by
/// <method>OcuPilot.Kernel.State.Turn.GuardedSweep</method>: the turn, its steps and its signals go
/// at retention and these rows stay, because a ledger row is the audit record of what the agent did
/// (AD-37). Retention over these rows is Story 14.4's, and <method>GuardedDeleteForTurn</method> and
/// <method>GuardedDeleteForUser</method> exist for a test's own cleanup, not for a sweep.</p>
/// <p><b>Bounded per turn</b> (AD-41): <method>GuardedAppend</method> stores at most
/// <code>LEDGERMAXROWS</code> rows for one turn and counts the rest on a single
/// <code>overflow</code> row, which takes <property>Seq</property> 0 so the sequence of stored calls
/// starts at 1.</p>
/// <p><b>The gate is not here.</b> This class answers rows as data, each carrying its own
/// <property>RequiredPairs</property> string; <class>OcuPilot.Kernel.Audit.Ledger</class> evaluates
/// them outside every escalated frame (AD-9's re-entry rule, and
/// <file>scripts/check-objectscript.py</file>'s state-package isolation).</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move</b> (Consistency Conventions): a new table
/// has no pre-existing rows for an older OcuPilot to reinterpret.</p>
Class OcuPilot.Kernel.State.Ledger Extends OcuPilot.Kernel.State.Base
{

/// <p>The kind a provider-call row carries.</p>
Parameter KINDLLM = "llm";

/// <p>The kind a tool-answer row carries.</p>
Parameter KINDTOOL = "tool";

/// <p>The kind the one per-turn overflow row carries.</p>
Parameter KINDOVERFLOW = "overflow";

/// <p>The <property>Seq</property> the overflow row takes, so a stored call's own sequence starts
/// at 1 and the pair <code>(TurnKey, Seq)</code> stays unique.</p>
Parameter OVERFLOWSEQ As %Integer = 0;

/// <p>The opaque, server-minted row id: 32 lower-case hex characters. Unique; matched exactly.</p>
Property LedgerKey As %String(MAXLEN = 64);

/// <p>The user the turn ran as, as <code>$USERNAME</code> read it. A weak reference (AD-37): a
/// <code>%String</code> matched <code>%EXACT</code>, never a foreign key, and a row whose user the
/// instance no longer holds still reads.</p>
Property UserName As %String(MAXLEN = 160);

/// <p>ISO-8601 UTC (Consistency Conventions: Dates).</p>
Property LoggedAt As %String(MAXLEN = 32);

/// <p>The turn the call belonged to. A weak reference too: the turn row is swept at retention and
/// this one is not.</p>
Property TurnKey As %String(MAXLEN = 64);

/// <p>1-based position of the call within its turn; <parameter>OVERFLOWSEQ</parameter> on the
/// overflow row.</p>
Property Seq As %Integer;

/// <p><parameter>KINDLLM</parameter>, <parameter>KINDTOOL</parameter> or
/// <parameter>KINDOVERFLOW</parameter>.</p>
Property Kind As %String(MAXLEN = 16);

/// <p>The canonical tool name on a <parameter>KINDTOOL</parameter> row, the provider key on a
/// <parameter>KINDLLM</parameter> one.</p>
Property Name As %String(MAXLEN = 128);

/// <p>The model a provider call named; <code>""</code> on a tool row.</p>
Property Model As %String(MAXLEN = 128);

/// <p>The screen-context route the turn was started from, or <code>""</code> for a turn that
/// carried no context.</p>
Property Route As %String(MAXLEN = 512);

/// <p>A tool call's target (the input's <code>id</code>, else <code>entity</code>, else
/// <code>route</code>); <code>""</code> on a provider row.</p>
Property Target As %String(MAXLEN = 256);

/// <p>The call's own arguments, redacted by declaration and then by the name-pattern backstop, cut
/// at <code>LEDGERROWMAXLENGTH</code> (AD-3). <b>Never a prompt, a message body or a tool result
/// body</b> -- those are transcripts, and Story 14.4's.</p>
Property Arguments As %String(MAXLEN = 4096);

/// <p>Whether that cut cut anything.</p>
Property ArgumentsTruncated As %Boolean [ InitialExpression = 0 ];

/// <p><code>ok</code>, <code>error</code> or <code>stopped</code>.</p>
Property Status As %String(MAXLEN = 16);

/// <p>The machine code the call answered, or <code>""</code>.</p>
Property Code As %String(MAXLEN = 64);

Property RequestTokens As %Integer [ InitialExpression = 0 ];

Property ResponseTokens As %Integer [ InitialExpression = 0 ];

/// <p>Every <code>(resource, permission)</code> pair the call required, canonically
/// <code>resource:permission</code>, sorted, de-duplicated and comma-joined -- a scalar, the way
/// <property>OcuPilot.Kernel.State.Step.FailedPair</property> is, and not a
/// <code>list Of</code>.</p>
/// <p><b>An over-long set fails the row's write rather than being cut.</b> Cutting would drop a
/// pair, and a row that records fewer pairs than the call required is a row a later cross-user read
/// would release too easily (AD-46). The writer logs the failure and the turn is unaffected
/// (AD-15).</p>
Property RequiredPairs As %String(MAXLEN = 512);

/// <p>On the overflow row, how many calls of this turn were counted and not stored; 0 elsewhere.</p>
Property Dropped As %Integer [ InitialExpression = 0 ];

Index LedgerKeyIdx On LedgerKey [ Unique ];

/// <p>The windowed read's index: a user's rows in time order.
/// <property>UserName</property> is indexed <code>Exact</code> because the read matches it with
/// <code>%EXACT</code> (a weak reference is compared as stored, AD-37), and the default
/// <code>SQLUPPER</code> collation would put the index out of that predicate's reach.</p>
Index LedgerUserTimeIdx On (UserName As Exact, LoggedAt);

Index LedgerTurnSeqIdx On (TurnKey, Seq) [ Unique ];

/// <p>Append one row to turn <var>pTurnKey</var>. <var>pSeq</var> is the call's position whether or
/// not it was stored; <var>pStored</var> is 0 once the turn holds
/// <code>LEDGERMAXROWS</code> rows, in which case the turn's overflow row is raised by one instead
/// -- the "counted, not stored" idiom
/// <method>OcuPilot.Kernel.State.Step.GuardedAppend</method> established.</p>
/// <p><b>Caller contract:</b> <var>pArguments</var> is already redacted and already cut
/// (<method>OcuPilot.Kernel.Audit.Ledger.RedactArguments</method>); nothing here redacts anything.
/// <var>pRequiredPairs</var> is the canonical joined string
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> answers.</p>
ClassMethod GuardedAppend(pTurnKey As %String, pUser As %String, pRoute As %String, pKind As %String, pName As %String, pModel As %String, pTarget As %String, pArguments As %String, pArgumentsTruncated As %Boolean, pStatus As %String, pCode As %String, pRequestTokens As %Integer, pResponseTokens As %Integer, pRequiredPairs As %String, pLimitsClass As %String, Output pSeq As %Integer, Output pStored As %Boolean) As %Status
{
    Set pSeq = 0
    Set pStored = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedIdsWhere("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND Seq > 0", pTurnKey, .tCount)
        If $$$ISERR(tSC) Quit
        Set tStoredCount = +$Get(tCount(1))
        If tStoredCount >= $Parameter(pLimitsClass, "LEDGERMAXROWS") {
            Set tSC = ..GuardedCountOverflow(pTurnKey, pUser, pRoute, .tDropped)
            If $$$ISERR(tSC) Quit
            Set pSeq = tStoredCount + tDropped
            Quit
        }
        Set tRow = ..%New()
        Set tRow.LedgerKey = ..NewKey()
        Set tRow.UserName = ..Cut(pUser, 160)
        Set tRow.LoggedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
        Set tRow.TurnKey = ..Cut(pTurnKey, 64)
        Set tRow.Seq = tStoredCount + 1
        Set tRow.Kind = ..Cut(pKind, 16)
        Set tRow.Name = ..Cut(pName, 128)
        Set tRow.Model = ..Cut(pModel, 128)
        Set tRow.Route = ..Cut(pRoute, 512)
        Set tRow.Target = ..Cut(pTarget, 256)
        Set tRow.Arguments = ..Cut(pArguments, 4096)
        Set tRow.ArgumentsTruncated = ''pArgumentsTruncated
        Set tRow.Status = ..Cut(pStatus, 16)
        Set tRow.Code = ..Cut(pCode, 64)
        Set tRow.RequestTokens = +pRequestTokens
        Set tRow.ResponseTokens = +pResponseTokens
        Set tRow.RequiredPairs = pRequiredPairs
        Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
        If $$$ISERR(tSC) Quit
        Set pSeq = tRow.Seq
        Set tRow = ""
        Set pStored = 1
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Count one call of turn <var>pTurnKey</var> past the row cap: open the turn's own
/// <parameter>KINDOVERFLOW</parameter> row, raise <property>Dropped</property> by one against the
/// version just read, or create it with <property>Dropped</property> 1. <var>pDropped</var> is the
/// new count.</p>
ClassMethod GuardedCountOverflow(pTurnKey As %String, pUser As %String, pRoute As %String, Output pDropped As %Integer) As %Status
{
    Set pDropped = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedOpenOneWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND Seq = ?", pTurnKey, ..#OVERFLOWSEQ, .tRow)
        If $$$ISERR(tSC) Quit
        If $IsObject(tRow) {
            Set tExpected = +tRow.RowVersion
            Set tRow.Dropped = tRow.Dropped + 1
            Set pDropped = tRow.Dropped
            Set tSC = ..GuardedSaveIfCurrent(tRow, tExpected)
            Set tRow = ""
            Quit
        }
        Set tRow = ..%New()
        Set tRow.LedgerKey = ..NewKey()
        Set tRow.UserName = ..Cut(pUser, 160)
        Set tRow.LoggedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
        Set tRow.TurnKey = ..Cut(pTurnKey, 64)
        Set tRow.Seq = ..#OVERFLOWSEQ
        Set tRow.Kind = ..#KINDOVERFLOW
        Set tRow.Route = ..Cut(pRoute, 512)
        Set tRow.Status = "ok"
        Set tRow.Dropped = 1
        Set pDropped = 1
        Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The ids of <var>pUser</var>'s stored call rows, newest first, at most <var>pMaxRows</var> of
/// them (AD-24: the caller asks for its cap plus one and reports the truncation). A non-empty
/// <var>pTurnKey</var> selects that turn's rows and emits no time predicate; otherwise
/// <var>pWindowHours</var> is <method>OcuPilot.Kernel.State.Base.BoundedWhere</method>'s window.
/// The overflow row is never among them -- its count is
/// <method>GuardedDroppedFor</method>'s answer.</p>
/// <p><var>pProblem</var> names the bound when the window or the arguments do not admit a bounded
/// read, in which case the status is an error and nothing ran. <b>Every value is bound</b> (AD-21):
/// the cutoff by <method>BoundedWhere</method>, the row cap and the predicates by
/// <method>OcuPilot.Kernel.State.Base.GuardedIdsBounded</method>, and the fragment holds only
/// <code>?</code>.</p>
ClassMethod GuardedIdsForWindow(pUser As %String, pWindowHours As %String, pTurnKey As %String, pMaxRows As %Integer, Output pIds, Output pProblem As %String) As %Status
{
    Kill pIds
    Set pProblem = ""
    Set tParams = []
    If pTurnKey '= "" {
        Set tFragment = ..BoundedWhere(..#BOUNDEDKEYED, "", .tParams, .pProblem, "Seq > 0", "%EXACT(UserName) = ?", "%EXACT(TurnKey) = ?")
    } Else {
        Set tFragment = ..BoundedWhere(pWindowHours, "LoggedAt", .tParams, .pProblem, "Seq > 0", "%EXACT(UserName) = ?")
    }
    If tFragment = "" Quit $$$ERROR($$$GeneralError, "the ledger read is not bounded: " _ pProblem)
    Do tParams.%Push(pUser, "string")
    If pTurnKey '= "" Do tParams.%Push(pTurnKey, "string")
    Quit ..GuardedIdsBounded("SELECT TOP ? ID FROM OcuPilot_Kernel_State.Ledger", tFragment, "ORDER BY LoggedAt DESC, Seq DESC", pMaxRows, .tParams, .pIds)
}

/// <p>How many of <var>pUser</var>'s calls were counted and not stored over the same selection
/// <method>GuardedIdsForWindow</method> makes, summed across that user's overflow rows.</p>
ClassMethod GuardedDroppedFor(pUser As %String, pWindowHours As %String, pTurnKey As %String, Output pCount As %Integer) As %Status
{
    Set pCount = 0
    Set tParams = []
    If pTurnKey '= "" {
        Set tFragment = ..BoundedWhere(..#BOUNDEDKEYED, "", .tParams, .tProblem, "Seq = 0", "%EXACT(UserName) = ?", "%EXACT(TurnKey) = ?")
    } Else {
        Set tFragment = ..BoundedWhere(pWindowHours, "LoggedAt", .tParams, .tProblem, "Seq = 0", "%EXACT(UserName) = ?")
    }
    If tFragment = "" Quit $$$ERROR($$$GeneralError, "the ledger dropped count is not bounded: " _ tProblem)
    Do tParams.%Push(pUser, "string")
    If pTurnKey '= "" Do tParams.%Push(pTurnKey, "string")
    Set tSC = ..GuardedIdsBounded("SELECT TOP ? COALESCE(SUM(Dropped), 0) FROM OcuPilot_Kernel_State.Ledger", tFragment, "", 1, .tParams, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set pCount = +$Get(tRows(1))
    Quit $$$OK
}

/// <p>Row <var>pId</var>'s columns as data, subscripted by wire name -- <code>ledgerId</code>,
/// <code>user</code>, <code>loggedAt</code>, <code>turnKey</code>, <code>seq</code>,
/// <code>kind</code>, <code>name</code>, <code>model</code>, <code>route</code>,
/// <code>target</code>, <code>arguments</code>, <code>argumentsTruncated</code>,
/// <code>status</code>, <code>code</code>, <code>requestTokens</code>,
/// <code>responseTokens</code>, <code>requiredPairs</code> and <code>dropped</code>.</p>
/// <p>Data, not a projection: this package names nothing outside it (AD-9), so the caller is what
/// turns these into a view and what evaluates <code>requiredPairs</code>.</p>
ClassMethod GuardedRow(pId As %String, Output pValues) As %Status
{
    Kill pValues
    Set tSC = ..GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set pValues("ledgerId") = ..Text(tRow.LedgerKey)
    Set pValues("user") = ..Text(tRow.UserName)
    Set pValues("loggedAt") = ..Text(tRow.LoggedAt)
    Set pValues("turnKey") = ..Text(tRow.TurnKey)
    Set pValues("seq") = +tRow.Seq
    Set pValues("kind") = ..Text(tRow.Kind)
    Set pValues("name") = ..Text(tRow.Name)
    Set pValues("model") = ..Text(tRow.Model)
    Set pValues("route") = ..Text(tRow.Route)
    Set pValues("target") = ..Text(tRow.Target)
    Set pValues("arguments") = ..Text(tRow.Arguments)
    Set pValues("argumentsTruncated") = ''tRow.ArgumentsTruncated
    Set pValues("status") = ..Text(tRow.Status)
    Set pValues("code") = ..Text(tRow.Code)
    Set pValues("requestTokens") = +tRow.RequestTokens
    Set pValues("responseTokens") = +tRow.ResponseTokens
    Set pValues("requiredPairs") = ..Text(tRow.RequiredPairs)
    Set pValues("dropped") = +tRow.Dropped
    Set tRow = ""
    Quit $$$OK
}

/// <p>Delete every row of turn <var>pTurnKey</var>. <b>Not part of any cascade or sweep</b> -- a
/// ledger row outlives its turn (AD-37); this exists so a test removes what it wrote.</p>
ClassMethod GuardedDeleteForTurn(pTurnKey As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", pTurnKey)
}

/// <p>Delete every row of <var>pUser</var>, matched exactly. Same caveat as
/// <method>GuardedDeleteForTurn</method>: a test's cleanup, never a lifecycle rule.</p>
ClassMethod GuardedDeleteForUser(pUser As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = ?", pUser)
}

/// <p>How many rows turn <var>pTurnKey</var> holds, the overflow row included.</p>
ClassMethod GuardedCountForTurn(pTurnKey As %String, Output pCount As %Integer) As %Status
{
    Set pCount = 0
    Set tSC = ..GuardedIdsWhere("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", pTurnKey, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set pCount = +$Get(tRows(1))
    Quit $$$OK
}

/// <p>A fresh opaque row id: 32 lower-case hex characters, the idiom
/// <method>OcuPilot.Kernel.State.Turn.NewKey</method> established.</p>
ClassMethod NewKey() As %String [ Private ]
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p><var>pValue</var> cut to <var>pMax</var> characters, never between the halves of a surrogate
/// pair. A column's declared length is a storage bound, not a caller contract: a value that
/// overruns it is cut here rather than failing the write, except
/// <property>RequiredPairs</property>, whose header says why.</p>
ClassMethod Cut(pValue As %String, pMax As %Integer) As %String [ Private ]
{
    Quit ##class(OcuPilot.Kernel.State.Turn).Cap(pValue, pMax, .tCut)
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
