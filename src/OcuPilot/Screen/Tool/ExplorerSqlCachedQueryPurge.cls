/// <p>Cached queries' Purge (Story 21.6, AD-6, AD-51, AD-53, AD-58): purge one cached query of a table, named by its class. Two callers reach it:
/// the tab's Purge row action and the agent's proposal and confirmation. A class the instance's statement index does not hold is refused at the
/// fresh read, 404, and so is a class of another namespace, for both callers, before anything is written.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlCachedQueryPurge Extends OcuPilot.Screen.Tool.SqlCachedQueryPurge
{

Parameter TOOLNAME = "explorer.sqlcachedqueries.purge";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries";

Parameter DESCRIPTION = "Propose purging one cached query, so it is prepared again the next time it runs. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the query by its class, as explorer.sqlcachedqueries.read reports it in its CachedQuery column, such as %sqlcq.USER.cls12. A class this namespace does not hold is refused.";

Parameter SCREENACTIONS = "purge";

Parameter IDARGUMENT = "CachedQuery";

Parameter IDDESCRIPTION = "The cached query to purge, named by its class as this namespace's Cached queries tab reports it in its CachedQuery column.";

/// <p>A cached query's class name.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If $Match(pId, ##class(OcuPilot.Port.SqlPort).#CACHEDQUERYPATTERN) Quit ""
    Quit "'" _ ..IdArgument() _ "' names one cached query by its class, such as %sqlcq.USER.cls12, as this namespace's Cached queries tab reports it"
}

}
