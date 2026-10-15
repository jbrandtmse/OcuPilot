/// <p>The handler behind <code>POST /api/ocupilot/screens/:screen/dryrun</code>: the review of a person's own action before it is
/// sent (AD-53, Story 20.31). The body is the action route's own, <code>{action, id, values?}</code>.</p>
/// <p><b>It resolves the action exactly as the action route does</b> (<method>OcuPilot.Api.ScreenAction.DryRun</method>): the same
/// descriptor, declared action, write tool, value channel, pair gate, fresh read and body, so the rows it answers are the rows the
/// agent's proposal card shows for the same action, and a request that route would refuse is refused here with the same envelope.
/// It stops before the write. It holds no target, writes nothing and asks no prohibited set.</p>
/// <p>An unreadable body, or one with no <code>action</code>, is 400 <code>TOOL.ARGUMENTS</code> before anything is read; a body key
/// beyond the route's three and a value the action declares secret, which this route never takes, are 400 as well. An action whose
/// tool does not declare <parameter>OcuPilot.Screen.Tool.Write.DRYRUN</parameter> is the framework's 404.</p>
/// <p>It answers <code>{rows, review}</code>: <code>rows</code> are the preview's diff and <code>review</code> is what the tool
/// answers beside them (<method>OcuPilot.Screen.Tool.Write.DryRunReview</method>).</p>
Class OcuPilot.Api.ScreenDryRun Extends %RegisteredObject
{

/// <p>Answer the request for <var>pScreen</var>, a <code>toolIdentifier</code>.</p>
ClassMethod Handle(pScreen As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tDescriptor = $ClassMethod(##class(OcuPilot.Api.ScreenAction).RegistryClass(), "DescriptorForTool", pScreen)
        If tDescriptor = "" {
            Set tSC = ..NotFound()
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) {
            If tStage = "parse" {
                Set tSC = ..Refuse("the body is not a JSON object naming the action")
            } Else {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            }
            Quit
        }
        If '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ..Refuse("the body is not a JSON object naming the action")
            Quit
        }
        Set tStrayKey = ""
        Set tKeyIterator = tBody.%GetIterator()
        While tKeyIterator.%GetNext(.tBodyKey, .tBodyValue) {
            If '$ListFind($ListBuild("action", "id", "values"), tBodyKey) Set tStrayKey = tBodyKey
        }
        If tStrayKey '= "" {
            Set tSC = ..Refuse("'" _ tStrayKey _ "' is not a key this route accepts")
            Quit
        }
        If tBody.%GetTypeOf("action") '= "string" || (tBody.%Get("action") = "") {
            Set tSC = ..Refuse("'action' names the row action and is required")
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.ScreenAction).DryRun(tDescriptor, tBody, .tPreview)
        If '$IsObject($Get(tPreview)) Quit
        Set tOut = {}
        Do tOut.%Set("rows", tPreview.%Get("diff"))
        Do tOut.%Set("review", tPreview.%Get("review"))
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tOut)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The framework's not-found envelope: an unknown screen.</p>
ClassMethod NotFound() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
}

/// <p>400 <code>TOOL.ARGUMENTS</code> with <var>pProblem</var> as <code>detail.problem</code>, the shape the action route refuses
/// its own malformed requests in.</p>
ClassMethod Refuse(pProblem As %String) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("problem", pProblem, "string")
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tDetail)
}

}
