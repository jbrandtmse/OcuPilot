/// <p>The turn job (AD-7, AD-9): the one place in shipped code that spawns a process.
/// <method>Start</method> is called by the turn handler, from a frame no escalation is in effect in,
/// after every escalated read has returned; everything the job starts from travels as a
/// <code>JOB</code> argument. The child inherits the caller's <code>$USERNAME</code> and
/// <code>$ROLES</code> and keeps them for its life, which is why nothing may be spawned from an
/// escalated frame.</p>
/// <p><method>Run</method> is the job's entry point. It refuses to run as anyone but the user it
/// was started for, begins the turn, runs the loop, and finishes the turn on every exit path.</p>
Class OcuPilot.Kernel.Agent.Job Extends %RegisteredObject
{

/// <p>Seconds <method>Start</method> waits for the spawn to be accepted.</p>
Parameter SPAWNTIMEOUT As %Integer = 5;

/// <p>Seconds <method>Run</method> waits for the turn's conversation lock
/// (<method>OcuPilot.Kernel.State.Convo.LoadOrCreate</method>). AD-41's slot lock already bounds
/// one user to one turn, so this lock is not contended in production traffic (inference).</p>
Parameter CONVERSATIONLOCKSECONDS As %Integer = 5;

/// <p>The loop the job runs.</p>
ClassMethod LoopClass() As %String
{
    Quit "OcuPilot.Kernel.Agent.Loop"
}

/// <p>Spawn the job for the reserved turn <var>pValues("key")</var>. <var>pValues</var> also
/// carries <code>user</code>, <code>definitionId</code>, <code>namespace</code>,
/// <code>message</code>, <code>readOnly</code> (the enforced read-only snapshot),
/// <code>resources</code>, <code>scope</code> (the request's resolved scope,
/// <method>OcuPilot.Kernel.Scope.Current</method> as the handler read it), <code>context</code>
/// (the already-bounded screen-context payload JSON, or <code>""</code>),
/// <code>contextRowCap</code> (<code>Switch.ContextRowCap</code> as the handler resolved it) and
/// <code>conversationId</code> (Story 4.5: the caller-owned conversation
/// <class>OcuPilot.Api.Turn</class> has already verified).
/// <var>pStarted</var> is 1 when the spawn was accepted; when it was not, the turn is finished
/// <code>failed</code> with <code>TURN.UNAVAILABLE</code> here.</p>
/// <p><b>Caller contract:</b> no <code>New $ROLES</code> escalation is in effect in any frame of
/// the caller's stack (AD-9).</p>
ClassMethod Start(ByRef pValues, Output pStarted As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pStarted = 0
    Set tKey = $Get(pValues("key"))
    Set tUser = $Get(pValues("user"))
    Try {
        Set tNamespace = $Get(pValues("namespace"))
        Job ##class(OcuPilot.Kernel.Agent.Job).Run(tKey, tUser, $Get(pValues("definitionId")), tNamespace, $Get(pValues("message")), ''$Get(pValues("readOnly")), $Get(pValues("resources")), $Get(pValues("scope")), $Get(pValues("context")), +$Get(pValues("contextRowCap")), $Get(pValues("conversationId"))):(tNamespace):..#SPAWNTIMEOUT
        Set pStarted = $Test
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pStarted = 0
    }
    If 'pStarted {
        Set tLimits = $ClassMethod(..LoopClass(), "LimitsClass")
        Set tFinishSC = ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED, ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE, "", "", 0, tLimits)
        If $$$ISOK(tSC) Set tSC = tFinishSC
    }
    Quit tSC
}

