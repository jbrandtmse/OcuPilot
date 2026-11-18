/// <p>Analytics' quality measure delete (AD-6, AD-10, AD-51, AD-53, AD-61, AD-65, Story 24.12): delete one quality measure's class, which removes the measure and its groups and documentation.
/// The card says so (<code>ANALYTICS.QUALITYMEASURE.DELETE</code>).</p>
/// <p><b>It is destructive</b>: a deleted measure cannot be restored from OcuPilot, so its card draws the destructive treatment, the Quality measures screen's row action Delete types the
/// measure's name, and its governance key ships disabled (AD-22). The fingerprint covers the measure's name, class and version, so a class changed after the mint closes the proposal
/// target-changed. Its read-back reads the measure gone on the port's 404. Two callers reach it: that row action through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureDelete Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction
{

Parameter TOOLNAME = "analytics.qualitymeasures.delete";

Parameter DESCRIPTION = "Propose deleting one quality measure of the namespace the user is working in: its class is deleted, so the measure, its groups, elements and documentation are gone, and this cannot be undone from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure exactly as the Quality measures list reports it in its Name column. A measure the namespace does not hold and one that two classes define are refused. If the measure's class changes before the proposal is confirmed, nothing is deleted.";

Parameter SCREENACTIONS = "delete";

Parameter WRITETYPE = "DELETE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter FINGERPRINTSUBJECT = "Name,Class,Caption,SubjectArea,Groups,Version,Namespace";

Parameter PRECONDITIONFIELD = "Version";

Parameter CONSEQUENCECODE = "ANALYTICS.QUALITYMEASURE.DELETE";

Parameter REMOVALROWS = "Name,Class,SubjectArea";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The quality measure, named exactly as this namespace's Quality measures list reports it in its Name column. A measure it does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>A delete has no argument beyond the target, so its rules are the state's alone.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(pIdValue, {}, .pProblem)
}

}
