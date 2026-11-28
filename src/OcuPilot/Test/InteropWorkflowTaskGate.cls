/// <p>Pins Story 24.17 Batch 4's gate as real principals in a child process (AD-8, AD-29, AD-39, AD-62): every read and write of the workflow tasks and worklist is refused before any vendor call and before
/// any value is judged, naming the pair that fails: the portal's, the write resource a write adds, and the namespace's database at READ for a read and WRITE for a write. A write an admitted principal
/// makes leaves its roles, user and namespace as they were; a refused one changes nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs; it creates and removes five principals in <code>USER</code>.</p>
Class OcuPilot.Test.InteropWorkflowTaskGate Extends OcuPilot.Test.InteropWorkflowTaskCase
{

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The principals: all the pairs; no write resource; no portal pair; READ on <code>USER</code>'s database alone; and nothing on <code>USER</code>'s database.</p>
Parameter PRINCIPALS = "OcuP2417wtAll:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wtNoWrite:%Ens_Portal:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wtNoPortal:%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wtDbRead:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:R,%DB_HSCUSTOM:RW;OcuP2417wtNoDb:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_HSCUSTOM:RW";

/// <p>The five legs of every principal, in order: the tasks list, the worklist, one task, an assign of it to the second member and a cancel of it.</p>
Parameter LEGNAMES = "tasks,worklist,task,assign,cancel";

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
    Set ..PreparedPassword = "OcuP2417wt" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

/// <p>The legs of every principal for the task <var>pId</var> as the array the child runs.</p>
ClassMethod Legs(pId As %String) As %DynamicArray
{
    Quit [
        {"name": "tasks", "endpoint": "WorkflowTasks", "type": "LIST", "field": "TaskId"},
        {"name": "worklist", "endpoint": "WorkflowWorklist", "type": "LIST", "field": "TaskId"},
        {"name": "task", "endpoint": "WorkflowTasks", "type": "WORKFLOWTASK", "query": {"id": (pId)}},
        {"name": "assign", "endpoint": "WorkflowTasks", "type": "ASSIGNWORKFLOWTASK", "query": {"id": (pId), "taskuser": (..#USERB)}},
        {"name": "cancel", "endpoint": "WorkflowTasks", "type": "CANCELWORKFLOWTASK", "query": {"id": (pId)}}
    ]
}

/// <p>The answer a leg is expected to carry, <code>http|code|failedPair</code>: <var>pPair</var> empty is an admitted call.</p>
ClassMethod Expect(pPair As %String = "", pRefusal As %String = "") As %String
{
    If pPair '= "" Quit "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ pPair
    If pRefusal '= "" Quit "409|" _ pRefusal _ "|"
    Quit "200||"
}

/// <p>AC4: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged, naming the pair, and writes nothing when it refuses. A principal holding every pair
/// reads, assigns, and is refused a cancel only by the namespace's having no production; one without the write resource reads and is refused each write naming <code>%Ens_WorkflowConfig:WRITE</code>;
/// one without the portal's pair is refused every leg naming it; one who can only read <code>USER</code>'s database reads and is refused each write naming <code>%DB_USER:WRITE</code>; one with nothing on it is refused each read naming
/// <code>%DB_USER:READ</code> and each write naming <code>%DB_USER:WRITE</code>.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.WORKFLOWWRITEPAIR</parameter> from the task writes' pairs in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the
/// <code>NoWrite</code> legs go red; drop the task writes from <method>OcuPilot.Port.InteropPort.IsAnyWrite</method> -- the <code>DbRead</code> legs go red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tOk = ..Expect()
    Set tNoProduction = ..Expect("", "INTEROP.PRODUCTION.NOTRUNNING")
    Set tWrite = ..Expect("%Ens_WorkflowConfig:WRITE")
    Set tPortal = ..Expect("%Ens_Portal:USE")
    Set tDbWrite = ..Expect("%DB_USER:WRITE")
    Set tDbRead = ..Expect("%DB_USER:READ")
    ; tasks, worklist, task, assign, cancel
    Set tExpected("OcuP2417wtAll") = $ListBuild(tOk, tOk, tOk, tOk, tNoProduction)
    Set tExpected("OcuP2417wtNoWrite") = $ListBuild(tOk, tOk, tOk, tWrite, tWrite)
    Set tExpected("OcuP2417wtNoPortal") = $ListBuild(tPortal, tPortal, tPortal, tPortal, tPortal)
    Set tExpected("OcuP2417wtDbRead") = $ListBuild(tOk, tOk, tOk, tDbWrite, tDbWrite)
    Set tExpected("OcuP2417wtNoDb") = $ListBuild(tDbRead, tDbRead, tDbRead, tDbWrite, tDbWrite)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $ClassMethod(..#FIXTURE, "DropWorkflowRows")
        Do $$$AssertStatusOK(..Arrange(), tUser _ ": the probe role and users are stored")
        Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, "", ..#USERA)
        Set tOut = $ClassMethod(..#FIXTURE, "ProbeAs", tUser, ..Legs(tId))
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        For tI = 1:1:$Length(..#LEGNAMES, ",") {
            Set tLegName = $Piece(..#LEGNAMES, ",", tI)
            Set tLeg = tOut.legs.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
        }
        Set tAdmitted = (tUser = "OcuP2417wtAll")
        Do $$$AssertEquals(..Facts(tId), ..#ROLE _ "|" _ $Select(tAdmitted: ..#USERB, 1: "") _ "|0|" _ $Select(tAdmitted: "Assigned", 1: "") _ "|0#" _ $Select(tAdmitted: ..#USERB, 1: ..#USERA), tUser _ ": an admitted assign moved the task and a refused one did not")
        If tAdmitted {
            Do $$$AssertEquals(tOut.before _ "|" _ tOut.sameUser _ "|" _ tOut.sameNamespace, tOut.after _ "|1|1", tUser _ ": its roles, user and namespace read the same after its writes")
        }
    }
}

/// <p>AC4: the endpoints' pair sets are the classic pages': both lists and the one-task read ask the portal's pair alone, and each write adds the dialog's WRITE; the port serves exactly those types, and the two
/// tools declare the screen's pairs, the write pair and WRITE on the namespace's database.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.WORKFLOWWRITEPAIR</parameter> from the tasks' pairs in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the write rows go red.</p>
Method TestThePairSetsAreTheClassicPagesAndTheToolsAddTheWritePair()
{
    Set tRead = "%Ens_Portal:USE"
    Set tWrite = tRead _ ",%Ens_WorkflowConfig:WRITE"
    For tCase = $ListBuild("WorkflowTasks", "LIST", tRead), $ListBuild("WorkflowTasks", "WORKFLOWTASK", tRead), $ListBuild("WorkflowTasks", "ASSIGNWORKFLOWTASK", tWrite), $ListBuild("WorkflowTasks", "CANCELWORKFLOWTASK", tWrite), $ListBuild("WorkflowWorklist", "LIST", tRead) {
        Set tPairs = $ClassMethod(..#PORT, "Pairs", $List(tCase, 1), $List(tCase, 2))
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List($List(tPairs, tI), 1) _ ":" _ $List($List(tPairs, tI), 2)
        }
        Do $$$AssertEquals(tText, $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": the pairs the port asks")
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", $List(tCase, 1), $List(tCase, 2)), $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": the endpoint serves it")
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", "WorkflowWorklist", "ASSIGNWORKFLOWTASK") && '$ClassMethod(..#PORT, "Serves", "WorkflowTasks", "ADDWORKFLOWMEMBER") && '$ClassMethod(..#PORT, "Serves", "WorkflowMembers", "CANCELWORKFLOWTASK"), "and no other family's type")
    For tTool = "OcuPilot.Screen.Tool.InteropWorkflowTaskAssign", "OcuPilot.Screen.Tool.InteropWorkflowTaskCancel" {
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && $ListFind(tPairs, $ListBuild("%Ens_WorkflowConfig", "WRITE")) && $ListFind(tPairs, $ListBuild("%Ens_Portal", "USE")), tTool _ ": the tool declares the screen's pair and the write pair")
        Set tWritesDb = 0
        For tI = 1:1:$ListLength(tPairs) {
            If ($List($List(tPairs, tI), 1) [ "%DB_") && ($List($List(tPairs, tI), 2) = "WRITE") Set tWritesDb = 1
        }
        Do $$$AssertTrue(tWritesDb, tTool _ ": and WRITE on the namespace's database")
    }
}

}
