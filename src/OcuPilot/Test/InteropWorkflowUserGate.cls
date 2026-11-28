/// <p>Pins Story 24.17 Batch 3a's gate as real principals in a child process (AD-8, AD-29, AD-39, AD-62): every read and write of the workflow users is refused before any vendor call and before
/// any value is judged, naming the pair that fails: the portal's, the classic page's own resource, the write resource a write and the user choices add, and WRITE on the namespace's database. The
/// user choices are the vendor's own answer to the caller, so a principal who holds the gate's pairs is offered its own name and one who also holds <code>%Admin_Secure:USE</code> every user's;
/// an add of another user's name is refused by name to the first and made for the second. A write an admitted principal makes leaves its roles, user and namespace as they were; a refused one
/// changes nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs; it creates and removes six principals in <code>USER</code>.</p>
Class OcuPilot.Test.InteropWorkflowUserGate Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The workflow users the legs read, edit and remove, and the instance user an add names beside the principal's own.</p>
Parameter HELDA = "OcuP2417wgHeldA";

Parameter HELDB = "OcuP2417wgHeldB";

Parameter TARGET = "OcuP2417wgTarget";

/// <p>The pairs every principal holds unless its entry leaves one out.</p>
Parameter BASE = "%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW";

/// <p>The principals: all of them; the classic page's resource at READ; no classic page resource; no portal pair; READ on <code>USER</code>'s database; and all of them with
/// <code>%Admin_Secure:USE</code>.</p>
Parameter PRINCIPALS = "OcuP2417wgAll:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgNoWrite:%Ens_Portal:U,%Ens_WorkflowConfig:R,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgNoRead:%Ens_Portal:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgNoPortal:%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuP2417wgDbRead:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:R,%DB_HSCUSTOM:RW;OcuP2417wgSecure:%Ens_Portal:U,%Ens_WorkflowConfig:RW,%DB_USER:RW,%DB_HSCUSTOM:RW,%Admin_Secure:U";

/// <p>The seven legs of every principal, in order: the list, one user, the choices, an add of the principal's own name, an add of <parameter>TARGET</parameter>, an edit of
/// <parameter>HELDA</parameter> and a remove of <parameter>HELDB</parameter>.</p>
Parameter LEGNAMES = "list,one,choices,addSelf,addOther,set,remove";

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

