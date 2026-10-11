/// <p>Pins Story 18.31's pairs with least-privileged principals (AD-8, AD-29, measured at plan): a principal holding
/// exactly the Web applications area's two pairs, and read on the install namespace's code database, reads the list and
/// the form, creates, changes and deletes a probe application over the wire, and confirms the agent's change in a process of
/// its own; without <code>%Admin_Secure:USE</code> both reads, every write and the confirm are refused naming it and the
/// screen is unavailable; and without <code>%DB_IRISSYS:READ</code> every write and the confirm are refused naming it.
/// Every refusal leaves the application list as it found it.</p>
/// <p>The legs are <class>OcuPilot.Test.DocDbAppGate</class>'s, over the privileged routine applications' screen, tools
/// and Save route, an application named by its name alone. The agent's confirm runs in a child process logged in as the
/// principal (<method>OcuPilot.Test.RoutineAppProbe.RunAs</method>), which reaches the real port.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe users, roles
/// and applications (<class>OcuPilot.Test.AuthOptionsProbe</class>'s principals) and sets the governance policy. Every probe
/// object is removed, and after each test the application list reads as that test found it.</p>
Class OcuPilot.Test.RoutineAppGate Extends OcuPilot.Test.DocDbAppGate
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Parameter SCREEN = "webapp.routineapps";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter LIST = "OcuPilot.Screen.Descriptor.RoutineAppList";

Parameter SAVEPATH = "/routine-application";

Parameter NAMESPACE = "";

Parameter OBJECTS = "privileged routine applications";

}
