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

/// <p><code>running</code>, <code>ok</code>, <code>error</code> or <code>stopped</code>.</p>
Property Status As %String(MAXLEN = 16);

Property Summary As %String(MAXLEN = "");

Property Text As %String(MAXLEN = "");

/// <p>The machine code a failed step carries, or <code>""</code>.</p>
Property Code As %String(MAXLEN = 64);

Property Truncated As %Boolean [ InitialExpression = 0 ];

/// <p>A tool step's target (Story 4.5): the input's <code>id</code>, else <code>entity</code>,
/// else <code>route</code>, else <code>""</code>. Empty for a model step.</p>
/// <p><b>Added with no <code>SCHEMAVERSION</code> move.</b> This and the four properties below are
/// safe-default additions: a row stored before they existed reads each back as <code>""</code>,
/// the same value a row with nothing to report holds.</p>
Property Target As %String(MAXLEN = "");

/// <p>A tool step's arguments (Story 4.5, AD-11, AD-39): compact JSON of the call's input, any key
/// matching <method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method> replaced with the same
/// redaction mark that class uses, cut at the summary cap. Empty for a model step.</p>
Property Arguments As %String(MAXLEN = "");

/// <p>A successful, rows-shaped tool step's result (Story 4.5, AD-24): JSON
/// <code>{rowsReturned, rowsSent, truncated}</code> from
/// <method>OcuPilot.Kernel.Agent.Bound.Apply</method>'s own <code>rowsAvailable</code>,
/// <code>rowsSent</code> and <code>truncated</code>. Empty for a model step, a failed step, or a
/// tool step whose result carries no rows.</p>
Property Result As %String(MAXLEN = "");

/// <p>A failed step's published sentence for <property>Code</property> (Story 4.5, AD-39) --
/// never vendor text, and never carried to the model, only to this record for the panel's card.
/// Empty for a step that did not fail.</p>
Property Reason As %String(MAXLEN = "");

/// <p>A failed tool step's <code>detail.failedPair</code> (Story 4.5, AD-8), spelled
/// <code>resource:permission</code>, when the failure carries one. Empty otherwise.</p>
Property FailedPair As %String(MAXLEN = 128);

Index TurnSeqIdx On (TurnKey, Seq) [ Unique ];

/// <p>Append a step to turn <var>pKey</var>. <var>pSeq</var> is its position whether or not it was
/// stored; <var>pStored</var> is 0 when the turn already holds the step cap, in which case the
/// turn's dropped count is raised instead.</p>
/// <p><var>pTarget</var>, <var>pArguments</var>, <var>pResult</var>, <var>pReason</var> and
/// <var>pFailedPair</var> are the tool-step fields (Story 4.5), trailing and optional so a model
/// step's append -- which carries none of them -- calls this unchanged. <var>pArguments</var> is
/// stored verbatim: the caller has already capped it at the summary cap
/// (<method>OcuPilot.Kernel.Agent.Dispatch.RedactedArguments</method>), so this does not re-cap it
/// a second time. <var>pArgumentsTruncated</var> is the caller's own answer to whether that cap cut
/// it, and sets <property>Truncated</property> when true, the same as a cut name or summary does.</p>
ClassMethod GuardedAppend(pKey As %String, pKind As %String, pName As %String, pStatus As %String, pSummary As %String, pText As %String, pCode As %String, pLimitsClass As %String, Output pSeq As %Integer, Output pStored As %Boolean, pTarget As %String = "", pArguments As %String = "", pResult As %String = "", pReason As %String = "", pFailedPair As %String = "", pArgumentsTruncated As %Boolean = 0) As %Status
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
        Set tRow.Target = ##class(OcuPilot.Kernel.State.Turn).Cap(pTarget, +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH"), .tTargetCut)
        Set tRow.Arguments = pArguments
        Set tRow.Result = pResult
        Set tRow.Reason = pReason
        Set tRow.FailedPair = pFailedPair
        Do ..ApplyContent(tRow, pName, pSummary, pText, pLimitsClass)
        If pArgumentsTruncated || $Get(tTargetCut) Set tRow.Truncated = 1
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

