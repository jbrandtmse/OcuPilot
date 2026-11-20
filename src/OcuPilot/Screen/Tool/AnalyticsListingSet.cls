/// <p>Analytics' listing change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-61, AD-65, Story 24.11): change one listing of a listing group of the request's namespace. A merge over the listing's
/// fresh read: the card shows the rows it moves. The write replaces only the class's <code>Listings</code> XData and its <code>DependsOn</code>, composed from the model read at the
/// write. A listing's name is never changed here. Changing its SQL needs <code>%DeepSee_ListingGroupSQL:USE</code>, and a caller without it never changes the SQL the model holds.</p>
/// <p>Two callers reach it: the Listings screen's row action Change listing through <class>OcuPilot.Api.ScreenAction</class>, whose values are strings (the disabled flag travels as
/// <code>true</code> or <code>false</code>), and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingSet Extends OcuPilot.Screen.Tool.AnalyticsListingAction
{

Parameter TOOLNAME = "analytics.listinggrouplistings.set";

Parameter DESCRIPTION = "Propose changing one listing of a listing group of the namespace the user is working in: its display name, type, fields, order by, joins, formats, data connector class, resource, select mode, disabled flag, description or SQL. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the group and the listing as the Listing groups and Listings lists report them, and give only what changes. Changing SQL needs the SQL privilege, and the listing then runs that SQL with the rights of whoever opens it. The group's class is saved and compiled, and a failed compile puts the class back. A listing the group does not hold, a listing that a target cube or another group already defines, and a group that two classes define are refused.";

Parameter WRITETYPE = "ENTRYSET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

Parameter SCREENVALUES = "set=DisplayName:Type:Fields:OrderBy:Joins:Formats:Source:Resource:SelectMode:Disabled:Description:SQL";

Parameter SCREENOPTIONAL = "set=DisplayName:Type:Fields:OrderBy:Joins:Formats:Source:Resource:SelectMode:Disabled:Description:SQL";

Parameter SCREENEMPTY = "set=DisplayName:Fields:OrderBy:Joins:Formats:Source:Resource:Description:SQL";

Parameter READBACKFIELDS = "DisplayName,Type,Fields,OrderBy,Joins,Formats,Source,Resource,SelectMode,Disabled,Description,SQL";

Parameter PRECONDITIONCODES = "ANALYTICS.LISTINGGROUP.ABSENT,ANALYTICS.LISTINGGROUP.AMBIGUOUS,ANALYTICS.LISTINGGROUP.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "DisplayName,Type,Fields,OrderBy,Joins,Formats,Source,Resource,SelectMode,Disabled,Description,SQL";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 12
    Set pRows(1) = $ListBuild("DisplayName", "string", 0)
    Set pRows(2) = $ListBuild("Type", "string", 0)
    Set pRows(3) = $ListBuild("Fields", "string", 0)
    Set pRows(4) = $ListBuild("OrderBy", "string", 0)
    Set pRows(5) = $ListBuild("Joins", "string", 0)
    Set pRows(6) = $ListBuild("Formats", "string", 0)
    Set pRows(7) = $ListBuild("Source", "string", 0)
    Set pRows(8) = $ListBuild("Resource", "string", 0)
    Set pRows(9) = $ListBuild("SelectMode", "string", 0)
    Set pRows(10) = $ListBuild("Disabled", "boolean", 0)
    Set pRows(11) = $ListBuild("Description", "string", 0)
    Set pRows(12) = $ListBuild("SQL", "string", 0)
    Quit $$$OK
}

}
