/// <p>SQL statements' Clean stale statements (Story 21.6, AD-6, AD-51, AD-53, AD-58): remove the namespace's stale entries from its statement index,
/// the statements that no class or routine in the namespace still holds and whose plan is not frozen. Two callers reach it: the page's own Clean stale statements action, on
/// the target <code>*</code>, and the agent's proposal and confirmation. The vendor's clean takes no argument, so the target <code>*</code> is the
/// namespace's index, whose fresh read answers the stale entries it holds; an index that holds none is refused at the fresh read, for both callers,
/// before anything is written. A removed entry does not come back, so its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlStatementClean Extends OcuPilot.Screen.Tool.SqlStatementAction
{

Parameter TOOLNAME = "explorer.sqlstatements.clean";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlStatementList";

Parameter DESCRIPTION = "Propose cleaning this namespace's statement index: removing the statements that no class or routine in the namespace still holds. A statement whose plan is frozen stays. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal '*' as the target. An index that holds no stale statements is refused.";

Parameter WRITETYPE = "CLEAN";

Parameter SCREENACTIONS = "clean";

Parameter READANSWERS = "Namespace,Statements,Stale";

Parameter FINGERPRINTSUBJECT = "Namespace,Stale";

Parameter STATEFIELD = "Stale";

Parameter STATEAFTER = "0";

Parameter PRECONDITIONFIELD = "Stale";

Parameter REFUSALCODE = "SQL.STATEMENT.NOSTALE";

Parameter CONSEQUENCECODE = "SQL.STATEMENT.CLEAN";

Parameter IDDESCRIPTION = "Send the literal '*': a clean acts on all of this namespace's statement index.";

/// <p>An index that holds at least one stale statement.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (+pFresh.%Get("Stale") > 0)
}

/// <p>The literal <code>*</code> only.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If pId = ##class(OcuPilot.Port.SqlPort).#ALLID Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ##class(OcuPilot.Port.SqlPort).#ALLID _ "': a clean acts on all of this namespace's statement index"
}

}
