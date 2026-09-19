/// <p>The handler behind the two <code>/proposal/:id</code> routes (Story 5.3, AD-12, AD-39):
/// confirm a proposal, and cancel one. Every caller has cleared
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>; every proposal is the caller's own, the same
/// discipline <class>OcuPilot.Api.Turn</class> already holds a turn to.</p>
/// <p><b>Nothing is decided here.</b> Whether the write may happen is
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>'s, inside its own atomic transition (AD-34,
/// AD-40); this class reads the caller, parses the body, delegates, and renders exactly one
/// envelope.</p>
/// <p><b>The caller is <code>$Username</code> and the proposal id is the route's.</b> Neither is
/// ever taken from the body, and the body carries only the fields the target screen declares
/// secret-typed for that tool -- a closed channel the kernel refuses anything else on (AD-6).</p>
Class OcuPilot.Api.Confirm Extends %RegisteredObject
{

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>POST /proposal/:id/confirm</code>: claim proposal <var>pId</var> for the caller
/// and issue the stored write. 200 with <code>{proposalId, state, closedReason, confirmedAt}</code>
/// on success; one refusal envelope otherwise, carrying the kernel's own code.</p>
ClassMethod HandleConfirm(pId As %String) As %Status
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
        ; No body at all is the ordinary shape: a tool with no declared secret-typed field takes
        ; nothing from the client at confirmation.
        If (tBody '= "") && ('$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject")) {
            Set tSC = ..RenderBadBody()
            Quit
        }
        Set tConfirmSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(pId, tBody, ..CallerUsername(), .tResult, .tHttpStatus, .tCode, .tDetail)
        If $$$ISERR(tConfirmSC) {
            Set tSC = ..RenderRefusal(tConfirmSC, tHttpStatus, tCode, tDetail)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /proposal/:id/cancel</code>: close the caller's own live proposal
/// <var>pId</var> with reason <code>you</code>. The same answer shape as
/// <method>HandleConfirm</method>; a row that is already terminal and an id nobody minted are the
/// same 404.</p>
ClassMethod HandleCancel(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCancelSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Cancel(pId, ..CallerUsername(), .tResult, .tHttpStatus, .tCode)
        If $$$ISERR(tCancelSC) {
            Set tSC = ..RenderRefusal(tCancelSC, tHttpStatus, tCode, "")
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Render one refusal envelope for the kernel's <var>pCode</var> at <var>pHttpStatus</var>, with
/// <var>pDetail</var> when the code owns one.</p>
/// <p>A stale-save refusal from OcuPilot's own state is
/// <parameter>OcuPilot.Api.Error.STATECONFLICT</parameter>, the answer every other handler gives it;
/// a code the kernel did not name at all is an internal error, never an envelope with an empty
/// <code>code</code>.</p>
ClassMethod RenderRefusal(pStatus As %Status, pHttpStatus As %Integer, pCode As %String, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    If ##class(OcuPilot.Kernel.State.Base).IsStaleSave(pStatus) {
        Quit ##class(OcuPilot.Api.Error).Render(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#REASONSTATECONFLICT, ##class(OcuPilot.Api.Error).#STATECONFLICT)
    }
    If (pCode = "") || (pCode = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pStatus))
    }
    Set tHttp = +pHttpStatus
    If tHttp < 400 Set tHttp = 500
    Quit ##class(OcuPilot.Api.Error).Render(tHttp, ..SlugFor(tHttp), ..ReasonFor(pCode), pCode, pDetail)
}

/// <p>The coarse slug <var>pHttpStatus</var> is rendered under, from
/// <class>OcuPilot.Api.Error</class>'s own closed enum. No new slug is declared for confirm: its
/// refusals are ordinary bad requests, forbiddens, not-founds and conflicts.</p>
ClassMethod SlugFor(pHttpStatus As %Integer) As %String [ Private ]
{
    If pHttpStatus = 400 Quit ##class(OcuPilot.Api.Error).#BADREQUEST
    If pHttpStatus = 403 Quit ##class(OcuPilot.Api.Error).#FORBIDDEN
    If pHttpStatus = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    If pHttpStatus = 409 Quit ##class(OcuPilot.Api.Error).#CONFLICT
    If pHttpStatus = 503 Quit ##class(OcuPilot.Api.Error).#UNAVAILABLE
    If pHttpStatus = 501 Quit ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED
    Quit ##class(OcuPilot.Api.Error).#SERVERERROR
}

/// <p>The written sentence <var>pCode</var> carries: the proposal family's own
/// (<method>OcuPilot.Kernel.Proposal.Write.ReasonFor</method>), else the tool-result vocabulary's,
/// which is where the restraint codes and <code>AUTH.NOPRIVILEGE</code> already live.</p>
ClassMethod ReasonFor(pCode As %String) As %String [ Private ]
{
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(pCode)
    If tReason '= "" Quit tReason
    Quit ##class(OcuPilot.Api.Error).ReasonForToolCode(pCode)
}

/// <p>Render the unreadable-body refusal, the same envelope every other JSON handler gives it.</p>
ClassMethod RenderBadBody() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
}

}
