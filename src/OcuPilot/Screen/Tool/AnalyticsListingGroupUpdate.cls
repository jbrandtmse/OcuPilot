/// <p>Analytics' listing group change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-61, AD-65, Story 24.11): change a listing group's caption, description, target cubes, resource,
/// default resource and whether it is disabled. A merge over the group's fresh read: the card shows the rows it moves. The write replaces only the class's
/// <code>Listings</code> XData and its <code>DependsOn</code>, composed from the model read at the write, so the group's listings, and any SQL the caller cannot see,
/// are kept as stored. A group's name and class are never changed here.</p>
/// <p>Two callers reach it: the Listing groups screen's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose values are strings (the disabled flag
/// travels as <code>true</code> or <code>false</code>), and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingGroupUpdate Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction
{

Parameter TOOLNAME = "analytics.listinggroups.update";

Parameter DESCRIPTION = "Propose changing one listing group's caption, description, target cubes, resource, default resource or disabled flag in the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the group as the Listing groups list reports it and give only what changes. The group's class is saved and compiled, its listings are never touched, and a failed compile puts the class back. A group the namespace does not hold, one that two classes define, a target cube that does not exist or does not accept listing groups, and a cube that already defines a listing of the group are refused.";

Parameter WRITETYPE = "UPDATE";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "update";

Parameter SCREENVALUES = "update=Caption:Description:TargetCubes:Resource:DefaultResource:Disabled";

Parameter SCREENOPTIONAL = "update=Caption:Description:TargetCubes:Resource:DefaultResource:Disabled";

Parameter SCREENEMPTY = "update=Caption:Description:Resource:DefaultResource";

Parameter READBACKFIELDS = "Caption,Description,TargetCubes,Resource,DefaultResource,Disabled";

Parameter PRECONDITIONCODES = "ANALYTICS.LISTINGGROUP.ABSENT,ANALYTICS.LISTINGGROUP.AMBIGUOUS,ANALYTICS.LISTINGGROUP.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Caption,Description,TargetCubes,Resource,DefaultResource,Disabled";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 6
    Set pRows(1) = $ListBuild("Caption", "string", 0)
    Set pRows(2) = $ListBuild("Description", "string", 0)
    Set pRows(3) = $ListBuild("TargetCubes", "string", 0)
    Set pRows(4) = $ListBuild("Resource", "string", 0)
    Set pRows(5) = $ListBuild("DefaultResource", "string", 0)
    Set pRows(6) = $ListBuild("Disabled", "boolean", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The listing group, named as the Listing groups list reports it in its Name column. A group the namespace does not hold is refused.", "string")
    Do tProperties.%Get("TargetCubes").%Set("description", "The whole new list of target cubes, comma-separated: each must exist and accept listing groups.", "string")
    Quit tSchema
}

/// <p>The dialog's values as this tool's arguments: the strings as sent, <code>Disabled</code> as <code>true</code> or <code>false</code>; the port judges them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tName = "Caption", "Description", "TargetCubes", "Resource", "DefaultResource" {
        Do ..CarryText(pValues, pArgs, tName)
    }
    Set pProblem = ..CarryDisabled(pValues, pArgs)
    Quit $$$OK
}

}
