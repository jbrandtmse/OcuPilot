/// <p>Locale definitions' Copy (Story 21.16, AD-6, AD-51, AD-52, AD-53, AD-54, AD-58): make one custom locale, whose name starts with
/// <code>y</code>, from the definition of a locale the instance lists, through <class>OcuPilot.Port.LocalePort</class>. The agent reaches it
/// through a proposal the user confirms; Locale definitions reaches it through its <code>copy</code> row action.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no locale of that name, and a name taken since the mint closes the proposal
/// target-changed (<code>LOCALE.COPY.TAKEN</code>). The new name must be <code>y</code>, two lowercase letters or digits and the last character of
/// the locale it copies (<class>OcuPilot.Area.OsMgmt.LocaleRules</class>). The copy is the source's own <code>Get</code> with its
/// <code>Name</code> and <code>Description</code> replaced; its read-back compares both (<parameter>READBACKFIELDS</parameter>).</p>
Class OcuPilot.Screen.Tool.LocaleCopy Extends OcuPilot.Screen.Tool.LocaleAction
{

Parameter TOOLNAME = "osmgmt.locales.copy";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

Parameter DESCRIPTION = "Propose copying one locale of this instance to a new custom locale, whose name starts with y. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the new locale's name, the locale to copy as the Locale definitions list reports it, and optionally a description. A name the instance already lists, a name that is not y, two lowercase letters or digits and the last character of the locale copied, and a locale to copy the list does not report are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "COPY";

Parameter SENDSBODY As BOOLEAN = 1;

/// <p>No screen action carries a create: the list's Copy reaches this tool through the Save route (<class>OcuPilot.Area.OsMgmt.LocaleCopySave</class>).</p>
Parameter SCREENACTIONS = "";

Parameter READBACKFIELDS = "Name,Description";

/// <p>The read-back re-reads the new locale through the delete tool's read, because the copy's own read is composed for a create.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.LocaleDelete";

Parameter READANSWERS = "Name,Description,Current,Custom";

Parameter PRECONDITIONCODES = "LOCALE.COPY.TAKEN";

Parameter FIELDS = "Name,Source,Description";

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
    Set pRows(2) = $ListBuild("Source", "string", 0)
    Set pRows(3) = $ListBuild("Description", "string", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The new custom locale's name: y, two lowercase letters or digits and the last character of the locale copied (w for Unicode, 8 for 8-bit). A name the instance already lists is refused, so check the Locale definitions list first.", "string")
    Do tProperties.%Get("Source").%Set("description", "The locale to copy, named exactly as the Locale definitions list reports it in its Name column.", "string")
    Do tProperties.%Get("Description").%Set("description", "The new locale's description. Omit it to keep the copied locale's.", "string")
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push("Source")
    Quit tSchema
}

/// <p>The name of the locale the confirmed copy <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The copy always asks its read for the create: a listed name is <code>TAKEN</code> and an unlisted one the 404 a create expects (AD-54), at
/// the mint and at the confirm alike.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.LocalePort).#ACTIONKEY) = ..#WRITETYPE
}

}
