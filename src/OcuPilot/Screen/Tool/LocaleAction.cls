/// <p>The base of the locale tools (Story 21.14, AD-51, AD-52, AD-53, AD-58): an action-style write through
/// <class>OcuPilot.Port.LocalePort</class>, which reads the locale through its <code>GET</code> and sends no body and no argument. The
/// locale is named by <method>IdArgument</method>, in the port's <code>name</code> query key.</p>
/// <p><b>Its rules are the port's</b>: the mint refuses what <class>OcuPilot.Area.OsMgmt.LocaleRules</class> refuses against the locale's
/// state (<method>ArgumentProblem</method>), and the port asks the same rules again at the write, for the confirm and for a screen's action
/// alike, before any vendor call.</p>
/// <p><b>Its pairs</b> are its screen's, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> where the screen's
/// set lacks them, then the custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-8, AD-44). It is a sibling of
/// <class>OcuPilot.Screen.Tool.BackupAction</class>, not a subclass: its port, state and rules differ, and subclassing would couple the
/// locales to backup.</p>
Class OcuPilot.Screen.Tool.LocaleAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port every locale write reaches its target through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.LocalePort";

/// <p>The port's single-object read.</p>
Parameter READTYPE = "GET";

/// <p>No body: the port builds the vendor call.</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>The port endpoint this tool reads and writes.</p>
Parameter ENDPOINTNAME = "Locales";

/// <p>The description the input schema gives the identifying property.</p>
Parameter IDDESCRIPTION;

/// <p>The pair the write itself names.</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The rules class the mint asks (AD-55).</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.LocaleRules";

Parameter CLASSICPAGES = "%CSP.UI.Portal.NLS";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINTNAME
}

/// <p>The port's own spelling of the name it is asked for.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.LocalePort).#NAMEKEY
}

/// <p>None: the tool sends no body and takes no argument, so its field list is empty by derivation (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The identifying property described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..#IDDESCRIPTION, "string")
    Quit tSchema
}

/// <p>No state row: the locale's own state is what the card names.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The agent's arguments refused against the locale's state, before anything is stored (AD-55):
/// <method>OcuPilot.Area.OsMgmt.LocaleRules.WriteProblem</method>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "WriteProblem", ..ToolClass(), pIdValue, pArgs, .pProblem)
}

/// <p>The screen's action takes no value, so it sends no argument.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
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
