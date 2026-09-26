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

/// <p>The kind a confirmed write's own row carries (Story 5.6, AD-41). One per confirmed write,
/// on the proposal's turn key, opened <parameter>STATUSPENDING</parameter> before the port call
/// and finalized after it.</p>
Parameter KINDWRITE = "write";

/// <p>The <property>Status</property> a row carries between its open and its finalize. <b>The one
/// status a reader must not read as an outcome</b>: a row still holding it records a write that
/// was issued and never accounted for, which is the trace a row written only on success could not
/// leave (AD-41).</p>
Parameter STATUSPENDING = "pending";

/// <p><property>PairsSense</property>: the writer resolved the call's pairs and checked them
/// against the caller (<class>OcuPilot.Kernel.Agent.Dispatch</class>, the confirm).</p>
Parameter SENSECHECKED = "checked";

/// <p><property>PairsSense</property>: the writer recorded the tool's <b>declared</b> pairs, for a
/// call refused before anything was checked
/// (<method>OcuPilot.Kernel.Agent.Loop.RecordRefusedRow</method>).</p>
Parameter SENSEDECLARED = "declared";

/// <p><property>PairsSense</property>: the writer recorded what the turn's screen route requires
/// (<method>OcuPilot.Kernel.Audit.Ledger.RecordProviderCall</method>).</p>
Parameter SENSEROUTE = "route";

/// <p><property>PairsSense</property>: the writer resolved its pairs and there were none. The one
/// sense on which an <b>empty</b> <property>RequiredPairs</property> is readable cross-user
/// (DW-1305): the row states a requirement, and the requirement is nothing.</p>
Parameter SENSENONE = "none";

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

/// <p>On a <parameter>KINDWRITE</parameter> row, the <b>names</b> of the fields the write actually
/// sent, comma-joined -- never a value (AD-41). <b>Secret-declared names are excluded by the
/// writer at write time</b> (AD-3), so nothing here is redacted afterwards. <code>""</code> on
/// every other kind.</p>
Property Fields As %String(MAXLEN = 512);

/// <p>Whether <property>Fields</property> holds fewer names than the write sent, because the cut
/// at <parameter>FIELDSMAXLENGTH</parameter> fell on a whole-name boundary short of the set.</p>
Property FieldsTruncated As %Boolean [ InitialExpression = 0 ];

/// <p>The declared length of <property>Fields</property>, read by
/// <method>OcuPilot.Kernel.Audit.Ledger.FieldsToString</method> so the bound it cuts at is not a
/// second literal.</p>
Parameter FIELDSMAXLENGTH As %Integer = 512;

/// <p>What claim <property>RequiredPairs</property> makes on this row:
/// <parameter>SENSECHECKED</parameter>, <parameter>SENSEDECLARED</parameter>,
/// <parameter>SENSEROUTE</parameter> or <parameter>SENSENONE</parameter>, and <code>""</code> on a
/// row stored before this column existed.</p>
/// <p><b>One column carried three incompatible meanings</b> (DW-1305, DW-1321), and an empty set
/// could not be told from a requirement the writer could not read -- so every empty set was
/// withheld from every cross-user reader, including the honestly-empty ones every turn from Home
/// produces. This column records which claim the row makes:
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> releases an empty set on
/// <parameter>SENSENONE</parameter> alone and withholds it under every other sense.</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move</b> (Consistency Conventions: when
/// SCHEMAVERSION moves): a row stored before this column existed reads back <code>""</code>, and
/// <code>""</code> is withheld cross-user -- which is exactly what that row already got. No
/// pre-existing row is reinterpreted, and the new answer is available only to rows a writer that
/// knows the sense wrote.</p>
Property PairsSense As %String(MAXLEN = 16);

/// <p>On a <parameter>KINDWRITE</parameter> row, what became of the write's audit marker
/// (AD-15): <code>""</code> while the row is <parameter>STATUSPENDING</parameter>,
/// <code>marked</code> when the emission landed a row, <code>not-marked</code> when the instance
/// dropped it, and <code>not-marking</code> when no marker was emitted at all because the write
/// did not happen -- the row that makes no claim about marking. <code>""</code> on every other
/// kind.</p>
Property AuditMarked As %String(MAXLEN = 16);

