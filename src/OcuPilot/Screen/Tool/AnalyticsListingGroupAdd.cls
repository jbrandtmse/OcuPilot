/// <p>Analytics' listing group create (AD-3, AD-6, AD-54, AD-55, AD-61, AD-65, Story 24.11): make one listing group, with its class, in the request's namespace. Two callers
/// reach it: the Listing groups screen's New listing group dialog through <class>OcuPilot.Area.Analytics.ListingGroupSave</class>, and the agent's proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no group of that name, and a name taken since the mint closes the proposal target-changed. The port refuses a name or
/// class already in use, a class that is malformed, begins with <code>%</code> or is in an <code>OcuPilot</code> package, and a target cube that does not exist or takes no
/// listing groups, each by its own code before anything is saved. Its fields are declared here (<method>FieldRows</method>, AD-3), and its read-back compares each
/// (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsListingGroupAdd Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction
{

Parameter TOOLNAME = "analytics.listinggroups.add";

Parameter DESCRIPTION = "Propose creating one listing group in the namespace the user is working in: a class that holds listings (drill-through queries) for one or more cubes. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the new group's name, the new class that holds it, and the target cubes, and optionally a caption, description, resource and default resource. The class is saved and compiled. A name or class the namespace already holds, a class name that is malformed, begins with % or is in an OcuPilot package, and a target cube that does not exist or does not accept listing groups are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "Class,Caption,Description,TargetCubes,Resource,DefaultResource,Disabled";

/// <p>The read-back re-reads the created group through the update's read, because the add's own read is composed for an add.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsListingGroupUpdate";

Parameter PRECONDITIONCODES = "ANALYTICS.LISTINGGROUP.TAKEN,ANALYTICS.LISTINGGROUP.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Name,Class,Caption,Description,TargetCubes,Resource,DefaultResource,Disabled";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The fields as the rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 8
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("Class", "string", 0)
    Set pRows(3) = $ListBuild("Caption", "string", 0)
    Set pRows(4) = $ListBuild("Description", "string", 0)
    Set pRows(5) = $ListBuild("TargetCubes", "string", 0)
    Set pRows(6) = $ListBuild("Resource", "string", 0)
    Set pRows(7) = $ListBuild("DefaultResource", "string", 0)
    Set pRows(8) = $ListBuild("Disabled", "boolean", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The new listing group's name: 1 to 250 characters with no control character. A name the namespace already holds is refused, compared without regard to case, so check the Listing groups list first.", "string")
    Do tProperties.%Get("Class").%Set("description", "The new class that holds the group: dotted letters and digits with a package, outside the % packages and the OcuPilot package. A class the namespace already holds is refused.", "string")
    Do tProperties.%Get("TargetCubes").%Set("description", "The cubes whose listings the group adds, comma-separated: each must exist and accept listing groups.", "string")
    Quit tSchema
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the group the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

}