/// <p>The job's entry point. Arguments are the values <method>Start</method> was given.</p>
/// <p>A turn it cannot begin -- the slot stayed held past the queued limit, or the begin failed --
/// is finished <code>failed</code> with <code>TURN.UNAVAILABLE</code> here; a row that already
/// ended is left as it is. Every failure the job meets is logged, because no request is waiting to
/// report it.</p>
/// <p><b>The conversation (Story 4.5).</b> After the turn begins, this opens
/// <var>pConversationId</var> exclusively (<method>OcuPilot.Kernel.State.Convo.LoadOrCreate</method>)
/// and holds the OREF for the rest of this method: its history seeds the loop's messages, and its
/// entry is appended once the loop ends, before the OREF is dropped on every exit path, including
/// the catch. A lock conflict opening it finishes the turn <code>failed</code> /
/// <code>TURN.BUSY</code> rather than running with no conversation; a persistence failure finishes
/// it <code>failed</code> / <code>TURN.UNAVAILABLE</code>, the same as any other open failure here.</p>
/// <p><b>The turn's screen-context route is recorded at begin</b> (Story 4.9), read off the payload
/// this job already holds through <method>OcuPilot.Kernel.Agent.Loop.ContextRoute</method> -- so the
/// turn row says which screen it ran from after its progress has been swept. That method is the one
/// reading of the payload's <code>route</code>, so the turn row and the loop's ledger rows agree by
/// construction; each frame calls it for itself rather than passing the value along.</p>
ClassMethod Run(pKey As %String, pUser As %String, pDefinitionId As %String, pNamespace As %String, pMessage As %String, pReadOnly As %Boolean, pResources As %String, pScope As %String = "", pContext As %String = "", pContextRowCap As %Integer = 0, pConversationId As %String = "")
{
    Set tBegun = 0
    Set tLimits = ""
    Set tConvo = ""
    Set tUnavailable = ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE
    Try {
        Set tLoop = ..LoopClass()
        Set tLimits = $ClassMethod(tLoop, "LimitsClass")
        Set tFailed = ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED
        If ($Username '= pUser) || ($Namespace '= pNamespace) {
            Do ..Log("the turn job did not start as its caller", $$$ERROR($$$GeneralError, "user or namespace differs from the start"))
            Do ..Finish(pKey, pUser, tFailed, tUnavailable, "", "", 0, tLimits)
            Quit
        }
        Do ##class(OcuPilot.Kernel.Scope).Set(pScope)
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedBegin(pKey, pUser, tLimits, .tBegun, .tStarted, $ClassMethod(tLoop, "ContextRoute", pContext))
        If $$$ISERR(tSC) || 'tBegun {
            Do ..Log("the turn could not be begun", $Select($$$ISERR(tSC): tSC, 1: $$$ERROR($$$GeneralError, "the slot stayed held past the queued limit, or the turn was no longer queued for this user")))
            Do ..Finish(pKey, pUser, tFailed, tUnavailable, "", "", 0, tLimits)
            Quit
        }
        Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate(pConversationId, pUser, ..#CONVERSATIONLOCKSECONDS, .tConvoStatus, .tLockConflict)
        If '$IsObject(tConvo) {
            Do ..Log("the turn's conversation could not be opened", tConvoStatus)
            Set tBegun = 0
            Do ..Finish(pKey, pUser, tFailed, $Select(tLockConflict: ##class(OcuPilot.Api.Error).#TURNBUSY, 1: tUnavailable), "", "", 0, tLimits)
            Quit
        }
        Set tSC = $ClassMethod(tLoop, "Run", pKey, pUser, pDefinitionId, pMessage, pReadOnly, pResources, tStarted, .tOutcome, pContext, pContextRowCap, tConvo)
        Set tState = $Get(tOutcome("state"), tFailed)
        Set tCode = $Get(tOutcome("code"), tUnavailable)
        If $$$ISERR(tSC) {
            Do ..Log("the turn loop failed", tSC)
            Set tState = tFailed
            Set tCode = tUnavailable
        }
        Set tBegun = 0
        Do ..AppendConvoEntry(tConvo, pKey, pMessage, tState, $Get(tOutcome("reply")), tCode, +$Get(tOutcome("errorSeq")), tLimits)
        Set tConvo = ""
        Do ..Finish(pKey, pUser, tState, tCode, $Get(tOutcome("limit")), $Get(tOutcome("reply")), +$Get(tOutcome("errorSeq")), tLimits)
    } Catch ex {
        Do ..Log("the turn job failed", ex.AsStatus())
        ; Mirrors the normal-completion path above: append the conversation entry, then drop the
        ; OREF, then finish the turn.
        If tBegun && (tLimits '= "") {
            Do ..AppendConvoEntry(tConvo, pKey, pMessage, ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED, "", tUnavailable, 0, tLimits)
        }
        Set tConvo = ""
        If tBegun && (tLimits '= "") {
            Do ..Finish(pKey, pUser, ##class(OcuPilot.Kernel.State.Turn).#STATEFAILED, tUnavailable, "", "", 0, tLimits)
        }
    }
}

/// <p>Append turn <var>pKey</var>'s conversation entry onto <var>pConvo</var>: its final step
/// projection (<method>OcuPilot.Kernel.State.Step.GuardedRows</method>), its dropped count and its
/// own turn key, which is what a restored conversation reads a turn's proposals by. A
/// no-op when <var>pConvo</var> is not an open OREF. Failures are logged, never thrown -- the
/// turn's own outcome does not depend on its conversation entry having been written.</p>
ClassMethod AppendConvoEntry(pConvo As OcuPilot.Kernel.State.Convo, pKey As %String, pMessage As %String, pState As %String, pReply As %String, pCode As %String, pErrorSeq As %Integer, pLimitsClass As %String) [ Private ]
{
    Try {
        If '$IsObject(pConvo) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedRows(pKey, .tSteps)
        If $$$ISERR(tSC) {
            Do ..Log("the turn's steps could not be read for its conversation entry", tSC)
            Quit
        }
        Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedDropped(pKey, .tDropped)
        If $$$ISERR(tSC) Set tDropped = 0
        Set tSC = ##class(OcuPilot.Kernel.State.Convo).AppendEntry(pConvo, pMessage, pState, pReply, pCode, pErrorSeq, tSteps, +tDropped, pLimitsClass, pKey)
        If $$$ISERR(tSC) Do ..Log("the turn's conversation entry could not be appended", tSC)
    } Catch ex {
        Do ..Log("appending the turn's conversation entry failed", ex.AsStatus())
    }
}

/// <p><method>OcuPilot.Kernel.State.Turn.GuardedFinish</method>, with a failure logged.</p>
ClassMethod Finish(pKey As %String, pUser As %String, pState As %String, pCode As %String, pLimitHit As %String, pReply As %String, pErrorSeq As %Integer, pLimitsClass As %String) [ Private ]
{
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(pKey, pUser, pState, pCode, pLimitHit, pReply, pErrorSeq, pLimitsClass)
    If $$$ISERR(tSC) Do ..Log("the turn could not be finished", tSC)
}

/// <p>Log <var>pStatus</var> under the turn subsystem with <code>TURN.UNAVAILABLE</code>.</p>
ClassMethod Log(pMessage As %String, pStatus As %Status) [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", pMessage, pStatus, ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE)
}

}
