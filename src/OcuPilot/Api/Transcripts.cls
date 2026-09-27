/// <p>The handler behind <code>GET /transcripts/:id</code> (Story 14.4, AD-9, AD-33, AD-37, AD-46):
/// one stored conversation, its owner's own or, to an OcuPilot administrator, another user's. Every
/// caller has cleared <method>OcuPilot.Api.Router.OnPreDispatch</method>.</p>
/// <p><b>The gate is the ledger's, not this route's.</b> Whether another user's tool results and
/// screen context reach the caller is <method>OcuPilot.Kernel.Audit.Ledger.GateTurns</method>'s
/// answer, which also records the read; this handler adds no check of its own and maps that
/// method's refusal to the same 404 an unknown id gets (AD-33). Messages and replies are sent
/// either way; proposals never are.</p>
Class OcuPilot.Api.Transcripts Extends %RegisteredObject
{

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>The ledger face the cross-user gate is asked through. Overridable for the reason
/// <method>OcuPilot.Kernel.Audit.Ledger.GateClass</method> is; production never overrides it.</p>
ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Kernel.Audit.Ledger"
}

/// <p>Answer <code>GET /transcripts/:id</code>: <code>{conversationId, user, own, released,
/// failedPair, turns:[{seq, appendedAt, message, state, reply, error, steps, context}]}</code>.
/// <code>own</code> is whether the caller started the conversation; <code>released</code> whether
/// <code>steps</code> and <code>context</code> carry what was stored -- always, for the owner --
/// and when it is false every turn's <code>steps</code> is <code>[]</code> and its
/// <code>context</code> null, with <code>failedPair</code> naming the first recorded pair the
/// caller does not hold, or <code>""</code>. An unknown id, and another user's id asked for by a
/// caller without <method>OcuPilot.Kernel.Audit.Ledger.AdminPair</method>, are one 404
/// <code>TURN.CONVERSATION.NOTFOUND</code>.</p>
ClassMethod HandleRead(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCaller = ..CallerUsername()
        Set tOwnerSC = ##class(OcuPilot.Kernel.State.Convo).GuardedOwnerOf(pId, .tOwner)
        If $$$ISERR(tOwnerSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tOwnerSC))
            Quit
        }
        If tOwner = "" {
            Set tSC = ..NotFound()
            Quit
        }
        Set tOwn = ($ZConvert(tOwner, "U") = $ZConvert(tCaller, "U"))
        Set tReleased = 1
        Set tFailedPair = ""
        If 'tOwn {
            Set tKeysSC = ##class(OcuPilot.Kernel.State.Entry).GuardedTurnKeys(pId, .tKeys)
            If $$$ISERR(tKeysSC) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tKeysSC))
                Quit
            }
            Set tTurnKeys = ""
            Set tSeq = ""
            For {
                Set tSeq = $Order(tKeys(tSeq), 1, tKey)
                If tSeq = "" Quit
                Set tTurnKeys = tTurnKeys _ $ListBuild(tKey)
            }
            Set tGateSC = $ClassMethod(..LedgerClass(), "GateTurns", tCaller, tOwner, pId, tTurnKeys, .tReleased, .tFailedPair, .tFault)
            If $$$ISERR(tGateSC) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tGateSC))
                Quit
            }
            If $IsObject(tFault) {
                If tFault.%Get("code") = ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE {
                    Set tSC = ..NotFound()
                } Else {
                    Set tSC = ##class(OcuPilot.Api.Error).Render(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, tFault.%Get("reason"), tFault.%Get("code"))
                }
                Quit
            }
        }
        Set tRowsSC = ##class(OcuPilot.Kernel.State.Entry).GuardedRows(pId, .tRows, 1)
        If $$$ISERR(tRowsSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tRowsSC))
            Quit
        }
        Set tTurns = []
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Do tTurns.%Push(..TurnObject(tRow, tReleased))
        }
        Set tView = {}
        Do tView.%Set("conversationId", pId, "string")
        Do tView.%Set("user", tOwner, "string")
        Do tView.%Set("own", tOwn, "boolean")
        Do tView.%Set("released", ''tReleased, "boolean")
        Do tView.%Set("failedPair", tFailedPair, "string")
        Do tView.%Set("turns", tTurns)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tView)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>One stored entry <var>pRow</var> as the wire turn: its error's reason added from the code
/// (the state package does not name this layer's vocabulary, AD-9), and its steps and context
/// dropped unless <var>pReleased</var>.</p>
ClassMethod TurnObject(pRow As %DynamicObject, pReleased As %Boolean) As %DynamicObject [ Private ]
{
    Set tTurn = {}
    Do tTurn.%Set("seq", +pRow.%Get("seq"), "number")
    Do ..Copy(pRow, tTurn, "appendedAt")
    Do tTurn.%Set("message", pRow.%Get("message"), "string")
    Do tTurn.%Set("state", pRow.%Get("state"), "string")
    Do ..Copy(pRow, tTurn, "reply")
    If $IsObject(pRow.%Get("error")) {
        Set tError = pRow.%Get("error")
        Do tError.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForTurnError(tError.%Get("code")), "string")
        Do tTurn.%Set("error", tError)
    } Else {
        Do tTurn.%Set("error", "", "null")
    }
    If pReleased {
        Do tTurn.%Set("steps", pRow.%Get("steps"))
        Do ..Copy(pRow, tTurn, "context")
    } Else {
        Do tTurn.%Set("steps", [])
        Do tTurn.%Set("context", "", "null")
    }
    Quit tTurn
}

/// <p>Copy member <var>pKey</var> of <var>pFrom</var> onto <var>pTo</var>, JSON null included.</p>
ClassMethod Copy(pFrom As %DynamicObject, pTo As %DynamicObject, pKey As %String) [ Private ]
{
    Set tType = pFrom.%GetTypeOf(pKey)
    If (tType = "null") || (tType = "unassigned") {
        Do pTo.%Set(pKey, "", "null")
        Quit
    }
    If (tType = "object") || (tType = "array") {
        Do pTo.%Set(pKey, pFrom.%Get(pKey))
        Quit
    }
    Do pTo.%Set(pKey, pFrom.%Get(pKey), tType)
}

/// <p>The one 404 an unknown conversation and a refused one share (AD-33).</p>
ClassMethod NotFound() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONTURNCONVERSATIONNOTFOUND, ##class(OcuPilot.Api.Error).#TURNCONVERSATIONNOTFOUND)
}

}
