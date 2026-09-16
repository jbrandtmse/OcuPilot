/// <p>The handler behind the three <code>/turn</code> routes (AD-7, AD-33, AD-41): start a turn in a
/// background job, poll its progress, and abandon the caller's turns at sign-out.</p>
/// <p>Every caller has cleared <method>OcuPilot.Api.Router.OnPreDispatch</method>. Every turn is
/// the caller's own: a poll for anyone else's turn answers exactly like a poll for an id that does
/// not exist, and an abandon reaches the caller's turns alone.</p>
/// <p><b>The escalation ordering is the start handler's to keep</b> (AD-9). Its escalated reads --
/// the restraint verdict, the default definition, the reserve -- all return before
/// <method>OcuPilot.Kernel.Agent.Job.Start</method> spawns, and no frame of this class escalates.</p>
Class OcuPilot.Api.Turn Extends %RegisteredObject
{

/// <p>The body member a start reads, and the field its violations land on.</p>
Parameter MESSAGEFIELD = "message";

/// <p>The loop whose limits class every bound here is read from.</p>
Parameter LOOPCLASS = "OcuPilot.Kernel.Agent.Loop";

/// <p>The authenticated caller. Its own method so a fixture can answer another user.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>POST /turn</code>: validate the body, refuse a switched-off agent or an instance
/// with no definition in force, reserve the caller's one slot, spawn the job, and answer 202 with
/// the opaque turn id. Nothing is reserved when any refusal answers, and no job is spawned for a
/// refused reserve.</p>
ClassMethod HandleStart() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderBadBody(" " _ $System.Status.GetErrorText(tReadSC))
            Quit
        }
        If '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ..RenderBadBody("")
            Quit
        }
        Set tLimits = $ClassMethod(..#LOOPCLASS, "LimitsClass")
        Set tViolation = ..MessageViolation(tBody, tLimits, .tReason)
        If tViolation '= "" {
            Set tSC = ..RenderViolation(tViolation, tReason)
            Quit
        }
        Set tUser = ..CallerUsername()
        Set tVerdictSC = ##class(OcuPilot.Kernel.Restraint).Resolved(tUser, .tVerdict)
        If $$$ISERR(tVerdictSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tVerdictSC))
            Quit
        }
        If +$Get(tVerdict("killSwitch")) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, tVerdict("reason"), tVerdict("code"))
            Quit
        }
        Set tDefaultSC = ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tDefinitionId)
        If $$$ISERR(tDefaultSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tDefaultSC))
            Quit
        }
        If tDefinitionId = "" {
            Set tCode = ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED
            Set tSC = ##class(OcuPilot.Api.Error).Render(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Kernel.Provider.Base).ReasonFor(tCode), tCode)
            Quit
        }
        Set tReserveSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, tDefinitionId, ##class(OcuPilot.Api.Error).#TURNABANDONEDJOBLOST, tLimits, .tKey, .tBusy, .tSweepSC)
        If $$$ISERR(tSweepSC) Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "terminal turns past retention could not be swept", tSweepSC, ##class(OcuPilot.Api.Error).#INTERNAL)
        If $$$ISERR(tReserveSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReserveSC))
            Quit
        }
        If tBusy {
            Set tSC = ##class(OcuPilot.Api.Error).Render(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#REASONTURNBUSY, ##class(OcuPilot.Api.Error).#TURNBUSY)
            Quit
        }
        Kill tValues
        Set tValues("key") = tKey
        Set tValues("user") = tUser
        Set tValues("definitionId") = tDefinitionId
        Set tValues("namespace") = $Namespace
        Set tValues("message") = tBody.%Get(..#MESSAGEFIELD)
        Set tValues("readOnly") = ''$Get(tVerdict("enforcedReadOnly"))
        Set tValues("resources") = ##class(OcuPilot.Api.Router).#ADMINRESOURCES
        Set tStartSC = ##class(OcuPilot.Kernel.Agent.Job).Start(.tValues, .tStarted)
        If $$$ISERR(tStartSC) Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "the turn job could not be started", tStartSC, ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE)
        If 'tStarted {
            Set tSC = ##class(OcuPilot.Api.Error).Render(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#REASONTURNUNAVAILABLE, ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE)
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("turnId", tKey, "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(202, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /turn/:id/progress</code> for the caller's own turn: finish it first when
/// its job is gone, renew its lease when it has not ended, and answer the progress projection with
/// the terminal code's sentence in <code>error.reason</code>. Another user's turn and an unknown id
/// both answer 404 <code>TURN.NOTFOUND</code>, with the same body, and renew nothing.</p>
ClassMethod HandleProgress(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tUser = ..CallerUsername()
        Set tOwnerSC = ##class(OcuPilot.Kernel.State.Turn).GuardedForOwner(pId, tUser, .tFound, .tValues)
        If $$$ISERR(tOwnerSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tOwnerSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound()
            Quit
        }
        Set tLimits = $ClassMethod(..#LOOPCLASS, "LimitsClass")
        Set tReconcileSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReconcile(tUser, ##class(OcuPilot.Api.Error).#TURNABANDONEDJOBLOST, tLimits)
        If $$$ISERR(tReconcileSC) Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "a lost turn could not be reconciled", tReconcileSC, ##class(OcuPilot.Api.Error).#INTERNAL)
        Set tViewSC = ##class(OcuPilot.Kernel.State.Turn).GuardedView(pId, tUser, .tFound, .tView)
        If $$$ISERR(tViewSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tViewSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound()
            Quit
        }
        If '##class(OcuPilot.Kernel.State.Turn).IsTerminal(tView.state) {
            Set tRenewSC = ##class(OcuPilot.Kernel.State.Turn).GuardedRenew(pId)
            If $$$ISERR(tRenewSC) Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "a turn's lease could not be renewed", tRenewSC, ##class(OcuPilot.Api.Error).#INTERNAL)
        }
        If $IsObject(tView.error) {
            Do tView.error.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForTurnError(tView.error.code), "string")
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tView)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /turn/abandon</code>: ask every queued or running turn of the caller to
/// abandon at its next step boundary, and answer <code>{"abandoned": n}</code>. Sign-out sends it,
/// because the instance observes no token sign-out (AD-31).</p>
ClassMethod HandleAbandon() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tAbandonSC = ##class(OcuPilot.Kernel.State.Turn).GuardedAbandonForUser(..CallerUsername(), .tCount)
        If $$$ISERR(tAbandonSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tAbandonSC))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("abandoned", +tCount, "number")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The violation code <var>pBody</var>'s message earns, or <code>""</code>: required when it is
/// absent, not a JSON string, or whitespace alone; length when it is longer than the limit.
/// <var>pReason</var> is the sentence the violation carries.</p>
ClassMethod MessageViolation(pBody As %DynamicObject, pLimitsClass As %String, Output pReason As %String) As %String
{
    Set pReason = ""
    If (pBody.%GetTypeOf(..#MESSAGEFIELD) '= "string") || ($ZStrip(pBody.%Get(..#MESSAGEFIELD), "<>WC") = "") {
        Set pReason = ##class(OcuPilot.Api.Error).#REASONTURNMESSAGEREQUIRED
        Quit ##class(OcuPilot.Api.Error).#TURNMESSAGEREQUIRED
    }
    Set tMax = +$Parameter(pLimitsClass, "MESSAGEMAXLENGTH")
    If $Length(pBody.%Get(..#MESSAGEFIELD)) > tMax {
        Set pReason = ##class(OcuPilot.Api.Error).#REASONTURNMESSAGELENGTH _ ": at most " _ tMax _ " characters."
        Quit ##class(OcuPilot.Api.Error).#TURNMESSAGELENGTH
    }
    Quit ""
}

/// <p>Refuse with 422: the violation's code on the envelope, and the same code with its sentence on
/// the field <parameter>MESSAGEFIELD</parameter> in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolation(pCode As %String, pReason As %String) As %Status [ Private ]
{
    Set tEntry = {}
    Do tEntry.%Set("field", ..#MESSAGEFIELD, "string")
    Do tEntry.%Set("code", pCode, "string")
    Do tEntry.%Set("reason", pReason, "string")
    Set tViolations = []
    Do tViolations.%Push(tEntry)
    Set tDetail = {}
    Do tDetail.%Set("violations", tViolations)
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pReason, pCode, tDetail)
}

/// <p>Refuse with 400 <code>TURN.BADBODY</code>; <var>pStage</var>, when not empty, names the read
/// stage that failed so a server-side fault is not presented as malformed client JSON (DW-24).</p>
ClassMethod RenderBadBody(pStage As %String) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONTURNBADBODY _ pStage, ##class(OcuPilot.Api.Error).#TURNBADBODY)
}

/// <p>Refuse with 404 <code>TURN.NOTFOUND</code>. The id is not echoed back.</p>
ClassMethod RenderNotFound() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONTURNNOTFOUND, ##class(OcuPilot.Api.Error).#TURNNOTFOUND)
}

}
