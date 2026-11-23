/// <p>SQL statements' Clear statistics (Story 21.6, AD-6, AD-51, AD-53, AD-58): remove one statement's run statistics, so counting starts again at
/// its next run. Two callers reach it: the list's Clear statistics row action and the agent's proposal and confirmation. It has no precondition,
/// and its state row is the statement's executions, which read blank afterwards. The statistics are not in the fingerprint's subject, and a
/// cleared statistic does not come back, so its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlStatementClearStatistics Extends OcuPilot.Screen.Tool.SqlStatementAction
{

Parameter TOOLNAME = "explorer.sqlstatements.clearstatistics";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlStatementList";

Parameter DESCRIPTION = "Propose clearing one SQL statement's run statistics, so counting starts again at its next run; its plan is unchanged. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the statement by the hash explorer.sqlstatements.read reports for it. A statement over OcuPilot's own tables is refused.";

Parameter WRITETYPE = "CLEARSTATISTICS";

Parameter SCREENACTIONS = "clear-statistics";

Parameter STATEFIELD = "Executions";

Parameter STATEAFTER = "";

Parameter CONSEQUENCECODE = "SQL.STATEMENT.CLEARSTATISTICS";

}
