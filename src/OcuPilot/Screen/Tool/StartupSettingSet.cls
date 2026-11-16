/// <p>Startup settings' Set value (Story 21.3, AD-6, AD-51, AD-53, AD-58): set one setting of <code>Config.Startup</code>. The agent reaches it
/// through a proposal the user confirms; Startup settings reaches it through its <code>set</code> row action, which names the
/// setting and the value. Its rules, pairs and consequence are <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
Class OcuPilot.Screen.Tool.StartupSettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.startupsettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.StartupSettingList";

Parameter DESCRIPTION = "Propose setting one startup setting of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting as the Startup settings list reports it, and give the new value as text in the form the list's Accepts column states; a boolean setting takes 1 or 0. A setting the list marks as shown and never changed, a name the list does not report and a value the setting does not accept are refused. A setting the card says takes effect at the next restart is stored now and applies only after the instance restarts.";

Parameter ENDPOINTNAME = "Startup";

Parameter CLASSICPAGES = "%CSP.UI.Portal.MemoryStartup,%CSP.UI.Portal.Config.ValueEditor";

}
