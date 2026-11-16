/// <p>What Interoperability's two startup writes share (AD-4, AD-6, AD-51, AD-52, AD-53, AD-56, AD-62, Story 24.3): a merge over one
/// production's <code>STARTUP</code> read through <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Productions row
/// actions Start with the instance and Shutdown group through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and
/// confirmation. The read is <code>{Name, Namespace, AutoStart, StartupPriority, ShutdownGroup, AutoStartOther}</code>, each a string
/// (<code>AutoStart</code> is <code>1</code> or <code>0</code>), and the fingerprint covers all of it, so a change made elsewhere
/// between the mint and the confirm refuses the confirm.</p>
/// <p><b>The read is composed from the values the write carries</b> (<method>PortQuery</method>), so a value the production already holds
/// is refused by the port with its own code, 409, from either caller, before anything is stored.</p>
/// <p><b>It declares</b> the write's own pair beyond the screen's pairs (each tool names it), WRITE on the namespace's globals database,
/// and the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44), each refused by name before any port call.
/// Neither write is destructive: each is undone by setting the old value back, which the card's before row shows.</p>
Class OcuPilot.Screen.Tool.InteropStartupAction Extends OcuPilot.Screen.Tool.InteropProductionAction [ Abstract ]
{

/// <p>The fresh read: one production's startup settings.</p>
Parameter READTYPE = "STARTUP";

Parameter READANSWERS = "Name,Namespace,AutoStart,StartupPriority,ShutdownGroup,AutoStartOther";

/// <p>A startup write sends a body: the production's startup settings with the new values (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter STATEFIELD = "";

Parameter PRECONDITIONFIELD = "";

Parameter FINGERPRINTSUBJECT = "";

/// <p>The read field a call's arguments do not carry and the merged payload does: the namespace.</p>
Parameter STATEMARKER = "Namespace";

Parameter CHANGEACTION = "updated";

/// <p>The query key each settable field travels under when the read is composed for the write.</p>
Parameter AUTOSTARTFIELD = "AutoStart";

Parameter PRIORITYFIELD = "StartupPriority";

Parameter GROUPFIELD = "ShutdownGroup";

/// <p>The refusals the port's <code>STARTUP</code> read answers when the values do not fit the production, and a namespace that runs no
/// productions (AD-51).</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Port.InteropPort).StartupPreconditionCodes()
}

/// <p>The state read's own query, then the values the write carries (<code>AutoStart</code>, <code>StartupPriority</code>,
/// <code>ShutdownGroup</code>) as strings when the call is composing for the action, so the port refuses a value the production holds. A
/// stored payload carries the marker and adds none.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf(..#STATEMARKER) '= "unassigned") Quit
    If pPayload.%GetTypeOf(..#AUTOSTARTFIELD) = "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#AUTOSTARTKEY) = pPayload.%Get(..#AUTOSTARTFIELD)
    If pPayload.%GetTypeOf(..#PRIORITYFIELD) = "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#PRIORITYKEY) = pPayload.%Get(..#PRIORITYFIELD)
    If pPayload.%GetTypeOf(..#GROUPFIELD) = "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#GROUPKEY) = pPayload.%Get(..#GROUPFIELD)
}

/// <p>The settable fields as the field rows the input schema is derived from: each a string (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set pRows($Increment(pRows)) = $ListBuild($List(tNames, tI), "string", 0)
    }
    Quit $$$OK
}

/// <p>The agent-facing description of settable field <var>pField</var>, in the schema.</p>
ClassMethod FieldDescription(pField As %String) As %String
{
    Quit ""
}

/// <p>The derived schema with each field described and the required ones marked: the target is one production.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", ..FieldDescription(tField), "string")
    }
    If tSchema.%GetTypeOf("required") = "array" {
        Set tRequired = ..RequiredFields()
        For tI = 1:1:$ListLength(tRequired) {
            Do tSchema.%Get("required").%Push($List(tRequired, tI))
        }
    }
    Quit tSchema
}

/// <p>The settable fields a call must carry.</p>
ClassMethod RequiredFields() As %List
{
    Quit ""
}

/// <p>No state rows: a merge's card shows the values it moves (<method>MergeUpdate</method>), and a production nobody established is
/// refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's values as this tool's arguments, each a string; the port judges them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Quit $$$OK
}

/// <p>The rules over the call: the port's <method>OcuPilot.Port.InteropPort.StartupViolations</method> over the settable fields, a field
/// that is not a string being a shape violation, then <method>ExtraProblem</method>, as one sentence naming each field and its published
/// sentence, or <code>""</code>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tValues
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If '$IsObject(pArgs) Quit
        Set tType = pArgs.%GetTypeOf(tField)
        If tType = "string" {
            Set tValues(tField) = pArgs.%Get(tField)
        } ElseIf tType '= "unassigned" {
            Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    }
    Set tSC = $ClassMethod(..#PORTCLASS, "StartupViolations", ..#WRITETYPE, .tValues, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    If pProblem = "" Set pProblem = ..ExtraProblem(.tValues)
    Quit $$$OK
}

/// <p>A rule beyond the shapes, over the string values <var>pValues</var> (<code>pValues(field)</code>), as a published sentence, or
/// <code>""</code>. None here.</p>
ClassMethod ExtraProblem(ByRef pValues) As %String
{
    Quit ""
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal
/// live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

}
