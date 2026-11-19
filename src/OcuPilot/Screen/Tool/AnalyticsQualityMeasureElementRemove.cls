/// <p>Analytics' quality measure element remove (AD-6, AD-10, AD-51, AD-53, AD-61, AD-65, Story 24.12): remove one element from a group of a quality measure, or, with an empty
/// <code>Name</code>, the group and every element in it (<code>ANALYTICS.QUALITYMEASURE.REMOVE</code>). The measure's class is saved and compiled with the part gone.</p>
/// <p><b>It is destructive</b>: a removed group or element cannot be restored from OcuPilot, so its card draws the destructive treatment, the Groups and elements screen's row actions Remove
/// element and Remove group type the element's name or the group's, and its governance key ships disabled (AD-22). Its read-back reads the part gone on the port's 404. Two callers reach it:
/// those row actions through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementRemove Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAction
{

Parameter TOOLNAME = "analytics.qualitymeasureelements.remove";

Parameter DESCRIPTION = "Propose removing one element from a quality measure's group in the namespace the user is working in, or, with an empty element name, the whole group and every element in it, which cannot be undone from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure and the group as the Quality measures and Groups and elements lists report them, and the element's name. The measure's class is saved and compiled. An element or group the measure does not hold, a measure that two classes define or that is linked to another measure, and a removal that leaves the measure's expression naming a group that cannot count are refused.";

Parameter SCREENACTIONS = "remove,remove-group";

Parameter WRITETYPE = "ENTRYREMOVE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter CONSEQUENCECODE = "ANALYTICS.QUALITYMEASURE.REMOVE";

Parameter FINGERPRINTSUBJECT = "QualityMeasure,Group,Name,Caption,MDX,Version,Namespace";

Parameter PRECONDITIONFIELD = "Version";

Parameter REMOVALROWS = "QualityMeasure,Group,Name,Caption,MDX";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.PARTABSENT,ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

/// <p>A removal has no argument beyond the target, so its rules are the state's alone.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(pIdValue, {}, .pProblem)
}

}