/// <p><property>AuditMarked</property>: the emission landed a row.</p>
Parameter MARKEDYES = "marked";

/// <p><property>AuditMarked</property>: the emission was made and the instance dropped it.</p>
Parameter MARKEDNO = "not-marked";

/// <p><property>AuditMarked</property>: no marker was emitted, because the write did not
/// happen.</p>
Parameter MARKEDNONE = "not-marking";

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
/// <p><b>A set holding fewer pairs than the call required says so</b> (AD-24, AD-41) -- an
/// over-long set cut at a whole-pair boundary, or a pair the grammar cannot spell left out by
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method>:
/// <property>RequiredPairsTruncated</property> reads 1, and a cross-user read withholds such a row
/// rather than gating on a set that is missing pairs (AD-46).</p>
Property RequiredPairs As %String(MAXLEN = 512);

/// <p>Whether <property>RequiredPairs</property> holds fewer pairs than the call required.</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move</b> (Consistency Conventions): a row stored
/// before this property existed holds nothing in its slot and so reads back <code>""</code>, which
/// <method>GuardedRow</method> and <method>OcuPilot.Kernel.Audit.Ledger.RowObject</method>
/// normalize with <code>''</code> to the 0 an uncut set holds. No older row is reinterpreted.</p>
Property RequiredPairsTruncated As %Boolean [ InitialExpression = 0 ];

