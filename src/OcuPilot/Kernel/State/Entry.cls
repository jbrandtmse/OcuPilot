/// <p>One turn's entry in a conversation (Story 4.5, AD-11, AD-33): the message that started it,
/// how it ended, and the final step projection a reload restores. Keyed by its conversation's
/// <property>ConvoKey</property> and a sequence number -- the same shape
/// <class>OcuPilot.Kernel.State.Step</class> already uses for a turn's own steps, not an object
/// <code>Relationship</code>. Appended once, by <class>OcuPilot.Kernel.Agent.Job</class>, after the
/// turn that produced it has finished; never updated afterward.</p>
/// <p><b>Everything here that came from the model is untrusted content</b> (AD-11): a client
/// renders it as data.</p>
Class OcuPilot.Kernel.State.Entry Extends OcuPilot.Kernel.State.Base
{

/// <p>The conversation this entry belongs to (<property>OcuPilot.Kernel.State.Convo.ConvKey</property>).</p>
Property ConvoKey As %String(MAXLEN = 64);

/// <p>1-based position within the conversation.</p>
Property Seq As %Integer;

/// <p>The user message that started the turn.</p>
Property Message As %String(MAXLEN = "");

/// <p>The turn's terminal state (<property>OcuPilot.Kernel.State.Turn.State</property>'s
/// vocabulary).</p>
Property State As %String(MAXLEN = 16);

/// <p>The reply a completed turn produced, or <code>""</code> for a turn that did not complete
/// with one.</p>
Property Reply As %String(MAXLEN = "");

/// <p>The terminal code a turn that did not complete ended with, or <code>""</code>.</p>
Property ErrorCode As %String(MAXLEN = 64);

/// <p>The sequence number, within the turn's own steps, that <property>ErrorCode</property>
/// applies to; 0 when no step was written.</p>
Property ErrorSeq As %Integer [ InitialExpression = 0 ];

/// <p>Stored as embedded JSON text deliberately: a verbatim snapshot of the turn's own step
/// projection (<method>OcuPilot.Kernel.State.Step.GuardedRows</method>'s array shape), captured
/// once when the entry is appended, for a client reload to restore -- never queried by member,
/// never joined, and read back whole by <method>GuardedRows</method>. A <code>%Stream</code>
/// rather than a bounded <code>%String</code> because a turn's full step array, capped at
/// <code>MAXSTEPS</code> rows of up to <code>TEXTMAXLENGTH</code> characters each, can exceed any
/// fixed <code>%String</code> length.</p>
Property StepsJson As %Stream.GlobalCharacter;

/// <p>Steps counted past the cap and not carried into <property>StepsJson</property>, copied from
/// the turn's own <property>OcuPilot.Kernel.State.Turn.StepsDropped</property> at append time.</p>
Property StepsDropped As %Integer [ InitialExpression = 0 ];

Index ConvoSeqIdx On (ConvoKey, Seq) [ Unique ];

/// <p>Append one entry to conversation <var>pConvoKey</var>. <var>pStepsJson</var> is the
/// already-capped step array, serialized.</p>
ClassMethod GuardedAppend(pConvoKey As %String, pMessage As %String, pState As %String, pReply As %String, pErrorCode As %String, pErrorSeq As %Integer, pStepsJson As %String, pStepsDropped As %Integer, pLimitsClass As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..GuardedIdsWhere("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", pConvoKey, .tCount)
        If $$$ISERR(tSC) Quit
        Set tRow = ..%New()
        Set tRow.ConvoKey = pConvoKey
        Set tRow.Seq = +$Get(tCount(1)) + 1
        Set tRow.Message = ##class(OcuPilot.Kernel.State.Turn).Cap(pMessage, +$Parameter(pLimitsClass, "MESSAGEMAXLENGTH"), .tCutMsg)
        Set tRow.State = pState
        Set tRow.Reply = ##class(OcuPilot.Kernel.State.Turn).Cap(pReply, +$Parameter(pLimitsClass, "TEXTMAXLENGTH"), .tCutReply)
        Set tRow.ErrorCode = pErrorCode
        Set tRow.ErrorSeq = +pErrorSeq
        Set tRow.StepsDropped = +pStepsDropped
        If pStepsJson '= "" Do tRow.StepsJson.Write(pStepsJson)
        Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
        Set tRow = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every entry of conversation <var>pConvoKey</var>, in sequence order, as <code>{seq, message,
/// state, reply, error, steps, stepsDropped}</code> -- <code>reply</code> and <code>error</code>
/// are JSON null when the turn carries none; <code>error</code> is otherwise <code>{seq,
/// code}</code>, with no <code>reason</code> (AD-9's re-entry rule: see
/// <class>OcuPilot.Kernel.State.Convo</class>). <code>steps</code> is the parsed array from
/// <property>StepsJson</property>, or <code>[]</code> when it is empty or does not parse.</p>
/// <p><b><property>StepsJson</property> is read through <method>OcuPilot.Kernel.State.Base.GuardedStreamText</method>,
/// never through <code>tRow.StepsJson</code> directly</b> (AD-9): a stream is read lazily, so
/// <method>OcuPilot.Kernel.State.Base.GuardedOpenId</method>'s own escalation -- spent opening
/// the row -- has already unwound by the time this method's own (unescalated) frame would touch
/// the stream. <code>AddRoles</code> is authorized by compiled routine, not by caller identity,
/// so the escalated read has to happen inside a method compiled into <class>Base</class>'s own
/// routine, which is what <code>GuardedStreamText</code> is for.</p>
ClassMethod GuardedRows(pConvoKey As %String, Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? ORDER BY Seq", pConvoKey, .tIds)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) Continue
        Set tOut = {}
        Do tOut.%Set("seq", +tRow.Seq, "number")
        Do tOut.%Set("message", ..Text(tRow.Message), "string")
        Do tOut.%Set("state", ..Text(tRow.State), "string")
        Set tReply = ..Text(tRow.Reply)
        If tReply = "" {
            Do tOut.%Set("reply", "", "null")
        } Else {
            Do tOut.%Set("reply", tReply, "string")
        }
        Set tCode = ..Text(tRow.ErrorCode)
        If tCode = "" {
            Do tOut.%Set("error", "", "null")
        } Else {
            Set tError = {}
            Do tError.%Set("seq", +tRow.ErrorSeq, "number")
            Do tError.%Set("code", tCode, "string")
            Do tOut.%Set("error", tError)
        }
        Set tStreamSC = ..GuardedStreamText(tRow, "StepsJson", .tStepsText)
        If $$$ISERR(tStreamSC) Set tStepsText = ""
        Set tSteps = []
        Try {
            If tStepsText '= "" {
                Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tStepsText)
                If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tSteps = tParsed
            }
        } Catch ex {
            ; A corrupted StepsJson is otherwise indistinguishable from a turn that genuinely
            ; carried no steps -- log the parse failure so the two are told apart in the fault log.
            Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "conversation " _ pConvoKey _ " entry " _ +tRow.Seq _ ": StepsJson could not be parsed", ex.AsStatus())
            Set tSteps = []
        }
        Do tOut.%Set("steps", tSteps)
        Do tOut.%Set("stepsDropped", +tRow.StepsDropped, "number")
        Set tRow = ""
        Do pRows.%Push(tOut)
    }
    Quit $$$OK
}

/// <p>Delete every entry of conversation <var>pConvoKey</var>. For test teardown only; production
/// never deletes a conversation (Story 14.4 owns retention).</p>
ClassMethod GuardedDeleteForConvo(pConvoKey As %String) As %Status
{
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", pConvoKey)
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
