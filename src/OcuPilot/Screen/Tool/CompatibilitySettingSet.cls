/// <p>Compatibility settings' Set value (Story 21.3, AD-6, AD-51, AD-53, AD-58): set one setting of <code>Config.Miscellaneous</code>. The agent reaches it
/// through a proposal the user confirms; Compatibility settings reaches it through its <code>set</code> row action, which names the
/// setting and the value. Its rules, pairs and consequence are <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
Class OcuPilot.Screen.Tool.CompatibilitySettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.compatibilitysettings.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.CompatibilitySettingList";

Parameter DESCRIPTION = "Propose setting one compatibility setting of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting as the Compatibility settings list reports it, and give the new value as text in the form the list's Accepts column states; a boolean setting takes 1 or 0. A setting the list marks as shown and never changed, a name the list does not report and a value the setting does not accept are refused. A setting the card says takes effect at the next restart is stored now and applies only after the instance restarts.";

Parameter ENDPOINTNAME = "Compatibility";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Config.ValueEditor";

}
