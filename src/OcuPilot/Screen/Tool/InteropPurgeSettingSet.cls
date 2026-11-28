/// <p>Interoperability's purge data setting change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-58, AD-62, Story 24.16): store a new value for one of the four settings
/// of the classic Purge Data Settings page, in the namespace the request is scoped to. It is <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s shape over
/// <class>OcuPilot.Port.InteropPort</class>: its fresh read is the port's <code>SETTING</code> row <code>{Name, Value, Stored, Kind, Accepts, Namespace}</code>, a value is
/// judged by <class>OcuPilot.Area.Interop.PurgeSettingRules</class> at the mint and again at the write, and its read-back compares <code>Value</code>. The
/// classic page stores all of its settings at once; a setting that is not stored reads the classic default, so a single stored node means what the page's Save means.</p>
/// <p>Its pairs are the screen's, which include WRITE on the classic page's own resource, and WRITE on the namespace's globals database (AD-8).</p>
Class OcuPilot.Screen.Tool.InteropPurgeSettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "interop.purgesettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropPurgeSettingList";

Parameter DESCRIPTION = "Propose changing one purge data setting of the namespace the user is working in, as the classic Purge Data Settings page's Save does. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting exactly as the Purge data settings list reports it in its Name column and give the new value as text in the form its Accepts column states: Include message bodies, Purge only completed sessions and Run bitmap cleanup for namespace take 1 or 0, and Description takes up to 2000 characters. The settings are used by the next purge. A setting the list does not report and a value the setting does not accept are refused.";

Parameter PORTCLASS = "OcuPilot.Port.InteropPort";

Parameter READTYPE = "SETTING";

Parameter WRITETYPE = "SETTINGSET";

Parameter ENDPOINTNAME = "PurgeSettings";

/// <p>The fresh read is composed from the action it is read for (<method>PortQuery</method>), at the mint as at a screen action.</p>
Parameter READSVALUES As BOOLEAN = 1;

Parameter RULES = "OcuPilot.Area.Interop.PurgeSettingRules";

Parameter CLASSICPAGES = "EnsPortal.PurgeSettings";

/// <p>The pair the write itself names, which its screen already declares.</p>
Parameter WRITERESOURCE = "%Ens_PurgeSettings";

Parameter WRITEPERMISSION = "WRITE";

Parameter READANSWERS = "Name,Value,Stored,Kind,Accepts,Namespace";

/// <p>None: a set of a purge setting has no effect beyond the stored value.</p>
Parameter CONSEQUENCECODE = "";

Parameter PRECONDITIONCODES = "CONFIG.SETTING.NOTFOUND,INTEROP.NAMESPACE";

/// <p>The query parameter the port reads the setting's name under.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#IDKEY
}

/// <p>The action key (composing the read for this write) when the call carries no <code>Stored</code> field, which a stored payload does, and the namespace a stored
/// payload names (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf("Stored") = "unassigned" Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If (pPayload.%GetTypeOf("Namespace") = "string") && (pPayload.%Get("Namespace") '= "") Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get("Namespace")
}

/// <p>What the caller must hold: the screen's own pairs, then WRITE on the globals database of the namespace the request is scoped to, which
/// <code>^Ens.Configuration</code> maps to, then the custom resource of the classic page (AD-8, AD-44, AD-62). <var>pResolved</var> is 0 when the database names no resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tGlobals = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(##class(OcuPilot.Kernel.Scope).Current(), .tGlobals, .tReadOnly) || (tGlobals = "") {
        Set pResolved = 0
        Quit ""
    }
    Set tDatabase = $ListBuild(tGlobals, "WRITE")
    If '$ListFind(tPairs, tDatabase) Set tPairs = tPairs _ $ListBuild(tDatabase)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>None: a purge setting's change has no consequence to state.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ""
}

/// <p>The setting and the value judged by <class>OcuPilot.Area.Interop.PurgeSettingRules</class>, which read nothing from the instance: the four settings and their limits are the
/// port's own, so a confirm sent from another namespace judges what the mint judged.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tValue = $Select($IsObject(pArgs) && (pArgs.%GetTypeOf("Value") = "string"): pArgs.%Get("Value"), 1: "")
    Set pProblem = $ClassMethod(..#RULES, "SentenceFor", ..Endpoint(), {"Name": (pIdValue)}, tValue)
    Quit $$$OK
}

/// <p>Nothing follows the write: the stored node is the whole of it.</p>
ClassMethod AfterWrite(pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

/// <p>No step follows the write in a copy-out script.</p>
ClassMethod SnippetAfter(pEndpoint As %String, pIdParam As %String, pIdValue As %String, pStoredPayload As %DynamicObject, pContext As %DynamicObject = "") As %DynamicArray
{
    Quit []
}

/// <p>What the schema says of the setting's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The setting, named exactly as the Purge data settings list reports it in its Name column. A setting the list does not report is refused."
}

}
