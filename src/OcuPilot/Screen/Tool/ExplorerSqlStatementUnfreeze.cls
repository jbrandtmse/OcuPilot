/// <p>SQL statements' Unfreeze plan (Story 21.6, AD-6, AD-51, AD-53, AD-58): unfreeze one statement's plan, so the statement takes the plan the
/// optimizer chooses the next time it is prepared. Two callers reach it: the list's Unfreeze plan row action and the agent's proposal and
/// confirmation. A statement whose plan is not frozen is refused at the fresh read, for both callers, before anything is written.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlStatementUnfreeze Extends OcuPilot.Screen.Tool.SqlStatementAction
{

Parameter TOOLNAME = "explorer.sqlstatements.unfreeze";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlStatementList";

Parameter DESCRIPTION = "Propose unfreezing one SQL statement's plan, so the statement takes the plan the optimizer chooses the next time it is prepared. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the statement by the hash explorer.sqlstatements.read reports for it. A statement whose plan is not frozen is refused, and so is a statement over OcuPilot's own tables.";

Parameter WRITETYPE = "UNFREEZE";

Parameter SCREENACTIONS = "unfreeze";

Parameter STATEFIELD = "PlanState";

Parameter STATEAFTER = "Unfrozen";

Parameter PRECONDITIONFIELD = "PlanState";

Parameter REFUSALCODE = "SQL.STATEMENT.NOTFROZEN";

Parameter CONSEQUENCECODE = "SQL.STATEMENT.UNFREEZE";

/// <p>A frozen plan, whether explicit or an upgrade's.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && ($Extract(pFresh.%Get("PlanState"), 1, 7) = "Frozen/")
}

}
