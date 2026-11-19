/// <p>Analytics' quality measure element change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-61, AD-65, Story 24.12): change one element of a group of a quality measure of the request's namespace, or the
/// group itself. A merge over the element's fresh read: the card shows the rows it moves. The write replaces only the class's <code>QualityMeasure</code> XData, composed from the model read at
/// the write, so every other part and every other line of the class is kept as stored. A group's, element's or measure's name is never changed here. An empty <code>Name</code> names the
/// group, whose element fields are then not set.</p>
/// <p>Two callers reach it: the Groups and elements screen's row action Change element through <class>OcuPilot.Api.ScreenAction</class>, whose values are strings (the flags travel as
/// <code>true</code> or <code>false</code>), and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementSet Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAction
{

Parameter TOOLNAME = "analytics.qualitymeasureelements.set";

Parameter DESCRIPTION = "Propose changing one element of a quality measure's group in the namespace the user is working in: its caption, MDX or disabled flag, or the group's caption, description or disabled flag. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure and the group as the Quality measures and Groups and elements lists report them, the element's name (empty to change only the group), and give only what changes. The measure's class is saved and compiled, and a failed compile puts the class back. An element or group the measure does not hold, a measure that two classes define or that is linked to another measure, and a change that leaves the measure's expression naming a group that cannot count are refused.";

Parameter WRITETYPE = "ENTRYSET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

Parameter SCREENVALUES = "set=Caption:MDX:Disabled:GroupCaption:GroupDescription:GroupDisabled";

Parameter SCREENOPTIONAL = "set=Caption:MDX:Disabled:GroupCaption:GroupDescription:GroupDisabled";

Parameter SCREENEMPTY = "set=Caption:MDX:GroupCaption:GroupDescription";

Parameter READBACKFIELDS = "GroupCaption,GroupDescription,GroupDisabled,Caption,MDX,Disabled";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.PARTABSENT,ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Caption,MDX,Disabled,GroupCaption,GroupDescription,GroupDisabled";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 6
    Set pRows(1) = $ListBuild("Caption", "string", 0)
    Set pRows(2) = $ListBuild("MDX", "string", 0)
    Set pRows(3) = $ListBuild("Disabled", "boolean", 0)
    Set pRows(4) = $ListBuild("GroupCaption", "string", 0)
    Set pRows(5) = $ListBuild("GroupDescription", "string", 0)
    Set pRows(6) = $ListBuild("GroupDisabled", "boolean", 0)
    Quit $$$OK
}

}