/// <p>Write <var>pText</var>, a streamed model call's whole text so far, onto step <var>pSeq</var>
/// of turn <var>pKey</var>, cut at the text cap (AD-33). Written only while that step is a
/// <code>model</code> step and still <code>running</code>, so a snapshot arriving after the
/// outcome write changes nothing; the outcome write replaces the snapshot. A step dropped past the
/// cap has no row, and nothing is written.</p>
/// <p><b>Caller contract:</b> a leaf storage call, made from a provider's chunk callback while its
/// socket is the current device; it does no device I/O and its escalated frame unwinds before it
/// returns (AD-9).</p>
ClassMethod GuardedSnapshotText(pKey As %String, pSeq As %Integer, pText As %String, pLimitsClass As %String) As %Status
{
    Set tSC = ..GuardedOpenOneWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ? AND Seq = ?", pKey, pSeq, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    If (tRow.Kind '= "model") || (tRow.Status '= "running") {
        Set tRow = ""
        Quit $$$OK
    }
    Do ..ApplyContent(tRow, tRow.Name, tRow.Summary, pText, pLimitsClass)
    Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
    Set tRow = ""
    Quit tSC
}

/// <p>Set tool step <var>pSeq</var> of turn <var>pKey</var>, appended <code>running</code> before
/// its call was dispatched, to its outcome: <var>pStatus</var>, <var>pCode</var>, the canonical
/// <var>pName</var> dispatch resolved, and the tool-step fields as
/// <method>GuardedAppend</method> takes them. A step that was dropped past the cap has no row, and
/// nothing is written.</p>
/// <p><var>pText</var> is the bounded result content the model was handed for this call, stored on
/// <property>Text</property> and cut at the text cap like any other step text. It is untrusted
/// content (AD-11, AD-33) and trailing, so a caller with nothing to record calls this unchanged and
/// the step reads <code>""</code> as it did before.</p>
ClassMethod GuardedFinishTool(pKey As %String, pSeq As %Integer, pName As %String, pStatus As %String, pCode As %String, pLimitsClass As %String, pTarget As %String = "", pArguments As %String = "", pResult As %String = "", pReason As %String = "", pFailedPair As %String = "", pArgumentsTruncated As %Boolean = 0, pText As %String = "") As %Status
{
    Set tSC = ..GuardedOpenOneWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ? AND Seq = ?", pKey, pSeq, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit tSC
    Set tRow.Status = pStatus
    Set tRow.Code = pCode
    Set tRow.Target = ##class(OcuPilot.Kernel.State.Turn).Cap(pTarget, +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH"), .tTargetCut)
    Set tRow.Arguments = pArguments
    Set tRow.Result = pResult
    Set tRow.Reason = pReason
    Set tRow.FailedPair = pFailedPair
    Do ..ApplyContent(tRow, pName, "", pText, pLimitsClass)
    If pArgumentsTruncated || $Get(tTargetCut) Set tRow.Truncated = 1
    Set tSC = ..GuardedSaveIfCurrent(tRow, +tRow.RowVersion)
    Set tRow = ""
    Quit tSC
}

/// <p>Every stored step of turn <var>pKey</var>, in sequence order, as
/// <code>{seq, kind, name, status, summary, text, code, truncated, target, arguments, result,
/// reason, failedPair}</code> (Story 4.5). <code>result</code> is the parsed <code>{rowsReturned,
/// rowsSent, truncated}</code> object when the step recorded one, else JSON null; every other new
/// field is the empty string when the step carries none.</p>
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
        Do tOut.%Set("target", ..Text(tRow.Target), "string")
        Do tOut.%Set("arguments", ..Text(tRow.Arguments), "string")
        Set tResultText = ..Text(tRow.Result)
        Set tResultObj = ""
        If tResultText '= "" {
            Try {
                Set tResultObj = ##class(%DynamicAbstractObject).%FromJSON(tResultText)
            } Catch {
                Set tResultObj = ""
            }
        }
        If $IsObject(tResultObj) {
            Do tOut.%Set("result", tResultObj)
        } Else {
            Do tOut.%Set("result", "", "null")
        }
        Do tOut.%Set("reason", ..Text(tRow.Reason), "string")
        Do tOut.%Set("failedPair", ..Text(tRow.FailedPair), "string")
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
