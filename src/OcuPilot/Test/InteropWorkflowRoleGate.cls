/// <p>Pins Story 24.17 Batch 3b's gate as real principals in a child process (AD-8, AD-29, AD-39, AD-62): every read and write of the workflow roles and their members is refused before any vendor call and
/// before any value is judged, naming the pair that fails: the portal's, the classic page's own resource, the write resource a write adds, and WRITE on the namespace's database. A write an admitted
/// principal makes leaves its roles, user and namespace as they were; a refused one changes nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs; it creates and removes five principals in <code>USER</code>.</p>
Class OcuPilot.Test.InteropWorkflowRoleGate Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter SCREEN = "/screens/interop.workflowroles";

Parameter SAVE = "/interop/workflow-roles";

Parameter ENDPOINT = "WorkflowRoles";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowRole";

Parameter ENTITY = "interop-workflow-role";

Parameter READTYPE = "WORKFLOWROLE";

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The roles and users the legs read, edit, add to and remove.</p>
Parameter HELDROLE = "OcuP2417wgHeldRole";

Parameter DROPROLE = "OcuP2417wgDropRole";

Parameter NEWROLE = "OcuP2417wgNewRole";

Parameter MEMBER = "OcuP2417wgMember";

Parameter NEWMEMBER = "OcuP2417wgNewMember";

/// <p>The principals: all the pairs; the classic page's resource at READ; no classic page resource; no portal pair; and READ on <code>USER</code>'s database.</p>
Parameter PRINCIPALS = "OcuP2417wgAll:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgNoWrite:%Ens_Portal:U,%Ens_WorkflowConfig:R,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgNoRead:%Ens_Portal:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgNoPortal:%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgDbRead:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:R,%DB_HSCUSTOM:RW";

/// <p>The nine legs of every principal, in order: the roles list, one role, the members of the held role, one member, an add of a new role, an edit of the held role, a remove of the other role,
/// an add of a member and a remove of one.</p>
Parameter LEGNAMES = "roles,role,members,member,roleAdd,roleSet,roleRemove,memberAdd,memberRemove";

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Set tSC = ##super()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuP2417wg" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

