/// <p>What Interoperability's three workflow user writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.17 Batch 3a): a write of one workflow user of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Workflow users list's New workflow user and its row actions Edit and Remove, and the agent's proposal and
/// confirmation. A workflow user is a user of the instance whom workflow tasks reach through the workflow roles they belong to; the port writes it with the vendor's own <code>%Save</code>
/// and <code>%DeleteId</code>, as the classic Workflow Users page does. The target is the user's name, kept exactly (AD-13).</p>
/// <p><b>A rename cannot be expressed</b>: the name is the target, and the update's settable fields are the full name and the active state; a different name is a remove and an add.</p>
/// <p><b>It declares</b> <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the namespace's globals database beyond the screen's pairs (AD-8, AD-62), each refused by name before any
/// port call, the remove included. The vendor checks no privilege of its own beyond the database and records no audit row of its own (measured).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowUserAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowUserList";

/// <p>The fresh read: one workflow user, composed for the action.</p>
Parameter READTYPE = "WORKFLOWUSER";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,FullName,IsActive,Roles,Namespace";

Parameter WRITERESOURCE = "%Ens_WorkflowConfig";

/// <p>The classic page whose own resource an operator may have assigned beyond the screen's (AD-8, AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.WFUsers";

/// <p>The read field a call's arguments do not carry and the stored payload does: the namespace.</p>
Parameter STATEMARKER = "Namespace";

/// <p>Whether the rules over the call judge the workflow user's name: an add, whose name is new. A user already held keeps the name it has.</p>
Parameter JUDGESNAME As BOOLEAN = 0;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTWORKFLOWUSERS
}

/// <p>The family's mint, which stores the namespace in an add's or an edit's arguments. The confirm acts where the proposal read because the payload carries it (the add's composed
/// payload, the edit's fresh read, the remove's fingerprint subject).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropCredentialMint"
}

/// <p>Whether the tool's read always asks for its action (<method>PortQuery</method>), at the confirm and the read-back as at the mint, so a namespace under source control is refused
/// before anything is claimed. An add and an edit declare 1; the remove asks only for the action its arguments carry, as the superclass does.</p>
Parameter READASKSACTION As BOOLEAN = 0;

/// <p>The superclass's read, with the action asked for always when <parameter>READASKSACTION</parameter>: a name the instance does not offer, or one held in any letter case, is refused
/// for an add, and a namespace under source control is refused for each write. The namespace is the payload's, else the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If ..#READASKSACTION Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    Do ##super(pPayload, .pQuery)
}

/// <p>The workflow user's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the schema says of the workflow user's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The workflow user's name, exactly as the Workflow users list reports it in its Name column. A workflow user the list does not report is refused."
}

/// <p>The derived schema with the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p>The full name and the active state as field rows the input schema is derived from (AD-3), with the name first when <var>pWithName</var>. The port has no body template to derive them
/// from.</p>
ClassMethod WorkflowFieldRows(pWithName As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    If pWithName Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("FullName", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("IsActive", "boolean", 0)
    Quit $$$OK
}

/// <p>The derived schema with the full name and the active state described.</p>
ClassMethod DescribeFields(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("FullName") = "object" Do tProperties.%Get("FullName").%Set("description", "The user's full name, as text, at most 128 characters with no control character. An empty string clears it.", "string")
    If tProperties.%GetTypeOf("IsActive") = "object" Do tProperties.%Get("IsActive").%Set("description", "Whether the workflow user is active. An inactive user is sent no new tasks through their workflow roles.", "string")
    Quit pSchema
}

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code> (AD-55):
/// <method>OcuPilot.Port.InteropPort.WorkflowViolations</method> over the arguments' fields and, for an add (<parameter>JUDGESNAME</parameter>), the id's name. The screen's Save and the
/// mint apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#PORTCLASS, "WorkflowViolations", pIdValue, pArgs, .tViolations, ..#JUDGESNAME)
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
