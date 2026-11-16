/// <p>The set of one startup, memory, compatibility, SQL, SQL Shell, TSQL or ISQL setting (AD-4, AD-6, AD-51, AD-52, AD-53,
/// AD-55, AD-56, AD-58, Stories 21.3 and 21.4): store a value for one setting of one of the endpoints behind
/// <class>OcuPilot.Port.ConfigPort</class>. It changes the instance's stored configuration; a setting whose vendor
/// source states a restart takes effect only at the next restart, which its card states
/// (<parameter>CONSEQUENCECODE</parameter>), and nothing here restarts the instance. A SQL setting whose change purges the
/// cached queries of every namespace says so on its card (<parameter>PURGECODE</parameter>).</p>
/// <p>Two callers reach it: the screen's row action Set value through <class>OcuPilot.Api.ScreenAction</class>, whose
/// dialog sends the value as text, and the agent's proposal and confirmation. It is a merge over the setting's fresh
/// read, so its card shows one <code>Value</code> row, its read-back compares the value
/// (<parameter>READBACKFIELDS</parameter>) and the port sends the complete property set with that one key changed (AD-4).
/// A setting shown and never changed, and a value the setting does not accept, are refused before any vendor call by
/// <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>, at the mint and again at the write.</p>
/// <p><b>Its pairs</b> are its screen's, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>,
/// then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44). The concrete tools each
/// name a descriptor and an endpoint. It is a sibling of <class>OcuPilot.Screen.Tool.InteropSettingSet</class>, not a
/// subclass, so the OS management screens stay clear of the interoperability port.</p>
Class OcuPilot.Screen.Tool.ConfigSettingSet Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter PORTCLASS = "OcuPilot.Port.ConfigPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "SET";

/// <p>The set sends a body: the setting's row with the new value (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The port endpoint this tool reads and writes.</p>
Parameter ENDPOINTNAME;

Parameter SCREENACTIONS = "set";

/// <p>The dialog sends the value as this tool's one value, which may be empty: a text setting may be cleared (AD-56 (ii)).</p>
Parameter SCREENVALUES = "set=Value";

Parameter SCREENEMPTY = "set=Value";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "Value";

/// <p>The names this tool's own read answers.</p>
Parameter READANSWERS = "Name,Value,Kind,Accepts,Restart,ReadOnly,Purges";

/// <p>The one argument: the new value.</p>
Parameter ARGUMENT = "Value";

/// <p>The rules class the mint asks (AD-55).</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.ConfigSettingRules";

/// <p>The pair the write itself names.</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The consequence code of a set of a setting that takes effect only at the next restart, pinned equal to
/// <parameter>OcuPilot.Api.ConfigError.SETTINGRESTART</parameter>.</p>
Parameter CONSEQUENCECODE = "CONFIG.SETTING.RESTART";

/// <p>The consequence code of a set of a setting whose change purges the cached queries of every namespace, pinned equal to
/// <parameter>OcuPilot.Api.ConfigError.SETTINGPURGE</parameter>.</p>
Parameter PURGECODE = "CONFIG.SETTING.PURGE";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINTNAME
}

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The one field a set sends, a string (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild(..#ARGUMENT, "string", 0)
    Quit $$$OK
}

/// <p>The derived schema with the setting's name and the value described, and the value required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    If tProperties.%GetTypeOf(..#ARGUMENT) = "object" {
        Do tProperties.%Get(..#ARGUMENT).%Set("description", ..ValueDescription(), "string")
        If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#ARGUMENT)
    }
    Quit tSchema
}

/// <p>What the schema says of the name that identifies the target.</p>
ClassMethod NameDescription() As %String
{
    Quit "The setting, named exactly as this screen's list reports it. A setting the list does not report, and one the list marks as shown and never changed, are refused."
}

/// <p>What the schema says of the one value.</p>
ClassMethod ValueDescription() As %String
{
    Quit "The new value, as text, in the form the setting's Accepts line states: a boolean setting takes 1 or 0. A value the setting does not accept is refused."
}

/// <p>No state rows: a merge's card shows the value it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and
/// a setting nobody lists is refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's value as this tool's argument; the rules judge it at the write.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#ARGUMENT) = "string") Do pArgs.%Set(..#ARGUMENT, pValues.%Get(..#ARGUMENT), "string")
    Quit $$$OK
}

/// <p>The agent's arguments refused by <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> against the setting's own
/// row, before anything is stored (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "WriteProblem", ..ToolClass(), pIdValue, pArgs, .pProblem)
}

/// <p>The same rules again at the confirm, so a confirm is refused what the mint would now refuse before the claim,
/// leaving the proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p><parameter>CONSEQUENCECODE</parameter> when the setting's fresh row, read as the caller through this tool's port,
/// says a change takes effect only at the next restart, else <parameter>PURGECODE</parameter> when it says a change purges the
/// cached queries, else <code>""</code>. The payload names the setting.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf("Name") '= "string") Quit ""
    Kill tQuery
    Set tQuery(..IdParam()) = pPayload.%Get("Name")
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tRow, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRow)) Set tRow = pPayload
    If (tRow.%GetTypeOf("Restart") = "boolean") && tRow.%Get("Restart") Quit ..#CONSEQUENCECODE
    If (tRow.%GetTypeOf("Purges") = "boolean") && tRow.%Get("Purges") Quit ..#PURGECODE
    Quit ""
}

/// <p>The purge of the cached queries a SQL setting's change owes, once the write has read OK, through the same port
/// <var>pPort</var> (<method>OcuPilot.Port.ConfigPort.PurgeAfterSet</method>), for the setting <var>pIdValue</var> whose fresh read
/// before the write was <var>pFresh</var>. Both callers reach it through
/// <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method>, so a purge that fails is answered 500 <code>INTERNAL</code> as an
/// applied write's failure, which the agent's confirm still marks (AD-15). A setting that does not purge owes nothing.</p>
ClassMethod AfterWrite(pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tKnown = $IsObject(pFresh) && (pFresh.%GetTypeOf(..#ARGUMENT) = "string")
    Quit $ClassMethod(pPort, "PurgeAfterSet", pEndpoint, pIdValue, $Select(tKnown: pFresh.%Get(..#ARGUMENT), 1: ""), tKnown, .pHttpStatus, .pFault)
}

/// <p><method>AfterWrite</method> as a copy-out script step (AD-59): the purge of the cached queries of every namespace for a setting
/// that purges (<method>OcuPilot.Port.ConfigPort.PurgeSteps</method>), unless the draft's diff <var>pContext</var> shows the value
/// unchanged.</p>
ClassMethod SnippetAfter(pEndpoint As %String, pIdParam As %String, pIdValue As %String, pStoredPayload As %DynamicObject, pContext As %DynamicObject = "") As %DynamicArray
{
    If $IsObject(pContext) && (pContext.%GetTypeOf("diff") = "array") {
        Set tChanged = 0
        Set tIterator = pContext.%Get("diff").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If tField = ..#ARGUMENT Set tChanged = 1
        }
        If 'tChanged Quit []
    }
    Quit $ClassMethod(..PortClass(), "PurgeSteps", pEndpoint, pIdValue)
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> where the set lacks it, then the custom
/// resource of each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
