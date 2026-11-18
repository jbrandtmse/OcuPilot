/// <p>Global nodes' route (Story 21.5): <code>POST /explorer/globals/nodes</code>, answering this screen only (AD-36, AD-39). In order: the
/// screen gate (<method>Gate</method>); the body's shape (<method>OcuPilot.Port.GlobalPort.PageRequest</method>); and the page
/// (<method>OcuPilot.Port.GlobalPort.Page</method>), which gates again and reads only the caller's namespace.</p>
/// <p>Nothing of the request or the nodes is logged. The answer never enters screen context, a tool, the ledger or an audit payload.</p>
Class OcuPilot.Area.Explorer.GlobalNodes Extends %RegisteredObject
{

/// <p>The screen the route answers for.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerGlobalView";

/// <p>The port that reads a page.</p>
Parameter PORTCLASS = "OcuPilot.Port.GlobalPort";

/// <p>Answer <code>POST /explorer/globals/nodes</code> in the request's scope with the port's page: <code>{rows, next, cut}</code>. A
/// refusal is one envelope: 403 <code>AUTH.NOPRIVILEGE</code> naming the pair, 400 <code>PORT.VALIDATION</code>, the port's own refusals,
/// or 500.</p>
ClassMethod HandleNodes() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tSC) Quit
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage, .tBodyField)
        If $$$ISERR(tReadSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderBodyRefusal(tBodyField)
            Quit
        }
        If '$ClassMethod(..#PORTCLASS, "PageRequest", $Get(tBody), .tRequest) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, $Parameter(..#PORTCLASS, "REASONPAGE"), ##class(OcuPilot.Api.Error).#PORTVALIDATION)
            Quit
        }
        Set tPageSC = $ClassMethod(..#PORTCLASS, "Page", ##class(OcuPilot.Kernel.Scope).Current(), tRequest, .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tPageSC) {
            Set tSC = ##class(OcuPilot.Area.Explorer.SqlConsole).RenderFault(tPageSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the global nodes' read failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Refuse a caller who does not hold the screen's pairs, the custom resource on its own classic page among them (AD-8, AD-44):
/// <var>pRefused</var> 1 means the envelope is written. A requirement that could not be read is refused too.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .tResolved)
    If tResolved && ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
