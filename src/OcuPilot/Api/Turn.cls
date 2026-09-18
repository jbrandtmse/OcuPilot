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

/// <p>The body member a start's screen context arrives on, and the field its violations land
/// on.</p>
Parameter CONTEXTFIELD = "context";

/// <p>The body member a start's conversation id arrives on, and the field its violation lands on
/// (Story 4.5).</p>
Parameter CONVERSATIONFIELD = "conversationId";

/// <p>The loop whose limits class every bound here is read from.</p>
Parameter LOOPCLASS = "OcuPilot.Kernel.Agent.Loop";

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>POST /turn</code>: validate the body, refuse a switched-off agent or an instance
/// with no definition in force, reserve the caller's one slot, spawn the job, and answer 202 with
/// the opaque turn id. Nothing is reserved when a refusal answers before the reserve; a turn whose
/// job could not be spawned is finished <code>failed</code> and answers 503.</p>
ClassMethod HandleStart() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) {
            If tStage = "parse" {
                Set tSC = ..RenderBadBody()
            } Else {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            }
            Quit
        }
        If '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ..RenderBadBody()
            Quit
        }
        Set tLimits = $ClassMethod(..#LOOPCLASS, "LimitsClass")
        Set tViolation = ..MessageViolation(tBody, tLimits, .tReason)
        If tViolation '= "" {
            Set tSC = ..RenderViolation(..#MESSAGEFIELD, tViolation, tReason)
            Quit
        }
        Set tContextViolation = ..ContextViolation(tBody, tLimits)
        If tContextViolation '= "" {
            Set tSC = ..RenderViolation(..#CONTEXTFIELD, tContextViolation, ##class(OcuPilot.Api.Error).ReasonForTurn(tContextViolation))
            Quit
        }
        Set tUser = ..CallerUsername()
        Set tConversationViolation = ..ConversationViolation(tBody)
        If tConversationViolation '= "" {
            Set tSC = ..RenderViolation(..#CONVERSATIONFIELD, tConversationViolation, ##class(OcuPilot.Api.Error).ReasonForTurn(tConversationViolation))
            Quit
        }
        Set tConversationId = tBody.%Get(..#CONVERSATIONFIELD)
        Set tConvoOwnerSC = ##class(OcuPilot.Kernel.State.Convo).GuardedOwner(tConversationId, tUser, .tConvoOwned)
        If $$$ISERR(tConvoOwnerSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tConvoOwnerSC))
            Quit
        }
        If 'tConvoOwned {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONTURNCONVERSATIONNOTFOUND, ##class(OcuPilot.Api.Error).#TURNCONVERSATIONNOTFOUND)
            Quit
        }
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
        Set tSwitchSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitchValues)
        If $$$ISERR(tSwitchSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSwitchSC))
            Quit
        }
        Set tRowCap = +tSwitchValues("contextRowCap")
        Set tShareEffective = ''tSwitchValues("shareContextByDefault")
        Set tSharingSC = ##class(OcuPilot.Kernel.State.Sharing).GuardedForUser(tUser, .tShareFound, .tShareValue)
        If $$$ISERR(tSharingSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSharingSC))
            Quit
        }
        If tShareFound Set tShareEffective = ''tShareValue

        Set tContextJson = ""
        If tShareEffective && tBody.%IsDefined(..#CONTEXTFIELD) && $IsObject(tBody.%Get(..#CONTEXTFIELD)) {
            Set tContextBuildSC = ##class(OcuPilot.Screen.Context).Build(tBody.%Get(..#CONTEXTFIELD), .tContextBuilt, .tContextPayload, .tFieldMaxLengths, .tDroppedFields)
            If $$$ISERR(tContextBuildSC) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tContextBuildSC))
                Quit
            }
            If tContextBuilt && 'tContextPayload.%IsDefined("rows") {
                ; A descriptor declaring context.secretFields (AD-24): identity only, and the
                ; kernel cutter never runs over it -- there are no rows to bound. rowsSent is still
                ; reported, 0, so a consumer reading it need not special-case "no rows key at all".
                Do tContextPayload.%Set("rowsSent", 0, "number")
                Set tContextJson = tContextPayload.%ToJSON()
            } ElseIf tContextBuilt {
                Set tDefaultFieldMax = +$Parameter(tLimits, "FIELDMAXLENGTH")
                Set tTotalMax = +$Parameter(tLimits, "TOOLRESULTMAXLENGTH")
                ; A non-scalar value Build dropped is reported before the cutter runs, so the
                ; size cut counts it and Apply ORs it into truncatedFields.
                If $ListLength(tDroppedFields) > 0 {
                    Set tDropped = []
                    For tI = 1:1:$ListLength(tDroppedFields) Do tDropped.%Push($List(tDroppedFields, tI))
                    Do tContextPayload.%Set("truncatedFields", tDropped)
                    Do tContextPayload.%Set("truncated", 1, "boolean")
                }
                Do ##class(OcuPilot.Kernel.Agent.Bound).Apply(tContextPayload, tRowCap, .tFieldMaxLengths, tDefaultFieldMax, tTotalMax, .tContextJson)
            }
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
        Set tValues("scope") = ##class(OcuPilot.Kernel.Scope).Current()
        Set tValues("context") = tContextJson
        Set tValues("contextRowCap") = tRowCap
        Set tValues("conversationId") = tConversationId
        Set tStartSC = ##class(OcuPilot.Kernel.Agent.Job).Start(.tValues, .tStarted)
        If $$$ISERR(tStartSC) || 'tStarted Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "the turn job could not be started", $Select($$$ISERR(tStartSC): tStartSC, 1: $$$ERROR($$$GeneralError, "the spawn was not accepted within its timeout")), ##class(OcuPilot.Api.Error).#TURNUNAVAILABLE)
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

