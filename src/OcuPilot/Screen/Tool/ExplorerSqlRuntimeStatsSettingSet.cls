/// <p>Runtime statistics collection's Set value (Story 21.26, AD-4, AD-6, AD-51, AD-53, AD-58): set one of the instance's SQL runtime statistics
/// collection rows (the level, the stop in minutes, the level after the stop). The agent reaches it through a proposal the user confirms; Runtime
/// statistics collection reaches it through its <code>set</code> row action, which names the row and the value. Its rules, pairs and consequence are
/// <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s, with the port's own gate and the rule that a stop is set while collection is on
/// (<class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>).</p>
Class OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsSettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "explorer.sqlruntimestatssettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlRuntimeStatsSettings";

Parameter DESCRIPTION = "Propose changing one row of the SQL runtime statistics collection on this instance: CollectionLevel, StopAfterMinutes or LevelAfterStop. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the row as the Runtime statistics collection list reports it, and give the new value as text in the form the list's Accepts column states; a choice takes one of the names it lists, written exactly. Turning collection on to a level of 2 or 3 stops it after 50 minutes unless the stop is set. A stop row is refused while collection is off, and so are StopsAt, a name the list does not report and a value the row does not accept.";

Parameter ENDPOINTNAME = "SQLStats";

Parameter CLASSICPAGES = "%CSP.UI.Portal.SQL.QButtons.RuntimeStatsSettings";

Parameter CONSEQUENCECODE = "SQL.RUNTIMESTATS.SET";

/// <p><parameter>CONSEQUENCECODE</parameter> for every row: a change applies to every namespace on the instance.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>The merge over the fresh read, with <code>Was</code>, the value the row held, added to the payload: the digest a confirm recomputes then
/// covers it, so a row changed since the review closes the proposal as moved though the new value overwrites the old one in the body. The port
/// reads only <code>Value</code> of the body.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISOK(tSC) && (pProblem = "") && $IsObject(pPayload) && $IsObject(pFresh) && (pFresh.%GetTypeOf("Value") = "string") Do pPayload.%Set("Was", pFresh.%Get("Value"), "string")
    Quit tSC
}

}
