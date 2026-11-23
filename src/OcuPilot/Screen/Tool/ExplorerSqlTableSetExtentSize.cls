/// <p>SQL table's Set extent size (Story 21.31, AD-6, AD-7, AD-51, AD-53, AD-56, AD-58): set one table's extent size as a fixed statistic, which the
/// optimizer uses in place of the collected one. Two callers reach it: the Table info tab's Set extent size page action, whose one value is
/// <code>ExtentSize</code>, and the agent's proposal and confirmation. It runs in the request. A table whose statistics were collected has them saved as
/// its fixed statistics first, so the other fixed values keep what was measured. A table the caller's own information schema does not show is refused at
/// the fresh read, 404, and a table of OcuPilot's own is refused, for both callers, before anything is written. Its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlTableSetExtentSize Extends OcuPilot.Screen.Tool.SqlTableSetAction
{

Parameter TOOLNAME = "explorer.sqltable.setextentsize";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlTable";

Parameter DESCRIPTION = "Propose setting the extent size of one SQL table as a fixed statistic, which the optimizer uses in place of the collected one until the table's fixed statistics are cleared. If the table's statistics were collected, they are first saved as its fixed statistics. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column, and give ExtentSize as a whole number from 0 to 1000000000000. A table this namespace does not show you is refused, and so is a table of OcuPilot's own.";

Parameter WRITETYPE = "SETEXTENT";

Parameter SCREENACTIONS = "set-extent-size";

Parameter SCREENVALUES = "set-extent-size=ExtentSize";

Parameter VALUENAMES = "ExtentSize";

Parameter VALUEDESCRIPTIONS = "ExtentSize=The table's new extent size, the number of rows the optimizer assumes, as a whole number from 0 to 1000000000000.";

Parameter CONSEQUENCECODE = "SQL.TABLE.SETEXTENTSIZE";

/// <p>The query carries the extent size, so the read-back compares it with the table's extent size read again.</p>
Parameter READBACKFIELDS = "ExtentSize";

Parameter READBACKPAYLOAD As BOOLEAN = 1;

}
