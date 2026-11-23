/// <p>SQL table's Collect statistics (Story 21.25, AD-6, AD-7, AD-51, AD-53, AD-58): measure one table's extent size and each field's selectivity
/// from its current rows. Two callers reach it: the Table info tab's Collect statistics page action, which takes no value, and the agent's proposal and
/// confirmation. The measurement runs in the request, with display off and no log file, and answers when it ends. The class definition is left as it is
/// and the fixed values the table holds are kept. A table the caller's own information schema does not show is refused at the fresh read, 404, and a
/// table of OcuPilot's own is refused, for both callers, before anything is written.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlTableTune Extends OcuPilot.Screen.Tool.SqlTableAction
{

Parameter TOOLNAME = "explorer.sqltable.tune";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlTable";

Parameter DESCRIPTION = "Propose collecting one SQL table's statistics: its extent size and each field's selectivity are measured from its current rows, and some of its cached queries may be purged. The fixed values the table holds are kept. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column. A table this namespace does not show you is refused, and so is a table of OcuPilot's own.";

Parameter WRITETYPE = "TUNE";

Parameter SCREENACTIONS = "tune";

Parameter CONSEQUENCECODE = "SQL.TABLE.TUNE";

}
