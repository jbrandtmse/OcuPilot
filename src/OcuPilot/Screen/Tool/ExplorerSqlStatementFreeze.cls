/// <p>SQL statements' Freeze plan (Story 21.6, AD-6, AD-51, AD-53, AD-58): freeze one statement's plan, so the statement keeps the plan it has
/// until it is unfrozen. Two callers reach it: the list's Freeze plan row action and the agent's proposal and confirmation. A statement whose plan
/// is already frozen, or is in the <code>Unfrozen/Parallel</code> state, is refused at the fresh read, for both callers, before anything is written,
/// each with its own sentence; the read-back reads <code>nothingSent</code>. The classic statement dialog disables its Freeze Plan button for a plan
/// in that state (<code>%CSP.UI.Portal.Dialog.SQLStatementDetails</code>, the button's disable condition and its title).</p>
Class OcuPilot.Screen.Tool.ExplorerSqlStatementFreeze Extends OcuPilot.Screen.Tool.SqlStatementAction
{

Parameter TOOLNAME = "explorer.sqlstatements.freeze";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlStatementList";

Parameter DESCRIPTION = "Propose freezing one SQL statement's plan, so the statement keeps its current plan until it is unfrozen, even when its indices or table statistics change. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the statement by the hash explorer.sqlstatements.read reports for it. A statement whose plan is already frozen is refused, and so is one whose plan uses parallel processing, and so is a statement over OcuPilot's own tables.";

Parameter WRITETYPE = "FREEZE";

Parameter SCREENACTIONS = "freeze";

Parameter STATEFIELD = "PlanState";

Parameter STATEAFTER = "Frozen/Explicit";

Parameter PRECONDITIONFIELD = "PlanState";

Parameter REFUSALCODE = "SQL.STATEMENT.ALREADYFROZEN";

/// <p>The code whose sentence refuses a plan in the <code>Unfrozen/Parallel</code> state.</p>
Parameter PARALLELCODE = "SQL.STATEMENT.PARALLEL";

Parameter CONSEQUENCECODE = "SQL.STATEMENT.FREEZE";

/// <p>An unfrozen plan only: a frozen plan is already what the person asked for, and a plan the instance is still scanning in parallel is
/// neither.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (pFresh.%Get("PlanState") = "Unfrozen")
}

/// <p>The parallel plan's sentence for a plan in the <code>Unfrozen/Parallel</code> state; the already-frozen sentence for any other plan this
/// tool refuses.</p>
ClassMethod RefusalCode(pFresh As %DynamicObject) As %String
{
    If $IsObject(pFresh) && (pFresh.%Get("PlanState") = "Unfrozen/Parallel") Quit ..#PARALLELCODE
    Quit ..#REFUSALCODE
}

}
