/// <p>Cached queries' Purge this table's cached queries (Story 21.6, AD-6, AD-51, AD-53, AD-58): purge every cached query of one table, named as
/// <code>Schema.Table</code>. Two callers reach it: the Cached queries page's own action, on the page's table, and the agent's proposal and
/// confirmation. A table the caller's own information schema does not show is refused at the fresh read, 404, for both callers, before anything is
/// written. A table of OcuPilot's own is purged like any other: a purge costs a re-prepare.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlCachedQueryPurgeTable Extends OcuPilot.Screen.Tool.SqlCachedQueryPurge
{

Parameter TOOLNAME = "explorer.sqlcachedqueries.purgetable";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries";

Parameter DESCRIPTION = "Propose purging every cached query of one table, so each is prepared again the next time it runs. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column. A table this namespace does not show you is refused.";

Parameter SCREENACTIONS = "purge-table";

Parameter IDARGUMENT = "Table";

Parameter IDDESCRIPTION = "The table whose cached queries to purge, as Schema.Table, as this namespace's SQL tables list reports it in its Table column.";

/// <p>A table, as <code>Schema.Table</code>: the shape <class>OcuPilot.Port.SqlPort</class> resolves through the caller's information schema, and
/// never a cached query's class.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    If (pId [ ".") && ($Length(pId) <= $Parameter(tPort, "MAXTABLE")) && ($ZStrip(pId, "*C") = pId) && ($Extract(pId, 1, $Length(##class(OcuPilot.Port.SqlPort).#CACHEDQUERYPREFIX)) '= ##class(OcuPilot.Port.SqlPort).#CACHEDQUERYPREFIX) Quit ""
    Quit "'" _ ..IdArgument() _ "' names one table as Schema.Table, as this namespace's SQL tables list reports it"
}

}
