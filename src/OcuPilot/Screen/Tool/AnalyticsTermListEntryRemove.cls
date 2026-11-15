/// <p>Analytics' term list entry remove (AD-6, AD-10, AD-51, AD-53, AD-65, Story 24.2): remove one entry from a term list. Cubes and pivots
/// that look the key up then get their default, and removing the last entry leaves an empty list. The classic page saves a list by
/// deleting and recreating it; this removes the one entry.</p>
/// <p><b>It is destructive</b>: a removed entry cannot be restored from OcuPilot, so its card draws the destructive treatment, the Entries
/// screen's row action Remove types the entry's key, and its governance key ships disabled (AD-22). Its read-back reads the entry gone on the
/// port's 404. Two callers reach it: that row action through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and
/// confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListEntryRemove Extends OcuPilot.Screen.Tool.AnalyticsTermListEntryAction
{

Parameter TOOLNAME = "analytics.termlistentries.remove";

Parameter DESCRIPTION = "Propose removing one entry from a term list of the namespace the user is working in, which cannot be restored from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the term list and the entry's key as the Term lists and entries lists report them. Cubes and pivots that look the key up then get their default value. An entry the list does not hold and a database that is read-only or not journaled are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "ENTRYREMOVE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter CONSEQUENCECODE = "ANALYTICS.TERMLIST.REMOVE";

Parameter FINGERPRINTSUBJECT = "TermList,Key,Value,Fields,Namespace";

Parameter PRECONDITIONFIELD = "Value";

Parameter REMOVALROWS = "TermList,Key,Value,Fields";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.ABSENT,ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

ClassMethod NameDescription() As %String
{
    Quit "The entry to remove, named exactly as the term list's entries list reports it in its Key column. An entry the list does not report is refused."
}

}
