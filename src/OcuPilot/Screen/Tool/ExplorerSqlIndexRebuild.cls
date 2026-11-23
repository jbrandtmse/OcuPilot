/// <p>SQL indices' Rebuild index (Story 21.25, AD-6, AD-7, AD-51, AD-53, AD-58): empty and build again one index of one table from its rows. Two callers
/// reach it: the Indices tab's Rebuild index row action and the agent's proposal and confirmation. The target is the composite
/// <code>[Table, Map]</code> (<class>OcuPilot.Screen.Tool.SqlIndexMint</class>). The rebuild runs in the request, holds the table's extent lock while it
/// builds, and answers when it ends. The table's data map holds the rows and has no index to rebuild, so it is refused at the fresh read, for both
/// callers, before anything is written; an index of a table of OcuPilot's own is refused the same way. Its governance key ships disabled: a rebuild
/// locks the table against changes while it runs.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlIndexRebuild Extends OcuPilot.Screen.Tool.SqlTableAction
{

Parameter TOOLNAME = "explorer.sqlindices.rebuild";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlIndices";

Parameter DESCRIPTION = "Propose rebuilding one index of one SQL table: the index is emptied and built again from the table's rows, and the table is locked against changes while it runs. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column, and the index by the SQL map name explorer.sqlindices.read reports in its Map column. The table's data map has no index to rebuild and is refused, and so is an index of a table of OcuPilot's own.";

/// <p>The fresh read: the one indices row of the target.</p>
Parameter READTYPE = "INDEX";

Parameter READANSWERS = "Namespace,Table,Class,Index,Map,Type";

Parameter WRITETYPE = "REBUILD";

Parameter SCREENACTIONS = "rebuild";

Parameter FINGERPRINTSUBJECT = "Namespace,Table,Map,Type";

Parameter PRECONDITIONFIELD = "Type";

Parameter REFUSALCODE = "SQL.TABLE.DATAMAP";

Parameter CONSEQUENCECODE = "SQL.TABLE.REBUILD";

Parameter IDDESCRIPTION = "The index to rebuild, named by the SQL map name the table's Indices tab reports in its Map column.";

/// <p>The index's SQL map name, which the table's indices rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Map"
}

/// <p><class>OcuPilot.Screen.Tool.SqlIndexMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SqlIndexMint"
}

/// <p>The index's map, which the card titles it by: the fresh read's <code>Map</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Map") = "string") Quit pFresh.%Get("Map")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Map") = "string") Quit pArgs.%Get("Map")
    Quit ""
}

/// <p>The composite id's table, which the kernel's own-name refusal judges.</p>
ClassMethod NameOf(pIdValue As %String) As %String
{
    Quit $ListGet(##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue), 1)
}

/// <p>The derived schema with the table added and required, and the map described: the target is one index of one table.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("Table", {"type": "string", "description": "The table the index belongs to, as Schema.Table, as this namespace's SQL tables list reports it in its Table column."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push("Table")
    Quit tSchema
}

/// <p>Why <var>pId</var> is not an index this tool acts on, or <code>""</code>: the composite <code>[Table, Map]</code>, the table shaped as a table
/// name (<method>OcuPilot.Screen.Tool.SqlTableAction.TableShaped</method>) and the map a non-empty name within the name bound
/// (<parameter>OcuPilot.Port.SqlPort.MAXNAME</parameter>) holding no control character.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If '$IsObject(pId) {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
        Set tMap = $ListGet(tParts, 2)
        If ($ListLength(tParts) = 2) && ..TableShaped($List(tParts, 1)) && (tMap '= "") && ($Length(tMap) <= ##class(OcuPilot.Port.SqlPort).#MAXNAME) && ($ZStrip(tMap, "*C") = tMap) Quit ""
    }
    Quit "'Table' names one table as Schema.Table and '" _ ..IdArgument() _ "' one of its indices by the SQL map name, as the table's Indices tab reports them"
}

/// <p>An index that is not the table's data map: the data map holds the rows and has no index to rebuild.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFresh) && (pFresh.%GetTypeOf("Type") = "string") && (pFresh.%Get("Type") '[ ##class(OcuPilot.Port.SqlPort).#DATAMAPTYPE)
}

}
