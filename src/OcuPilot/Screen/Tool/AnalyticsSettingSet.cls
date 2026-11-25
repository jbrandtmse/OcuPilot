/// <p>Analytics' General setting change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-58, AD-65, Story 24.13): store a new value for one General setting of the namespace the request is scoped to, as the classic
/// Settings page's Save does. It is <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s shape over <class>OcuPilot.Port.AnalyticsPort</class>: its fresh read is the port's <code>SETTING</code> row
/// <code>{Name, Value, Stored, Kind, Accepts, Namespace}</code>, a value is judged by <class>OcuPilot.Area.Analytics.SettingRules</class> at the mint and again at the write, and its read-back
/// compares <code>Value</code>.</p>
/// <p><b>The page saves its whole form.</b> The port composes it from every setting as its row shows it and stores all fourteen, so a namespace that has never saved holds every General row stored
/// afterwards; the card says so (<parameter>CONSEQUENCECODE</parameter>) when any row is not stored. The Google Maps key is a secret and is refused here; its own tool
/// (<class>OcuPilot.Screen.Tool.AnalyticsSettingKey</class>) sets it. The <code>Worklist</code> row turns the Worklists options on and off through the page's own call.</p>
Class OcuPilot.Screen.Tool.AnalyticsSettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "analytics.settings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsSettingList";

Parameter DESCRIPTION = "Propose changing one General analytics setting of the namespace the user is working in, as the classic Settings page's Save does. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting exactly as the General list reports it in its Setting column and give the new value as text in the form its Accepts column states: a choice takes one of the names listed, a boolean takes 1 or 0, a text setting takes up to 2000 characters. The Google Maps key is a secret and has its own action. A setting the list does not report, a value the setting does not accept and a database that is read-only are refused.";

Parameter PORTCLASS = "OcuPilot.Port.AnalyticsPort";

Parameter READTYPE = "SETTING";

Parameter WRITETYPE = "SETTINGSET";

Parameter ENDPOINTNAME = "Settings";

/// <p>The fresh read is composed from the action it is read for (<method>PortQuery</method>), at the mint as at a screen action.</p>
Parameter READSVALUES As BOOLEAN = 1;

Parameter RULES = "OcuPilot.Area.Analytics.SettingRules";

Parameter CLASSICPAGES = "%DeepSee.UI.Settings";

Parameter READANSWERS = "Name,Value,Stored,Kind,Accepts,Namespace";

/// <p>The consequence code of a set that stores every General row, pinned equal to <parameter>OcuPilot.Api.AnalyticsError.SETTINGSAVE</parameter>.</p>
Parameter CONSEQUENCECODE = "ANALYTICS.SETTING.SAVE";

Parameter PRECONDITIONCODES = "CONFIG.SETTING.NOTFOUND,ANALYTICS.SETTING.SECRET,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

/// <p>The query parameter the port reads the setting's name under.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#IDKEY
}

/// <p>The action key (composing the read for this write) and the namespace a stored payload names.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##class(OcuPilot.Port.AnalyticsPort).ActionQuery(pPayload, "Stored", ..#WRITETYPE, .pQuery)
}

/// <p>What the caller must hold: the screen's own pairs, WRITE on the database the settings global maps to, READ on the routines database and the custom
/// resource of the classic Settings page, each refused by name before any port call (AD-8, AD-44, AD-65).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).WritePairs(..#DESCRIPTORCLASS, ##class(OcuPilot.Port.AnalyticsPort).#SETTINGSGLOBAL, ..#CLASSICPAGES, .pResolved)
}

/// <p><parameter>CONSEQUENCECODE</parameter> when the namespace the payload names holds a General row that is not stored, which this write stores, else <code>""</code>. A set of
/// <code>Worklist</code> stores no other row.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf("Name") '= "string") || (pPayload.%Get("Name") = ##class(OcuPilot.Port.AnalyticsPort).#SETTINGCUSTOMNAME) Quit ""
    Quit $Select(##class(OcuPilot.Port.AnalyticsPort).UnstoredGeneral($Select(pPayload.%GetTypeOf("Namespace") = "string": pPayload.%Get("Namespace"), 1: "")): ..#CONSEQUENCECODE, 1: "")
}

/// <p>A setting changed since the review closes the proposal as moved (<method>OcuPilot.Screen.Tool.ConfigSettingSet.MergeUpdate</method>).</p>
Parameter GUARDMOVED As BOOLEAN = 1;

/// <p>Nothing follows the write: the page's own call is the whole of it.</p>
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

/// <p><code>Value</code> when the call <var>pInput</var> names the Google Maps key, in any case, else none: the set refuses that setting, and its ledger row and step show the redaction mark
/// in place of whatever the agent sent for it (AD-3 layer 1, AD-35, AD-41).</p>
ClassMethod CallSecretNames(pInput As %DynamicAbstractObject) As %List
{
    If '$IsObject(pInput) || 'pInput.%IsA("%Library.DynamicObject") Quit ""
    If pInput.%GetTypeOf("Name") '= "string" Quit ""
    If $ZConvert(pInput.%Get("Name"), "U") = $ZConvert(##class(OcuPilot.Port.AnalyticsPort).#SETTINGSECRETNAME, "U") Quit $ListBuild("Value")
    Quit ""
}

/// <p>What the schema says of the setting's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The setting, named exactly as the General list reports it in its Setting column. A setting the list does not report is refused, and so is the Google Maps key, which has its own action."
}

}
