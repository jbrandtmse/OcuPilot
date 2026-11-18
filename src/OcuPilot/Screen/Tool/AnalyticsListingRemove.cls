/// <p>Analytics' listing remove (AD-6, AD-10, AD-51, AD-53, AD-61, AD-65, Story 24.11): remove one listing from a listing group; cubes lose it once the group's class compiles
/// (<code>ANALYTICS.LISTINGGROUP.REMOVE</code>).</p>
/// <p><b>It is destructive</b>: a removed listing cannot be restored from OcuPilot, so its card draws the destructive treatment, the Listings screen's row action Remove listing types the
/// listing's name, and its governance key ships disabled (AD-22). Its read-back reads the listing gone on the port's 404. Two callers reach it: that row action through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingRemove Extends OcuPilot.Screen.Tool.AnalyticsListingAction
{

Parameter TOOLNAME = "analytics.listinggrouplistings.remove";

Parameter DESCRIPTION = "Propose removing one listing from a listing group of the namespace the user is working in, which cannot be undone from OcuPilot: cubes lose the listing once the group's class is compiled. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the group and the listing as the Listing groups and Listings lists report them. A listing the group does not hold and a group that two classes define are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "ENTRYREMOVE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter CONSEQUENCECODE = "ANALYTICS.LISTINGGROUP.REMOVE";

Parameter FINGERPRINTSUBJECT = "ListingGroup,Name,Type,Fields,Source,Version,Namespace";

Parameter PRECONDITIONFIELD = "Version";

Parameter REMOVALROWS = "ListingGroup,Name,Type,Fields";

Parameter PRECONDITIONCODES = "ANALYTICS.LISTINGGROUP.ABSENT,ANALYTICS.LISTINGGROUP.AMBIGUOUS,ANALYTICS.LISTINGGROUP.READONLY,ANALYTICS.NAMESPACE";

/// <p>A removal has no argument beyond the target, so its rules are the state's alone.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(pIdValue, {}, .pProblem)
}

}
