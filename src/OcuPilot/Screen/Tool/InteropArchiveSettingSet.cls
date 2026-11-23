/// <p>Interoperability's archive setting change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-58, AD-62, Story 24.16 Batch 4): store a new value for one of the settings of the classic
/// Archive Manager page, in the namespace the request is scoped to: Archive to namespace or Number of days before archiving. The archive class is shown and never set. It is
/// <class>OcuPilot.Screen.Tool.InteropPurgeSettingSet</class>'s shape over the port's Archive settings endpoint: its fresh read is the port's <code>SETTING</code> row
/// <code>{Name, Value, Stored, Kind, Accepts, ReadOnly, Namespace}</code>, a value is judged by <class>OcuPilot.Area.Interop.ArchiveSettingRules</class> at the mint, and again at
/// the write in the namespace the proposal read, and its read-back compares <code>Value</code>. Each setting is set by itself; the other two keep what the namespace holds.</p>
/// <p>Its pairs are the screen's, which include WRITE on the classic page's own resource, and WRITE on the namespace's globals database (AD-8).</p>
Class OcuPilot.Screen.Tool.InteropArchiveSettingSet Extends OcuPilot.Screen.Tool.InteropPurgeSettingSet
{

Parameter TOOLNAME = "interop.archivesettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropArchiveSettingList";

Parameter DESCRIPTION = "Propose changing one archive setting of the namespace the user is working in, as the classic Archive Manager page's Save does. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting exactly as the Archive settings list reports it in its Name column and give the new value as text in the form its Accepts column states: Archive to namespace takes the name of another interoperability namespace the list names, and Number of days before archiving takes a whole number from 0 to 36500. Archive manager class name is shown and never changed. The settings are used by the next archive run. A setting the list does not report, one that is shown and never changed, and a value the setting does not accept are refused.";

Parameter ENDPOINTNAME = "ArchiveSettings";

Parameter RULES = "OcuPilot.Area.Interop.ArchiveSettingRules";

Parameter CLASSICPAGES = "EnsPortal.ArchiveManager";

Parameter WRITERESOURCE = "%Ens_ArchiveManager";

Parameter READANSWERS = "Name,Value,Stored,Kind,Accepts,ReadOnly,Namespace";

/// <p>What the caller must hold: the screen's own pairs, which are READ on the classic page's resource, then WRITE on it, then WRITE on the globals database of the namespace the request
/// is scoped to, which <code>^Ens.ArchiveManager</code> maps to, then the custom resource of the classic page (AD-8, AD-44, AD-62). <var>pResolved</var> is 0 when the database names no
/// resource.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Set tGlobals = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(##class(OcuPilot.Kernel.Scope).Current(), .tGlobals, .tReadOnly) || (tGlobals = "") {
        Set pResolved = 0
        Quit ""
    }
    Set tDatabase = $ListBuild(tGlobals, "WRITE")
    If '$ListFind(tPairs, tDatabase) Set tPairs = tPairs _ $ListBuild(tDatabase)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The setting and the value judged by <class>OcuPilot.Area.Interop.ArchiveSettingRules</class> against the namespace the request is scoped to: the class is read-only
/// (<code>CONFIG.SETTING.READONLY</code>), Archive to namespace is one of the namespaces the classic page lists other than this one, the days are a whole number from 0 to 36500.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tValue = $Select($IsObject(pArgs) && (pArgs.%GetTypeOf("Value") = "string"): pArgs.%Get("Value"), 1: "")
    Set tRow = {"Name": (pIdValue), "ReadOnly": (''##class(OcuPilot.Port.InteropPort).ArchiveSettingReadOnly(pIdValue)), "Namespace": (##class(OcuPilot.Kernel.Scope).Current())}
    Set pProblem = $ClassMethod(..#RULES, "SentenceFor", ..Endpoint(), tRow, tValue)
    Quit $$$OK
}

/// <p>The rules again at the confirm, except the target's membership of the namespaces the classic page lists: that list is the proposal's own namespace's, which the
/// confirming request may not be scoped to, so the port judges it at the write, in the namespace the proposal read.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tEntry = ##class(OcuPilot.Port.InteropPort).ArchiveSettingEntry(pIdValue)
    If (tEntry = "") || ($List(tEntry, 4) '= "choice") Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
    Quit $$$OK
}

/// <p>What the schema says of the setting's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The setting, named exactly as the Archive settings list reports it in its Name column. A setting the list does not report, and the archive class, which is shown and never changed, are refused."
}

}
