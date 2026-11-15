/// <p>Memory settings' Set value (Story 21.3, AD-6, AD-51, AD-53, AD-58): set one setting of <code>Config.config</code>. The agent reaches it
/// through a proposal the user confirms; Memory settings reaches it through its <code>set</code> row action, which names the
/// setting and the value. Its rules, pairs and consequence are <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
Class OcuPilot.Screen.Tool.MemorySettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.memorysettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.MemorySettingList";

Parameter DESCRIPTION = "Propose setting one memory setting of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting as the Memory settings list reports it, and give the new value as text in the form the list's Accepts column states; a boolean setting takes 1 or 0. A setting the list marks as shown and never changed, a name the list does not report and a value the setting does not accept are refused. A setting the card says takes effect at the next restart is stored now and applies only after the instance restarts.";

Parameter ENDPOINTNAME = "Memory";

Parameter CLASSICPAGES = "%CSP.UI.Portal.MemoryStartup,%CSP.UI.Portal.Config.ValueEditor";

}
