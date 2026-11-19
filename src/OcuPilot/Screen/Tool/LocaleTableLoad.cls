/// <p>Locale properties' Load table (Story 21.16, AD-6, AD-10, AD-51, AD-52, AD-53, AD-58): load one table a locale lists into the running instance
/// through <class>OcuPilot.Port.LocalePort</class>, which calls <code>Config.NLS.Tables.Load</code> with the locale, the type the list fixes and the
/// table. The agent reaches it through a proposal the user confirms; the Locale properties screen reaches it through its <code>load-table</code>
/// row action. Only a table the locale's own <code>Tables</code> query lists as not built in, compared exactly, is loadable; any locale may be
/// the source, the current one included.</p>
/// <p><b>It is destructive</b>: a load makes the table available to every process until the next restart, and on the current locale it can change
/// the instance's defaults. Its card draws the destructive treatment (<parameter>CONSEQUENCECODE</parameter>) and its governance key ships disabled
/// (AD-22). It sends no body; its fingerprint covers the row's locale, name and whether it is loadable.</p>
Class OcuPilot.Screen.Tool.LocaleTableLoad Extends OcuPilot.Screen.Tool.LocalePropertyAction
{

Parameter TOOLNAME = "osmgmt.localeproperties.load";

Parameter DESCRIPTION = "Propose loading one table a locale lists into the running instance, so that every process can use it until the next restart. On the current locale it can also change the instance's defaults. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the locale and the table exactly as the Locale properties list reports them, for example PatternTables:Latin2. Only a table the row marks as loadable is accepted; a table that is built in, a row that is not a table and an accent table are refused.";

Parameter WRITETYPE = "LOAD";

Parameter SCREENACTIONS = "load-table";

/// <p>Declared: a load changes what every process on the instance can use, and on the current locale can change its defaults.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CLASSICPAGES = "%CSP.UI.Portal.NLS";

Parameter PRECONDITIONFIELD = "Loadable";

Parameter FINGERPRINTSUBJECT = "Locale,Name,Loadable";

Parameter PRECONDITIONCODES = "LOCALE.TABLE.NOTLOADABLE";

Parameter IDDESCRIPTION = "The table to load, named exactly as the Locale properties list reports it in its Name column, for example PatternTables:Latin2. Only a row the list marks as loadable is accepted.";

/// <p>The client maps it to the load consequence, pinned equal to <parameter>OcuPilot.Api.LocaleError.LOAD</parameter>.</p>
Parameter CONSEQUENCECODE = "LOCALE.LOAD";

/// <p><parameter>CONSEQUENCECODE</parameter>, the warning the card states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
