/// <p>Locale properties' Remove table (Story 21.16, AD-6, AD-51, AD-52, AD-53, AD-56 (ii), AD-58): remove one table from a list of a custom locale
/// that is not the current locale, through <class>OcuPilot.Port.LocalePort</class>. The agent reaches it through a proposal the user confirms;
/// the Locale properties screen reaches it through its <code>remove-table</code> row action.</p>
/// <p>It is not destructive: it touches only a custom, non-current locale, and Add table restores it, so its governance key ships on. The change is a
/// delta over the fresh read (AD-56 (ii)). A table that is its list's default, a row that is not a table, a locale InterSystems ships and the
/// current locale are refused before any vendor call. Its read-back reads the row gone on the port's 404.</p>
Class OcuPilot.Screen.Tool.LocaleTableRemove Extends OcuPilot.Screen.Tool.LocalePropertyAction
{

Parameter TOOLNAME = "osmgmt.localeproperties.remove";

Parameter DESCRIPTION = "Propose removing one table from a list of one custom locale, whose name starts with y and which is not the current locale. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the locale and the table exactly as the Locale properties list reports them, for example PatternTables:Latin2. A table that is a default of the locale, a row that is not a table, a locale InterSystems ships and the current locale are refused.";

Parameter WRITETYPE = "REMOVE";

Parameter SCREENACTIONS = "remove-table";

Parameter CHANGEACTION = "deleted";

Parameter PRECONDITIONFIELD = "Value";

Parameter FINGERPRINTSUBJECT = "Locale,Name,Value";

Parameter REMOVALROWS = "Locale,Name,Value";

Parameter PRECONDITIONCODES = "LOCALE.TABLE.DEFAULT,LOCALE.TABLE.ROW";

Parameter IDDESCRIPTION = "The table to remove, named exactly as the Locale properties list reports it in its Name column, for example PatternTables:Latin2. A table that is a default of the locale and a row that is not a table are refused.";

/// <p>The removal rows the card shows: what the removed row held. A read that answered no <code>Value</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Value") '= "string") {
            Set pProblem = "this instance did not report the table, and a table whose state is unknown is not one to remove"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
