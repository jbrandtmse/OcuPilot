/// <p>Interoperability's workflow member add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 24.17 Batch 3b): add one workflow user of the namespace to one of its workflow roles, with an optional rank and
/// title. Two callers reach it: the Role members list's Add member dialog through <class>OcuPilot.Area.Interop.WorkflowMemberSave</class>, and the agent's proposal and confirmation. The user is a
/// member at once; an active member is sent each unassigned task of the role (<code>INTEROP.WORKFLOW.MEMBERADD</code>).</p>
/// <p><b>A create</b> (AD-54): its fresh read must find the user a workflow user of the namespace, held exactly, and not yet a member, so a membership added since the mint reads present at the
/// confirm's re-read and closes the proposal target-changed. A namespace under source control refuses it.</p>
/// <p><b>Its payload</b> is the user and the fields the caller supplies and the namespace the add was composed in (<method>ComposeCreate</method>); the role is the id's first part. Its read-back
/// compares the rank and the title (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowMemberAdd Extends OcuPilot.Screen.Tool.InteropWorkflowMemberAction
{

Parameter TOOLNAME = "interop.workflowmembers.add";

Parameter DESCRIPTION = "Propose adding one workflow user to a workflow role of the namespace the user is working in. Adding a member makes the user a recipient of the role's tasks: an active member is sent each unassigned task of the role. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the role, named exactly as the Workflow roles list reports it, and the user, who must be a workflow user of the namespace named exactly as the Workflow users list reports it, and optionally a rank, a whole number from 1 to 5 where 1 is the highest, which is 3 when left out, and a title of at most 128 characters with no control character. A user who is not a workflow user, a user who is already a member, a role the namespace does not hold and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDWORKFLOWMEMBER";

/// <p>An active member is sent the role's unassigned tasks; one sentence, stated whenever the member is active.</p>
Parameter CONSEQUENCECODE = "INTEROP.WORKFLOW.MEMBERADD";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends that a read answers (AD-58).</p>
Parameter READBACKFIELDS = "Ranking,Title";

/// <p>The read-back re-reads the created membership through the remove's single-object read, because the add's own read asks for the add and answers a held membership as
/// <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropWorkflowMemberRemove";

Parameter PRECONDITIONCODES = "INTEROP.WORKFLOW.MEMBERTAKEN,INTEROP.WORKFLOW.MEMBERUSER,INTEROP.WORKFLOW.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "User,Ranking,Title";

/// <p>The user and the two fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The three fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..WorkflowMemberFieldRows(1, .pRows)
}

/// <p>What the schema says of the new member's user name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The user to add: a workflow user of this namespace, named exactly as the Workflow users list reports it in its Name column. A user who is not a workflow user, and one who is already a member of the role, are refused."
}

/// <p>The derived schema with the rank and the title described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Ranking") = "object" Do tProperties.%Get("Ranking").%Set("description", "The member's rank in the role, a whole number from 1 to 5 where 1 is the highest. Omit it to take 3. The rank and the title can decide which member a task is sent to.", "string")
    If tProperties.%GetTypeOf("Title") = "object" Do tProperties.%Get("Title").%Set("description", "The member's title in the role, as text, at most 128 characters with no control character. Omit it for none.", "string")
    Quit tSchema
}

/// <p>The composed payload and diff of the create (AD-54): the user and the fields the caller supplied, as the kernel's <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them, and
/// the namespace the request is scoped to, which the port query and the prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    ; The user is the id's second part, which the kernel leaves out of a create's payload; the consequence reads it to tell an active member from an inactive one.
    If pArgs.%GetTypeOf(pIdArgument) = "string" Do pPayload.%Set(pIdArgument, pArgs.%Get(pIdArgument), "string")
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The composite id of the membership the confirmed add <var>pWritten</var> created, or <code>""</code>: the id its read-back re-reads it by.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("Role") '= "string") || (pWritten.%GetTypeOf("User") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("Role"), pWritten.%Get("User")))
}

/// <p><parameter>CONSEQUENCECODE</parameter> when the user the payload adds is active, read as the caller through the fresh read of the user, and <code>""</code> for an inactive user, who is sent
/// nothing. A payload whose user cannot be read keeps the code.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf("User") '= "string") Quit ..#CONSEQUENCECODE
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.InteropPort).#IDKEY) = pPayload.%Get("User")
    If pPayload.%GetTypeOf("Namespace") = "string" Set tQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get("Namespace")
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ##class(OcuPilot.Port.InteropPort).#ENDPOINTWORKFLOWUSERS, ##class(OcuPilot.Port.InteropPort).#TYPEWORKFLOWUSER, .tQuery, "", .tHeld, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tHeld)) || (tHeld.%GetTypeOf("IsActive") '= "boolean") Quit ..#CONSEQUENCECODE
    If 'tHeld.%Get("IsActive") Quit ""
    Quit ..#CONSEQUENCECODE
}

/// <p>The add always asks its read for the add (<method>OcuPilot.Screen.Tool.InteropWorkflowMemberAction.PortQuery</method>): a user who is not a workflow user is refused, a membership held
/// is <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the confirm alike.</p>
Parameter READASKSACTION As BOOLEAN = 1;

}
