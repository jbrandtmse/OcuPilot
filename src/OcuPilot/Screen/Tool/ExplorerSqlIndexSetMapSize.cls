/// <p>SQL indices' Set map size (Story 21.31, AD-6, AD-7, AD-51, AD-53, AD-56, AD-58): set one map's size, in MB, as a fixed statistic, which the optimizer
/// uses in place of the measured one. Two callers reach it: the Indices tab's Set map size row action, whose one value is <code>SizeMB</code>, and the
/// agent's proposal and confirmation. The target is the composite <code>[Table, Map]</code> (<class>OcuPilot.Screen.Tool.SqlIndexMint</class>). The
/// instance takes a map's size in blocks of 2 KB, so the port sends 512 blocks for each MB. It runs in the request. A table whose statistics were collected
/// has them saved as its fixed statistics first. A map the table does not hold is refused at the fresh read, 400, and a map of a table of OcuPilot's own
/// is refused, for both callers, before anything is written. Its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlIndexSetMapSize Extends OcuPilot.Screen.Tool.SqlTableSetAction
{

Parameter TOOLNAME = "explorer.sqlindices.setmapsize";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlIndices";

Parameter DESCRIPTION = "Propose setting the size of one map or index of one SQL table, in MB, as a fixed statistic, which the optimizer uses in place of the measured one until the table's fixed statistics are cleared. If the table's statistics were collected, they are first saved as its fixed statistics. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column, and the map by the SQL map name explorer.sqlindices.read reports in its Map column, and give SizeMB as a whole number of MB, 1 or more. A map of a table of OcuPilot's own is refused.";

/// <p>The fresh read: the one indices row of the target, with its size.</p>
Parameter READTYPE = "INDEX";

Parameter READANSWERS = "Namespace,Table,Class,Index,Map,Type,SizeMB,StatsKind,CollectedAt,HasFixed";

Parameter WRITETYPE = "SETMAPSIZE";

Parameter SCREENACTIONS = "set-map-size";

Parameter SCREENVALUES = "set-map-size=SizeMB";

Parameter VALUENAMES = "SizeMB";

Parameter VALUEDESCRIPTIONS = "SizeMB=The map's new size, as a whole number of MB, 1 or more.";

Parameter FINGERPRINTSUBJECT = "Namespace,Table,Map,Type,SizeMB,StatsKind,CollectedAt,HasFixed";

Parameter PRECONDITIONFIELD = "Type";

Parameter SECONDARGUMENT = "Map";

Parameter SECONDDESCRIPTION = "The map to change, named by the SQL map name the table's Indices tab reports in its Map column.";

Parameter CONSEQUENCECODE = "SQL.TABLE.SETMAPSIZE";

/// <p>The query carries the size, so the read-back compares it with the map's size read again.</p>
Parameter READBACKFIELDS = "SizeMB";

Parameter READBACKPAYLOAD As BOOLEAN = 1;

/// <p><class>OcuPilot.Screen.Tool.SqlIndexMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SqlIndexMint"
}

}
