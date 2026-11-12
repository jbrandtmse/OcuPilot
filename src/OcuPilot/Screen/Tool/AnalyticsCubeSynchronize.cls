/// <p>The Cube manager's Synchronize (AD-6, AD-51, AD-53, AD-65, Story 20.34): apply the source changes recorded since a cube's last
/// update to it and to the cubes that depend on it. Its source must record changes (DSTIME), and the cube stays queryable. It never turns
/// into a build: a cube that has never been built is refused, where the vendor would build it.</p>
/// <p>It is not destructive: the facts it leaves are the source's, so its governance key ships enabled (AD-22). The cube's own
/// pre-synchronize and post-synchronize code runs as the signed-in person.</p>
/// <p>Two callers reach it: the Cube manager's row action Synchronize through <class>OcuPilot.Api.ScreenAction</class>, which sends it
/// at once, and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.AnalyticsAction</class>'s.</p>
Class OcuPilot.Screen.Tool.AnalyticsCubeSynchronize Extends OcuPilot.Screen.Tool.AnalyticsAction
{

Parameter TOOLNAME = "analytics.cubemanager.synchronize";

Parameter DESCRIPTION = "Propose synchronizing one cube: apply the source changes recorded since its last update to it and to the cubes that depend on it. Its source must record changes (DSTIME), and the cube stays queryable. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the cube by its logical name exactly as the Cube manager or the Cubes list reports it. A cube that is being built or synchronized now, that has never been built, or whose source does not record changes is refused; build it instead.";

Parameter SCREENACTIONS = "synchronize";

Parameter WRITETYPE = "SYNCHRONIZE";

Parameter CHANGEACTION = "updated";

Parameter FINGERPRINTSUBJECT = "Updating,Built,Synchronizes,DependentCubes,Namespace";

Parameter PRECONDITIONFIELD = "Synchronizes";

Parameter PRECONDITIONCODES = "ANALYTICS.CUBE.BUSY,ANALYTICS.CUBE.NODSTIME,ANALYTICS.CUBE.NOTBUILT,ANALYTICS.CUBE.READONLY,ANALYTICS.NAMESPACE";

Parameter CONSEQUENCECODE = "ANALYTICS.CUBE.SYNCHRONIZE";

Parameter AFTERROW = "Last update";

Parameter AFTERWORD = "Synchronized now";

}
