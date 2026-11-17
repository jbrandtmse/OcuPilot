/// <p>Locale definitions' Install (Story 21.14, AD-6, AD-10, AD-51, AD-53, AD-58): make one locale the instance's current locale through
/// <class>OcuPilot.Port.LocalePort</class>. The agent reaches it through a proposal the user confirms; Locale definitions reaches it through
/// its <code>install</code> row action. Installing purges every cached query and can change IRISTEMP's default collation, which the card
/// states (<parameter>CONSEQUENCECODE</parameter>); the answer names that collation before and after.</p>
/// <p><b>It is destructive</b>: it purges every cached query and can change IRISTEMP's default collation. Its card draws the destructive
/// treatment, its row action types the locale's name, and its governance key ships disabled (AD-22). A locale the vendor's own check refuses is refused before any vendor call.
/// Its fingerprint covers the locale's name and whether it is current: a change since the mint refuses the confirm.</p>
Class OcuPilot.Screen.Tool.LocaleInstall Extends OcuPilot.Screen.Tool.LocaleAction
{

Parameter TOOLNAME = "osmgmt.locales.install";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

Parameter DESCRIPTION = "Propose installing one locale as this instance's current locale. Installing purges every cached query and can change IRISTEMP's default collation. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the locale exactly as the Locale definitions list reports it. A locale the list does not report, and one the instance's own check refuses to install, are refused.";

Parameter WRITETYPE = "INSTALL";

Parameter SCREENACTIONS = "install";

/// <p>Declared: an install purges every cached query and can change IRISTEMP's default collation.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter READANSWERS = "Name,Description,Current,Custom";

Parameter PRECONDITIONFIELD = "Current";

Parameter FINGERPRINTSUBJECT = "Name,Current";

Parameter IDDESCRIPTION = "The locale to install, named exactly as the Locale definitions list reports it in its Name column. A locale the list does not report is refused.";

/// <p>The client maps it to the install consequence, pinned equal to <parameter>OcuPilot.Api.LocaleError.INSTALL</parameter>.</p>
Parameter CONSEQUENCECODE = "LOCALE.INSTALL";

/// <p><parameter>CONSEQUENCECODE</parameter>, the warning the card states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
