/// <p>Interoperability's workflow user update (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 24.17 Batch 3a): change the full name or the active state of one workflow user of the request's
/// namespace. The change is stored at once. Making a user inactive deletes their worklist and leaves each task they hold unassigned (<code>INTEROP.WORKFLOW.USERINACTIVE</code>).
/// <b>The name cannot be changed</b>: to rename a workflow user, remove it and add the new name.</p>
/// <p>Two callers reach it: the Workflow users list's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose dialog sends the fields it changed, and the agent's proposal and
/// confirmation. It is a merge over the workflow user's fresh read, so its card shows one row for each field it moves and its read-back compares the two fields
/// (<parameter>READBACKFIELDS</parameter>).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowUserUpdate Extends OcuPilot.Screen.Tool.InteropWorkflowUserAction
{

Parameter TOOLNAME = "interop.workflowusers.update";

Parameter DESCRIPTION = "Propose changing the full name or the active state of one workflow user of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the workflow user exactly as the Workflow users list reports it, and give only the fields to change; a full name sent as an empty string is cleared and a field left out is kept. Making a user inactive stops new tasks reaching them through their workflow roles, deletes their worklist and leaves each task they hold unassigned. The name cannot be changed by this tool. A full name over 128 characters or holding a control character, a workflow user the namespace does not hold and a namespace under source control are refused.";

Parameter WRITETYPE = "SETWORKFLOWUSER";

/// <p>The update sends a body: the workflow user's row with the new values (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter CONSEQUENCECODE = "INTEROP.WORKFLOW.USERINACTIVE";

Parameter SCREENACTIONS = "edit";

/// <p>The dialog's values are the two fields (AD-56 (ii)); the name is the target. The active state is sent as <code>true</code> or <code>false</code>.</p>
Parameter SCREENVALUES = "edit=FullName:IsActive";

/// <p>The full name may be empty: clearing it is the request.</p>
Parameter SCREENEMPTY = "edit=FullName";

/// <p>The dialog sends the fields it changed and no other: a value left out keeps what the workflow user holds, so a change made elsewhere to another field since the list was read is kept
/// (AD-4, AD-56).</p>
Parameter SCREENOPTIONAL = "edit=FullName:IsActive";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "FullName,IsActive";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The edit always asks its read for the edit, so a namespace under source control is refused before anything is claimed.</p>
Parameter READASKSACTION As BOOLEAN = 1;

/// <p><parameter>CONSEQUENCECODE</parameter> when the payload makes an active workflow user inactive, read as the caller through this tool's port in the payload's namespace, and
/// <code>""</code> otherwise: a user already inactive, or one made active, states nothing. A read that answers no active state keeps the code.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf("IsActive") '= "boolean") || pPayload.%Get("IsActive") Quit ""
    If pPayload.%GetTypeOf("Name") '= "string" Quit ..#CONSEQUENCECODE
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.InteropPort).#IDKEY) = pPayload.%Get("Name")
    If pPayload.%GetTypeOf("Namespace") = "string" Set tQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get("Namespace")
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tHeld, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tHeld)) || (tHeld.%GetTypeOf("IsActive") '= "boolean") Quit ..#CONSEQUENCECODE
    If 'tHeld.%Get("IsActive") Quit ""
    Quit ..#CONSEQUENCECODE
}

/// <p>The two fields an update may set.</p>
Parameter FIELDS = "FullName,IsActive";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The two fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..WorkflowFieldRows(0, .pRows)
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>No state rows: a merge's card shows the values it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and a workflow user nobody established is refused by the fresh
/// read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's values as this tool's arguments: the full name as sent, an empty one included, and the active state as the boolean its <code>true</code> or <code>false</code> text names;
/// any other state text is <var>pProblem</var>. The port judges the rest.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    If pValues.%GetTypeOf("FullName") = "string" Do pArgs.%Set("FullName", pValues.%Get("FullName"), "string")
    If pValues.%GetTypeOf("IsActive") = "string" {
        If '$ListFind($ListBuild("true", "false"), pValues.%Get("IsActive")) {
            Set pProblem = "'IsActive' is true or false"
        } Else {
            Do pArgs.%Set("IsActive", (pValues.%Get("IsActive") = "true"), "boolean")
        }
    }
    Quit $$$OK
}

}
