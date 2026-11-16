/// <p>The base of the backup tools (Story 21.2, AD-51, AD-52, AD-53, AD-58): an action-style write through
/// <class>OcuPilot.Port.BackupPort</class>, which reads the target through its <code>GET</code> and sends no body. The
/// task or database is named by <method>IdArgument</method> and the one argument a tool admits, if any, by
/// <parameter>ARGUMENT</parameter>, carried in the port query (<method>PortQuery</method>).</p>
/// <p><b>Its rules are the port's</b>: the mint refuses what <class>OcuPilot.Area.OsMgmt.BackupRules</class> refuses
/// against the target's state (<method>ArgumentProblem</method>), and the port asks the same rules again at the write, for
/// the confirm and for a screen's action alike, before any vendor call.</p>
/// <p><b>A tool whose target is the instance's write state</b> declares <parameter>FIXEDID</parameter>, the one literal
/// id every caller names it by, as Journals' switches do (<class>OcuPilot.Screen.Tool.JournalSwitch</class>); any other id
/// is refused for the agent.</p>
/// <p><b>Its pairs</b> are its screen's, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
/// where the screen's set lacks them, then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-8,
/// AD-44). It is a sibling of <class>OcuPilot.Screen.Tool.DatabaseAction</class>, not a subclass: its port, state and rules
/// differ, and subclassing would couple the disk operations to backup.</p>
Class OcuPilot.Screen.Tool.BackupAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port every backup write reaches its target through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.BackupPort";

/// <p>The port's single-object read.</p>
Parameter READTYPE = "GET";

/// <p>No body: the port builds the vendor call.</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>The port endpoint this tool reads and writes.</p>
Parameter ENDPOINTNAME;

/// <p>The one argument this tool admits, or <code>""</code>, and its JSON type, whether it is required, and the
/// description the input schema gives it.</p>
Parameter ARGUMENT;

Parameter ARGUMENTTYPE = "integer";

Parameter ARGUMENTREQUIRED As BOOLEAN = 1;

Parameter ARGUMENTDESCRIPTION;

/// <p>The one id every caller names the target by, or <code>""</code> for a target named by the caller.</p>
Parameter FIXEDID;

/// <p>The description the input schema gives the identifying property.</p>
Parameter IDDESCRIPTION;

/// <p>The pair the write itself names.</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The rules class the mint asks (AD-55).</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.BackupRules";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINTNAME
}

/// <p>The port's own spelling of the name it is asked for.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.BackupPort).#NAMEKEY
}

/// <p><parameter>ARGUMENT</parameter> alone, or none: the tool sends no body, so its field list is empty by derivation
/// (AD-3), and its one argument reaches the port through <method>PortQuery</method>.</p>
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
    Set tProperty = {}
    Do tProperty.%Set("type", ..#ARGUMENTTYPE, "string")
    Do tProperty.%Set("description", ..#ARGUMENTDESCRIPTION, "string")
    Do tProperties.%Set(..#ARGUMENT, tProperty)
    If ..#ARGUMENTREQUIRED Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>The stored payload's <parameter>ARGUMENT</parameter>, as its text, under the port's own query key (AD-52): a number or a
/// string only, so a boolean is no limit. <var>pPayload</var> may also be the caller's arguments, which carry the same name.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If (..#ARGUMENT = "") || '$IsObject(pPayload) Quit
    Set tType = pPayload.%GetTypeOf(..#ARGUMENT)
    If (tType '= "number") && (tType '= "string") Quit
    Set pQuery(..#ARGUMENT) = pPayload.%Get(..#ARGUMENT)
}

/// <p>No state row: the target's own state is what the card names.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The agent's arguments refused against the target's state, before anything is stored (AD-55): an id other than
/// <parameter>FIXEDID</parameter> where one is declared, then
/// <method>OcuPilot.Area.OsMgmt.BackupRules.WriteProblem</method>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..IdProblem(pIdValue)
    If pProblem '= "" Quit $$$OK
    Quit $ClassMethod(..#RULES, "WriteProblem", ..ToolClass(), pIdValue, pArgs, .pProblem)
}

/// <p>Why <var>pId</var> is not this tool's target where <parameter>FIXEDID</parameter> is declared, or <code>""</code>.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If (..#FIXEDID = "") || (pId = ..#FIXEDID) Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ..#FIXEDID _ "': this acts on the instance's database writes"
}

/// <p>The screen's value as this tool's argument (AD-56 (ii)): the text of a whole number from 1 without a leading zero as a number, anything else as it came,
/// so the port's rules refuse it before any vendor call. The screen's target is refused unless it is <parameter>FIXEDID</parameter>
/// where one is declared, as for the agent.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..IdArgument()) = "string") Set pProblem = ..IdProblem(pValues.%Get(..IdArgument()))
    If pProblem '= "" Quit $$$OK
    If (..#ARGUMENT = "") || '$IsObject(pValues) Quit $$$OK
    If pValues.%GetTypeOf(..#ARGUMENT) = "unassigned" Quit $$$OK
    Set tValue = pValues.%Get(..#ARGUMENT)
    If $Match(tValue, "^[1-9][0-9]{0,8}$") {
        Do pArgs.%Set(..#ARGUMENT, +tValue, "number")
    } Else {
        Do pArgs.%Set(..#ARGUMENT, tValue, "string")
    }
    Quit $$$OK
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
