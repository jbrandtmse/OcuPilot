/// <p>Analytics' listing add (AD-3, AD-6, AD-54, AD-55, AD-61, AD-65, Story 24.11): add one listing to a listing group of the request's namespace. Two callers reach it: the Listings
/// screen's Add listing dialog through <class>OcuPilot.Area.Analytics.ListingSave</class>, and the agent's proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no listing of that name in the group, and a name added since the mint closes the proposal target-changed. A group that is not
/// there is <code>ANALYTICS.LISTINGGROUP.ABSENT</code>. The group's class is saved and compiled, and a listing a target cube or another group already defines is refused before anything is
/// saved. Its fields are declared here (<method>FieldRows</method>, AD-3), and its read-back compares each (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsListingAdd Extends OcuPilot.Screen.Tool.AnalyticsListingAction
{

Parameter TOOLNAME = "analytics.listinggrouplistings.add";

Parameter DESCRIPTION = "Propose adding one listing to a listing group of the namespace the user is working in: a drill-through query that cubes the group targets offer. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the group as the Listing groups list reports it, the new listing's name, and optionally its display name, type (table or map), fields, order by, joins, formats, data connector class, resource, select mode (0 logical, 1 ODBC, 2 display), disabled flag, description and SQL. Setting SQL needs the SQL privilege, and the listing then runs that SQL with the rights of whoever opens it. The group's class is saved and compiled. A name the group already holds, a listing that a target cube or another group already defines, a group that does not exist or that two classes define are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ENTRYADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "DisplayName,Type,Fields,OrderBy,Joins,Formats,Source,Resource,SelectMode,Disabled,Description,SQL";

Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsListingSet";

Parameter PRECONDITIONCODES = "ANALYTICS.LISTINGGROUP.LISTINGTAKEN,ANALYTICS.LISTINGGROUP.ABSENT,ANALYTICS.LISTINGGROUP.AMBIGUOUS,ANALYTICS.LISTINGGROUP.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Name,DisplayName,Type,Fields,OrderBy,Joins,Formats,Source,Resource,SelectMode,Disabled,Description,SQL";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 13
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("DisplayName", "string", 0)
    Set pRows(3) = $ListBuild("Type", "string", 0)
    Set pRows(4) = $ListBuild("Fields", "string", 0)
    Set pRows(5) = $ListBuild("OrderBy", "string", 0)
    Set pRows(6) = $ListBuild("Joins", "string", 0)
    Set pRows(7) = $ListBuild("Formats", "string", 0)
    Set pRows(8) = $ListBuild("Source", "string", 0)
    Set pRows(9) = $ListBuild("Resource", "string", 0)
    Set pRows(10) = $ListBuild("SelectMode", "string", 0)
    Set pRows(11) = $ListBuild("Disabled", "boolean", 0)
    Set pRows(12) = $ListBuild("Description", "string", 0)
    Set pRows(13) = $ListBuild("SQL", "string", 0)
    Quit $$$OK
}

ClassMethod NameDescription() As %String
{
    Quit "The new listing's name: 1 to 250 characters with no control character. A name the group already holds is refused, so check the group's Listings list first."
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The composite id of the listing the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("ListingGroup") '= "string") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("ListingGroup"), pWritten.%Get("Name")))
}

}
