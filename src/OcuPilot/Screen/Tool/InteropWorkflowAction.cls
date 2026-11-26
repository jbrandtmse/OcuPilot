/// <p>What Interoperability's workflow writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.17): a write of one workflow user, workflow role or role member of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the screen's actions and the agent's proposal and confirmation. The target is kept exactly (AD-13).</p>
/// <p><b>It declares</b> <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the namespace's globals database beyond the screen's pairs (AD-8, AD-62), each refused by name before any
/// port call, the remove included. The vendor checks no privilege of its own beyond the database and records no audit row of its own (measured).</p>
/// <p>A subclass names its screen, read, endpoint and classic page, the port method that judges the caller's fields (<parameter>VIOLATIONSMETHOD</parameter>) and the read field the card titles
/// the target by (<parameter>TARGETFIELD</parameter>).</p>
Class OcuPilot.Screen.Tool.InteropWorkflowAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter WRITERESOURCE = "%Ens_WorkflowConfig";

/// <p>The read field a call's arguments do not carry and the stored payload does: the namespace.</p>
Parameter STATEMARKER = "Namespace";

/// <p>Whether the rules over the call judge the target's name: an add, whose name is new. A target already held keeps the name it has.</p>
Parameter JUDGESNAME As BOOLEAN = 0;

/// <p>Whether the tool's read always asks for its action (<method>PortQuery</method>), at the confirm and the read-back as at the mint, so a namespace under source control is refused
/// before anything is claimed. An add and an edit declare 1; a remove asks only for the action its arguments carry, as the superclass does.</p>
Parameter READASKSACTION As BOOLEAN = 0;

/// <p>The <class>OcuPilot.Port.InteropPort</class> method that judges the caller's fields: called with the id, the arguments, the violations it answers and
/// <parameter>JUDGESNAME</parameter>.</p>
Parameter VIOLATIONSMETHOD;

/// <p>The fresh read's field, and the agent's argument, the card titles the target by.</p>
Parameter TARGETFIELD = "Name";

/// <p>The family's mint, which stores the namespace in an add's or an edit's arguments. The confirm acts where the proposal read because the payload carries it (the add's composed
/// payload, the edit's fresh read, the remove's fingerprint subject).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropCredentialMint"
}

/// <p>The superclass's read, with the action asked for always when <parameter>READASKSACTION</parameter>: an add of a target the namespace cannot take is refused, and a namespace under
/// source control is refused for each write. The namespace is the payload's, else the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If ..#READASKSACTION Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    Do ##super(pPayload, .pQuery)
}

/// <p>The target's name, which the card titles it by: the fresh read's <parameter>TARGETFIELD</parameter>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#TARGETFIELD) = "string") Quit pFresh.%Get(..#TARGETFIELD)
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#TARGETFIELD) = "string") Quit pArgs.%Get(..#TARGETFIELD)
    Quit ""
}

/// <p>What the schema says of the target's name; a subclass names it.</p>
ClassMethod NameDescription() As %String
{
    Quit ""
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

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code> (AD-55): <parameter>VIOLATIONSMETHOD</parameter> over the arguments'
/// fields and, for an add (<parameter>JUDGESNAME</parameter>), the id's name. The screen's Save and the mint apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#PORTCLASS, ..#VIOLATIONSMETHOD, pIdValue, pArgs, .tViolations, ..#JUDGESNAME)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ..ViolationsProblem(.tViolations)
    Quit $$$OK
}

/// <p>The violations <var>pViolations</var> (<code>pViolations(n) = $ListBuild(field, code)</code>, the count in <code>pViolations</code>) as one sentence naming each field and its
/// published sentence, or <code>""</code>.</p>
ClassMethod ViolationsProblem(ByRef pViolations) As %String
{
    Set tProblem = ""
    For tI = 1:1:$Get(pViolations) {
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: " ") _ "'" _ $List(pViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2))
    }
    Quit tProblem
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

}
