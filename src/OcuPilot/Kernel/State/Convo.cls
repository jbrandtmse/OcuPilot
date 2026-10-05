/// <p>One conversation (Story 4.5, AD-11, AD-19, AD-41): who started it, and the ordered turns it
/// holds. Held in OcuPilot's protected database and reached only through
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods (AD-9). Turns themselves are rows of
/// <class>OcuPilot.Kernel.State.Entry</class>, keyed by this row's opaque <property>ConvKey</property>
/// -- the same shape <class>OcuPilot.Kernel.State.Turn</class> and
/// <class>OcuPilot.Kernel.State.Step</class> already use, not an object <code>Relationship</code>.</p>
/// <p><b>Per-conversation lock (Design Notes: lock reconciliation).</b> <method>LoadOrCreate</method>
/// is the harvested <code>Chat.History.LoadOrCreate</code> protocol: it answers the row's OREF at
/// concurrency 4 (exclusive, retained) from both the load and the create branch, so a caller that
/// holds the OREF is the row's only writer until it drops every reference. AD-41's per-user turn
/// slot lock (<class>OcuPilot.Kernel.State.Turn</class>) already bounds one user to one turn at a
/// time, so in Release 1 this lock is never contended in production traffic (inference); it is what still holds
/// once a later epic makes per-user turn limits configurable, and it is what
/// <class>OcuPilot.Test.Convo</class> pins directly.</p>
Class OcuPilot.Kernel.State.Convo Extends OcuPilot.Kernel.State.Base
{

/// <p>The user who created this conversation, as <code>$USERNAME</code> read it. A weak reference
/// (AD-37).</p>
Property UserName As %String(MAXLEN = 160);

/// <p>The opaque, server-minted conversation id. Unique; matched exactly.</p>
Property ConvKey As %String(MAXLEN = 64);

/// <p>ISO-8601 UTC (Consistency Conventions: Dates).</p>
Property CreatedAt As %String(MAXLEN = 32);

Index ConvKeyIdx On ConvKey [ Unique ];

Index ConvUserIdx On UserName;

/// <p>How many characters of a conversation's first message the Transcripts list shows as its
/// title.</p>
Parameter TITLEMAXLENGTH As %Integer = 120;

/// <p>The <code>TOP</code> a screen read with no cap binds, so the statement keeps one form.</p>
Parameter SCREENROWSALL As %Integer = 2147483647;

/// <p>Load conversation <var>pId</var>, or create a new one when <var>pId</var> is <code>""</code>,
/// and answer the OREF at concurrency 4 through
/// <method>OcuPilot.Kernel.State.Base.GuardedOpenIdExclusive</method>. The load branch resolves
/// <var>pId</var> to its row id with a plain, lock-free lookup and then opens that row exclusively;
/// the create branch inserts a new row, then opens it the same way -- so both branches return an
/// identically locked OREF. Waits up to <var>pTimeout</var> seconds for the lock.</p>
/// <p><var>pStatus</var> is an error, and the answer <code>$$$NULLOREF</code>, when <var>pId</var>
/// names no conversation, when the insert fails, or when the exclusive open fails; <var>pLockConflict</var>
/// is 1 only for the last of those, and only when the open failed because the wait for the lock
/// itself timed out (a busy row), never for any other open failure (a persistence problem).</p>
/// <p><b>Caller contract:</b> the caller drops every reference to the answered OREF on every exit
/// path, including a caught exception -- that is what releases the lock (<class>OcuPilot.Kernel.Agent.Job</class>
/// holds it for a turn's life and releases it there; <class>OcuPilot.Api.Conversation</class>
/// releases it at once after reading <property>ConvKey</property>).</p>
ClassMethod LoadOrCreate(pId As %String, pUser As %String, pTimeout As %Integer, Output pStatus As %Status, Output pLockConflict As %Boolean) As Convo
{
    Set pStatus = $$$OK
    Set pLockConflict = 0
    Set tConvo = $$$NULLOREF
    Try {
        If pId '= "" {
            Set tSC = ..GuardedIdsWhere("SELECT ID FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", pId, .tIds)
            If $$$ISERR(tSC) {
                Set pStatus = tSC
                Quit
            }
            If $Get(tIds(1)) = "" {
                Set pStatus = $$$ERROR($$$GeneralError, "no conversation with that identifier exists")
                Quit
            }
            Set tRowId = tIds(1)
        } Else {
            Set tRow = ..%New()
            Set tRow.ConvKey = ..NewKey()
            Set tRow.UserName = pUser
            Set tRow.CreatedAt = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
            Set tSC = ..GuardedSaveIfCurrent(tRow, 0)
            If $$$ISERR(tSC) {
                Set pStatus = tSC
                Quit
            }
            Set tRowId = tRow.%Id()
            Set tRow = ""
        }
        Set tSC = ..GuardedOpenIdExclusive(tRowId, pTimeout, .tConvo, .pLockConflict)
        If $$$ISERR(tSC) {
            Set pStatus = tSC
            Set tConvo = $$$NULLOREF
        }
    } Catch ex {
        Set pStatus = ex.AsStatus()
        Set tConvo = $$$NULLOREF
    }
    Quit tConvo
}

