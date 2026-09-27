/// <p>The handler behind <code>GET /api/ocupilot/screens/:screen/impact?action=&amp;id=&amp;value=</code>:
/// the impact of a removal a screen's dialog is about to confirm (AD-8, AD-53), read fresh each
/// time the dialog opens.</p>
/// <p><b>It resolves the action exactly as the action route does</b>
/// (<method>OcuPilot.Api.ScreenAction.Preview</method>): the same descriptor, declared action,
/// write tool, value channel, pair gate, fresh read and body, and a request that route would refuse
/// is refused here with the same envelope. It also refuses a value the action declares secret,
/// which a query string would carry into access logs. It writes nothing and asks the prohibited set
/// only through <method>OcuPilot.Kernel.Proposal.Impact.Of</method>.</p>
/// <p>It answers <code>{impact}</code>: that method's object, or <code>null</code> for an action
/// whose write removes nothing it covers. <code>value</code>, where present, is the action's one
/// declared value (the role a Remove role would take).</p>
Class OcuPilot.Api.ScreenImpact Extends %RegisteredObject
{

/// <p>Answer the request for <var>pScreen</var>, a <code>toolIdentifier</code>.</p>
ClassMethod Handle(pScreen As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDescriptor = $ClassMethod(##class(OcuPilot.Api.ScreenAction).RegistryClass(), "DescriptorForTool", pScreen)
        If tDescriptor = "" {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.ScreenAction).Preview(tDescriptor, %request.Get("action"), %request.Get("id"), %request.Get("value"), .tPreview)
        If '$IsObject(tPreview) Quit
        Set tImpact = ##class(OcuPilot.Kernel.Proposal.Impact).Of(tPreview.%Get("tool"), tPreview.%Get("targetRef"), tPreview.%Get("fresh").%ToJSON(), tPreview.%Get("payload").%ToJSON(), tPreview.%Get("diff").%ToJSON())
        Set tOut = {}
        If $IsObject(tImpact) {
            Do tOut.%Set("impact", tImpact)
        } Else {
            Do tOut.%Set("impact", "", "null")
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tOut)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
