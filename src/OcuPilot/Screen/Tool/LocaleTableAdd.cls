/// <p>Locale properties' Add table (Story 21.16, AD-6, AD-51, AD-52, AD-53, AD-54, AD-56 (ii), AD-58): add one table to a list of a custom locale that is
/// not the current locale, through <class>OcuPilot.Port.LocalePort</class>: a table of one of the eight internal lists, or an input/output table
/// with its input and output sides. The agent reaches it through a proposal the user confirms; the Locale properties screen reaches it through its
/// <code>add-table</code> primary action.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no row of that name, and a table listed since the mint closes the proposal target-changed
/// (<code>LOCALE.TABLE.TAKEN</code>). The change is a delta over the fresh read (AD-56 (ii)): the port sends the complete settable set with the one
/// member added. A table the instance does not hold for the locale's character set is refused
/// (<code>LOCALE.TABLE.UNAVAILABLE</code>).</p>
Class OcuPilot.Screen.Tool.LocaleTableAdd Extends OcuPilot.Screen.Tool.LocalePropertyAction
{

Parameter TOOLNAME = "osmgmt.localeproperties.add";

Parameter DESCRIPTION = "Propose adding one table to a list of one custom locale, whose name starts with y and which is not the current locale. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the locale, and the table as the list, a colon and the table, for example PatternTables:Latin2. For an input/output table, named XLTTables:<name>, also give InputFrom and OutputTo; no other table takes either. A table the locale already lists, a table the instance does not hold for the locale's character set, a locale InterSystems ships and the current locale are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADD";

Parameter SENDSBODY As BOOLEAN = 1;

/// <p>No screen action carries a create: the list's Add table reaches this tool through the Save route (<class>OcuPilot.Area.OsMgmt.LocaleTableSave</class>).</p>
Parameter SCREENACTIONS = "";

Parameter READBACKFIELDS = "Value";

/// <p>The read-back re-reads the added row through the set tool's read, because the add's own read is composed for a create.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.LocalePropertySet";

Parameter PRECONDITIONCODES = "LOCALE.TABLE.TAKEN";

Parameter FIELDS = "Name,InputFrom,OutputTo";

Parameter IDDESCRIPTION = "The table to add: its list, a colon and the table, for example PatternTables:Latin2, or XLTTables:<name> for an input/output table. A table the locale already lists is refused.";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The fields as the rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 3
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("InputFrom", "string", 0)
    Set pRows(3) = $ListBuild("OutputTo", "string", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("InputFrom").%Set("description", "For an input/output table only: the character set the table translates from, as the instance names it.", "string")
    Do tProperties.%Get("OutputTo").%Set("description", "For an input/output table only: the character set the table translates to, as the instance names it.", "string")
    Quit tSchema
}

/// <p>The value the added row reads as, derived from the payload's own fields on the body the write sends, so the read-back compares it with the row
/// the instance now lists: the table, or <code>&lt;InputFrom&gt; / &lt;OutputTo&gt;</code> for an input/output table. It is no argument and no diff
/// row.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    Set tName = $Select(pPayload.%GetTypeOf("Name") = "string": pPayload.%Get("Name"), 1: "")
    Set tValue = $Piece(tName, ":", 2, *)
    If $Piece(tName, ":", 1) = ##class(OcuPilot.Port.LocalePort).#IOLIST {
        Set tValue = $Select(pPayload.%GetTypeOf("InputFrom") = "string": pPayload.%Get("InputFrom"), 1: "") _ " / " _ $Select(pPayload.%GetTypeOf("OutputTo") = "string": pPayload.%Get("OutputTo"), 1: "")
    }
    Do pPayload.%Set("Value", tValue, "string")
}

/// <p>The composite id of the row the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("Locale") '= "string") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("Locale"), pWritten.%Get("Name")))
}

/// <p>The add always asks its read for the create: a listed row is <code>TAKEN</code> and an absent one the 404 a create expects (AD-54).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.LocalePort).#ACTIONKEY) = ..#WRITETYPE
}

}
