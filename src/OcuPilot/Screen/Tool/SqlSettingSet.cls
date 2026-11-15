/// <p>SQL settings' Set value (Story 21.4, AD-6, AD-51, AD-53, AD-58): set one SQL setting of this instance (<code>Config.SQL</code>). The agent reaches it
/// through a proposal the user confirms; SQL settings reaches it through its <code>set</code> row action, which names the
/// setting and the value. Its rules, pairs and consequence are <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
Class OcuPilot.Screen.Tool.SqlSettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.sqlsettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SqlSettingList";

Parameter DESCRIPTION = "Propose setting one SQL setting of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting as the SQL settings list reports it, and give the new value as text in the form the list's Accepts column states; a boolean setting takes 1 or 0. A setting the list marks as shown and never changed, a name the list does not report and a value the setting does not accept are refused. A setting the card says purges the cached queries is stored now and purges the cached queries in every namespace when its value changes.";

Parameter ENDPOINTNAME = "SQL";

Parameter CLASSICPAGES = "%CSP.UI.Portal.SQL.Configure.SQL";

}
