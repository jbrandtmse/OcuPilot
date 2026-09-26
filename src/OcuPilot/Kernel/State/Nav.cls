/// <p>The one pending client-fulfilled navigation directive per turn (Story 4.7, AD-9, AD-11 rule
/// 3): the route and entity id the browser is being asked to open, and -- once the browser or the
/// wait itself has answered -- the outcome. Held in OcuPilot's protected database and reached only
/// through <class>OcuPilot.Kernel.State.Base</class>'s guarded methods.</p>
/// <p><b>One row per turn.</b> <index>NavTurnKeyIdx</index> is unique: a turn's second
/// navigation call reuses the row, overwriting the first's outcome, because the first has already
/// been waited out and settled (or lapsed) before the loop ever asks for a second one -- there is
/// never more than one directive outstanding for a turn at a time.</p>
/// <p><b>The read-back guarantee (AD-11 rule 3).</b> <method>GuardedRequest</method> refuses a
/// <var>pSeq</var> that names no committed <code>announce</code> step for that turn, which is what
/// makes it impossible for a reader to observe a directive the transcript does not also carry.
/// <method>GuardedSettle</method> claims through <method>OcuPilot.Kernel.State.Base.GuardedSaveIfCurrent</method>,
/// so exactly one caller wins a race between the browser's own answer and the turn job settling the
/// wait as lapsed; the loser's claim is simply not recorded (<var>pClaimed</var> 0), never an
/// exception. <method>GuardedPending</method> opens a fresh row on every call and holds no OREF
/// across the turn job's wait (<file>.claude/rules/objectscript-basics.md</file>'s <code>%OpenId</code>
/// stale-read trap).</p>
Class OcuPilot.Kernel.State.Nav Extends OcuPilot.Kernel.State.Base
{

/// <p>The turn this directive belongs to.</p>
Property TurnKey As %String(MAXLEN = 64);

/// <p>The announce step's own <property>OcuPilot.Kernel.State.Step.Seq</property> -- the read-back
/// key <method>GuardedRequest</method> and <method>GuardedSettle</method> both key on.</p>
Property Seq As %Integer;

Property Route As %String(MAXLEN = "");

/// <p><code>""</code> for a screen opened with no row selected.</p>
Property EntityId As %String(MAXLEN = "");

/// <p>The name of a flag criterion the target screen declares, applied on arrival (Story 5.8,
/// AD-21), or <code>""</code>. Never a value: the value the read sends is the descriptor's own.</p>
/// <p><b>No <code>SCHEMAVERSION</code> move</b> (Consistency Conventions): every pre-existing row
/// reads it as <code>""</code>, which is exactly "this directive named no filter".</p>
Property Criterion As %String(MAXLEN = 64);

/// <p>The criteria values the arriving screen's read runs with (Story 11.11, AD-11), as the JSON of
/// an object keyed by that screen's declared criteria, or <code>""</code> for none. Validated
/// against the target's read before the directive was requested.</p>
/// <p><b>No <code>SCHEMAVERSION</code> move</b> (Consistency Conventions): every pre-existing row
/// reads it as <code>""</code>, which is exactly "this directive carried no criteria".</p>
Property Criteria As %String(MAXLEN = 16000);

Property RequestedAt As %String(MAXLEN = 32);

/// <p><code>""</code> while unsettled; <code>opened</code>, <code>refused</code> or
/// <code>unavailable</code> once the browser or the turn job's own lapse has answered.</p>
Property Outcome As %String(MAXLEN = 16);

/// <p>The machine code accompanying a non-<code>opened</code> outcome; <code>""</code> for
/// <code>opened</code> and while unsettled.</p>
Property Code As %String(MAXLEN = 64);

Property SettledAt As %String(MAXLEN = 32);

Index NavTurnKeyIdx On TurnKey [ Unique ];

/// <p>Request a directive for turn <var>pKey</var>: open <var>pRoute</var>, optionally selecting
/// <var>pEntityId</var>, optionally applying the declared flag criterion <var>pCriterion</var> and
/// the criteria object <var>pCriteria</var>. Refuses when <var>pSeq</var> names no committed <code>announce</code> step
/// of this turn (AD-11 rule 3) -- the ordering guarantee that makes a directive impossible to
/// observe before its announcement is in the transcript. A turn's second navigation reuses the row
/// (see the class header); its outcome, code and settled time are cleared.</p>
ClassMethod GuardedRequest(pKey As %String, pSeq As %Integer, pRoute As %String, pEntityId As %String, pCriterion As %String = "", pCriteria As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ? AND Seq = ? AND %EXACT(Kind) = 'announce'", pKey, pSeq, .tIds)
        If $$$ISERR(tSC) Quit
        If $Get(tIds(1)) = "" {
            Set tSC = $$$ERROR($$$GeneralError, "turn " _ pKey _ ": Seq " _ pSeq _ " names no committed announce step, so no directive can be requested for it")
            Quit
        }
        Set tSC = ..OpenByKey(pKey, .tRow)
        If $$$ISERR(tSC) Quit
        Set tExpected = 0
        If $IsObject(tRow) {
            Set tExpected = +tRow.RowVersion
        } Else {
            Set tRow = ..%New()
            Set tRow.TurnKey = pKey
        }
        Set tRow.Seq = pSeq
        Set tRow.Route = pRoute
        Set tRow.EntityId = pEntityId
        Set tRow.Criterion = pCriterion
        Set tRow.Criteria = $Select($IsObject(pCriteria) && pCriteria.%Size(): pCriteria.%ToJSON(), 1: "")
        Set tRow.RequestedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
        Set tRow.Outcome = ""
        Set tRow.Code = ""
        Set tRow.SettledAt = ""
        Set tSC = ..GuardedSaveIfCurrent(tRow, tExpected)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The unsettled directive for turn <var>pKey</var>, read fresh with no OREF held across a wait:
/// <var>pSeq</var>, <var>pRoute</var>, <var>pEntityId</var>, <var>pCriterion</var> and
/// <var>pCriteria</var> (the criteria JSON) are <code>0</code>/<code>""</code> when the turn holds
/// no directive at all. <var>pSettled</var> is 1 once <var>pOutcome</var> and
/// <var>pCode</var> carry an answer.</p>
ClassMethod GuardedPending(pKey As %String, Output pSeq As %Integer, Output pRoute As %String, Output pEntityId As %String, Output pSettled As %Boolean, Output pOutcome As %String, Output pCode As %String, Output pCriterion As %String, Output pCriteria As %String) As %Status
{
    Set pSeq = 0
    Set pRoute = ""
    Set pEntityId = ""
    Set pCriterion = ""
    Set pCriteria = ""
    Set pSettled = 0
    Set pOutcome = ""
    Set pCode = ""
    Set tSC = ..OpenByKey(pKey, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tRow) {
        Set pSeq = +tRow.Seq
        Set pRoute = ..Text(tRow.Route)
        Set pEntityId = ..Text(tRow.EntityId)
        Set pCriterion = ..Text(tRow.Criterion)
        Set pCriteria = ..Text(tRow.Criteria)
        Set pOutcome = ..Text(tRow.Outcome)
        Set pCode = ..Text(tRow.Code)
        Set pSettled = (pOutcome '= "")
    }
    Set tRow = ""
    Quit $$$OK
}

/// <p>Claim the directive for turn <var>pKey</var> at <var>pSeq</var> with <var>pOutcome</var> and
/// <var>pCode</var>. <var>pClaimed</var> is 1 only when a matching, still-unsettled row existed and
/// this call won it (<method>OcuPilot.Kernel.State.Base.GuardedSaveIfCurrent</method>'s own
/// exactly-one-winner contract) -- a second settle for the same directive, a settle naming the
/// wrong <var>pSeq</var>, or one arriving after the turn job's own lapse has already claimed it,
/// answers <var>pClaimed</var> 0 and writes nothing. Never an error for any of those: the caller
/// (<class>OcuPilot.Api.Turn</class>) is what turns an unclaimed settle into 409.</p>
ClassMethod GuardedSettle(pKey As %String, pSeq As %Integer, pOutcome As %String, pCode As %String, Output pClaimed As %Boolean) As %Status
{
    Set pClaimed = 0
    Set tSC = ..OpenByKey(pKey, .tRow)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit $$$OK
    If (+tRow.Seq '= +pSeq) || (..Text(tRow.Outcome) '= "") {
        Set tRow = ""
        Quit $$$OK
    }
    Set tRow.Outcome = pOutcome
    Set tRow.Code = pCode
    Set tRow.SettledAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
    Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
    Set tRow = ""
    If $$$ISERR(tSC) {
        ; A racing writer won first (GuardedSaveIfCurrent's own stale-save refusal): the loser is
        ; told by pClaimed, never by an error.
        If ..IsStaleSave(tSC) Set tSC = $$$OK
        Quit tSC
    }
    Set pClaimed = 1
    Quit $$$OK
}

/// <p>Delete turn <var>pKey</var>'s directive, if it has one. Called from
/// <method>OcuPilot.Kernel.State.Turn.GuardedDelete</method> alongside the turn's steps.</p>
ClassMethod GuardedDeleteForTurn(pKey As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Nav WHERE %EXACT(TurnKey) = ?", pKey)
}

/// <p>The row for <var>pKey</var>, matched exactly, or <code>$$$NULLOREF</code>.</p>
ClassMethod OpenByKey(pKey As %String, Output pRow) As %Status [ Private ]
{
    Quit ..GuardedOpenOneWhere("SELECT ID FROM OcuPilot_Kernel_State.Nav WHERE %EXACT(TurnKey) = ?", pKey, .pRow)
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
