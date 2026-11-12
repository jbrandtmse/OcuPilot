/// <p>The Cube manager's Build (AD-6, AD-51, AD-53, AD-65, Story 20.34): delete one cube's facts and rebuild them from its source,
/// with every cube that depends on it, on the instance's own build agents, in the request that asks for it. It is the classic Cube
/// Manager's Build, and also its Repair Build, which is the same vendor call. The cubes cannot be queried while it runs, and a build
/// that fails leaves their facts gone.</p>
/// <p><b>It is destructive</b> (AD-22): the card draws the destructive treatment, the screen asks for the cube's name, and its
/// governance key ships off, so the agent's call is denied until a person turns it on while a person's Build still runs. The cube's own
/// code and the namespace's analytics start-up code run as the signed-in person, as the classic page runs them.</p>
/// <p>Two callers reach it: the Cube manager's row action Build through <class>OcuPilot.Api.ScreenAction</class>, and the agent's
/// proposal and confirmation. Its state, fingerprint and refusals are <class>OcuPilot.Screen.Tool.AnalyticsAction</class>'s; its
/// fingerprint covers the cube's last build to the millisecond, so a build confirmed after someone else's is refused as moved.</p>
Class OcuPilot.Screen.Tool.AnalyticsCubeBuild Extends OcuPilot.Screen.Tool.AnalyticsAction
{

Parameter TOOLNAME = "analytics.cubemanager.build";

Parameter DESCRIPTION = "Propose rebuilding one cube from its source: it deletes the cube's facts and rebuilds them, with every cube that depends on it. It is the classic Cube Manager's Build, also called Repair Build. The cubes cannot be queried while it runs, and a build that fails leaves their facts gone. It changes nothing by itself: it answers a proposal the user reviews and confirms by typing the cube's name. Name the cube by its logical name exactly as the Cube manager or the Cubes list reports it. A cube that is being built or synchronized now, or that depends on one, is refused.";

Parameter SCREENACTIONS = "build";

Parameter WRITETYPE = "BUILD";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter FINGERPRINTSUBJECT = "Updating,DependentCubes,BuildStamp,Namespace";

Parameter PRECONDITIONFIELD = "Updating";

Parameter PRECONDITIONCODES = "ANALYTICS.CUBE.BUSY,ANALYTICS.CUBE.READONLY,ANALYTICS.NAMESPACE";

Parameter CONSEQUENCECODE = "ANALYTICS.CUBE.BUILD";

Parameter AFTERROW = "Last build";

Parameter AFTERWORD = "Rebuilt now";

}