/// <p>The legs of the principal <var>pUser</var> as the array the child runs.</p>
ClassMethod Legs(pUser As %String) As %DynamicArray
{
    Quit [
        {"name": "list", "endpoint": "WorkflowUsers", "type": "LIST"},
        {"name": "one", "endpoint": "WorkflowUsers", "type": "WORKFLOWUSER", "query": {"id": (..#HELDA)}},
        {"name": "choices", "endpoint": "WorkflowUsers", "type": "WORKFLOWUSERCHOICES"},
        {"name": "addSelf", "endpoint": "WorkflowUsers", "type": "ADDWORKFLOWUSER", "query": {"id": (pUser)}, "body": {"FullName": "self"}},
        {"name": "addOther", "endpoint": "WorkflowUsers", "type": "ADDWORKFLOWUSER", "query": {"id": (..#TARGET)}, "body": {"FullName": "other"}},
        {"name": "set", "endpoint": "WorkflowUsers", "type": "SETWORKFLOWUSER", "query": {"id": (..#HELDA)}, "body": {"FullName": "gate"}},
        {"name": "remove", "endpoint": "WorkflowUsers", "type": "REMOVEWORKFLOWUSER", "query": {"id": (..#HELDB)}}
    ]
}

/// <p>The answer a leg is expected to carry, <code>http|code|failedPair</code>: <var>pPair</var> empty is an admitted call.</p>
ClassMethod Expect(pPair As %String = "", pOk As %String = "200||") As %String
{
    If pPair = "" Quit pOk
    Quit "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ pPair
}

/// <p>The workflow rows a principal's legs act on: two held users and the instance user an add may name.</p>
ClassMethod Arrange() As %Status
{
    Set tFx = ..#FIXTURE
    Do $ClassMethod(tFx, "DropWorkflowRows")
    Set tSC = $ClassMethod(tFx, "ProbeUser", ..#HELDA, "held", 1)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#HELDB, "held", 1))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "InstanceUser", ..#TARGET))
    Quit tSC
}

/// <p>AC4: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged, naming the pair, and writes nothing when it refuses. A principal holding
/// every pair reads, and is offered its own name by the choices, so it adds its own name and is refused another's by <code>USERNAME</code>; it edits and removes. One whose classic page resource
/// is READ alone reads and is refused the choices and each write naming <code>%Ens_WorkflowConfig:WRITE</code>; one without it is refused every leg naming its READ; one without the portal's pair
/// every leg naming it; one who can only read <code>USER</code>'s database reads and is refused the choices and each write naming <code>%DB_USER:WRITE</code>.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.WORKFLOWWRITEPAIR</parameter> from <method>OcuPilot.Port.InteropPort.Pairs</method> -- the <code>NoWrite</code> legs go red; drop
/// the choices from the write half of <method>OcuPilot.Port.InteropPort.Admit</method> -- the <code>DbRead</code> choices leg goes red.</p>
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
    Set tName = "422|INTEROP.WORKFLOW.USERNAME|"
    ; list, one, choices, add of the principal's own name, add of another, edit, remove
    Set tExpected("OcuP2417wgAll") = $ListBuild(tOk, tOk, tOk, tOk, tName, tOk, tOk)
    Set tExpected("OcuP2417wgNoWrite") = $ListBuild(tOk, tOk, tWrite, tWrite, tWrite, tWrite, tWrite)
    Set tExpected("OcuP2417wgNoRead") = $ListBuild(tRead, tRead, tRead, tRead, tRead, tRead, tRead)
    Set tExpected("OcuP2417wgNoPortal") = $ListBuild(tPortal, tPortal, tPortal, tPortal, tPortal, tPortal, tPortal)
    Set tExpected("OcuP2417wgDbRead") = $ListBuild(tOk, tOk, tDb, tDb, tDb, tDb, tDb)
    Set tExpected("OcuP2417wgSecure") = $ListBuild(tOk, tOk, tOk, tOk, tOk, tOk, tOk)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $$$AssertStatusOK(..Arrange(), tUser _ ": the held users are stored")
        Set tOut = $ClassMethod(..#FIXTURE, "ProbeAs", tUser, ..Legs(tUser))
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        For tI = 1:1:$Length(..#LEGNAMES, ",") {
            Set tLegName = $Piece(..#LEGNAMES, ",", tI)
            Set tLeg = tOut.legs.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
        }
        Set tAdmitted = (tUser = "OcuP2417wgAll") || (tUser = "OcuP2417wgSecure")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#HELDA), $Select(tAdmitted: "gate|1", 1: "held|1"), tUser _ ": an admitted edit changed the held user and a refused one did not")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#HELDB), $Select(tAdmitted: "<absent>", 1: "held|1"), tUser _ ": an admitted remove took the other and a refused one did not")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, tUser), $Select(tAdmitted: "self|1", 1: "<absent>"), tUser _ ": an admitted add of the principal's own name stored it and a refused one did not")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserText", ..#SOURCE, ..#TARGET), $Select(tUser = "OcuP2417wgSecure": "other|1", 1: "<absent>"), tUser _ ": and the add of another's name was made for the principal who is offered it alone")
        If tAdmitted {
            Do $$$AssertEquals(tOut.before _ "|" _ tOut.sameUser _ "|" _ tOut.sameNamespace, tOut.after _ "|1|1", tUser _ ": its roles, user and namespace read the same after its writes")
        }
    }
}

/// <p>AC4: the user choices are the vendor's own answer to the caller and OcuPilot adds nothing: a principal who holds the gate's pairs is offered its own name alone, and one who also holds
/// <code>%Admin_Secure:USE</code> is offered every user the classic selector lists, the probe instance users included; neither is offered <code>_SYSTEM</code> or the other names the selector
/// leaves out.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListWorkflowChoices</method> read the users of <code>Security.Users</code> directly -- the plain principal is offered more than its own
/// name and this goes red.</p>
Method TestTheChoicesAreTheVendorsAnswerToTheCaller()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK(..Arrange(), "the instance user an add may name is stored")
    Set tLegs = [{"name": "choices", "endpoint": "WorkflowUsers", "type": "WORKFLOWUSERCHOICES"}]
    Set tPlain = $ClassMethod(..#FIXTURE, "ProbeAs", "OcuP2417wgAll", tLegs)
    Do $$$AssertTrue($IsObject(tPlain) && (tPlain.%Get("error") = ""), "the plain principal's probe ran: " _ $Select($IsObject(tPlain): tPlain.%Get("error"), 1: tPlain))
    If $IsObject(tPlain) && (tPlain.%Get("error") = "") {
        Do $$$AssertEquals(tPlain.legs.choices.names, "OcuP2417wgAll", "a principal who holds the gate's pairs is offered its own name alone")
    }
    Set tSecure = $ClassMethod(..#FIXTURE, "ProbeAs", "OcuP2417wgSecure", tLegs)
    Do $$$AssertTrue($IsObject(tSecure) && (tSecure.%Get("error") = ""), "the Secure principal's probe ran: " _ $Select($IsObject(tSecure): tSecure.%Get("error"), 1: tSecure))
    If $IsObject(tSecure) && (tSecure.%Get("error") = "") {
        Set tNames = "," _ tSecure.legs.choices.names _ ","
        Do $$$AssertTrue((tNames [ ",OcuP2417wgTarget,") && (tNames [ ",OcuP2417wgAll,") && (tNames [ ",irisowner,"), "a principal who also holds %Admin_Secure:USE is offered every user, the probe instance users among them: " _ tNames)
        Do $$$AssertTrue((tNames '[ ",_SYSTEM,") && (tNames '[ ",_PUBLIC,") && (tNames '[ ",UnknownUser,"), "and neither is offered the names the selector leaves out")
    }
}

/// <p>AC4: the endpoint's pair sets are the classic page's: the list and the one-user read ask the portal's pair and the page's READ, and the user choices and each write add the page's WRITE; the port
/// serves exactly those types, and the three tools declare the write pair and WRITE on the namespace's database beyond the screen's own.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.WORKFLOWWRITEPAIR</parameter> from the choices' pairs in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the choices row goes red.</p>
Method TestThePairSetsAreTheClassicPagesAndTheToolsAddTheWritePair()
{
    Set tRead = "%Ens_Portal:USE,%Ens_WorkflowConfig:READ"
    Set tWrite = tRead _ ",%Ens_WorkflowConfig:WRITE"
    For tCase = $ListBuild("LIST", tRead), $ListBuild("WORKFLOWUSER", tRead), $ListBuild("WORKFLOWUSERCHOICES", tWrite), $ListBuild("ADDWORKFLOWUSER", tWrite), $ListBuild("SETWORKFLOWUSER", tWrite), $ListBuild("REMOVEWORKFLOWUSER", tWrite) {
        Set tPairs = $ClassMethod(..#PORT, "Pairs", ..#ENDPOINT, $List(tCase, 1))
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List($List(tPairs, tI), 1) _ ":" _ $List($List(tPairs, tI), 2)
        }
        Do $$$AssertEquals(tText, $List(tCase, 2), $List(tCase, 1) _ ": the pairs the port asks")
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", ..#ENDPOINT, $List(tCase, 1)), $List(tCase, 1) _ ": the endpoint serves it")
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", ..#ENDPOINT, "SCHEDULE"), "and no other family's type")
    For tTool = "Add", "Update", "Remove" {
        Set tPairs = $ClassMethod(..#TOOLPREFIX _ tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && $ListFind(tPairs, $ListBuild("%Ens_WorkflowConfig", "WRITE")) && $ListFind(tPairs, $ListBuild("%Ens_WorkflowConfig", "READ")) && $ListFind(tPairs, $ListBuild("%Ens_Portal", "USE")), tTool _ ": the tool declares the screen's pairs and the write pair")
        Set tWritesDb = 0
        For tI = 1:1:$ListLength(tPairs) {
            If ($List($List(tPairs, tI), 1) [ "%DB_") && ($List($List(tPairs, tI), 2) = "WRITE") Set tWritesDb = 1
        }
        Do $$$AssertTrue(tWritesDb, tTool _ ": and WRITE on the namespace's database")
    }
}

}
