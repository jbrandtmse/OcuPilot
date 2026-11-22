/// <p>Cached queries' Purge all cached queries in this namespace (Story 21.6, AD-6, AD-51, AD-53, AD-58): purge every cached query of the
/// namespace. Two callers reach it: the Cached queries page's own action, on the target <code>*</code>, and the agent's proposal and
/// confirmation. The classic SQL page offers it from any of its pages, so it is not tied to the table the tab shows.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlCachedQueryPurgeNamespace Extends OcuPilot.Screen.Tool.SqlCachedQueryPurge
{

Parameter TOOLNAME = "explorer.sqlcachedqueries.purgenamespace";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries";

Parameter DESCRIPTION = "Propose purging every cached query in this namespace, so each is prepared again the next time it runs. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal '*' as the target.";

Parameter SCREENACTIONS = "purge-namespace";

Parameter IDARGUMENT = "Target";

Parameter IDDESCRIPTION = "Send the literal '*': this purges all of this namespace's cached queries.";

/// <p>The literal <code>*</code> only.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If pId = ##class(OcuPilot.Port.SqlPort).#ALLID Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ##class(OcuPilot.Port.SqlPort).#ALLID _ "': this purges all of this namespace's cached queries"
}

}
