/// <p>The audit database's purge tool (AD-51, AD-52, AD-53, FR-75): remove every audit record on this
/// instance dated before a cut-off day's midnight, instance time. The Auditing screen reaches it
/// through its <code>purge</code> row action, with the cut-off as the action's one value (AD-56
/// (ii)).</p>
/// <p><b>It is unadvertised</b> (<parameter>ADVERTISED</parameter> 0, AD-53's named case): a purge
/// erases the marker trail of the agent's own writes, so no provider request, dispatch lookup or
/// screen context sees it until Epic 14 registers it behind a policy key disabled by default
/// (AD-22). Its screen's action route resolves it, and nothing else does.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and
/// <class>OcuPilot.Port.AuditPort</class> composes the vendor's <code>Security.Audit.Record</code>
/// <code>PURGE</code> body from <code>PurgeBefore</code>, which travels in the port query
/// (<method>PortQuery</method>). The vendor's end time is exclusive, so every record dated on or
/// after the cut-off day remains, and the vendor records its own
/// <code>%System/%Security/AuditChange</code> event. The vendor runs it in a Work Queue worker and
/// the port awaits it within its bound (AD-26).</p>
/// <p><b>Its pairs are the Auditing screen's and <code>%Admin_Operate:USE</code></b> (AD-8 as
/// amended 2026-09-24), for the port's poll of the queued purge.</p>
Class OcuPilot.Screen.Tool.AuditPurge Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.auditing.purge";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter DESCRIPTION = "Propose removing every audit record on this instance dated before a cut-off day, including the agent's own audit markers from that period. It changes nothing by itself: it answers a proposal the user reviews and confirms. Once confirmed it cannot be undone. The target is the instance's auditing configuration, which has exactly one instance.";

/// <p>Unadvertised (AD-53): the screen's caller alone reaches it.</p>
Parameter ADVERTISED As BOOLEAN = 0;

Parameter PORTCLASS = "OcuPilot.Port.AuditPort";

Parameter READTYPE = "DATABASE";

Parameter WRITETYPE = "PURGE";

/// <p>No body: the port composes it (<parameter>OcuPilot.Port.AuditPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>Destructive: a purged record is gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter SCREENACTIONS = "purge";

Parameter SCREENVALUES = "purge=PurgeBefore";

Parameter READANSWERS = "Enabled,CopyNamespace,PurgeBefore";

Parameter PRECONDITIONFIELD = "PurgeBefore";

Parameter FINGERPRINTSUBJECT = "PurgeBefore";

/// <p>The one argument this tool admits: the cut-off day, <code>YYYY-MM-DD</code>.</p>
Parameter CUTOFFFIELD = "PurgeBefore";

Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AuditPort).#RECORDENDPOINT
}

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#CUTOFFFIELD)
}

/// <p>The identifying property as <class>OcuPilot.Screen.Tool.AuditingUpdate</class> describes it,
/// and <parameter>CUTOFFFIELD</parameter>, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one auditing configuration, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'. Any other spelling names the same configuration.", "string")
    }
    Do tProperties.%Set(..#CUTOFFFIELD, {"type": "string", "maxLength": 10, "description": "The cut-off day, YYYY-MM-DD: every record dated before its midnight, instance time, is removed. A day after today on this instance is refused."})
    Do tSchema.%Get("required").%Push(..#CUTOFFFIELD)
    Quit tSchema
}

/// <p>No state row: the merge's <parameter>CUTOFFFIELD</parameter> row is the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The stored payload's <parameter>CUTOFFFIELD</parameter>, under the port's own query key (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#CUTOFFFIELD) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.AuditPort).#CUTOFFQUERY) = pPayload.%Get(..#CUTOFFFIELD)
}

/// <p>What is wrong with <var>pValue</var> as a cut-off, or <code>""</code>: it must be
/// <code>YYYY-MM-DD</code>, a real date, and no later than today on the instance's own calendar
/// (<code>+$Horolog</code>, Conventions, Dates).</p>
ClassMethod CutoffProblem(pValue As %String) As %String
{
    If '$Match(pValue, "^\d{4}-\d{2}-\d{2}$") Quit "'" _ ..#CUTOFFFIELD _ "' must be a date written YYYY-MM-DD"
    Set tDay = $ZDateH(pValue, 3, , , , , , , -1)
    If tDay = -1 Quit "'" _ pValue _ "' is not a date"
    If tDay > +$Horolog Quit "'" _ pValue _ "' is after today on this instance, and a purge cannot cut off in the future"
    Quit ""
}

/// <p>The agent's arguments refused by <method>CutoffProblem</method> before anything is stored
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ..CutoffProblem(pArgs.%Get(..#CUTOFFFIELD))
    Quit $$$OK
}

/// <p>The screen's <code>purge</code> value as this tool's argument, refused by
/// <method>CutoffProblem</method> exactly as the agent's would be (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tValue = ""
    If $IsObject(pValues) Set tValue = pValues.%Get(..#CUTOFFFIELD)
    Set pProblem = ..CutoffProblem(tValue)
    If pProblem = "" Do pArgs.%Set(..#CUTOFFFIELD, tValue, "string")
    Quit $$$OK
}

/// <p>The screen's own pairs and <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>,
/// appended once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
