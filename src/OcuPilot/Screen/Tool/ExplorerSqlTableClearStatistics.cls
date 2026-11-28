/// <p>SQL table's Clear fixed statistics (Story 21.25, AD-6, AD-7, AD-51, AD-53, AD-58): remove the fixed statistics saved for one table, so the optimizer
/// uses collected statistics, or none. Two callers reach it: the Table info tab's Clear fixed statistics page action and the agent's proposal and
/// confirmation. A table that has no fixed statistics is refused at the fresh read, for both callers, before anything is written, and a table of
/// OcuPilot's own is refused the same way. Its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlTableClearStatistics Extends OcuPilot.Screen.Tool.SqlTableAction
{

Parameter TOOLNAME = "explorer.sqltable.clearstatistics";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlTable";

Parameter DESCRIPTION = "Propose removing the fixed statistics saved for one SQL table, so the optimizer uses collected statistics, or none. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column. A table with no fixed statistics is refused, and so is a table of OcuPilot's own.";

Parameter WRITETYPE = "CLEARSTATS";

Parameter SCREENACTIONS = "clear-statistics";

Parameter PRECONDITIONFIELD = "HasFixed";

Parameter REFUSALCODE = "SQL.TABLE.NOFIXEDSTATS";

Parameter CONSEQUENCECODE = "SQL.TABLE.CLEARSTATISTICS";

/// <p>A table that holds fixed statistics.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (pFresh.%GetTypeOf("HasFixed") = "boolean") && pFresh.%Get("HasFixed")
}

}
