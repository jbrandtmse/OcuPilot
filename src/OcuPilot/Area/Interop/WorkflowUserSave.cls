/// <p>Workflow users' New workflow user (AD-55, AD-54, Story 24.17 Batch 3a): <code>POST /interop/workflow-users</code> adds one workflow user to the request's namespace through
/// <class>OcuPilot.Screen.Tool.InteropWorkflowUserAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a workflow
/// user belongs to its namespace, so the member is the name alone (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the user's name, its absence
/// read, the prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code> and, optionally, <code>FullName</code> and
/// <code>IsActive</code>; any other member is 400 <code>PORT.FIELD.UNEXPECTED</code>, so a name cannot be changed through this route.</p>
/// <p>The rules over the name's shape and the fields are <method>OcuPilot.Port.InteropPort.WorkflowViolations</method>'s, which reads no vendor class; whether the instance offers the name
/// is judged by the port's add and its absence read, after the gate.</p>
Class OcuPilot.Area.Interop.WorkflowUserSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropWorkflowUserAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowUserList";

/// <p>Empty: a workflow user has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "INTEROP.WORKFLOW.USERNAME";

Parameter TAKENCODE = "INTEROP.WORKFLOW.USERTAKEN";

Parameter TAKENREASON = "This namespace already has a workflow user with that name, in some letter case.";

/// <p>Answer <code>GET /interop/workflow-users/choices</code>: the users of the instance a new workflow user may take in the request's namespace, as
/// <code>{rows}</code> of <code>{Name, Namespace}</code>, which the New workflow user dialog offers its Name from (AD-62). It is the port's <code>WORKFLOWUSERCHOICES</code> read, behind
/// the same pairs as the add: a caller short of one is refused naming it, by <method>Gate</method> and by the port. It writes nothing.</p>
ClassMethod HandleChoices() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", ##class(OcuPilot.Port.InteropPort).#ENDPOINTWORKFLOWUSERS, ##class(OcuPilot.Port.InteropPort).#TYPEWORKFLOWUSERCHOICES, .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If '$IsObject($Get(tFault)) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("rows", $Select($IsObject($Get(tRows)): tRows, 1: []))
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The rules over the workflow user's name and fields, which call no vendor class.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "WorkflowViolations", pName, pFields, .pViolations, 1)
}

}
