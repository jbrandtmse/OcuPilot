/// <p>What Interoperability's two workflow member writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.17 Batch 3b): a write of one membership of one workflow role of the request's namespace
/// through <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Role members list's Add member and its row action Remove, and the agent's proposal and confirmation. The port
/// writes it with the vendor's own <code>AddUserToRole</code> and <code>RemoveUserFromRole</code>, as the classic dialogs do. The target is the composite <code>[Role, User]</code>
/// (<class>OcuPilot.Screen.Tool.InteropWorkflowMemberMint</class>), each part kept exactly (AD-13).</p>
/// <p><b>A membership has no edit</b>: the classic page has none, so a rank or a title is changed by removing the member and adding them again.</p>
/// <p><b>It declares</b> <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the namespace's globals database beyond the screen's pairs (AD-8, AD-62), each refused by name before any
/// port call. The vendor checks no privilege of its own beyond the database and records no audit row of its own (measured).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowMemberAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowMemberList";

/// <p>The fresh read: one membership, composed for the action.</p>
Parameter READTYPE = "WORKFLOWMEMBER";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Role,User,FullName,Ranking,Title,IsActive,Namespace";

Parameter WRITERESOURCE = "%Ens_WorkflowConfig";

/// <p>The classic page whose own resource an operator may have assigned beyond the screen's (AD-8, AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.WFRoles";

/// <p>The read field a call's arguments do not carry and the stored payload does: the namespace.</p>
Parameter STATEMARKER = "Namespace";

/// <p>The argument naming the workflow role the membership belongs to.</p>
Parameter ROLEARGUMENT = "Role";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTWORKFLOWMEMBERS
}

/// <p><class>OcuPilot.Screen.Tool.InteropWorkflowMemberMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropWorkflowMemberMint"
}

/// <p>The member's user name, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "User"
}

/// <p>Whether the tool's read always asks for its action (<method>PortQuery</method>), at the confirm and the read-back as at the mint, so a namespace under source control is refused
/// before anything is claimed. The add declares 1; the remove asks only for the action its arguments carry, as the superclass does.</p>
Parameter READASKSACTION As BOOLEAN = 0;

/// <p>The superclass's read, with the action asked for always when <parameter>READASKSACTION</parameter>: a user who is not a workflow user of the namespace and a user already a member are
/// refused for an add, and a namespace under source control is refused for each write. The namespace is the payload's, else the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If ..#READASKSACTION Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    Do ##super(pPayload, .pQuery)
}

/// <p>The member's user name, which the card titles it by: the fresh read's <code>User</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("User") = "string") Quit pFresh.%Get("User")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("User") = "string") Quit pArgs.%Get("User")
    Quit ""
}

/// <p>What the schema says of the member's user name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The member's user name, exactly as the role's members list reports it in its User column. A member the list does not report is refused."
}

/// <p>The derived schema with the role added and required, and the user described: the target is one member of one workflow role.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#ROLEARGUMENT, {"type": "string", "description": "The workflow role the member belongs to, named exactly as this namespace's Workflow roles list reports it in its Name column, letter case included."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#ROLEARGUMENT)
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p>The rank and the title as field rows the input schema is derived from (AD-3), with the user first when <var>pWithUser</var>. The port has no body template to derive them from.</p>
ClassMethod WorkflowMemberFieldRows(pWithUser As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    If pWithUser Set pRows($Increment(pRows)) = $ListBuild("User", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Ranking", "number", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Title", "string", 0)
    Quit $$$OK
}

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code> (AD-55):
/// <method>OcuPilot.Port.InteropPort.WorkflowMemberViolations</method> over the id's role and user and the arguments' fields. The screen's Save and the mint apply them alike. A remove has no
/// fields to judge.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 2 Quit $$$OK
    Set tSC = $ClassMethod(..#PORTCLASS, "WorkflowMemberViolations", $List(tParts, 1), $List(tParts, 2), pArgs, .tViolations, 1)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

}
