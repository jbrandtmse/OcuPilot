/// <p>The Security advisor's stop-ignoring tool (AD-6, AD-51, AD-52, AD-53): stop ignoring one security recommendation. It is
/// <class>OcuPilot.Screen.Tool.SecurityAdvisorIgnore</class> with the <code>UNIGNORE</code> request type, and <code>Ignored</code>
/// moving from <code>true</code> to <code>false</code>.</p>
Class OcuPilot.Screen.Tool.SecurityAdvisorUnignore Extends OcuPilot.Screen.Tool.SecurityAdvisorIgnore
{

Parameter TOOLNAME = "security.advisor.unignore";

Parameter DESCRIPTION = "Propose no longer ignoring one security recommendation, so the instance's own Security Advisor shows it as an open recommendation again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the recommendation by its type, its element and its code exactly as the security advisor list reports them; an element of one space is a type's general row. A recommendation the list does not report, or one that is not ignored, is refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "unignore";

Parameter WRITETYPE = "UNIGNORE";

Parameter AFTER = "false";

}
