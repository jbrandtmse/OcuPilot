/// <p>The handler behind the two <code>/conversation</code> routes (Story 4.5, AD-9, AD-19): create
/// a conversation and read one back. Every caller has cleared
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>; every conversation is the caller's own, the
/// same discipline <class>OcuPilot.Api.Turn</class> already holds a turn to.</p>
Class OcuPilot.Api.Conversation Extends %RegisteredObject
{

/// <p>Seconds <method>HandleCreate</method> waits for the new row's lock. A fresh, never-shared
/// row is not contended in practice; the wait exists only so a failure here answers the same
/// class of error a load's failure would.</p>
Parameter LOCKTIMEOUT As %Integer = 5;

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>POST /conversation</code>: create a conversation for the caller and answer 201
/// <code>{conversationId}</code>. Uses <method>OcuPilot.Kernel.State.Convo.LoadOrCreate</method>'s
/// create branch and releases the lock at once -- nothing here holds it the way a running turn
/// does.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tUser = ..CallerUsername()
        Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, ..#LOCKTIMEOUT, .tStatus, .tLockConflict)
        If '$IsObject(tConvo) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tStatus))
            Quit
        }
        Set tKey = tConvo.ConvKey
        Set tConvo = ""
        Set tAnswer = {}
        Do tAnswer.%Set("conversationId", tKey, "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /conversation/:id</code> for the caller's own conversation:
/// <code>{conversationId, turns:[{seq, message, state, reply, error, steps, stepsDropped,
/// proposals}]}</code>. An id the caller does not own, matched exactly, is 404
/// <code>TURN.CONVERSATION.NOTFOUND</code>, the same as an unknown one. Each turn's
/// <code>error.reason</code> is added here, from the code
/// <method>OcuPilot.Kernel.State.Convo.GuardedView</method> answers -- that package does not name
/// this class (AD-9's re-entry rule).</p>
/// <p><b>Each turn's <code>proposals</code> is attached here too, and for the same reason</b>
/// (AD-9, AD-37): the assembly is two guarded storage reads joined outside every escalated frame,
/// which is what AD-9's re-entry rule requires, and it is the shape
/// <method>OcuPilot.Api.Turn.HandleProgress</method> already uses to hang a turn's proposals off
/// the progress view. The rows are the same wire projection the poll carries
/// (<method>OcuPilot.Kernel.State.Propose.GuardedRowsForConvo</method>), read once for the whole
/// transcript rather than once per turn.</p>
/// <p><b>A proposal store that cannot be read degrades to no proposals</b>, logged: a card the
/// panel cannot draw is a card that does not appear, never a conversation read that fails. An
/// entry appended before the turn key was stored reads <code>""</code> and answers the same
/// way.</p>
ClassMethod HandleRead(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tUser = ..CallerUsername()
        Set tViewSC = ##class(OcuPilot.Kernel.State.Convo).GuardedView(pId, tUser, .tFound, .tView)
        If $$$ISERR(tViewSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tViewSC))
            Quit
        }
        If 'tFound {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONTURNCONVERSATIONNOTFOUND, ##class(OcuPilot.Api.Error).#TURNCONVERSATIONNOTFOUND)
            Quit
        }
        Set tTurns = tView.%Get("turns")
        If $IsObject(tTurns) && tTurns.%IsA("%Library.DynamicArray") {
            Set tIterator = tTurns.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tTurn) {
                If $IsObject(tTurn) && $IsObject(tTurn.%Get("error")) {
                    Do tTurn.error.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForTurnError(tTurn.error.code), "string")
                }
            }
        }
        Do ..AttachProposals(pId, tUser, tView)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tView)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Hang each turn's own <code>proposals[]</code> off <var>pView</var>, in place: the wire rows
/// <method>OcuPilot.Kernel.State.Propose.GuardedRowsForConvo</method> answers for conversation
/// <var>pId</var> owned by <var>pUser</var>, matched to each turn by the key
/// <method>OcuPilot.Kernel.State.Entry.GuardedTurnKeys</method> answers for that turn's own
/// <code>seq</code> -- never by position in the array, since
/// <method>OcuPilot.Kernel.State.Entry.GuardedRows</method> drops an entry it cannot open and a
/// single such row would otherwise shift every later turn onto the previous turn's proposals.</p>
/// <p><b>Never a failure of the read it decorates.</b> Either guarded read failing leaves every
/// turn with an empty array and logs why -- the degradation the caller contract above states.</p>
ClassMethod AttachProposals(pId As %String, pUser As %String, pView As %DynamicObject) [ Private ]
{
    Try {
        Set tTurns = pView.%Get("turns")
        If '$IsObject(tTurns) || 'tTurns.%IsA("%Library.DynamicArray") Quit
        Kill tByTurn
        Set tProposalSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForConvo(pId, pUser, .tByTurn)
        If $$$ISERR(tProposalSC) {
            Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "a conversation's proposals could not be read", tProposalSC, ##class(OcuPilot.Api.Error).#INTERNAL)
            Kill tByTurn
        }
        Set tKeysSC = ##class(OcuPilot.Kernel.State.Entry).GuardedTurnKeys(pId, .tKeys)
        If $$$ISERR(tKeysSC) {
            Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "a conversation's turn keys could not be read", tKeysSC, ##class(OcuPilot.Api.Error).#INTERNAL)
            Kill tKeys
        }
        For tI = 0:1:tTurns.%Size() - 1 {
            Set tTurn = tTurns.%Get(tI)
            If '$IsObject(tTurn) Continue
            Set tKey = $Get(tKeys(+tTurn.%Get("seq")))
            Set tRows = []
            If (tKey '= "") && $Data(tByTurn(tKey)) Set tRows = tByTurn(tKey)
            Do tTurn.%Set("proposals", tRows)
        }
    } Catch ex {
        Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "a conversation's proposals could not be attached", ex.AsStatus(), ##class(OcuPilot.Api.Error).#INTERNAL)
    }
}

}
