/// <p>SQL runtime statistics' Purge statistics (Story 21.26, AD-6, AD-51, AD-53, AD-58): remove every runtime statistics row the namespace holds.
/// Two callers reach it: the page's own Purge statistics action, on the target <code>*</code>, and the agent's proposal and confirmation. The
/// vendor's purge takes the namespace alone, so the target <code>*</code> is the namespace's statistics, whose fresh read answers how many rows it
/// holds; a namespace that holds none is refused at the fresh read, for both callers, before anything is written. A purged row does not come back,
/// so its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsPurge Extends OcuPilot.Screen.Tool.SqlStatementAction
{

Parameter TOOLNAME = "explorer.sqlruntimestats.purge";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlRuntimeStats";

Parameter DESCRIPTION = "Propose purging every runtime statistics row this namespace holds. New statistics are recorded only while collection is on. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal '*' as the target. A namespace that holds no runtime statistics is refused.";

Parameter READTYPE = "STATS";

Parameter WRITETYPE = "PURGESTATS";

Parameter SCREENACTIONS = "purge";

Parameter READANSWERS = "Namespace,Rows";

Parameter FINGERPRINTSUBJECT = "Namespace,Rows";

Parameter STATEFIELD = "Rows";

Parameter STATEAFTER = "0";

Parameter PRECONDITIONFIELD = "Rows";

Parameter REFUSALCODE = "SQL.RUNTIMESTATS.NOROWS";

Parameter CONSEQUENCECODE = "SQL.RUNTIMESTATS.PURGE";

Parameter IDDESCRIPTION = "Send the literal '*': this purges all of this namespace's runtime statistics.";

/// <p>The argument naming the target.</p>
ClassMethod IdArgument() As %String
{
    Quit "Target"
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTRUNTIMESTATS
}

/// <p>A namespace that holds at least one runtime statistics row.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (+pFresh.%Get("Rows") > 0)
}

/// <p>The literal <code>*</code> only.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If pId = ##class(OcuPilot.Port.SqlPort).#ALLID Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ##class(OcuPilot.Port.SqlPort).#ALLID _ "': this purges all of this namespace's runtime statistics"
}

}
