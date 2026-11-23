/// <p>SQL table's Rebuild all indices (Story 21.25, AD-6, AD-7, AD-51, AD-53, AD-58): empty and build again every index of one table from its rows. Two
/// callers reach it: the Table info tab's Rebuild all indices page action and the agent's proposal and confirmation. The rebuild runs in the
/// request, holds the table's extent lock while it builds, and answers when it ends. A table the caller's own information schema does not show is
/// refused at the fresh read, 404, and a table of OcuPilot's own is refused, for both callers, before anything is written. Its governance key
/// ships disabled: a rebuild locks the table against changes while it runs.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlTableRebuildIndices Extends OcuPilot.Screen.Tool.SqlTableAction
{

Parameter TOOLNAME = "explorer.sqltable.rebuildindices";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlTable";

Parameter DESCRIPTION = "Propose rebuilding every index of one SQL table: each index is emptied and built again from the table's rows, and the table is locked against changes while it runs. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column. A table this namespace does not show you is refused, and so is a table of OcuPilot's own.";

Parameter WRITETYPE = "REBUILDALL";

Parameter SCREENACTIONS = "rebuild-indices";

Parameter CONSEQUENCECODE = "SQL.TABLE.REBUILDALL";

}
