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
/// <code>{conversationId, turns:[{seq, message, state, reply, error, steps, stepsDropped}]}</code>.
/// An id the caller does not own, matched exactly, is 404
/// <code>TURN.CONVERSATION.NOTFOUND</code>, the same as an unknown one. Each turn's
/// <code>error.reason</code> is added here, from the code
/// <method>OcuPilot.Kernel.State.Convo.GuardedView</method> answers -- that package does not name
/// this class (AD-9's re-entry rule).</p>
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
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tView)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