/// <p>The legs of every principal as the array the child runs.</p>
ClassMethod Legs() As %DynamicArray
{
    Set tMember = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#HELDROLE, ..#MEMBER))
    Set tNewMember = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#HELDROLE, ..#NEWMEMBER))
    Quit [
        {"name": "roles", "endpoint": "WorkflowRoles", "type": "LIST"},
        {"name": "role", "endpoint": "WorkflowRoles", "type": "WORKFLOWROLE", "query": {"id": (..#HELDROLE)}},
        {"name": "members", "endpoint": "WorkflowMembers", "type": "LIST", "query": {"role": (..#HELDROLE)}, "field": "User"},
        {"name": "member", "endpoint": "WorkflowMembers", "type": "WORKFLOWMEMBER", "query": {"id": (tMember)}},
        {"name": "roleAdd", "endpoint": "WorkflowRoles", "type": "ADDWORKFLOWROLE", "query": {"id": (..#NEWROLE)}, "body": {"Description": "new"}},
        {"name": "roleSet", "endpoint": "WorkflowRoles", "type": "SETWORKFLOWROLE", "query": {"id": (..#HELDROLE)}, "body": {"Description": "gate"}},
        {"name": "roleRemove", "endpoint": "WorkflowRoles", "type": "REMOVEWORKFLOWROLE", "query": {"id": (..#DROPROLE)}},
        {"name": "memberAdd", "endpoint": "WorkflowMembers", "type": "ADDWORKFLOWMEMBER", "query": {"id": (tNewMember)}, "body": {"Ranking": 2}},
        {"name": "memberRemove", "endpoint": "WorkflowMembers", "type": "REMOVEWORKFLOWMEMBER", "query": {"id": (tMember)}}
    ]
}

/// <p>The answer a leg is expected to carry, <code>http|code|failedPair</code>: <var>pPair</var> empty is an admitted call.</p>
ClassMethod Expect(pPair As %String = "") As %String
{
    If pPair = "" Quit "200||"
    Quit "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ pPair
}

/// <p>The rows a principal's legs act on: two held roles, the held role's member and a workflow user to add.</p>
ClassMethod Arrange() As %Status
{
    Set tFx = ..#FIXTURE
    Do $ClassMethod(tFx, "DropWorkflowRows")
    Set tSC = $ClassMethod(tFx, "ProbeRole", ..#HELDROLE, ..#SOURCE, "held", 20)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#DROPROLE, ..#SOURCE, "drop", 20))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#MEMBER, "Mem", 0))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#NEWMEMBER, "New", 0))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#HELDROLE, ..#MEMBER, ..#SOURCE, 3, "t"))
    Quit tSC
}

/// <p>AC5: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged, naming the pair, and writes nothing when it refuses. A principal holding every pair
/// reads and writes; one whose classic page resource is READ alone reads and is refused each write naming <code>%Ens_WorkflowConfig:WRITE</code>; one without it is refused every leg naming its READ; one
/// without the portal's pair every leg naming it; one who can only read <code>USER</code>'s database reads and is refused each write naming <code>%DB_USER:WRITE</code>.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.WORKFLOWWRITEPAIR</parameter> from the roles' and members' pairs in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the
/// <code>NoWrite</code> legs go red; drop the member writes from <method>OcuPilot.Port.InteropPort.IsAnyWrite</method> -- the <code>DbRead</code> member legs go red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tOk = ..Expect()
    Set tWrite = ..Expect("%Ens_WorkflowConfig:WRITE")
    Set tRead = ..Expect("%Ens_WorkflowConfig:READ")
    Set tPortal = ..Expect("%Ens_Portal:USE")
    Set tDb = ..Expect("%DB_USER:WRITE")
    ; roles, role, members, member, roleAdd, roleSet, roleRemove, memberAdd, memberRemove
    Set tExpected("OcuP2417wgAll") = $ListBuild(tOk, tOk, tOk, tOk, tOk, tOk, tOk, tOk, tOk)
    Set tExpected("OcuP2417wgNoWrite") = $ListBuild(tOk, tOk, tOk, tOk, tWrite, tWrite, tWrite, tWrite, tWrite)
    Set tExpected("OcuP2417wgNoRead") = $ListBuild(tRead, tRead, tRead, tRead, tRead, tRead, tRead, tRead, tRead)
    Set tExpected("OcuP2417wgNoPortal") = $ListBuild(tPortal, tPortal, tPortal, tPortal, tPortal, tPortal, tPortal, tPortal, tPortal)
    Set tExpected("OcuP2417wgDbRead") = $ListBuild(tOk, tOk, tOk, tOk, tDb, tDb, tDb, tDb, tDb)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $$$AssertStatusOK(..Arrange(), tUser _ ": the held roles and member are stored")
        Set tOut = $ClassMethod(..#FIXTURE, "ProbeAs", tUser, ..Legs())
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        For tI = 1:1:$Length(..#LEGNAMES, ",") {
            Set tLegName = $Piece(..#LEGNAMES, ",", tI)
            Set tLeg = tOut.legs.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
        }
        Set tAdmitted = (tUser = "OcuP2417wgAll")
        Set tFx = ..#FIXTURE
        Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#HELDROLE), $Select(tAdmitted: "gate|20", 1: "held|20"), tUser _ ": an admitted edit changed the held role and a refused one did not")
        Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#DROPROLE), $Select(tAdmitted: "<absent>", 1: "drop|20"), tUser _ ": an admitted remove took the other role and a refused one did not")
        Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#NEWROLE), $Select(tAdmitted: "new|100", 1: "<absent>"), tUser _ ": an admitted add stored the new role and a refused one did not")
        Do $$$AssertEquals($ClassMethod(tFx, "MemberText", ..#SOURCE, ..#HELDROLE, ..#NEWMEMBER) _ "|" _ $ClassMethod(tFx, "MemberText", ..#SOURCE, ..#HELDROLE, ..#MEMBER), $Select(tAdmitted: "2||<absent>", 1: "<absent>|3|t"), tUser _ ": an admitted member add and remove changed the memberships and a refused one did not")
        If tAdmitted {
            Do $$$AssertEquals(tOut.before _ "|" _ tOut.sameUser _ "|" _ tOut.sameNamespace, tOut.after _ "|1|1", tUser _ ": its roles, user and namespace read the same after its writes")
        }
    }
}

/// <p>AC5: the endpoints' pair sets are the classic page's: the lists and the one-object reads ask the portal's pair and the page's READ, and each write adds the page's WRITE; the port serves exactly those
/// types, and the five tools declare the write pair and WRITE on the namespace's database beyond the screens' own.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.WORKFLOWWRITEPAIR</parameter> from the members' pairs in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the member rows go red.</p>
Method TestThePairSetsAreTheClassicPagesAndTheToolsAddTheWritePair()
{
    Set tRead = "%Ens_Portal:USE,%Ens_WorkflowConfig:READ"
    Set tWrite = tRead _ ",%Ens_WorkflowConfig:WRITE"
    For tCase = $ListBuild("WorkflowRoles", "LIST", tRead), $ListBuild("WorkflowRoles", "WORKFLOWROLE", tRead), $ListBuild("WorkflowRoles", "ADDWORKFLOWROLE", tWrite), $ListBuild("WorkflowRoles", "SETWORKFLOWROLE", tWrite), $ListBuild("WorkflowRoles", "REMOVEWORKFLOWROLE", tWrite), $ListBuild("WorkflowMembers", "LIST", tRead), $ListBuild("WorkflowMembers", "WORKFLOWMEMBER", tRead), $ListBuild("WorkflowMembers", "ADDWORKFLOWMEMBER", tWrite), $ListBuild("WorkflowMembers", "REMOVEWORKFLOWMEMBER", tWrite) {
        Set tPairs = $ClassMethod(..#PORT, "Pairs", $List(tCase, 1), $List(tCase, 2))
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List($List(tPairs, tI), 1) _ ":" _ $List($List(tPairs, tI), 2)
        }
        Do $$$AssertEquals(tText, $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": the pairs the port asks")
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", $List(tCase, 1), $List(tCase, 2)), $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": the endpoint serves it")
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", "WorkflowRoles", "ADDWORKFLOWMEMBER") && '$ClassMethod(..#PORT, "Serves", "WorkflowMembers", "ADDWORKFLOWROLE") && '$ClassMethod(..#PORT, "Serves", "WorkflowUsers", "ADDWORKFLOWROLE") && '$ClassMethod(..#PORT, "Serves", "WorkflowRoles", "ADDWORKFLOWUSER"), "and no other family's type")
    For tTool = "OcuPilot.Screen.Tool.InteropWorkflowRoleAdd", "OcuPilot.Screen.Tool.InteropWorkflowRoleUpdate", "OcuPilot.Screen.Tool.InteropWorkflowRoleRemove", "OcuPilot.Screen.Tool.InteropWorkflowMemberAdd", "OcuPilot.Screen.Tool.InteropWorkflowMemberRemove" {
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && $ListFind(tPairs, $ListBuild("%Ens_WorkflowConfig", "WRITE")) && $ListFind(tPairs, $ListBuild("%Ens_WorkflowConfig", "READ")) && $ListFind(tPairs, $ListBuild("%Ens_Portal", "USE")), tTool _ ": the tool declares the screen's pairs and the write pair")
        Set tWritesDb = 0
        For tI = 1:1:$ListLength(tPairs) {
            If ($List($List(tPairs, tI), 1) [ "%DB_") && ($List($List(tPairs, tI), 2) = "WRITE") Set tWritesDb = 1
        }
        Do $$$AssertTrue(tWritesDb, tTool _ ": and WRITE on the namespace's database")
    }
}

}