/// <p>The declared length of <property>RequiredPairs</property>, read by
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> so the bound it cuts at is not a
/// second literal. <class>OcuPilot.Test.Ledger</class> asserts it equals the column's
/// <code>MAXLEN</code>, which a property keyword cannot itself read.</p>
Parameter PAIRSMAXLENGTH As %Integer = 512;

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
/// A string still longer than <code>LEDGERROWMAXLENGTH</code> is cut here, and the row's
/// <property>ArgumentsTruncated</property> is then 1 whatever <var>pArgumentsTruncated</var> says.
/// <var>pRequiredPairs</var> is the canonical joined string
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> answers, already cut at a whole-pair
/// boundary, and <var>pRequiredPairsTruncated</var> is that method's own truncation answer -- it is
/// trailing and defaults to 0 so the provider-call caller, which declares no pairs, is unchanged.
/// <var>pPairsSense</var> is what claim that set makes (<property>PairsSense</property>), trailing
/// and defaulting to <code>""</code> for the same reason. <var>pLedgerKey</var> comes back as the
/// new row's own key, or <code>""</code> when the cap counted the call instead of storing it --
/// which is what <method>GuardedFinalize</method> needs and what makes a finalize on an
/// overflowed call a no-op rather than a write to somebody else's row.</p>
ClassMethod GuardedAppend(pTurnKey As %String, pUser As %String, pRoute As %String, pKind As %String, pName As %String, pModel As %String, pTarget As %String, pArguments As %String, pArgumentsTruncated As %Boolean, pStatus As %String, pCode As %String, pRequestTokens As %Integer, pResponseTokens As %Integer, pRequiredPairs As %String, pLimitsClass As %String, Output pSeq As %Integer, Output pStored As %Boolean, pRequiredPairsTruncated As %Boolean = 0, pPairsSense As %String = "", Output pLedgerKey As %String) As %Status
{
    Set pSeq = 0
    Set pStored = 0
    Set pLedgerKey = ""
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
        Set tRow.Route = ..Cut(pRoute, ..#ROUTEMAXLENGTH)
        Set tRow.Target = ..Cut(pTarget, 256)
        Set tRow.Arguments = ..Cut(pArguments, +$Parameter(pLimitsClass, "LEDGERROWMAXLENGTH"))
        Set tRow.ArgumentsTruncated = ''pArgumentsTruncated || ($Length(pArguments) > +$Parameter(pLimitsClass, "LEDGERROWMAXLENGTH"))
        Set tRow.Status = ..Cut(pStatus, 16)
        Set tRow.Code = ..Cut(pCode, 64)
        Set tRow.RequestTokens = +pRequestTokens
        Set tRow.ResponseTokens = +pResponseTokens
        Set tRow.RequiredPairs = pRequiredPairs
        Set tRow.RequiredPairsTruncated = ''pRequiredPairsTruncated
        Set tRow.PairsSense = ..Cut(pPairsSense, 16)
        Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
        If $$$ISERR(tSC) Quit
        Set pSeq = tRow.Seq
        Set pLedgerKey = tRow.LedgerKey
        Set tRow = ""
        Set pStored = 1
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Finalize the row <var>pLedgerKey</var> names with what was actually executed (AD-41): the
/// outcome, the machine code, the resolved target, the field names the write sent, the pairs it
/// evaluated and the marker's own outcome.</p>
/// <p><b>Caller contract:</b> <var>pLedgerKey</var> is <method>GuardedAppend</method>'s own answer.
/// <code>""</code> -- the key an overflowed call answers -- is not an error and writes nothing.
/// <var>pFields</var> and <var>pRequiredPairs</var> are already the canonical joined strings
/// <class>OcuPilot.Kernel.Audit.Ledger</class> builds, already cut at a whole-member boundary, and
/// their truncation flags are that class's own answers; nothing here redacts or cuts anything.</p>
/// <p>The save is conditional on the version just read (Consistency Conventions: concurrent writes
/// to OcuPilot's own state). A row that has gone is not an error: a ledger row is not the write,
/// and the write has already happened.</p>
ClassMethod GuardedFinalize(pLedgerKey As %String, pStatus As %String, pCode As %String, pTarget As %String, pFields As %String, pFieldsTruncated As %Boolean, pRequiredPairs As %String, pRequiredPairsTruncated As %Boolean, pPairsSense As %String, pAuditMarked As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If pLedgerKey = "" Quit
        Set tSC = ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(LedgerKey) = ?", pLedgerKey, .tRow)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tRow) Quit
        Set tExpected = +tRow.RowVersion
        Set tRow.Status = ..Cut(pStatus, 16)
        Set tRow.Code = ..Cut(pCode, 64)
        Set tRow.Target = ..Cut(pTarget, 256)
        Set tRow.Fields = pFields
        Set tRow.FieldsTruncated = ''pFieldsTruncated
        Set tRow.RequiredPairs = pRequiredPairs
        Set tRow.RequiredPairsTruncated = ''pRequiredPairsTruncated
        Set tRow.PairsSense = ..Cut(pPairsSense, 16)
        Set tRow.AuditMarked = ..Cut(pAuditMarked, 16)
        Set tSC = ..GuardedSaveIfCurrent(tRow, tExpected)
        Set tRow = ""
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
        Set tRow.Route = ..Cut(pRoute, ..#ROUTEMAXLENGTH)
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
/// <code>responseTokens</code>, <code>requiredPairs</code>, <code>requiredPairsTruncated</code>,
/// <code>pairsSense</code>, <code>fields</code>, <code>fieldsTruncated</code>,
/// <code>auditMarked</code> and <code>dropped</code>.</p>
/// <p>Data, not a projection: this package names nothing outside it (AD-9), so the caller is what
/// turns these into a view and what evaluates <code>requiredPairs</code>.</p>
/// <p><b>A row that is gone answers no values and no error.</b>
/// <method>OcuPilot.Kernel.State.Base.GuardedOpenId</method> reports a missing id as a failure,
/// which is right for a caller that holds an id it must find and wrong for one walking ids it read
/// a moment ago: a row deleted in between would make the whole read unavailable rather than one row
/// absent. So a failure to open is classified against existence first, and only a row that still
/// exists yields an error.</p>
ClassMethod GuardedRow(pId As %String, Output pValues) As %Status
{
    Kill pValues
    Set tSC = ..GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) && $$$ISOK(..GuardedExistsId(pId, .tExists)) && 'tExists Quit $$$OK
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
    Set pValues("requiredPairsTruncated") = ''tRow.RequiredPairsTruncated
    Set pValues("pairsSense") = ..Text(tRow.PairsSense)
    Set pValues("fields") = ..Text(tRow.Fields)
    Set pValues("fieldsTruncated") = ''tRow.FieldsTruncated
    Set pValues("auditMarked") = ..Text(tRow.AuditMarked)
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
/// overruns it is cut here rather than failing the write. <property>RequiredPairs</property> is
/// the one column not cut here, because a cut between two pairs is the only safe one and
/// <method>OcuPilot.Kernel.Audit.Ledger.PairsToString</method> is what knows where those
/// boundaries are.</p>
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
