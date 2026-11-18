/// <p>What the listing group editor's three listing write tools share (AD-6, AD-51, AD-52, AD-53, AD-61, AD-65, Story 24.11): a write of one listing of one listing group of the
/// request's namespace through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Listings screen's Add listing and its row actions Change listing and Remove
/// listing, and the agent's proposal and confirmation. The target is the composite <code>[ListingGroup, Name]</code> (<class>OcuPilot.Screen.Tool.AnalyticsListingMint</class>), each
/// part kept exactly (AD-13). Every write saves and compiles the group's class.</p>
/// <p><b>The fresh read is the port's <code>LISTING</code></b>, whose <code>SQL</code> is answered only to a holder of <code>%DeepSee_ListingGroupSQL:USE</code>. A write that sets or
/// changes a listing's SQL needs that pair, judged at the mint and again at the write; a call from a caller without it never changes the SQL the model holds.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingAction Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsListingGroupListingList";

Parameter READTYPE = "LISTING";

Parameter READANSWERS = "ListingGroup,Name,DisplayName,Type,Fields,OrderBy,Joins,Formats,Source,Resource,SelectMode,Disabled,Description,SQL,Version,Namespace";

/// <p>The argument naming the listing group the listing belongs to.</p>
Parameter LISTARGUMENT = "ListingGroup";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTLISTINGGROUPLISTINGS
}

/// <p><class>OcuPilot.Screen.Tool.AnalyticsListingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.AnalyticsListingMint"
}

/// <p>The listing's name, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>What the schema says of the listing's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The listing's name, as the group's Listings list reports it in its Name column. A listing the group does not report is refused."
}

/// <p>The derived schema with the listing group added and required, and the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#LISTARGUMENT, {"type": "string", "description": "The listing group the listing belongs to, named exactly as this namespace's Listing groups list reports it in its Name column."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#LISTARGUMENT)
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    Quit tSchema
}

/// <p>The group inside the composite id <var>pIdValue</var> and the listing: both <code>""</code> for any other spelling.</p>
ClassMethod TargetParts(pIdValue As %String, Output pGroup As %String, Output pListing As %String)
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    Set pGroup = $Select($ListLength(tParts) = 2: $List(tParts, 1), 1: "")
    Set pListing = $Select($ListLength(tParts) = 2: $List(tParts, 2), 1: "")
}

/// <p>The listing group's sentence for a listing that sets SQL, else the one every write states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf("SQL") '= "string") || (pPayload.%Get("SQL") = "") Quit ..#CONSEQUENCECODE
    If ..#CONSEQUENCECODE '= ##class(OcuPilot.Screen.Tool.AnalyticsListingGroupAction).#CONSEQUENCECODE Quit ..#CONSEQUENCECODE
    Quit ..#SQLCONSEQUENCECODE
}

/// <p>The listing's members the dialogs send as text: each as sent, which may be empty; <code>Disabled</code> as <code>true</code> or <code>false</code>.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    For tName = "DisplayName", "Type", "Fields", "OrderBy", "Joins", "Formats", "Source", "Resource", "SelectMode", "Description", "SQL" {
        Do ..CarryText(pValues, pArgs, tName)
    }
    Set pProblem = ..CarryDisabled(pValues, pArgs)
    Quit $$$OK
}

}
