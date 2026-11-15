/// <p>SQL Shell settings' Set value (Story 21.4, AD-6, AD-51, AD-53, AD-58): set one default of the SQL Shell on this instance. The agent reaches it
/// through a proposal the user confirms; SQL Shell settings reaches it through its <code>set</code> row action, which names the
/// setting and the value. Its rules, pairs and consequence are <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
Class OcuPilot.Screen.Tool.SqlShellSettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.sqlshellsettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SqlShellSettingList";

Parameter DESCRIPTION = "Propose setting one default of the SQL Shell on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting as the SQL Shell settings list reports it, and give the new value as text in the form the list's Accepts column states; a choice takes one of the names it lists, written exactly. A setting the list marks as shown and never changed, a name the list does not report and a value the setting does not accept are refused.";

Parameter ENDPOINTNAME = "SQLShell";

Parameter CLASSICPAGES = "%CSP.UI.Portal.SQL.Configure.SQL";

}
