/// <p>System-wide security's Set value (Story 21.10, AD-4, AD-6, AD-51, AD-53, AD-58): set one system-wide security parameter of
/// <code>Security.System</code>. The agent reaches it through a proposal the user confirms; System-wide security reaches it through its
/// <code>set</code> row action, which names the parameter and the value. Its rules, pairs and merge are
/// <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
/// <p><b>It is destructive</b>: a change moves how every user of the instance signs in, is locked out or is checked, so its card is drawn
/// in the destructive treatment and states <parameter>SECURITYCONSEQUENCE</parameter> (AD-22: its key ships disabled). A parameter the
/// port's roster marks shown and never changed is refused at the mint and again at the write.</p>
Class OcuPilot.Screen.Tool.SystemSecuritySettingSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "security.systemsecurity.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SystemSecuritySettingList";

Parameter DESCRIPTION = "Propose setting one system-wide security parameter of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the parameter as the System-wide security list reports it, and give the new value as text in the form the list's Accepts column states; a boolean parameter takes 1 or 0. A parameter the list marks as shown and never changed, a name the list does not report and a value the parameter does not accept are refused. A change affects how every user of the instance signs in, is locked out or is checked.";

Parameter ENDPOINTNAME = "Security";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Parameters";

/// <p>Declared: the change reaches every user of the instance.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The consequence code of every set, which the client maps to its published sentence.</p>
Parameter SECURITYCONSEQUENCE = "SECURITY.SYSTEM.SET";

/// <p><parameter>SECURITYCONSEQUENCE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#SECURITYCONSEQUENCE
}

}
