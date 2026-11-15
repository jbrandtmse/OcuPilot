/// <p>Pins <class>OcuPilot.Port.BackupPort</class>'s pair sets with least-privileged principals (AD-29, AC1): a principal holding the
/// read pairs alone reads the three lists and the write state and is refused a freeze 403 naming <code>%DB_IRISSYS:WRITE</code>; a
/// principal holding exactly the write pairs freezes and thaws database writes, takes a database off the backup list and puts it back,
/// and runs a backup. Each leg runs in a child process logged in as the principal (<method>OcuPilot.Test.JournalProbe.RunAs</method>).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>BACKUPVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe users and roles, freezes
/// database writes, changes the backup database list and runs a backup. After each test writes are thawed, the list and the history
/// are as the test found them, and every probe object is removed by exact name (<class>OcuPilot.Test.JournalProbe</class>,
/// <class>OcuPilot.Test.BackupProbe</class>).</p>
Class OcuPilot.Test.BackupWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the backup writes, set there alone too.</p>
Parameter BACKUPVARIABLE = "OCUPILOT_ALLOW_BACKUP_CONTROL";

Parameter PORT = "OcuPilot.Port.BackupPort";

Parameter PRINCIPALS = "OcuPilot.Test.JournalProbe";

Parameter PROBE = "OcuPilot.Test.BackupProbe";

/// <p>The reader, holding the port's read pairs, and the writer, holding its write pairs, each <code>user:role:pairs</code> beyond the
/// install namespace's code read.</p>
Parameter READER = "OCUPROBE185BKREAD:OCUPROBE185BKREADROLE:%Admin_Operate:U,%DB_IRISSYS:R";

Parameter WRITER = "OCUPROBE185BKWRITE:OCUPROBE185BKWRITEROLE:%Admin_Operate:U,%DB_IRISSYS:RW";

