/// <p>Interoperability's workflow user add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 24.17 Batch 3a): add one workflow user to the request's namespace, from the users of the instance, with an
/// optional full name and active state. Two callers reach it: the Workflow users list's New workflow user dialog through <class>OcuPilot.Area.Interop.WorkflowUserSave</class>, and the
/// agent's proposal and confirmation. The user is stored at once; it grants no privilege and receives no task until a workflow role names it.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no workflow user of that name in any letter case and the name must be one the instance's user choices answer exactly, so a name added
/// since the mint reads present at the confirm's re-read and closes the proposal target-changed. A namespace under source control refuses it.</p>
/// <p><b>Its payload</b> is the name and the fields the caller supplies and the namespace the add was composed in (<method>ComposeCreate</method>); its read-back compares the full name and the
/// active state (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowUserAdd Extends OcuPilot.Screen.Tool.InteropWorkflowUserAction
{

Parameter TOOLNAME = "interop.workflowusers.add";

Parameter DESCRIPTION = "Propose adding one workflow user to the namespace the user is working in. A workflow user is a user of this instance who can be sent workflow tasks through the workflow roles they belong to; adding one gives no task by itself. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the user's name, which cannot be changed afterwards and which must be one the instance offers for a workflow user, spelled as it offers it, and optionally a full name of at most 128 characters and whether the user is active, which is the default. A name the instance does not offer, a name the namespace already holds in any letter case and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDWORKFLOWUSER";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends that a read answers (AD-58).</p>
Parameter READBACKFIELDS = "FullName,IsActive";

/// <p>The read-back re-reads the created workflow user through the update's single-object read, because the add's own read asks for the add and answers a held name as
/// <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropWorkflowUserUpdate";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.USERTAKEN,INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Name,FullName,IsActive";

/// <p>An add judges the name it is given.</p>
Parameter JUDGESNAME As BOOLEAN = 1;

/// <p>The name and the two fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The three fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..WorkflowFieldRows(1, .pRows)
}

/// <p>What the schema says of the new workflow user's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new workflow user's name: a user of this instance, spelled exactly as the instance offers it for a workflow user. It cannot be changed afterwards. A name the namespace already holds, in any letter case, is refused, so check the Workflow users list first."
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>The composed payload and diff of the create (AD-54): the name and the fields the caller supplied, as the kernel's <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them,
/// and the namespace the request is scoped to, which the port query and the prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the workflow user the confirmed add <var>pWritten</var> created, or <code>""</code>: the id its read-back re-reads it by.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Name") '= "string" Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The add always asks its read for the add (<method>OcuPilot.Screen.Tool.InteropWorkflowUserAction.PortQuery</method>): a name the instance does not offer is refused, present in any letter
/// case is <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the confirm alike.</p>
Parameter READASKSACTION As BOOLEAN = 1;

}
