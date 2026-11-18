/// <p>Listing groups' New listing group (AD-55, AD-54, Story 24.11): <code>POST /analytics/listing-groups</code> creates one listing group, with its class, in the request's namespace
/// through <class>OcuPilot.Screen.Tool.AnalyticsListingGroupAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save for a
/// member with no parent: the order of the Save, its hold on the group's name, its absence read, the prohibited set, the port's add and the read-back are the superclass's. The body's
/// members are <code>Name</code> and, optionally, <code>Class</code>, <code>Caption</code>, <code>Description</code>, <code>TargetCubes</code>, <code>Resource</code>,
/// <code>DefaultResource</code> and <code>Disabled</code>; the rules over them are <method>OcuPilot.Port.AnalyticsPort.ListingGroupViolations</method>'s and the port's own.</p>
Class OcuPilot.Area.Analytics.ListingGroupSave Extends OcuPilot.Area.Interop.ItemSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsListingGroupAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsListingGroupList";

/// <p>No parent: the group is namespace-scoped.</p>
Parameter PRODUCTIONMEMBER;

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "PORT.FIELD.SHAPE";

Parameter TAKENCODE = "ANALYTICS.LISTINGGROUP.TAKEN";

Parameter TAKENREASON = "This namespace already holds a listing group or class with that name.";

/// <p>The port method that judges the body's shape; a subclass for another definition names its own, of the same signature.</p>
Parameter VIOLATIONSMETHOD = "ListingGroupViolations";

ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pFields.%ToJSON())
    Do tBody.%Set("Name", pName, "string")
    Quit $ClassMethod(..PortClass(), ..#VIOLATIONSMETHOD, $ClassMethod(..#CREATETOOL, "WriteType"), pName, "", tBody, .pViolations)
}

}
