/// <p>SQL schema's Tune all tables (Story 21.25, AD-6, AD-7, AD-51, AD-53, AD-56, AD-58): measure every table of one schema as Collect statistics measures
/// one. Two callers reach it: the schema's Tables tab's Tune all tables page action, whose one value is
/// <code>ClearValues</code>, and the agent's proposal and confirmation. The tune runs in the request, with display off and no log file, and answers when
/// it ends; a message the instance answers is its refusal. A schema the caller's own information schema shows no table of is refused at the fresh read,
/// 404, and a schema of OcuPilot's own is refused, for both callers, before anything is written. Its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlSchemaTune Extends OcuPilot.Screen.Tool.SqlTableTuneAction
{

Parameter TOOLNAME = "explorer.sqlschematables.tune";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlSchema";

Parameter DESCRIPTION = "Propose collecting the statistics of every table in one SQL schema: each table's extent size and each field's selectivity are measured from its current rows, and some cached queries may be purged, including ones on other tables. With ClearValues true the fixed values each table holds are cleared first. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the schema as explorer.sqlschemas.read reports it in its Schema column. A schema this namespace shows you no table of is refused, and so is a schema of OcuPilot's own.";

Parameter WRITETYPE = "TUNESCHEMA";

Parameter SCREENACTIONS = "tune";

Parameter SCREENVALUES = "tune=ClearValues";

Parameter VALUENAMES = "ClearValues";

/// <p>The schema's read, which counts its tables.</p>
Parameter READTYPE = "SCHEMA";

Parameter READANSWERS = "Namespace,Schema,Tables,ClearValues";

/// <p>The namespace, how many tables the tune measures and the declared value: a table added or dropped since the proposal is not the tune the
/// person reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,Tables,ClearValues";

Parameter PRECONDITIONFIELD = "Tables";

Parameter IDDESCRIPTION = "The schema to tune, as this namespace's SQL schemas list reports it in its Schema column.";

Parameter CONSEQUENCECODE = "SQL.TABLE.TUNESCHEMA";

/// <p>The schema's name.</p>
ClassMethod IdArgument() As %String
{
    Quit "Schema"
}

/// <p>The id names a schema.</p>
ClassMethod NamesSchema() As %Boolean
{
    Quit 1
}

/// <p>Why <var>pId</var> is not a schema this tool acts on, or <code>""</code>: a name of 1 to
/// <parameter>OcuPilot.Port.AtelierPort.MAXSCHEMA</parameter> characters holding no control character, which is the shape the port resolves.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If '$IsObject(pId) && (pId '= "") && ($Length(pId) <= $Parameter("OcuPilot.Port.AtelierPort", "MAXSCHEMA")) && ($ZStrip(pId, "*C") = pId) Quit ""
    Quit "'" _ ..IdArgument() _ "' names one schema, as this namespace's SQL schemas list reports it"
}

}
