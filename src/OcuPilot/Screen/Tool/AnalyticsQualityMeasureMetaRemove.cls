/// <p>Analytics' quality measure documentation remove (AD-6, AD-10, AD-51, AD-53, AD-61, AD-65, Story 24.12): remove one documentation item from a quality measure
/// (<code>ANALYTICS.QUALITYMEASURE.REMOVE</code>). The measure's class is saved and compiled with the item gone.</p>
/// <p><b>It is destructive</b>: a removed item cannot be restored from OcuPilot, so its card draws the destructive treatment, the Documentation screen's row action Remove documentation item
/// types the item's name, and its governance key ships disabled (AD-22). Its read-back reads the item gone on the port's 404. Two callers reach it: that row action through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaRemove Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAction
{

Parameter TOOLNAME = "analytics.qualitymeasuremetas.remove";

Parameter DESCRIPTION = "Propose removing one documentation item from a quality measure of the namespace the user is working in, which cannot be undone from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure and the item as the Quality measures and Documentation lists report them. The measure's class is saved and compiled. An item the measure does not hold and a measure that two classes define or that is linked to another measure are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "ENTRYREMOVE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter CONSEQUENCECODE = "ANALYTICS.QUALITYMEASURE.REMOVE";

Parameter FINGERPRINTSUBJECT = "QualityMeasure,Name,Caption,Section,Version,Namespace";

Parameter PRECONDITIONFIELD = "Version";

Parameter REMOVALROWS = "QualityMeasure,Name,Caption,Section";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.PARTABSENT,ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

/// <p>A removal has no argument beyond the target, so its rules are the state's alone.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(pIdValue, {}, .pProblem)
}

}
