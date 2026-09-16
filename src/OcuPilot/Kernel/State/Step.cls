/// <p>One progress record of a turn (AD-33): a provider call, a tool call, and what each answered.
/// Keyed by the turn's key and a sequence number, written only by the job running that turn, and
/// deleted with it (<method>OcuPilot.Kernel.State.Turn.GuardedDelete</method>).</p>
/// <p><b>Everything a step carries that came from the model is untrusted content</b> (AD-11): the
/// panel renders it as data. <b>The caps are applied here, on write</b>: at most the step cap per
/// turn, with later steps counted on the turn row; a name or summary cut at the summary cap and a
/// text cut at the text cap, with <property>Truncated</property> set when either was cut.</p>
Class OcuPilot.Kernel.State.Step Extends OcuPilot.Kernel.State.Base
{

/// <p>The turn this step belongs to.</p>
Property TurnKey As %String(MAXLEN = 64);

/// <p>1-based position in the turn, counting steps that were dropped past the cap.</p>
Property Seq As %Integer;

/// <p><code>model</code> or <code>tool</code>.</p>
Property Kind As %String(MAXLEN = 16);

/// <p>What the step names: the provider call, or the tool the model asked for.</p>
Property Name As %String(MAXLEN = "");

/// <p><code>running</code>, <code>ok</code> or <code>error</code>.</p>
Property Status As %String(MAXLEN = 16);

Property Summary As %String(MAXLEN = "");

Property Text As %String(MAXLEN = "");

/// <p>The machine code a failed step carries, or <code>""</code>.</p>
Property Code As %String(MAXLEN = 64);

Property Truncated As %Boolean [ InitialExpression = 0 ];

Index TurnSeqIdx On (TurnKey, Seq) [ Unique ];

/// <p>Append a step to turn <var>pKey</var>. <var>pSeq</var> is its position whether or not it was
/// stored; <var>pStored</var> is 0 when the turn already holds the step cap, in which case the
/// turn's dropped count is raised instead.</p>
ClassMethod GuardedAppend(pKey As %String, pKind As %String, pName As %String, pStatus As %String, pSummary As %String, pText As %String, pCode As %String, pLimitsClass As %String, Output pSeq As %Integer, Output pStored As %Boolean) As %Status
{
    Set pSeq = 0
    Set pStored = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedIdsWhere("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", pKey, .tCount)
        If $$$ISERR(tSC) Quit
        Set tStoredCount = +$Get(tCount(1))
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedDropped(pKey, .tDropped)
        If $$$ISERR(tSC) Quit
        If tStoredCount >= $Parameter(pLimitsClass, "MAXSTEPS") {
            Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedAddDropped(pKey, .tDropped)
            If $$$ISERR(tSC) Quit
            Set pSeq = tStoredCount + tDropped
            Quit
        }
        Set tRow = ..%New()
        Set tRow.TurnKey = pKey
        Set tRow.Seq = tStoredCount + tDropped + 1
        Set tRow.Kind = pKind
        Set tRow.Status = pStatus
        Set tRow.Code = pCode
        Do ..ApplyContent(tRow, pName, pSummary, pText, pLimitsClass)
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

/// <p>Set step <var>pSeq</var> of turn <var>pKey</var> to its outcome. A step that was dropped past
/// the cap has no row, and nothing is written.</p>
ClassMethod GuardedUpdate(pKey As %String, pSeq As %Integer, pStatus As %String, pSummary As %String, pText As %String, pCode As %String, pLimitsClass As %String) As %Status
{
    Set tSC = ..GuardedOpenOneWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ? AND Seq = ?", pKey, pSeq, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set tRow.Status = pStatus
    Set tRow.Code = pCode
    Do ..ApplyContent(tRow, tRow.Name, pSummary, pText, pLimitsClass)
    Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
    Set tRow = ""
    Quit tSC
}

/// <p>Every stored step of turn <var>pKey</var>, in sequence order, as
/// <code>{seq, kind, name, status, summary, text, code, truncated}</code>.</p>
ClassMethod GuardedRows(pKey As %String, Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ? ORDER BY Seq", pKey, .tIds)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) Continue
        Set tOut = {}
        Do tOut.%Set("seq", +tRow.Seq, "number")
        Do tOut.%Set("kind", ..Text(tRow.Kind), "string")
        Do tOut.%Set("name", ..Text(tRow.Name), "string")
        Do tOut.%Set("status", ..Text(tRow.Status), "string")
        Do tOut.%Set("summary", ..Text(tRow.Summary), "string")
        Do tOut.%Set("text", ..Text(tRow.Text), "string")
        Do tOut.%Set("code", ..Text(tRow.Code), "string")
        Do tOut.%Set("truncated", ''tRow.Truncated, "boolean")
        Set tRow = ""
        Do pRows.%Push(tOut)
    }
    Quit $$$OK
}

/// <p>Delete every step of turn <var>pKey</var>.</p>
ClassMethod GuardedDeleteForTurn(pKey As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", pKey)
}

/// <p>Write the three text fields onto <var>pRow</var>, each cut at its cap, and set
/// <property>Truncated</property> when any was cut; a flag set by an earlier write stays set.</p>
ClassMethod ApplyContent(pRow As OcuPilot.Kernel.State.Step, pName As %String, pSummary As %String, pText As %String, pLimitsClass As %String) [ Private ]
{
    Set tCut = ''pRow.Truncated
    Set tSummaryMax = +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH")
    Set pRow.Name = ##class(OcuPilot.Kernel.State.Turn).Cap(pName, tSummaryMax, .tCut)
    Set pRow.Summary = ##class(OcuPilot.Kernel.State.Turn).Cap(pSummary, tSummaryMax, .tCut)
    Set pRow.Text = ##class(OcuPilot.Kernel.State.Turn).Cap(pText, +$Parameter(pLimitsClass, "TEXTMAXLENGTH"), .tCut)
    Set pRow.Truncated = tCut
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
