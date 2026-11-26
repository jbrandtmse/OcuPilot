/// <p>SQL index analyzer's Purge analysis (Story 21.27, AD-6, AD-7, AD-51, AD-53, AD-58): remove the statements the namespace has gathered and every
/// report's results. The classic page's two purges are one here. Two callers reach it: the page's own Purge analysis action, on the target <code>*</code>,
/// and the agent's proposal and confirmation. A namespace that holds neither is refused at the fresh read, for both callers, before anything is called.
/// A removed result comes back only by gathering and running again, and its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisPurge Extends OcuPilot.Screen.Tool.SqlIndexAnalysisAction
{

Parameter TOOLNAME = "explorer.sqlindexanalysis.purge";

Parameter DESCRIPTION = "Propose purging this namespace's index analysis: the SQL statements it has gathered and every report's results are removed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal '*' as the target. A namespace that holds no index analysis is refused.";

Parameter WRITETYPE = "PURGEANALYSIS";

Parameter SCREENACTIONS = "purge";

Parameter REFUSALCODE = "SQL.INDEXANALYSIS.NOROWS";

Parameter CONSEQUENCECODE = "SQL.INDEXANALYSIS.PURGE";

/// <p>A namespace that holds a gathered statement or a report row.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && ((+pFresh.%Get("Statements") + pFresh.%Get("Rows")) > 0)
}

}
