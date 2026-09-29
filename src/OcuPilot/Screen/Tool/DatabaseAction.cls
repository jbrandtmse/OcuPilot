/// <p>The base of the disk operation tools (Story 18.4, AD-51, AD-52, AD-53): an action-style write
/// through <class>OcuPilot.Port.DatabasePort</class>'s <code>Database.Actions</code> branch, which reads
/// the target through the port-composed <code>STATE</code> type and builds the vendor body from the
/// tool's one declared argument, <parameter>ARGUMENT</parameter>, carried in the port query
/// (<method>PortQuery</method>). The tool sends no body.</p>
/// <p><b>Its rules are the port's</b>: the mint refuses a state the operation's precondition forbids
/// and an argument its rules refuse (<method>ArgumentProblem</method>, through
/// <method>OcuPilot.Area.OsMgmt.DatabaseRules.ActionProblem</method>), and the port asks the same rules
/// again at the write, for the confirm and for a screen's action alike, before any vendor call.</p>
/// <p><b>Its pairs</b> are its screen's, then <parameter>POLLRESOURCE</parameter> and
/// <parameter>WRITERESOURCE</parameter> where the screen's set lacks them, then the custom resource of
/// each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44). A concrete tool names its
/// <parameter>TOOLNAME</parameter>, <parameter>DESCRIPTORCLASS</parameter>,
/// <parameter>WRITETYPE</parameter>, <parameter>SCREENACTIONS</parameter>, fingerprint subject and
/// pairs.</p>
Class OcuPilot.Screen.Tool.DatabaseAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port every disk operation reaches its target through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.DatabasePort";

/// <p>The port-composed fresh read (AD-51 as amended 2026-09-29).</p>
Parameter READTYPE = "STATE";

/// <p>No body: the port builds it.</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>None of the operations removes data.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>What the <code>STATE</code> read answers through the port (DW-1475).</p>
Parameter READANSWERS = "Directory,Mounted,ReadOnly,Size,MaxSize,FreeSpace,ResourceName,NewVolumeDirectory,NewVolumeThreshold,Dismounted,TargetSize,TargetFreeSpace,InitialSize,Globals";

/// <p>The one argument this tool admits, or <code>""</code>.</p>
Parameter ARGUMENT;

/// <p>The JSON shape of <parameter>ARGUMENT</parameter>: <code>integer</code>, <code>boolean</code> or
/// <code>array</code>.</p>
Parameter ARGUMENTTYPE = "integer";

/// <p>Whether <parameter>ARGUMENT</parameter> is required.</p>
Parameter ARGUMENTREQUIRED As BOOLEAN = 1;

/// <p>The description the input schema gives <parameter>ARGUMENT</parameter>.</p>
Parameter ARGUMENTDESCRIPTION;

/// <p>The description the input schema gives the identifying property.</p>
Parameter IDDESCRIPTION = "The database, named by the directory this instance's own databases list reports for it. A directory the list does not report is refused.";

/// <p>The pair the port's poll of a queued operation needs, where the screen's set lacks it (AD-8's
/// endpoint clause), or <code>""</code>.</p>
Parameter POLLRESOURCE;

Parameter POLLPERMISSION = "USE";

/// <p>The pair the write itself names.</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

/// <p>The rules class the mint asks (AD-55).</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.DatabaseRules";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.DatabasePort).#ACTIONSENDPOINT
}

/// <p>A database on Database details and Databases is named by its directory.</p>
ClassMethod IdArgument() As %String
{
    Quit "Directory"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.DatabasePort).#DIRPARAM
}

