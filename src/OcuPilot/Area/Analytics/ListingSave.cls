/// <p>Listings' Add listing (AD-55, AD-54, Story 24.11): <code>POST /analytics/listing-group-listings</code> adds one listing to a listing group of the request's namespace through
/// <class>OcuPilot.Screen.Tool.AnalyticsListingAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with the listing group
/// as the parent and the listing's name as the member. The body's members are <code>ListingGroup</code>, <code>Name</code> and, optionally, <code>DisplayName</code>, <code>Type</code>,
/// <code>Fields</code>, <code>OrderBy</code>, <code>Joins</code>, <code>Formats</code>, <code>Source</code>, <code>Resource</code>, <code>SelectMode</code>, <code>Disabled</code>,
/// <code>Description</code> and <code>SQL</code>; a group the namespace does not hold is 404 <code>ANALYTICS.LISTINGGROUP.ABSENT</code>, and the rules over the fields are
/// <method>OcuPilot.Port.AnalyticsPort.ListingGroupViolations</method>'s and the port's own.</p>
Class OcuPilot.Area.Analytics.ListingSave Extends OcuPilot.Area.Interop.ItemSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsListingAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsListingGroupListingList";

Parameter PRODUCTIONMEMBER = "ListingGroup";

Parameter NAMEMEMBER = "Name";

Parameter PARENTEMPTYCODE = "PORT.FIELD.SHAPE";

Parameter NAMEEMPTYCODE = "PORT.FIELD.SHAPE";

Parameter TAKENCODE = "ANALYTICS.LISTINGGROUP.LISTINGTAKEN";

Parameter TAKENREASON = "A listing of this group is already defined for a target cube. Choose other target cubes.";

/// <p>Whether <var>pNamespace</var> holds the listing group <var>pParent</var>, read through the port's own group read.</p>
ClassMethod ParentHeld(pNamespace As %String, pParent As %String) As %Boolean
{
    Quit $$$ISOK(..ParentRefusal(pNamespace, pParent, .tHttp, .tFault))
}

/// <p>The endpoint, read type and absence code of the parent's own read: the listing group's here; the quality measure's in the Saves of its parts (Story 24.12).</p>
ClassMethod ParentEndpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTLISTINGGROUPS
}

ClassMethod ParentReadType() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#TYPELISTINGGROUP
}

ClassMethod ParentAbsentCode() As %String
{
    Quit ##class(OcuPilot.Api.AnalyticsError).#LISTINGGROUPABSENT
}

/// <p>The port's read of the parent <var>pParent</var> in <var>pNamespace</var>: <code>$$$OK</code> when it is held, 404 with <method>ParentAbsentCode</method> when it is not, and any
/// other refusal of the read as the port answered it.</p>
ClassMethod ParentRefusal(pNamespace As %String, pParent As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AnalyticsPort).#IDKEY) = pParent
    Set tQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pNamespace
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..ParentEndpoint(), ..ParentReadType(), .tQuery, "", .tRow, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) || (+$Get(pHttpStatus) '= 404) Quit tSC
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ..ParentAbsentCode(), ##class(OcuPilot.Api.AnalyticsError).ReasonFor(..ParentAbsentCode()))
    Quit $$$ERROR($$$GeneralError, ..ParentAbsentCode())
}

ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "ListingGroupViolations", $ClassMethod(..#CREATETOOL, "WriteType"), pParent, pName, pFields, .pViolations)
}

}