/// <p>The backup list as it stood before each test.</p>
Property PreparedList As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#BACKUPVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.BackupWriteGate creates and deletes users and roles, freezes database writes, changes the backup database list and runs a backup on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#BACKUPVARIABLE _ " must both read 1 here, so nothing was changed.")
    }
    Do $ClassMethod(..#PROBE, "Thaw")
    Do $ClassMethod(..#PROBE, "Remove")
    Quit $ClassMethod(..#PRINCIPALS, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "WaitForSettled", 15)
    Do $ClassMethod(..#PROBE, "Thaw")
    Do $ClassMethod(..#PROBE, "KeepHistory")
    Set ..PreparedList = $ClassMethod(..#PROBE, "ListedNames")
    Set tSC = $$$OK
    For tEntry = ..#READER, ..#WRITER {
        Set tSC = $ClassMethod(..#PRINCIPALS, "SeedPrincipal", $Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Piece(tEntry, ":", 3, *))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForIdle", 120), 1, "no probe backup is still running")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForSettled", 15), 1, "the last backup's own suspension of writes has ended")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Thaw"), 0, "writes are thawed after the test")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetList", ..PreparedList), "the backup list is put back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remove"), "", "every backup probe object is removed")
    Do $ClassMethod(..#PROBE, "RestoreHistory")
    Do $$$AssertStatusOK($ClassMethod(..#PRINCIPALS, "RemoveAll", .tRemaining), "every probe principal is removed by exact name")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#PROBE, "Thaw")
    Quit $ClassMethod(..#PRINCIPALS, "RemoveAll", .tRemaining)
}

/// <p>The step of <var>pPlan</var> answered as <code>http|code</code> for each step, joined with <code>;</code>, run as <var>pUser</var>,
/// or the run's error.</p>
ClassMethod Steps(pUser As %String, pPlan As %DynamicArray) As %String
{
    Set tRun = $ClassMethod(..#PRINCIPALS, "RunAs", pUser, pPlan, 180)
    If '$IsObject(tRun) || (tRun.%Get("error") '= "") Quit "error: " _ $Select($IsObject(tRun): tRun.%Get("error"), 1: "")
    If (tRun.%Get("username") '= pUser) || 'tRun.%Get("loggedIn") Quit "not " _ pUser _ ": " _ tRun.%Get("username")
    Set tOut = ""
    Set tIterator = tRun.%Get("steps").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tCode = $Select($IsObject(tStep.%Get("fault")): tStep.%Get("fault").%Get("code"), 1: "")
        Set tPair = $Select(tCode = "AUTH.NOPRIVILEGE": " " _ tStep.%Get("fault").%Get("detail").%Get("failedPair"), 1: "")
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tStep.%Get("http") _ "|" _ tCode _ tPair
    }
    Quit tOut
}

/// <p>A plan step for <var>pEndpoint</var> and <var>pType</var> through the backup port, with the query <var>pQuery</var>.</p>
ClassMethod Step(pEndpoint As %String, pType As %String, pQuery As %DynamicObject = "") As %DynamicObject
{
    Set tStep = {"port": (..#PORT)}
    Do tStep.%Set("endpoint", pEndpoint, "string")
    Do tStep.%Set("type", pType, "string")
    If $IsObject(pQuery) Do tStep.%Set("query", pQuery)
    Quit tStep
}

/// <p><b>AC1, AD-29.</b> The read pairs read the three lists and the write state, and are refused a freeze naming the write pair.</p>
/// <p>Mutation (Rule 19): <code>PAIRS</code> gains <code>%DB_IRISSYS:WRITE</code> -> every read leg answers 403 and this goes red.</p>
Method TestTheReadPairsReadEveryListAndAreRefusedAFreeze()
{
    Set tUser = $Piece(..#READER, ":", 1)
    Set tPlan = [(..Step("Tasks", "LIST")), (..Step("History", "LIST")), (..Step("Databases", "LIST")), (..Step("Writes", "GET")), (..Step("Writes", "FREEZE", {"limit": "5"}))]
    Do $$$AssertEquals(..Steps(tUser, tPlan), "200|;200|;200|;200|;403|AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE", "the reader reads each list and the write state, and its freeze is refused naming the write pair")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WritesFrozen"), 0, "and nothing was frozen")
}

/// <p><b>AC1, AD-29.</b> The write pairs freeze and thaw database writes, take a listed database off the backup list and put it back, and
/// run a backup of the probe database, each answering 200.</p>
/// <p>Mutation (Rule 19): <code>SuspendCall</code> discards the vendor's output through <code>%SYS.Capture</code> instead of the null
/// device -> the writer's freeze answers 500 and this goes red.</p>
Method TestTheWritePairsFreezeThawChangeTheListAndRun()
{
    Set tUser = $Piece(..#WRITER, ":", 1)
    Set tName = $Piece(..PreparedList, ",", 1)
    Do $$$AssertTrue(tName '= "", "the backup list holds a database to take off and put back")
    Set tPlan = [(..Step("Writes", "FREEZE", {"limit": "30"})), (..Step("Writes", "THAW")), (..Step("Databases", "REMOVE", {"name": (tName)})), (..Step("Databases", "ADD", {"name": (tName)}))]
    Do $$$AssertEquals(..Steps(tUser, tPlan), "200|;200|;200|;200|", "the writer freezes, thaws, and takes " _ tName _ " off the list and puts it back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WritesFrozen"), 0, "writes are thawed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Create", $Parameter(..#PROBE, "RUNDATABASE")), "the run database and the probe task are created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetList", $Parameter(..#PROBE, "RUNDATABASE")), "and the list holds only the run database")
    Set tBefore = $ClassMethod(..#PROBE, "HistoryCount")
    Do $$$AssertEquals(..Steps(tUser, [(..Step("Tasks", "RUN", {"name": ($Parameter(..#PROBE, "TASK"))}))]), "200|", "the writer runs a backup")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForHistory", tBefore + 1, 120), 1, "and it finishes, adding a history row")
}

}
