/// <p>Interoperability's workflow role update (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 24.17 Batch 3b): change the description or the capacity of one workflow role of the request's
/// namespace. The change is stored at once. <b>The name cannot be changed</b>: to rename a workflow role, remove it and add the new name; <b>nor are its members edited here</b>.</p>
/// <p>Two callers reach it: the Workflow roles list's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose dialog sends the fields it changed, and the agent's proposal and
/// confirmation. It is a merge over the workflow role's fresh read, so its card shows one row for each field it moves and its read-back compares the two fields
/// (<parameter>READBACKFIELDS</parameter>).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowRoleUpdate Extends OcuPilot.Screen.Tool.InteropWorkflowRoleAction
{

Parameter TOOLNAME = "interop.workflowroles.update";

Parameter DESCRIPTION = "Propose changing the description or the capacity of one workflow role of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the workflow role exactly as the Workflow roles list reports it, and give only the fields to change; a description sent as an empty string is cleared and a field left out is kept. The capacity is a whole number from 1 to 100. The name and the members cannot be changed by this tool. A description over 2,000 characters, a capacity outside 1 to 100, a workflow role the namespace does not hold and a namespace under source control are refused.";

Parameter WRITETYPE = "SETWORKFLOWROLE";

/// <p>The update sends a body: the workflow role's row with the new values (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "edit";

/// <p>The dialog's values are the two fields (AD-56 (ii)); the name is the target. The capacity is sent as its number.</p>
Parameter SCREENVALUES = "edit=Description:Capacity";

/// <p>The description may be empty: clearing it is the request.</p>
Parameter SCREENEMPTY = "edit=Description";

/// <p>The dialog sends the fields it changed and no other: a value left out keeps what the workflow role holds, so a change made elsewhere to another field since the list was read is kept
/// (AD-4, AD-56).</p>
Parameter SCREENOPTIONAL = "edit=Description:Capacity";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "Description,Capacity";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The edit always asks its read for the edit, so a namespace under source control is refused before anything is claimed.</p>
Parameter READASKSACTION As BOOLEAN = 1;

/// <p>The two fields an update may set.</p>
Parameter FIELDS = "Description,Capacity";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The two fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..WorkflowRoleFieldRows(0, .pRows)
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>No state rows: a merge's card shows the values it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and a workflow role nobody established is refused by the fresh
/// read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's values as this tool's arguments: the description as sent, an empty one included, and the capacity as the number its text names; a capacity text that is no number is
/// <var>pProblem</var>, with the sentence the port publishes for it. The port judges the rest.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    If pValues.%GetTypeOf("Description") = "string" Do pArgs.%Set("Description", pValues.%Get("Description"), "string")
    If pValues.%GetTypeOf("Capacity") = "string" {
        If '$IsValidNum(pValues.%Get("Capacity")) {
            Set pProblem = $ClassMethod(..#PORTCLASS, "ReasonFor", "INTEROP.WORKFLOW.ROLECAPACITY")
        } Else {
            Do pArgs.%Set("Capacity", +pValues.%Get("Capacity"), "number")
        }
    }
    Quit $$$OK
}

}
