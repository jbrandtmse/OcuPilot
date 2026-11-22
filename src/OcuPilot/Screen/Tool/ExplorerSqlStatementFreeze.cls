/// <p>SQL statements' Freeze plan (Story 21.6, AD-6, AD-51, AD-53, AD-58): freeze one statement's plan, so the statement keeps the plan it has
/// until it is unfrozen. Two callers reach it: the list's Freeze plan row action and the agent's proposal and confirmation. A statement whose plan
/// is already frozen is refused at the fresh read, for both callers, before anything is written; the read-back reads <code>nothingSent</code>.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlStatementFreeze Extends OcuPilot.Screen.Tool.SqlStatementAction
{

Parameter TOOLNAME = "explorer.sqlstatements.freeze";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlStatementList";

Parameter DESCRIPTION = "Propose freezing one SQL statement's plan, so the statement keeps its current plan until it is unfrozen, even when its indices or table statistics change. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the statement by the hash explorer.sqlstatements.read reports for it. A statement whose plan is already frozen is refused, and so is a statement over OcuPilot's own tables.";

Parameter WRITETYPE = "FREEZE";

Parameter SCREENACTIONS = "freeze";

Parameter STATEFIELD = "PlanState";

Parameter STATEAFTER = "Frozen/Explicit";

Parameter PRECONDITIONFIELD = "PlanState";

Parameter REFUSALCODE = "SQL.STATEMENT.ALREADYFROZEN";

Parameter CONSEQUENCECODE = "SQL.STATEMENT.FREEZE";

/// <p>An unfrozen plan only: a frozen plan is already what the person asked for, and a plan the instance is still scanning in parallel is
/// neither.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (pFresh.%Get("PlanState") = "Unfrozen")
}

}
