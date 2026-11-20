/// <p>Analytics' worklist hide (AD-51, AD-53, AD-58, AD-65, Story 24.13): stop showing one worklist on one panel of the home or the dashboard page, as the classic Worklists tab's checkbox does. It writes one
/// option, and hiding a worklist that is hidden writes the same value and succeeds. It is not destructive: Show undoes it.</p>
Class OcuPilot.Screen.Tool.AnalyticsWorklistHide Extends OcuPilot.Screen.Tool.AnalyticsWorklistAction
{

Parameter TOOLNAME = "analytics.worklists.hide";

Parameter DESCRIPTION = "Propose hiding one worklist on one panel of the home or dashboard page of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the page, the panel and the worklist's class exactly as the Worklists list reports them in its Page, Panel and Class columns. Worklists that are not customized, a worklist the page does not list and a settings database that is read-only are refused.";

Parameter SCREENACTIONS = "hide";

Parameter WRITETYPE = "WORKLISTHIDE";

Parameter SHOWN As BOOLEAN = 0;

}
