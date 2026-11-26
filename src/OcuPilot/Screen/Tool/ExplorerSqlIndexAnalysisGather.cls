/// <p>SQL index analyzer's Gather statements (Story 21.27, AD-6, AD-7, AD-51, AD-53, AD-58): gather the namespace's cached queries, class methods, class
/// queries and routines again, replacing the statements it had gathered and every report's results. Two callers reach it: the page's own Gather statements
/// action, which sends the two skip choices, and the agent's proposal and confirmation, which may leave either out and so skips what the classic page's
/// boxes skip. The gathering runs in the request; one that includes system classes and routines outlasts the page's wait and runs to its end
/// (<class>OcuPilot.Port.SqlPort</class>), so the consequence the card states says so when <code>SkipSystem</code> is false. It also rebuilds the
/// namespace's class dependency data, as the classic gathering does.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisGather Extends OcuPilot.Screen.Tool.SqlIndexAnalysisAction
{

Parameter TOOLNAME = "explorer.sqlindexanalysis.gather";

Parameter DESCRIPTION = "Propose gathering this namespace's SQL statements for the index analyzer: its cached queries, class methods, class queries and routines are gathered again, and the statements it had gathered and every report's results are replaced. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal '*' as the target. Gathering system classes and routines takes longer than the page waits, so leave SkipSystem true unless the person asks for them.";

Parameter WRITETYPE = "GATHER";

Parameter SCREENACTIONS = "gather";

Parameter SCREENVALUES = "gather=SkipSystem:SkipInserts";

Parameter VALUENAMES = "SkipSystem,SkipInserts";

/// <p>The analysis the person reviewed and the two choices, so a confirm gathers with the choices reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Statements,IndexUsage,TableScans,TempIndices,JoinIndices,OutlierIndices,Rows,SkipSystem,SkipInserts";

Parameter VALUEDESCRIPTIONS = "SkipSystem=true (the default) skips system classes and routines, false gathers them too, which takes much longer.|SkipInserts=true (the default) skips INSERT statements, false gathers them too.";

Parameter CONSEQUENCECODE = "SQL.INDEXANALYSIS.GATHER";

/// <p>Both skip choices are optional: an absent one is true.</p>
ClassMethod RequiredFields() As %List
{
    Quit ""
}

/// <p>The gathering's consequence, with the sentence about system classes and routines when the payload says to include them.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If $IsObject(pPayload) && (pPayload.%GetTypeOf("SkipSystem") = "boolean") && 'pPayload.%Get("SkipSystem") Quit "SQL.INDEXANALYSIS.GATHERSYSTEM"
    Quit ..#CONSEQUENCECODE
}

}
