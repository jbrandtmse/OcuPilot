/// <p>What Interoperability's three schedule spec writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.15): a write of one schedule spec of the
/// request's namespace through <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Schedule specs list's New schedule spec and its
/// row actions Edit and Remove, and the agent's proposal and confirmation. A schedule spec is a named text of START and STOP parts that the production
/// items naming it as <code>@</code> and the name follow; the port judges it with the vendor's own validator and never runs it. The target is the
/// schedule spec's name, kept exactly (AD-13).</p>
/// <p><b>A rename cannot be expressed</b>: the name is the target, and the update's settable fields are the spec, the description and the deployable
/// flag; a different name is a remove and an add.</p>
/// <p><b>It declares</b> <code>%Ens_ProductionConfig:WRITE</code> and WRITE on the namespace's globals database beyond the screen's pairs (AD-8,
/// AD-62), each refused by name before any port call, the remove included. The vendor checks no privilege of its own beyond the database and records
/// no audit row of its own (measured).</p>
Class OcuPilot.Screen.Tool.InteropScheduleAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropScheduleList";

/// <p>The fresh read: one schedule spec, composed for the action.</p>
Parameter READTYPE = "SCHEDULE";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Description,ScheduleSpec,Deployable,Namespace";

Parameter WRITERESOURCE = "%Ens_ProductionConfig";

/// <p>The read field a call's arguments do not carry and the stored payload does: the namespace.</p>
Parameter STATEMARKER = "Namespace";

/// <p>Whether the rules over the call judge the schedule spec's name and require its spec: an add, whose name is new. A schedule spec already held
/// keeps the name it has.</p>
Parameter JUDGESNAME As BOOLEAN = 0;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTSCHEDULES
}

/// <p>The mint that stores the namespace in an add's or an edit's arguments, so a confirm judges their fields where the proposal read.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropCredentialMint"
}

/// <p>Whether the tool's read always asks for its action (<method>PortQuery</method>), at the confirm and the read-back as at the mint, so a
/// namespace under source control is refused before anything is claimed. An add and an edit declare 1; the remove asks only for the action its
/// arguments carry, as the superclass does.</p>
Parameter READASKSACTION As BOOLEAN = 0;

/// <p>The superclass's read, with the action asked for always when <parameter>READASKSACTION</parameter>: present, in any letter case, is
/// <code>TAKEN</code> for an add, and a namespace under source control is refused for each write. The namespace is the payload's, else the
/// request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If ..#READASKSACTION Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    Do ##super(pPayload, .pQuery)
}

/// <p>The schedule spec's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the schema says of the schedule spec's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The schedule spec's name, exactly as the Schedule specs list reports it in its Name column. A schedule spec the list does not report is refused."
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

/// <p>The spec, the description and the deployable flag as field rows the input schema is derived from (AD-3), with the name first when
/// <var>pWithName</var>. The port has no body template to derive them from.</p>
ClassMethod ScheduleFieldRows(pWithName As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    If pWithName Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("ScheduleSpec", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Description", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Deployable", "boolean", 0)
    Quit $$$OK
}

/// <p>The derived schema with the spec, the description and the flag described.</p>
ClassMethod DescribeFields(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("ScheduleSpec") = "object" Do tProperties.%Get("ScheduleSpec").%Set("description", "The schedule, as text: parts separated by commas, each START or STOP, a colon and a date and time, for example START:*-*-*T08:00:00,STOP:*-*-*T17:00:00, where * matches any. A schedule the instance does not accept, and the empty one, are refused.", "string")
    If tProperties.%GetTypeOf("Description") = "object" Do tProperties.%Get("Description").%Set("description", "What this schedule is for, as text, at most 256 characters. An empty string clears it.", "string")
    If tProperties.%GetTypeOf("Deployable") = "object" Do tProperties.%Get("Deployable").%Set("description", "Whether the schedule spec is included when schedule specs are exported to a deployment package.", "string")
    Quit pSchema
}

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code> (AD-55):
/// <method>OcuPilot.Port.InteropPort.ScheduleViolations</method> over the arguments' fields and, for an add (<parameter>JUDGESNAME</parameter>),
/// the id's name and the spec it requires. The screen's Save and the mint apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#PORTCLASS, "ScheduleViolations", pIdValue, pArgs, .tViolations, ..#JUDGESNAME, 1, ..#JUDGESNAME)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal live
/// (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

}
