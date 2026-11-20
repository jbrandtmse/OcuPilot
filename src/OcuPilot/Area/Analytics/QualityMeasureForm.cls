/// <p>Quality measures' form read (AD-5, AD-29, AD-36, AD-65, Story 24.12): <code>GET /analytics/quality-measures/form?name=</code> answers one quality measure as the Edit and Copy dialogs show it:
/// <code>{Name, Catalog, Set, Id, Class, Caption, Description, SubjectArea, Expression, LinkedTo, Published, Format, Href, Compiled, Groups, Version, Namespace}</code>, read through
/// <class>OcuPilot.Port.AnalyticsPort</class>'s <code>QUALITYMEASURE</code> type in the request's namespace, after the Quality measures screen's pairs. It is
/// <class>OcuPilot.Area.Analytics.ListingGroupForm</class> with the measure's own descriptor, endpoint, read type and name rule. It writes nothing. A name the instance does not hold is
/// 404, a missing or malformed one 400 <code>PORT.VALIDATION</code>, and any other refusal the gate's or the port's own envelope.</p>
Class OcuPilot.Area.Analytics.QualityMeasureForm Extends OcuPilot.Area.Analytics.ListingGroupForm
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList";

Parameter SHAPEMETHOD = "QualityMeasureKeyShaped";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTQUALITYMEASURES
}

ClassMethod ReadType() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#TYPEQUALITYMEASURE
}

ClassMethod RequiredReason() As %String
{
    Quit ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE
}

}