/// <p>Whether <var>pUser</var>, matched exactly, owns conversation <var>pKey</var>. A plain read:
/// unlike <method>LoadOrCreate</method> this takes no lock and opens nothing exclusively.</p>
ClassMethod GuardedOwner(pKey As %String, pUser As %String, Output pFound As %Boolean) As %Status
{
    Set pFound = 0
    Set tSC = ..GuardedIdsWhereTwoParam("SELECT ID FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ? AND %EXACT(UserName) = ?", pKey, pUser, .tIds)
    If $$$ISERR(tSC) Quit tSC
    Set pFound = ($Get(tIds(1)) '= "")
    Quit $$$OK
}

/// <p>Append the entry for one finished turn onto <var>pConvo</var>, an OREF <method>LoadOrCreate</method>
/// answered. <var>pTurnKey</var> is that turn's own key, which is what lets a restored
/// conversation carry the turn's proposals; a caller that has none may omit it.
/// <var>pCitations</var> is the reply's citations as JSON text, or <code>""</code> for none.
/// <var>pContextJson</var> is the turn's bounded screen-context payload as JSON text, or
/// <code>""</code>, <var>pDefinitionId</var> the definition it ran under, and <var>pEgress</var> its
/// egress fact as JSON text, or <code>""</code>
/// (<method>OcuPilot.Kernel.State.Entry.GuardedAppend</method>). Defensively re-caps <var>pStepsJson</var> to <var>pLimitsClass</var>'s own
/// <code>MAXSTEPS</code>, even though the caller's own projection
/// (<method>OcuPilot.Kernel.State.Step.GuardedRows</method>) is already within it.</p>
ClassMethod AppendEntry(pConvo As Convo, pMessage As %String, pState As %String, pReply As %String, pErrorCode As %String, pErrorSeq As %Integer, pStepsJson As %DynamicArray, pStepsDropped As %Integer, pLimitsClass As %String, pTurnKey As %String = "", pCitations As %String = "", pContextJson As %String = "", pDefinitionId As %String = "", pEgress As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        If '$IsObject(pConvo) {
            Set tSC = $$$ERROR($$$GeneralError, "AppendEntry requires an open conversation OREF")
            Quit
        }
        Set tMax = +$Parameter(pLimitsClass, "MAXSTEPS")
        Set tSteps = pStepsJson
        If '$IsObject(tSteps) || 'tSteps.%IsA("%Library.DynamicArray") Set tSteps = []
        If tSteps.%Size() > tMax {
            Set pStepsDropped = pStepsDropped + (tSteps.%Size() - tMax)
            Set tKept = []
            For tI = 0:1:tMax - 1 Do tKept.%Push(tSteps.%Get(tI))
            Set tSteps = tKept
        }
        Set tSC = ##class(OcuPilot.Kernel.State.Entry).GuardedAppend(pConvo.ConvKey, pMessage, pState, pReply, pErrorCode, pErrorSeq, tSteps.%ToJSON(), pStepsDropped, pLimitsClass, pTurnKey, pCitations, pContextJson, pDefinitionId, pEgress)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The user who created conversation <var>pKey</var>, matched exactly, as stored; <var>pUser</var>
/// is <code>""</code> when no conversation holds that key. A plain read, like
/// <method>GuardedOwner</method>; the user is a weak reference (AD-37), so a name the instance no
/// longer holds still reads back.</p>
ClassMethod GuardedOwnerOf(pKey As %String, Output pUser As %String) As %Status
{
    Set pUser = ""
    Set tSC = ..GuardedIdsWhere("SELECT UserName FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", pKey, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set pUser = $Get(tRows(1))
    If pUser = $Char(0) Set pUser = ""
    Quit $$$OK
}

/// <p>The Transcripts list's rows (AD-36's <code>state</code> source, as amended for a store scoped
/// to its caller): <code>{id, user, started, lastActivity, turns, title}</code> for every
/// conversation holding at least one entry, newest first, at most <var>pMaxRows</var> of them
/// (<code>SELECT TOP ?</code>; <code>""</code> reads every one).</p>
/// <p><b>Scoped to the calling process, decided before any escalated frame</b> (AD-8, AD-9): a
/// process holding <code>OcuPilotAdmin:USE</code> reads every user's conversations, and any other
/// reads only those whose <property>UserName</property> is its own <code>$USERNAME</code>.
/// <code>title</code> is the first message cut to <parameter>TITLEMAXLENGTH</parameter> characters,
/// and only on the caller's own rows -- another user's text never reaches this caller's screen or
/// its agent. <code>started</code> is <property>CreatedAt</property>; <code>lastActivity</code> is
/// the newest entry's time, or <code>started</code> where no entry records one.</p>
ClassMethod GuardedScreenRows(Output pRows As %DynamicArray, pMaxRows As %String = "") As %Status
{
    Set pRows = ""
    Set tCaller = $Username
    Set tAll = ''$System.Security.Check(..#ADMINRESOURCE, "USE")
    If (pMaxRows '= "") && '$Match(pMaxRows, "^[1-9][0-9]*$") Quit $$$ERROR($$$GeneralError, "maxRows must be empty or a whole number above zero")
    Set tTop = $Select(pMaxRows = "": ..#SCREENROWSALL, 1: +pMaxRows)
    If tAll {
        Set tSC = ..GuardedIdsWhere("SELECT TOP ? c.ID FROM OcuPilot_Kernel_State.Convo c WHERE EXISTS (SELECT e.ID FROM OcuPilot_Kernel_State.Entry e WHERE e.ConvoKey = c.ConvKey) ORDER BY c.ID DESC", tTop, .tIds)
    } Else {
        Set tSC = ..GuardedIdsWhereTwoParam("SELECT TOP ? c.ID FROM OcuPilot_Kernel_State.Convo c WHERE %EXACT(c.UserName) = ? AND EXISTS (SELECT e.ID FROM OcuPilot_Kernel_State.Entry e WHERE e.ConvoKey = c.ConvKey) ORDER BY c.ID DESC", tTop, tCaller, .tIds)
    }
    If $$$ISERR(tSC) Quit tSC
    Set pRows = []
    For tI = 1:1:+$Get(tIds) {
        Set tOpenSC = ..GuardedOpenId(tIds(tI), .tRow)
        If $$$ISERR(tOpenSC) || '$IsObject(tRow) Continue
        Set tKey = tRow.ConvKey
        Set tUser = ..Text(tRow.UserName)
        Set tStarted = ..Text(tRow.CreatedAt)
        Set tRow = ""
        Set tSC = ..GuardedPairsWhere("SELECT COUNT(*), MAX(%EXACT(AppendedAt)) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", tKey, .tStats)
        If $$$ISERR(tSC) Quit
        Set tTurns = +$Get(tStats(1))
        If tTurns = 0 Continue
        Set tLast = ..Text($Get(tStats(1, 2)))
        If tLast = "" Set tLast = tStarted
        Set tTitle = ""
        If tUser = tCaller {
            Set tSC = ..GuardedIdsWhere("SELECT TOP 1 Message FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ? ORDER BY Seq", tKey, .tFirst)
            If $$$ISERR(tSC) Quit
            Set tTitle = ##class(OcuPilot.Kernel.State.Turn).Cap(..Text($Get(tFirst(1))), ..#TITLEMAXLENGTH, .tCut)
        }
        Set tOut = {}
        Do tOut.%Set("id", tKey, "string")
        Do tOut.%Set("user", tUser, "string")
        Do tOut.%Set("started", tStarted, "string")
        Do tOut.%Set("lastActivity", tLast, "string")
        Do tOut.%Set("turns", tTurns, "number")
        Do tOut.%Set("title", tTitle, "string")
        Do pRows.%Push(tOut)
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>Delete every conversation that holds no entry and whose <property>CreatedAt</property> is
/// before <var>pCutoff</var> (ISO-8601 UTC). <var>pRemoved</var> is how many went. The retention
/// sweep passes the longest retention's cutoff, so a conversation outlives every entry it could
/// have held.</p>
ClassMethod GuardedPurgeEmpty(pCutoff As %String, Output pRemoved As %Integer) As %Status
{
    Set pRemoved = 0
    Set tParams = []
    Do tParams.%Push(pCutoff, "string")
    Quit ..GuardedExecuteRows("DELETE FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(CreatedAt) < ? AND NOT EXISTS (SELECT e.ID FROM OcuPilot_Kernel_State.Entry e WHERE e.ConvoKey = OcuPilot_Kernel_State.Convo.ConvKey)", .tParams, .pRemoved)
}

/// <p>The GET shape of conversation <var>pKey</var> when <var>pUser</var> owns it:
/// <code>{conversationId, turns:[{seq, message, state, reply, citations, error:{seq,code}, steps,
/// stepsDropped, egress}]}</code>. <code>error</code> here carries no <code>reason</code> --
/// <class>OcuPilot.Api.Conversation</class> adds it the way
/// <class>OcuPilot.Api.Turn</class> adds it to a turn's progress view, because this package does
/// not name the API's vocabulary class (AD-9's re-entry rule).</p>
ClassMethod GuardedView(pKey As %String, pUser As %String, Output pFound As %Boolean, Output pView As %DynamicObject) As %Status
{
    Set pFound = 0
    Set pView = ""
    Set tSC = ..GuardedOwner(pKey, pUser, .pFound)
    If $$$ISERR(tSC) || 'pFound Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Entry).GuardedRows(pKey, .tTurns)
    If $$$ISERR(tSC) Quit tSC
    Set tView = {}
    Do tView.%Set("conversationId", pKey, "string")
    Do tView.%Set("turns", tTurns)
    Set pView = tView
    Quit $$$OK
}

/// <p>The prior-turn messages the next model request replays (Design Notes: why history is in
/// scope): each turn of <var>pConvo</var> carrying a reply contributes its user message then its
/// reply, oldest first, dropping the oldest whole turns until the combined text fits
/// <var>pMaxLength</var> characters. A turn with no reply is skipped entirely -- never a stopped
/// or failed turn, never tool results, never screen context. With <var>pDefinitionId</var>, a turn whose
/// entry recorded a different definition is left out too; an entry that recorded none is kept.</p>
ClassMethod HistoryMessages(pConvo As Convo, pMaxLength As %Integer, Output pMessages As %DynamicArray, pDefinitionId As %String = "") As %Status
{
    Set pMessages = []
    Set tSC = $$$OK
    Try {
        If '$IsObject(pConvo) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Entry).GuardedRows(pConvo.ConvKey, .tTurns, 0, 1)
        If $$$ISERR(tSC) Quit
        Set tKept = 0
        Set tTotal = 0
        Kill tSelected
        For tI = tTurns.%Size() - 1:-1:0 {
            Set tTurn = tTurns.%Get(tI)
            If tTurn.%GetTypeOf("reply") '= "string" Continue
            If tTurn.%Get("reply") = "" Continue
            ; One conversation, one definition (Story 19.11, AD-42): an entry that ran under another
            ; definition is not replayed. An entry that recorded none still is.
            If (pDefinitionId '= "") && (tTurn.%Get("definitionId") '= "") && (tTurn.%Get("definitionId") '= pDefinitionId) Continue
            Set tLen = $Length(tTurn.%Get("message")) + $Length(tTurn.%Get("reply"))
            If (tTotal + tLen) > pMaxLength Quit
            Set tKept = tKept + 1
            Set tSelected(tKept) = tTurn
            Set tTotal = tTotal + tLen
        }
        For tI = tKept:-1:1 {
            Set tTurn = tSelected(tI)
            Do pMessages.%Push(..PlainMessage("user", tTurn.%Get("message")))
            Do pMessages.%Push(..PlainMessage("assistant", tTurn.%Get("reply")))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pMessages = []
    }
    Quit tSC
}

/// <p>A canonical <code>{role, content}</code> message.</p>
ClassMethod PlainMessage(pRole As %String, pContent As %String) As %DynamicObject [ Private ]
{
    Set tMsg = {}
    Do tMsg.%Set("role", pRole, "string")
    Do tMsg.%Set("content", pContent, "string")
    Quit tMsg
}

/// <p>A fresh opaque conversation id: 32 lower-case hex characters from the instance's random
/// source -- the same shape <method>OcuPilot.Kernel.State.Turn.NewKey</method> mints.</p>
ClassMethod NewKey() As %String [ Private ]
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p>Delete conversation <var>pKey</var> and its entries. For test teardown only; production
/// removes a conversation only through retention (<method>GuardedPurgeEmpty</method>).</p>
ClassMethod GuardedDelete(pKey As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.State.Entry).GuardedDeleteForConvo(pKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ..GuardedExecuteOneParam("DELETE FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = ?", pKey)
}

/// <p><var>pValue</var> with the <code>$Char(0)</code> a SQL <code>UPDATE</code> leaves normalized
/// to <code>""</code>.</p>
ClassMethod Text(pValue As %String) As %String [ Private ]
{
    If pValue = $Char(0) Quit ""
    Quit pValue
}

}
