/// <p>Analytics' listing group delete (AD-6, AD-10, AD-51, AD-53, AD-61, AD-65, Story 24.11): delete one listing group's class, which removes the group and its listings from every
/// cube that used them. Cubes lose its listings, which the card says (<code>ANALYTICS.LISTINGGROUP.DELETE</code>).</p>
/// <p><b>It is destructive</b>: a deleted group cannot be restored from OcuPilot, so its card draws the destructive treatment, the Listing groups screen's row action Delete types the
/// group's name, and its governance key ships disabled (AD-22). The fingerprint covers the group's name, class and version, so a class changed after the mint closes the proposal
/// target-changed. Its read-back reads the group gone on the port's 404. Two callers reach it: that row action through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingGroupDelete Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction
{

Parameter TOOLNAME = "analytics.listinggroups.delete";

Parameter DESCRIPTION = "Propose deleting one listing group of the namespace the user is working in: its class is deleted, so cubes lose the group's listings, and this cannot be undone from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the group exactly as the Listing groups list reports it in its Name column. A group the namespace does not hold and one that two classes define are refused. If the group's class changes before the proposal is confirmed, nothing is deleted.";

Parameter SCREENACTIONS = "delete";

Parameter WRITETYPE = "DELETE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter FINGERPRINTSUBJECT = "Name,Class,Caption,TargetCubes,Listings,Version,Namespace";

Parameter PRECONDITIONFIELD = "Version";

Parameter CONSEQUENCECODE = "ANALYTICS.LISTINGGROUP.DELETE";

Parameter REMOVALROWS = "Name,Class,TargetCubes";

Parameter PRECONDITIONCODES = "ANALYTICS.LISTINGGROUP.ABSENT,ANALYTICS.LISTINGGROUP.AMBIGUOUS,ANALYTICS.LISTINGGROUP.READONLY,ANALYTICS.NAMESPACE";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The listing group, named exactly as this namespace's Listing groups list reports it in its Name column. A group it does not report is refused.", "string")
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
