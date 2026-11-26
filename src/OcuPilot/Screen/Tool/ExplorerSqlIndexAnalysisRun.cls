/// <p>SQL index analyzer's Run report (Story 21.27, AD-6, AD-7, AD-51, AD-53, AD-58): run one of the five reports over the statements the namespace has
/// gathered, replacing that report's earlier results and no other's. Two callers reach it: the page's own Run report action, which sends the report and the
/// three skip choices, and the agent's proposal and confirmation, which names the report and may leave a choice out, and so skips what the classic page's
/// boxes skip. A namespace that has gathered no statement is refused at the fresh read, for both callers, before anything is called: the vendor would
/// gather them itself, with the report's own skip choices, which takes longer than the page waits where system classes are included.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisRun Extends OcuPilot.Screen.Tool.SqlIndexAnalysisAction
{

Parameter TOOLNAME = "explorer.sqlindexanalysis.run";

Parameter DESCRIPTION = "Propose running one index analyzer report over the SQL statements this namespace has gathered: IU is Index usage, TS Table scan, TI Temporary index, JI Missing join index and OI Outlier index. That report's earlier results are replaced. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal '*' as the target. A namespace that has gathered no statements is refused.";

Parameter WRITETYPE = "RUNREPORT";

Parameter SCREENACTIONS = "run";

Parameter SCREENVALUES = "run=Report:SkipSystem:SkipInserts:SkipIdKeys";

Parameter VALUENAMES = "Report,SkipSystem,SkipInserts,SkipIdKeys";

Parameter REQUIREDVALUES = "Report";

/// <p>The analysis the person reviewed, the report and the three choices, so a confirm runs the report with the choices reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Statements,IndexUsage,TableScans,TempIndices,JoinIndices,OutlierIndices,Rows,Report,SkipSystem,SkipInserts,SkipIdKeys";

Parameter VALUEDESCRIPTIONS = "Report=One of IU (Index usage), TS (Table scan), TI (Temporary index), JI (Missing join index) or OI (Outlier index).|SkipSystem=true (the default) skips system classes and routines.|SkipInserts=true (the default) skips INSERT statements.|SkipIdKeys=true (the default) skips IDKEY indices, for the Index usage report alone.";

Parameter REFUSALCODE = "SQL.INDEXANALYSIS.NOSTATEMENTS";

Parameter CONSEQUENCECODE = "SQL.INDEXANALYSIS.RUN";

/// <p>A namespace that has gathered at least one statement.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (+pFresh.%Get("Statements") > 0)
}

}
