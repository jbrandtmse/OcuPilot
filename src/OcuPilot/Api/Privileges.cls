/// <p>The handlers behind <code>GET /users/effective</code> and <code>GET /permissions/check</code>
/// (Story 16.3, FR-74): the user editor's Effective privileges tab and the command-bar permission
/// check.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: each reads its query parameters and hands
/// them to the kernel -- <method>OcuPilot.Kernel.Shell.EffectiveUser.Of</method> and
/// <method>OcuPilot.Kernel.Shell.PermissionCheck.Check</method>, the operation the
/// <code>permissions.privileges.check</code> tool also answers through -- and writes the answer
/// through <class>OcuPilot.Api.Response</class> or the refusal through
/// <class>OcuPilot.Api.Error</class> (AD-12). Neither gates on its own: the kernel does, as the
/// caller (AD-8).</p>
Class OcuPilot.Api.Privileges Extends %RegisteredObject
{

/// <p>Answer <code>GET /users/effective?name=&lt;user&gt;</code>.</p>
ClassMethod HandleEffective() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCallSC = ##class(OcuPilot.Kernel.Shell.EffectiveUser).Of($Get(%request.Data("name", 1)), .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tCallSC) {
            Set tSC = ..Refusal(tCallSC, tHttp, tFault)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /permissions/check?kind=&amp;name=&amp;resource=&amp;permission=</code>.</p>
ClassMethod HandleCheck() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCallSC = $ClassMethod(..CheckClass(), "Check", $Get(%request.Data("kind", 1)), $Get(%request.Data("name", 1)), $Get(%request.Data("resource", 1)), $Get(%request.Data("permission", 1)), .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tCallSC) {
            Set tSC = ..Refusal(tCallSC, tHttp, tFault)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The class whose <code>Check</code> answers <method>HandleCheck</method>. A seam, so a fixture
/// can drive the shipped handler over a cut read.</p>
ClassMethod CheckClass() As %String
{
    Quit "OcuPilot.Kernel.Shell.PermissionCheck"
}

/// <p>Render a kernel refusal: its own status and fault, or the generic internal envelope, with the
/// status logged, when it carries no fault or an internal one.</p>
ClassMethod Refusal(pStatus As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status [ Private ]
{
    If '$IsObject(pFault) || ((+pHttpStatus >= 500) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL)) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pStatus))
    }
    Quit ##class(OcuPilot.Api.Error).Render(+pHttpStatus, pFault.%Get("error"), pFault.%Get("reason"), pFault.%Get("code"), $Select(pFault.%GetTypeOf("detail") = "object": pFault.%Get("detail"), 1: ""))
}

}
