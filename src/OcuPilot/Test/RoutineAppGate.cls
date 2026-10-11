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

/// <p>Story 18.33 (C6): the holder of the area's two pairs and the install database's read applies the role and routine
/// actions to a probe application over the wire; the instance holds the changes.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.RoutineAppUpdate.SCREENACTIONS</parameter> -- the route
/// answers 404 and both legs go red.</p>
Method TestTheDeclaredPairsApplyTheRoleAndRoutineActions()
{
    Set tUser = ..User(1)
    Set tPath = "/screens/" _ ..#SCREEN _ "/action"
    Do $$$AssertEquals(..Wire("POST", tPath, {"action": "add-application-role", "id": (..Id(..Name("A"))), "values": {"Role": "%Developer"}}, tUser), "200 ", "the holder's add of an application role is accepted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Targets", ..Name("A"), ""), "%Developer", "and the instance holds it")
    Do $$$AssertEquals(..Wire("POST", tPath, {"action": "add-routine", "id": (..Id(..Name("A"))), "values": {"RoutineOrClass": "OcuProbe1833.Gate", "Db": "HSCUSTOM", "Type": "Class"}}, tUser), "200 ", "and of a routine")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Entries", ..Name("A")), "OcuProbe1833.Gate:HSCUSTOM:Class", "which the instance holds")
}

/// <p>Story 18.33 (C6): without <code>%Admin_Secure:USE</code> the role and routine actions are refused naming it, and
/// without <code>%DB_IRISSYS:READ</code> naming that, before any port call; the probe applications are as they were.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.DocDbAppUpdate.PrivilegePairs</method> answer no pair -- the
/// outsiders' actions are accepted and both principals' legs go red.</p>
Method TestWithoutAPairTheRoleAndRoutineActionsAreRefusedByName()
{
    Set tPath = "/screens/" _ ..#SCREEN _ "/action"
    For tCase = $ListBuild(2, "%Admin_Secure:USE"), $ListBuild(3, "%DB_IRISSYS:READ") {
        Set tUser = ..User($List(tCase, 1))
        Do $$$AssertEquals(..Wire("POST", tPath, {"action": "add-application-role", "id": (..Id(..Name("A"))), "values": {"Role": "%Developer"}}, tUser), "403 " _ $List(tCase, 2), tUser _ ": an application role is refused naming the pair")
        Do $$$AssertEquals(..Wire("POST", tPath, {"action": "add-routine", "id": (..Id(..Name("A"))), "values": {"RoutineOrClass": "OcuProbe1833.Gate", "Db": "HSCUSTOM", "Type": "Class"}}, tUser), "403 " _ $List(tCase, 2), tUser _ ": and a routine")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedSeeded, "nothing was written")
}

}