/// <p><parameter>ARGUMENT</parameter> alone, or none: the tool sends no body, so its field list is
/// empty by derivation (AD-3), and its one argument reaches the port through
/// <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    If ..#ARGUMENT = "" Quit ""
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The identifying property described, and <parameter>ARGUMENT</parameter> added in its
/// <parameter>ARGUMENTTYPE</parameter>, required when <parameter>ARGUMENTREQUIRED</parameter>.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..#IDDESCRIPTION, "string")
    If ..#ARGUMENT = "" Quit tSchema
    If ..#ARGUMENTTYPE = "array" {
        Set tProperty = {"type": "array", "items": {"type": "string"}}
    } Else {
        Set tProperty = {}
        Do tProperty.%Set("type", ..#ARGUMENTTYPE, "string")
    }
    Do tProperty.%Set("description", ..#ARGUMENTDESCRIPTION, "string")
    Do tProperties.%Set(..#ARGUMENT, tProperty)
    If ..#ARGUMENTREQUIRED Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>The stored payload's <parameter>ARGUMENT</parameter>, under the port's own query key (AD-52): a
/// boolean as <code>true</code> or <code>false</code>, an array as its compact JSON, anything else as
/// its text. <var>pPayload</var> may also be the caller's arguments, which carry the same name.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If (..#ARGUMENT = "") || '$IsObject(pPayload) Quit
    Set tType = pPayload.%GetTypeOf(..#ARGUMENT)
    If (tType = "unassigned") || (tType = "null") Quit
    Set tValue = pPayload.%Get(..#ARGUMENT)
    If tType = "boolean" {
        Set pQuery(..#ARGUMENT) = $Select(tValue: "true", 1: "false")
    } ElseIf $IsObject(tValue) {
        Set pQuery(..#ARGUMENT) = tValue.%ToJSON()
    } Else {
        Set pQuery(..#ARGUMENT) = tValue
    }
}

/// <p>No state row by default: an argument's own merge row is the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The agent's arguments refused by the operation's rules against the target's state, before
/// anything is stored (AD-55): <method>OcuPilot.Area.OsMgmt.DatabaseRules.ActionProblem</method>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "ActionProblem", ..ToolClass(), pIdValue, pArgs, .pProblem)
}

/// <p>The screen's value as this tool's argument (AD-56 (ii)): a whole number's text as a number,
/// <code>true</code> or <code>false</code> as a boolean, and an array's JSON text as that array. A
/// value that is none of these is carried as it came, and the port's own rules refuse it before any
/// vendor call.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If (..#ARGUMENT = "") || '$IsObject(pValues) Quit $$$OK
    If pValues.%GetTypeOf(..#ARGUMENT) = "unassigned" Quit $$$OK
    Set tValue = pValues.%Get(..#ARGUMENT)
    If ..#ARGUMENTTYPE = "boolean" {
        If (tValue = "true") || (tValue = "false") {
            Do pArgs.%Set(..#ARGUMENT, (tValue = "true"), "boolean")
            Quit $$$OK
        }
    } ElseIf ..#ARGUMENTTYPE = "array" {
        Try {
            Set tArray = ##class(%DynamicAbstractObject).%FromJSON(tValue)
        } Catch {
            Set tArray = ""
        }
        If $IsObject(tArray) && tArray.%IsA("%Library.DynamicArray") {
            Do pArgs.%Set(..#ARGUMENT, tArray)
            Quit $$$OK
        }
    } ElseIf $Match(tValue, "[0-9]{1,9}") {
        Do pArgs.%Set(..#ARGUMENT, +tValue, "number")
        Quit $$$OK
    }
    Do pArgs.%Set(..#ARGUMENT, tValue, "string")
    Quit $$$OK
}

/// <p><code>%DB_&lt;resource&gt;:READ</code> on the resource of the database <var>pArgs</var>'s
/// <method>IdArgument</method> names (AD-8 as amended 2026-09-29), read through this tool's port and
/// <code>STATE</code> type as the caller. No target named, and a target the instance does not hold,
/// add none; a read the caller's privileges refuse adds none either, since the declared pairs refuse
/// that caller by name first; any other failed read leaves <var>pResolved</var> 0, and the call is
/// refused.</p>
ClassMethod TargetResourcePair(pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf(..IdArgument()) '= "string") Quit ""
    Kill tQuery
    Set tQuery(..IdParam()) = pArgs.%Get(..IdArgument())
    Set tSC = $ClassMethod(..ReadPort(), "Invoke", ..Endpoint(), ..#READTYPE, .tQuery, "", .tState, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If (+$Get(tHttp) = 404) || (+$Get(tHttp) = 403) Quit ""
        Set pResolved = 0
        Quit ""
    }
    If '$IsObject($Get(tState)) Quit ""
    Set tResource = tState.%Get("ResourceName")
    If (tResource = "") || $IsObject(tResource) Quit ""
    Quit $ListBuild($ListBuild(tResource, "READ"))
}

/// <p>The port this tool's own <code>STATE</code> read goes through: its declared port, or
/// <class>OcuPilot.Port.DatabasePort</class> where a subclass declares the write base's default, since
/// only that port composes the read.</p>
ClassMethod ReadPort() As %String
{
    Set tPort = ..PortClass()
    If (tPort = "") || (tPort = $Parameter("OcuPilot.Screen.Tool.Write", "PORTCLASS")) Quit "OcuPilot.Port.DatabasePort"
    Quit tPort
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>POLLRESOURCE</parameter>:<parameter>POLLPERMISSION</parameter> and
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> where the set lacks
/// them, then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    If ..#POLLRESOURCE '= "" {
        Set tPoll = $ListBuild(..#POLLRESOURCE, ..#POLLPERMISSION)
        If '$ListFind(tPairs, tPoll) Set tPairs = tPairs _ $ListBuild(tPoll)
    }
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
