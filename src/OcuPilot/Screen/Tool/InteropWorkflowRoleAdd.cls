/// <p>Interoperability's workflow role add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 24.17 Batch 3b): add one workflow role to the request's namespace, with an optional description and capacity. Two
/// callers reach it: the Workflow roles list's New workflow role dialog through <class>OcuPilot.Area.Interop.WorkflowRoleSave</class>, and the agent's proposal and confirmation. The role is stored
/// at once; it has no members until some are added.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no workflow role of that name in any letter case, so a name added since the mint reads present at the confirm's re-read and closes the
/// proposal target-changed. A namespace under source control refuses it.</p>
/// <p><b>Its payload</b> is the name and the fields the caller supplies and the namespace the add was composed in (<method>ComposeCreate</method>); its read-back compares the description and the
/// capacity (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowRoleAdd Extends OcuPilot.Screen.Tool.InteropWorkflowRoleAction
{

Parameter TOOLNAME = "interop.workflowroles.add";

Parameter DESCRIPTION = "Propose adding one workflow role to the namespace the user is working in. A workflow role is a group of workflow users who are sent the same tasks; a new role has no members until some are added. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the role's name, 1 to 128 characters with no control character, which cannot be changed afterwards, and optionally a description of at most 2,000 characters and a capacity, a whole number from 1 to 100, which is 100 when left out. A name the namespace already holds in any letter case, and a namespace under source control, are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDWORKFLOWROLE";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends that a read answers (AD-58).</p>
Parameter READBACKFIELDS = "Description,Capacity";

/// <p>The read-back re-reads the created workflow role through the update's single-object read, because the add's own read asks for the add and answers a held name as
/// <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropWorkflowRoleUpdate";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.ROLETAKEN,INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Name,Description,Capacity";

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
    Quit ..WorkflowRoleFieldRows(1, .pRows)
}

/// <p>What the schema says of the new workflow role's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new workflow role's name: 1 to 128 characters with no control character. It cannot be changed afterwards. A name the namespace already holds, in any letter case, is refused, so check the Workflow roles list first."
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

/// <p>The name of the workflow role the confirmed add <var>pWritten</var> created, or <code>""</code>: the id its read-back re-reads it by.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Name") '= "string" Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The add always asks its read for the add (<method>OcuPilot.Screen.Tool.InteropWorkflowRoleAction.PortQuery</method>): a name held in any letter case is <code>TAKEN</code> and absent is the
/// 404 a create expects (AD-54), at the mint and at the confirm alike.</p>
Parameter READASKSACTION As BOOLEAN = 1;

}
