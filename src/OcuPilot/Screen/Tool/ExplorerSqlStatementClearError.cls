/// <p>SQL statements' Clear plan error (Story 21.6, AD-6, AD-51, AD-53, AD-58): remove one statement's plan error from the statement index; the plan
/// itself is unchanged. Two callers reach it: the list's Clear plan error row action and the agent's proposal and confirmation. A statement with
/// no plan error is refused at the fresh read, for both callers, before anything is written.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlStatementClearError Extends OcuPilot.Screen.Tool.SqlStatementAction
{

Parameter TOOLNAME = "explorer.sqlstatements.clearerror";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlStatementList";

Parameter DESCRIPTION = "Propose clearing one SQL statement's plan error from the statement index; the plan itself is unchanged. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the statement by the hash explorer.sqlstatements.read reports for it. A statement with no plan error is refused, and so is a statement over OcuPilot's own tables.";

Parameter WRITETYPE = "CLEARERROR";

Parameter SCREENACTIONS = "clear-error";

Parameter STATEFIELD = "PlanError";

Parameter STATEAFTER = "";

Parameter PRECONDITIONFIELD = "PlanError";

Parameter REFUSALCODE = "SQL.STATEMENT.NOERROR";

Parameter CONSEQUENCECODE = "SQL.STATEMENT.CLEARERROR";

/// <p>A statement that holds a plan error.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (pFresh.%Get("PlanError") '= "")
}

}