/// <p>Answer <code>POST /turn/:id/stop</code> (Story 4.5): ask the caller's own turn <var>pId</var>
/// to stop at its next step boundary, and answer 200 <code>{stopRequested}</code>.
/// <var>stopRequested</var> is <code>false</code>, never an error, for a turn that has already
/// ended -- there is nothing left to stop. An id the caller does not own, matched exactly, is 404
/// <code>TURN.NOTFOUND</code>, the same as an unknown one.</p>
ClassMethod HandleStop(pId As %String) As %Status
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
        Set tStopRequested = 0
        If '##class(OcuPilot.Kernel.State.Turn).IsTerminal(tValues("state")) {
            Set tStopSC = ##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(pId, tUser, .tStopRequested)
            If $$$ISERR(tStopSC) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tStopSC))
                Quit
            }
        }
        Set tAnswer = {}
        Do tAnswer.%Set("stopRequested", ''tStopRequested, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /turn/:id/navigation</code> (Story 4.7, AD-11 rule 3): settle the caller's
/// own pending client-fulfilled navigation directive with the browser's answer. Owner gate first
/// (404 <code>TURN.NOTFOUND</code>, the same as an unknown id and another user's turn alike); then
/// the closed body vocabulary <code>{seq, outcome:"opened"|"refused", code:"NAV.REFUSEDUNSAVED"|null}</code>
/// (422 <code>TURN.NAVIGATION.INVALID</code> otherwise, so the client can never author
/// model-visible text); then the claim itself
/// (<method>OcuPilot.Kernel.State.Nav.GuardedSettle</method>, 409 <code>STATE.CONFLICT</code> when
/// nothing is pending, the <code>seq</code> does not match, or the directive was already settled);
/// then a trivial <code>{settled}</code> ack.</p>
ClassMethod HandleNavigation(pId As %String) As %Status
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
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) {
            If tStage = "parse" {
                Set tSC = ..RenderNavigationInvalid()
            } Else {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            }
            Quit
        }
        If ..NavigationViolation(tBody, .tSeq, .tOutcome, .tCode) {
            Set tSC = ..RenderNavigationInvalid()
            Quit
        }
        Set tSettleSC = ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(pId, tSeq, tOutcome, tCode, .tClaimed)
        If $$$ISERR(tSettleSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSettleSC))
            Quit
        }
        If 'tClaimed {
            Set tSC = ##class(OcuPilot.Api.Error).Render(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#REASONSTATECONFLICT, ##class(OcuPilot.Api.Error).#STATECONFLICT)
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("settled", 1, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether <var>pBody</var> breaks the navigation settle's closed body vocabulary
/// (Story 4.7): any key beyond <code>seq</code>, <code>outcome</code> and <code>code</code>; a
/// <code>seq</code> that is not a whole number of at least 1; an <code>outcome</code> outside
/// <code>{"opened","refused"}</code>; a <code>code</code> that is not <code>null</code> when
/// <code>outcome</code> is <code>"opened"</code>, or that is not exactly
/// <parameter>OcuPilot.Api.Error.NAVREFUSEDUNSAVED</parameter> when it is <code>"refused"</code> --
/// the one code a browser is ever the author of, so the client can never post model-visible text
/// through this route. <var>pSeq</var>/<var>pOutcome</var>/<var>pCode</var> are set only when this
/// answers 0.</p>
ClassMethod NavigationViolation(pBody As %DynamicObject, Output pSeq As %Integer, Output pOutcome As %String, Output pCode As %String) As %Boolean
{
    Set pSeq = 0
    Set pOutcome = ""
    Set pCode = ""
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 1
    Set tBad = 0
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tIgnored) {
        If (tKey '= "seq") && (tKey '= "outcome") && (tKey '= "code") {
            Set tBad = 1
            Quit
        }
    }
    If tBad Quit 1
    If pBody.%GetTypeOf("seq") '= "number" Quit 1
    Set tSeq = pBody.%Get("seq")
    If (tSeq '= (tSeq \ 1)) || (tSeq < 1) Quit 1
    If pBody.%GetTypeOf("outcome") '= "string" Quit 1
    Set tOutcome = pBody.%Get("outcome")
    If '$ListFind($ListBuild("opened", "refused"), tOutcome) Quit 1
    Set tCodeType = pBody.%GetTypeOf("code")
    If tOutcome = "opened" {
        If (tCodeType '= "null") && (tCodeType '= "unassigned") Quit 1
    } Else {
        If (tCodeType '= "string") || (pBody.%Get("code") '= ##class(OcuPilot.Api.Error).#NAVREFUSEDUNSAVED) Quit 1
    }
    Set pSeq = tSeq
    Set pOutcome = tOutcome
    Set pCode = $Select(tOutcome = "opened": "", 1: pBody.%Get("code"))
    Quit 0
}

/// <p>Refuse with 422 <code>TURN.NAVIGATION.INVALID</code> (Story 4.7).</p>
ClassMethod RenderNavigationInvalid() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONTURNNAVIGATIONINVALID, ##class(OcuPilot.Api.Error).#TURNNAVIGATIONINVALID)
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

/// <p>The violation code <var>pBody</var>'s <code>conversationId</code> earns, or <code>""</code>
/// (Story 4.5): required when it is absent, not a JSON string, or empty. Ownership is checked
/// separately, after this passes (<method>OcuPilot.Kernel.State.Convo.GuardedOwner</method>) --
/// this method reports only the shape.</p>
ClassMethod ConversationViolation(pBody As %DynamicObject) As %String
{
    If (pBody.%GetTypeOf(..#CONVERSATIONFIELD) '= "string") || (pBody.%Get(..#CONVERSATIONFIELD) = "") {
        Quit ##class(OcuPilot.Api.Error).#TURNCONVERSATIONREQUIRED
    }
    Quit ""
}

/// <p>The violation code <var>pBody</var>'s <code>context</code> earns, or <code>""</code>
/// (Story 4.4, AD-24): checked only when <code>context</code> is present at all. The wire shape is
/// <code>{route, namespace, entity?, view?: {sort?, direction?, filter?, rows, rowsAvailable?}}</code>;
/// every present member must carry its declared JSON type, <code>view.rows</code> is required when
/// <code>view</code> is present, and <code>namespace</code> must equal the request's resolved
/// scope (<method>OcuPilot.Kernel.Scope.Current</method>, from <code>?ns=</code>) -- a caller
/// naming a different namespace could otherwise carry rows from one scope into a turn running in
/// another.</p>
/// <p><b>entity, sort, direction and filter are bounded here, not by the cutter.</b>
/// <class>OcuPilot.Kernel.Agent.Bound</class> only cuts a <code>view.rows</code> row's own field
/// values and never the payload's top-level strings, so each is refused above
/// <var>pLimitsClass</var>'s <code>FIELDMAXLENGTH</code>; with them bounded, a rowless payload
/// always fits the total budget. <code>rowsAvailable</code> is a whole number.</p>
ClassMethod ContextViolation(pBody As %DynamicObject, pLimitsClass As %String) As %String
{
    If 'pBody.%IsDefined(..#CONTEXTFIELD) Quit ""
    Set tCode = ##class(OcuPilot.Api.Error).#TURNCONTEXTINVALID
    Set tContext = pBody.%Get(..#CONTEXTFIELD)
    If '$IsObject(tContext) || 'tContext.%IsA("%Library.DynamicObject") Quit tCode
    If (tContext.%GetTypeOf("route") '= "string") || (tContext.%Get("route") = "") Quit tCode
    If tContext.%GetTypeOf("namespace") '= "string" Quit tCode
    If tContext.%Get("namespace") '= ##class(OcuPilot.Kernel.Scope).Current() Quit tCode
    If tContext.%IsDefined("entity") {
        Set tEntityType = tContext.%GetTypeOf("entity")
        If (tEntityType '= "string") && (tEntityType '= "null") Quit tCode
        If (tEntityType = "string") && ($Length(tContext.%Get("entity")) > +$Parameter(pLimitsClass, "FIELDMAXLENGTH")) Quit tCode
    }
    If 'tContext.%IsDefined("view") Quit ""
    Set tView = tContext.%Get("view")
    If '$IsObject(tView) || 'tView.%IsA("%Library.DynamicObject") Quit tCode
    Set tBadMember = 0
    For tMember = "sort", "direction", "filter" {
        If 'tView.%IsDefined(tMember) Continue
        If (tView.%GetTypeOf(tMember) '= "string") || ($Length(tView.%Get(tMember)) > +$Parameter(pLimitsClass, "FIELDMAXLENGTH")) Set tBadMember = 1
    }
    If tBadMember Quit tCode
    If tView.%GetTypeOf("rows") '= "array" Quit tCode
    Set tRows = tView.%Get("rows")
    Set tBadRow = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") {
            Set tBadRow = 1
            Quit
        }
    }
    If tBadRow Quit tCode
    If tView.%IsDefined("rowsAvailable") {
        If tView.%GetTypeOf("rowsAvailable") '= "number" Quit tCode
        Set tRowsAvailable = tView.%Get("rowsAvailable")
        If (tRowsAvailable < 0) || (tRowsAvailable '= (tRowsAvailable \ 1)) || (tRowsAvailable < tRows.%Size()) Quit tCode
    }
    Quit ""
}

/// <p>Refuse with 422: the violation's code on the envelope, and the same code with its sentence on
/// <var>pField</var> in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolation(pField As %String, pCode As %String, pReason As %String) As %Status [ Private ]
{
    Set tEntry = {}
    Do tEntry.%Set("field", pField, "string")
    Do tEntry.%Set("code", pCode, "string")
    Do tEntry.%Set("reason", pReason, "string")
    Set tViolations = []
    Do tViolations.%Push(tEntry)
    Set tDetail = {}
    Do tDetail.%Set("violations", tViolations)
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pReason, pCode, tDetail)
}

/// <p>Refuse with 400 <code>TURN.BADBODY</code> and its written sentence alone (AD-39). A body the
/// server could not read or decode is an internal failure, never this refusal (DW-24).</p>
ClassMethod RenderBadBody() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONTURNBADBODY, ##class(OcuPilot.Api.Error).#TURNBADBODY)
}

/// <p>Refuse with 404 <code>TURN.NOTFOUND</code>. The id is not echoed back.</p>
ClassMethod RenderNotFound() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONTURNNOTFOUND, ##class(OcuPilot.Api.Error).#TURNNOTFOUND)
}

}
