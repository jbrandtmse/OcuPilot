/// <p>Pins Story 18.4's integrity check and its log (AC6, AC7): the check of one database and of a set on
/// both callers of <code>osmgmt.databases.integrity</code> -- the Databases list's
/// <code>integrity</code> action (<class>OcuPilot.Test.DatabaseActionFixture</class>) and the agent's
/// mint and confirm -- with the body the port sends and the report it leaves; the set id's canonical
/// spelling (AD-13); the refusals, each before any vendor call; the Integrity log's list, pages and rows
/// (<class>OcuPilot.Port.LogSourcePort</class>, live and through
/// <class>OcuPilot.Test.LogSourceFixture</class>); a least-privileged reader over the wire; and the
/// vendor query's columns the log reads.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PRINCIPALSVARIABLE</parameter> reading
/// <code>1</code>, because the class creates, checks and deletes probe databases
/// (<class>OcuPilot.Test.DatabaseActionProbe</class>), creates and deletes two users and two roles, and
/// sets the governance policy. <method>OnBeforeAllTests</method> refuses anywhere either does not; every
/// probe object and check is removed before all, after each and after all.</p>
Class OcuPilot.Test.DatabaseIntegrity Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.DatabaseActionProbe";

Parameter ACTION = "OcuPilot.Test.DatabaseActionFixture";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter ACCEPT = "OcuPilot.Test.DatabaseAcceptPort";

Parameter LOG = "OcuPilot.Port.LogSourcePort";

Parameter FIXTURE = "OcuPilot.Test.LogSourceFixture";

Parameter SCREEN = "osmgmt.databases";

Parameter TOOL = "OcuPilot.Screen.Tool.DatabaseIntegrityCheck";

Parameter KEY = "osmgmt.databases.integrity";

Parameter SOURCE = "integrity";

/// <p>The two principals, each <code>user:role:grants</code> beyond the install namespace's code
/// read: the Integrity log's two pairs, and the system database's read with an administrative
/// resource other than <code>%Admin_Operate</code>, since OcuPilot refuses an account holding none.</p>
Parameter PRINCIPALS = "OcuProbe184IntegrityReader:OcuProbe184IntegrityReaderRole:%Admin_Operate:U;%DB_IRISSYS:R,OcuProbe184IntegrityNoOperate:OcuProbe184IntegrityNoOperateRole:%Admin_Manage:U;%DB_IRISSYS:R";

/// <p>The columns of <code>SYS.BackgroundIntegrity:ListIntegrityTasks</code>, in order, measured on
/// <code>ocupilot-b-ci</code>; the log reads <code>ID</code>, <code>StartTime</code>,
/// <code>RunningState</code> and <code>HasEnded</code>, and the probe's removal
/// <code>DatabaseList</code>.</p>
Parameter QUERYCOLUMNS = "ID,StartTime,RunningState,HasEnded,FinalStatus,DatabaseList,ListOfGlobalLists,MaxProcesses,PartialCheck,PID";

Property PreparedPassword As %String;

Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseIntegrity creates, checks and deletes databases, users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PRINCIPALSVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbe184Integ" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#FIXTURE, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object and check is removed")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    Set tSC = $$$ADDSC(tSC, ..RemovePrincipals())
    Quit tSC
}

/// <p>One database and a set, on both callers (AC6): the screen's check of one database with a global
/// sends <code>{"Databases":[{"Directory":&lt;dir&gt;,"Globals":["OcuProbe184Fill"]}]}</code> and its
/// report names that directory and global; the agent's check of a set sends each member once, in the
/// set's canonical order, with no <code>Globals</code>, and its proposal names that canonical set. Each is
/// queued, read once and forgotten.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionBody</method> drops a set's second
/// member -> the agent's body goes red.</p>
Method TestOneDatabaseAndASetAreCheckedOnBothCallers()
{
    Set tA = ..AddProbe("OCUPROBE184IA", 1)
    Set tB = ..AddProbe("OCUPROBE184IB")
    Set tAlerts = $ClassMethod(..#PROBE, "SecondReads")
    Do $$$AssertTrue(tAlerts >= 0, "messages.log is read (" _ tAlerts _ ")")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $$$AssertEquals(..Act(tA, ..FillValues()), "200 ", "the screen's check of one database answers 200")
    Set tWanted = {"Databases": [{}]}
    Do tWanted.Databases.%Get(0).%Set("Directory", tA, "string")
    Do tWanted.Databases.%Get(0).%Set("Globals", ["OcuProbe184Fill"])
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/INTEGRITYCHECK"), tWanted.%ToJSON(), "sending the one directory and its global")
    Set tLines = ..NewestLines(.tCheck)
    Do $$$AssertTrue($ListFind(tLines, "Directory: " _ tA), "its report names the directory (check " _ tCheck _ ")")
    Do $$$AssertTrue(..AnyStarts(tLines, "Global: OcuProbe184Fill"), "and the one global it checked")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable(..#KEY), "the agent's key is enabled")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSet = ##class(%DynamicArray).%New()
    Do tSet.%Push(tB, "string")
    Do tSet.%Push(tA, "string")
    Do tSet.%Push($Extract(tA, 1, *-1), "string")
    Set tProposal = ##class(OcuPilot.Test.DatabaseActions).Minted(..#TOOL, tSet.%ToJSON(), {})
    Set tCanonical = ##class(%DynamicArray).%New()
    Do tCanonical.%Push(tA, "string")
    Do tCanonical.%Push(tB, "string")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("target").%Get("id"), 1: "not minted"), tCanonical.%ToJSON(), "the agent's check of a set is minted against the canonical set")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "200 ", "and confirmed")
    Set tWanted = {"Databases": [{}, {}]}
    Do tWanted.Databases.%Get(0).%Set("Directory", tA, "string")
    Do tWanted.Databases.%Get(1).%Set("Directory", tB, "string")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/INTEGRITYCHECK"), tWanted.%ToJSON(), "sending each member once, in order, with no globals")
    Set tLines = ..NewestLines(.tCheck)
    Do $$$AssertTrue($ListFind(tLines, "Directory: " _ tA) && $ListFind(tLines, "Directory: " _ tB), "its report names both directories (check " _ tCheck _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 0, "each queued check was read once and its row deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SecondReads"), tAlerts, "and no second read of an ended task was logged")
}

/// <p>The set id (AD-13 as amended): a JSON array of directories keeps each member's first spelling,
/// drops a later one naming the same directory, and sorts the rest into compact JSON; a one-member set
/// reads as its member; any other value is kept exactly, so Database details' ids are unchanged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.CanonicalSet</method> keeps the members'
/// order -> the sorted leg goes red.</p>
Method TestTheSetIdIsCanonical()
{
    Set tA = "/durable/iris/mgr/ocuprobe184ia/"
    Set tB = "/durable/iris/mgr/ocuprobe184ib/"
    Set tSet = ##class(%DynamicArray).%New()
    Do tSet.%Push(tB, "string")
    Do tSet.%Push(tA, "string")
    Do tSet.%Push($Extract(tA, 1, *-1), "string")
    Set tCanonical = ##class(%DynamicArray).%New()
    Do tCanonical.%Push(tA, "string")
    Do tCanonical.%Push(tB, "string")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", tSet.%ToJSON()), tCanonical.%ToJSON(), "a set is deduplicated by directory and sorted")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("database", "instance", tSet.%ToJSON(), .tKey)
    Do $$$AssertStatusOK(tSC, "a set is a valid database id")
    Do $$$AssertEquals($Piece(tKey, $Char(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR), 3, *), tCanonical.%ToJSON(), "and its key carries the canonical set")
    Set tOne = ##class(%DynamicArray).%New()
    Do tOne.%Push(tA, "string")
    Do tOne.%Push($Extract(tA, 1, *-1), "string")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", tOne.%ToJSON()), tA, "a set of one directory reads as that directory")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", $Extract(tA, 1, *-1)), $Extract(tA, 1, *-1), "one directory is kept exactly")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("database", "[1,2]"), "[1,2]", "and so is an array that is not of directories")
}

/// <p>The refusals, each before any vendor call (AC6): an empty set is refused 422
/// <code>DATABASE.INTEGRITY.DATABASES</code> with no call at all; a set with a dismounted member 409
/// <code>DATABASE.DISMOUNTED</code> naming it; a global that is not a global name 422
/// <code>DATABASE.GLOBALS.SHAPE</code>; and globals over two databases 422
/// <code>DATABASE.GLOBALS.ONEDATABASE</code> -- on the screen and at the mint.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionViolations</method> accepts an empty
/// set -> the accept port records a check and this goes red;
/// <method>OcuPilot.Area.OsMgmt.DatabaseRules.ActionProblem</method> names no member -> the mint's
/// dismounted leg goes red.</p>
Method TestTheRefusalsSendNoCall()
{
    Set tA = ..AddProbe("OCUPROBE184IA")
    Set tB = ..AddProbe("OCUPROBE184IB")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Do $ClassMethod(..#ACCEPT, "Clear")
    Do $$$AssertEquals(..Act("[]", ..NoGlobals(), .tAnswer), "422 DATABASE.VALIDATION", "the screen's check of no database is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Violation(tAnswer), "Databases:DATABASE.INTEGRITY.DATABASES", "on Databases")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "CallCount"), 0, "with no call at all")
    Do $$$AssertTrue(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#TOOL, "[]", {}) [ "'Databases'", "and the mint refuses it on Databases")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Mount(tB, "DISMOUNT"), "the second database is dismounted")
    Set tSet = ##class(%DynamicArray).%New()
    Do tSet.%Push(tA, "string")
    Do tSet.%Push(tB, "string")
    Do $$$AssertEquals(..Act(tSet.%ToJSON(), ..NoGlobals(), .tAnswer), "409 DATABASE.DISMOUNTED", "a set with a dismounted member is refused")
    Set tParsed = ##class(OcuPilot.Test.DatabaseWrite).Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed) && $IsObject(tParsed.%Get("detail")): tParsed.detail.%Get("dismounted"), 1: ""), tB, "naming the dismounted member")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#TOOL, tSet.%ToJSON(), {}), ##class(OcuPilot.Api.DatabaseError).ReasonFor("DATABASE.DISMOUNTED") _ " (" _ tB _ ")", "and the mint, with the code's sentence naming it")

    For tBad = "1bad", "^OcuProbe", "a b" {
        Set tGlobals = ##class(%DynamicArray).%New()
        Do tGlobals.%Push(tBad, "string")
        Set tValues = {}
        Do tValues.%Set("Globals", tGlobals.%ToJSON(), "string")
        Do $$$AssertEquals(..Act(tA, tValues, .tAnswer), "422 DATABASE.VALIDATION", tBad _ ": the screen's check is refused")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Violation(tAnswer), "Globals:DATABASE.GLOBALS.SHAPE", tBad _ ": on Globals")
        Set tArgs = {}
        Do tArgs.%Set("Globals", tGlobals)
        Do $$$AssertTrue(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#TOOL, tA, tArgs) [ "'Globals'", tBad _ ": and the mint")
    }

    Set tC = ..AddProbe("OCUPROBE184IC")
    Set tSet = ##class(%DynamicArray).%New()
    Do tSet.%Push(tA, "string")
    Do tSet.%Push(tC, "string")
    Do $$$AssertEquals(..Act(tSet.%ToJSON(), ..FillValues(), .tAnswer), "422 DATABASE.VALIDATION", "globals over two databases are refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Violation(tAnswer), "Globals:DATABASE.GLOBALS.ONEDATABASE", "on Globals")
    Do $$$AssertTrue(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#TOOL, tSet.%ToJSON(), {"Globals": ["OcuProbe184Fill"]}) [ "'Globals'", "and the mint")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
}

/// <p>The flow's <code>globals</code> step, over its own route (AC6): an empty set, a name that is not a
/// global name and globals over two databases each answer 200 with their one violation on their field.
/// The directories are ones the instance does not configure, so a step that read them would answer
/// that read's refusal instead: the step makes no vendor call.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.DatabaseRules.Validate</method> skips
/// <method>OcuPilot.Area.OsMgmt.DatabaseRules.IntegrityViolations</method> -> each case answers no
/// violation and this goes red.</p>
Method TestTheGlobalsStepAnswersEachViolationOnItsField()
{
    Set tA = $ClassMethod(..#PROBE, "DirectoryFor", "unconfigureda")
    Set tB = $ClassMethod(..#PROBE, "DirectoryFor", "unconfiguredb")
    Set tWanted = $ListBuild("Databases DATABASE.INTEGRITY.DATABASES", "Globals DATABASE.GLOBALS.SHAPE", "Globals DATABASE.GLOBALS.ONEDATABASE")
    For tCase = 1:1:3 {
        Set tDatabases = []
        If tCase > 1 Do tDatabases.%Push(tA, "string")
        If tCase = 3 Do tDatabases.%Push(tB, "string")
        Set tBody = {"step": "globals", "values": {}}
        Do tBody.values.%Set("Databases", tDatabases)
        Do tBody.values.%Set("Globals", [($Select(tCase = 2: "1bad", 1: "OcuProbe184Fill"))])
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/database/check", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
        Set tAnswer = ##class(OcuPilot.Test.DatabaseWrite).Parsed(tRaw)
        Set tOne = $Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("violations") = "array") && (tAnswer.violations.%Size() = 1): tAnswer.violations.%Get(0).field _ " " _ tAnswer.violations.%Get(0).code, 1: $Extract(tRaw, 1, 200))
        Do $$$AssertEquals(tStatus _ " " _ tOne, "200 " _ $List(tWanted, tCase), tBody.values.%ToJSON() _ ": the step answers its one violation on its field")
    }
}

/// <p>The Integrity log over a live check (AC7): its list names the check just run first, ended, with
/// its start as a log time; a page of it, by its id and by default, is its report; its rows are that
/// report's non-empty lines at the check's time; an id that is not a number is 400 <code>LOG.FILE</code>
/// and one the instance does not hold 404 <code>LOG.ABSENT</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.IntegrityChecks</method> sorts oldest
/// first -> the list's newest leg goes red.</p>
Method TestTheLogListsPagesAndRowsTheCheckJustRun()
{
    Set tA = ..AddProbe("OCUPROBE184IA", 1)
    Set tB = ..AddProbe("OCUPROBE184IB")
    Do $$$AssertEquals(..Check(tB), 200, "a first check is run")
    Do $$$AssertEquals(..Check(tA), 200, "and a second")
    Set tSC = $ClassMethod(..#LOG, "Files", ..#SOURCE, .tFiles, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the list answers")
    Set tFirst = $Select($IsObject($Get(tFiles)): tFiles.files.%Get(0), 1: "")
    Do $$$AssertTrue($IsObject(tFirst) && tFirst.%Get("ended") && (tFirst.%Get("state") = "Done"), "its first check has ended, done")
    Do $$$AssertTrue($IsObject(tFirst) && $Match(tFirst.%Get("time"), "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.000"), "with its start as a log time (" _ $Select($IsObject(tFirst): tFirst.%Get("time"), 1: "") _ ")")
    Set tId = $Select($IsObject(tFirst): tFirst.%Get("name"), 1: "")
    Set tSC = $ClassMethod(..#LOG, "Page", ..#SOURCE, "", "", "", .tPage, .tHttp, .tFault, tId)
    Set tLines = ..Lines(tPage)
    Do $$$AssertEquals(tHttp _ " " _ $ListGet(tLines, 1), "200 No Errors were found.", "a page of it is its report")
    Do $$$AssertTrue($ListFind(tLines, "Directory: " _ tA) && '$ListFind(tLines, "Directory: " _ tB), "of the check just run, the newest")
    Do $$$AssertEquals($Select($IsObject($Get(tPage)): tPage.%Get("check") _ "|" _ tPage.%Get("running"), 1: ""), tId _ "|0", "naming the check, ended")
    Set tSC = $ClassMethod(..#LOG, "Page", ..#SOURCE, "", "", "", .tNewest, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tNewest)): tNewest.%Get("check"), 1: ""), tId, "the default page is the newest check's")
    Set tSC = $ClassMethod(..#LOG, "Rows", ..#SOURCE, 3, .tRows, .tHttp, .tFault, .tTruncated)
    Set tRow = $Select($IsObject($Get(tRows)): tRows.%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: 0) _ " " _ tTruncated, "3 1", "its rows are the report's first three non-empty lines, truncated")
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("time") _ "|" _ tRow.%Get("severity") _ "|" _ tRow.%Get("text"), 1: ""), $Select($IsObject(tFirst): tFirst.%Get("time"), 1: "") _ "|info|No Errors were found.", "each at the check's time")
    Set tSC = $ClassMethod(..#LOG, "Page", ..#SOURCE, "", "", "", .tPage, .tHttp, .tFault, "../x")
    Do $$$AssertEquals(tHttp _ " " _ ..Code(tFault), "400 LOG.FILE", "an id that is not a number is refused")
    Set tSC = $ClassMethod(..#LOG, "Page", ..#SOURCE, "", "", "", .tPage, .tHttp, .tFault, "9999999999")
    Do $$$AssertEquals(tHttp _ " " _ ..Code(tFault), "404 LOG.ABSENT", "and one the instance does not hold")
}

/// <p>The log's own shapes over armed checks (AC7): a check still running pages no lines and says so,
/// and answers no rows; a report's lines marked <code>****</code> are errors; no check pages 404
/// <code>LOG.ABSENT</code>, lists none and answers no rows; and the list stops at fifty, truncated.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.IntegrityRows</method> marks every line
/// <code>info</code> -> the error leg goes red.</p>
Method TestTheLogsShapesOverArmedChecks()
{
    Do $ClassMethod(..#FIXTURE, "ArmIntegrityChecks", [{"ID": "7", "StartTime": "2026-09-29 10:00:00", "RunningState": "Running", "HasEnded": false}].%ToJSON())
    Set tSC = $ClassMethod(..#FIXTURE, "Page", ..#SOURCE, "", "", "", .tPage, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tPage)): tPage.%Get("running") _ "|" _ tPage.%Get("state") _ "|" _ tPage.%Get("lines").%Size(), 1: tHttp), "1|Running|0", "a running check pages no lines and says it is running")
    Set tSC = $ClassMethod(..#FIXTURE, "Rows", ..#SOURCE, 10, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tRows)): tRows.%Size(), 1: ""), "200 0", "and answers no rows")

    Do $ClassMethod(..#FIXTURE, "ArmIntegrityChecks", [{"ID": "8", "StartTime": "2026-09-29 10:00:00", "RunningState": "Done", "HasEnded": true}].%ToJSON())
    Do $ClassMethod(..#FIXTURE, "ArmIntegrityReport", "8", $ListBuild("************** Details Of Errors Found **************", "", "**** Global ^X: block 5 is bad", "Full Listing of Databases Checked"))
    Set tSC = $ClassMethod(..#FIXTURE, "Rows", ..#SOURCE, 10, .tRows, .tHttp, .tFault, .tTruncated)
    Set tSeverities = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tSeverities = tSeverities _ $Select(tSeverities = "": "", 1: ",") _ tRow.%Get("severity")
        }
    }
    Do $$$AssertEquals(tSeverities, "error,error,info", "a line marked **** is an error, the rest are info, and an empty line is no row")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)) && $IsObject(tRows.%Get(0)): tRows.%Get(0).%Get("time"), 1: ""), "2026-09-29T10:00:00.000", "at the check's start")

    Do $ClassMethod(..#FIXTURE, "ArmIntegrityChecks", "[]")
    Set tSC = $ClassMethod(..#FIXTURE, "Page", ..#SOURCE, "", "", "", .tPage, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..Code(tFault), "404 LOG.ABSENT", "no check pages absent")
    Set tSC = $ClassMethod(..#FIXTURE, "Files", ..#SOURCE, .tFiles, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFiles)): tFiles.files.%Size(), 1: ""), "200 0", "lists none")
    Set tSC = $ClassMethod(..#FIXTURE, "Rows", ..#SOURCE, 10, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tRows)): tRows.%Size(), 1: ""), "200 0", "and answers no rows")

    Set tMany = []
    For tI = 60:-1:1 {
        Do tMany.%Push({"ID": (tI _ ""), "StartTime": "2026-09-29 10:00:00", "RunningState": "Done", "HasEnded": true})
    }
    Do $ClassMethod(..#FIXTURE, "ArmIntegrityChecks", tMany.%ToJSON())
    Set tSC = $ClassMethod(..#FIXTURE, "Files", ..#SOURCE, .tFiles, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFiles)): tFiles.files.%Size() _ " " _ tFiles.%Get("truncated") _ " " _ tFiles.files.%Get(0).%Get("name"), 1: ""), "50 1 60", "the list stops at fifty, in the order held, truncated")
}

/// <p>A report pages from its heading (AC7): with no cursor the first page opens on the report's verdict
/// and says more follows, its cursor reads on into the listing, and that cursor sent for another check
/// restarts at that check's own heading.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.IntegrityPage</method> starts a page with
/// no cursor at the report's tail -> the first page opens mid-listing and this goes red; its identity
/// leaves out the check -> the other check's page carries on from the cursor and this goes red.</p>
Method TestAReportPagesFromItsHeading()
{
    Set tLines = $ListBuild("No Errors were found.", "", "", "Full Listing of Databases Checked")
    For tI = 1:1:40 {
        Set tLines = tLines _ $ListBuild("Global: OcuProbe" _ tI _ "    Top/Bottom Pnt Level: # of blocks=1")
    }
    Do $ClassMethod(..#FIXTURE, "ArmIntegrityChecks", [{"ID": "9", "StartTime": "2026-09-29 11:00:00", "RunningState": "Done", "HasEnded": true}, {"ID": "8", "StartTime": "2026-09-29 10:00:00", "RunningState": "Done", "HasEnded": true}].%ToJSON())
    Do $ClassMethod(..#FIXTURE, "ArmIntegrityReport", "9", tLines)
    Do $ClassMethod(..#FIXTURE, "ArmIntegrityReport", "8", tLines)
    Set tSC = $ClassMethod(..#FIXTURE, "Page", ..#SOURCE, "", 400, "", .tPage, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the newest check pages")
    Do $$$AssertEquals($Select($IsObject($Get(tPage)): tPage.lines.%Get(0) _ "|" _ tPage.%Get("truncated"), 1: tHttp), "No Errors were found.|1", "its first page opens on the verdict, and more follows")
    Set tSC = $ClassMethod(..#FIXTURE, "Page", ..#SOURCE, tPage.%Get("offset"), 400, tPage.%Get("identity"), .tNext, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tNext)): tNext.%Get("restarted") _ "|" _ $Extract(tNext.lines.%Get(0), 1, 16), 1: tHttp), "0|Global: OcuProbe", "its cursor reads on into the listing")
    Set tSC = $ClassMethod(..#FIXTURE, "Page", ..#SOURCE, tPage.%Get("offset"), 400, tPage.%Get("identity"), .tOther, .tHttp, .tFault, "8")
    Do $$$AssertEquals($Select($IsObject($Get(tOther)): tOther.%Get("restarted") _ "|" _ tOther.lines.%Get(0), 1: tHttp), "1|No Errors were found.", "and the same cursor for another check restarts at its heading")
}

/// <p>DW-1848 (AC7): a check over a probe database with a damaged data block
/// (<method>OcuPilot.Test.DatabaseActionProbe.DamageBlock</method>) ends in state <code>Error</code>, and
/// the Integrity log renders its report through <code>Display^Integrity</code>'s own capture: the errors'
/// heading first, the directory's one damaged global, that global marked <code>****</code>, and the
/// vendor's own description of the damage naming the block. The declared read answers each line the
/// report marks <code>****</code> as an error, the damaged global's among them, and every other line as
/// info.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.IntegrityReport</method> renders every
/// check through the no-errors branch -> the report opens "No Errors were found." and this goes red.</p>
Method TestADamagedBlockIsReportedAsErrors()
{
    Set tA = ..AddProbe("OCUPROBE184IA", 1)
    Set tGlobal = $Parameter(..#PROBE, "GLOBAL")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DamageBlock", "OCUPROBE184IA", .tBlock), "a data block of " _ tGlobal _ " is damaged (" _ tBlock _ ")")
    Do $$$AssertEquals(..Check(tA), 200, "a check is run")
    Set tLines = ..NewestLines(.tCheck)
    Set tSC = $ClassMethod(..#LOG, "Files", ..#SOURCE, .tFiles, .tHttp, .tFault)
    Set tFirst = $Select($IsObject($Get(tFiles)): tFiles.files.%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tFirst): tFirst.%Get("name") _ "|" _ tFirst.%Get("state"), 1: ""), tCheck _ "|Error", "the check is listed ended in error")
    Do $$$AssertEquals($ListGet(tLines, 1), $Parameter(..#LOG, "INTEGRITYERRORS"), "its report opens with the errors' heading")
    Do $$$AssertTrue($ListFind(tLines, "Directory: " _ tA) && $ListFind(tLines, "Errors found in 1 globals or supporting structures"), "naming the directory and its one damaged global")
    Do $$$AssertTrue(..AnyStarts(tLines, "**** Global: " _ tGlobal), "marking that global ****")
    Do $$$AssertTrue(..AnyHolds(tLines, "lower level block " _ tBlock), "with the vendor's description of the damage naming the block")
    Set tSC = $ClassMethod(..#LOG, "Rows", ..#SOURCE, 1000, .tRows, .tHttp, .tFault, .tTruncated)
    Set (tErrors, tMarks, tBoth, tMarkedGlobal, tDescribed) = 0
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tMark = ($Extract(tRow.%Get("text"), 1, 4) = "****")
            Set tError = (tRow.%Get("severity") = "error")
            Set tErrors = tErrors + tError
            Set tMarks = tMarks + tMark
            Set tBoth = tBoth + (tMark && tError)
            If tMark && tError && ($Extract(tRow.%Get("text"), 1, $Length("**** Global: " _ tGlobal)) = ("**** Global: " _ tGlobal)) Set tMarkedGlobal = 1
            If 'tError && (tRow.%Get("text") [ ("lower level block " _ tBlock)) Set tDescribed = 1
        }
    }
    Do $$$AssertTrue((tBoth > 0) && (tErrors = tBoth) && (tMarks = tBoth), "the read's error rows are exactly the lines marked **** (" _ tErrors _ " errors, " _ tMarks _ " marked)")
    Do $$$AssertTrue(tMarkedGlobal && tDescribed, "the damaged global's row is an error, and the description's an info row")
}

/// <p>A least-privileged reader over the wire (AC7, Task 0): a principal holding
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> alone lists the checks and pages the
/// newest; one holding <code>%Admin_Manage:USE</code> in its place is refused 403 naming it on both
/// reads.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.LogSourcePort.INTEGRITYPAIRS</parameter> drops
/// <code>%Admin_Operate:USE</code> -> the refused reader is answered and this goes red.</p>
Method TestTheOperateReaderReadsTheLogOverTheWire()
{
    Do $$$AssertStatusOK(..EnsurePrincipals(), "the two principals exist with their grants read back")
    Set tA = ..AddProbe("OCUPROBE184IA")
    Do $$$AssertEquals(..Check(tA), 200, "a check is run")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tReader = $Piece($Piece(..#PRINCIPALS, ",", 1), ":", 1)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/logs/integrity/files", tReader, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "the list is answered as JSON")
    Set tId = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("files")) && $IsObject(tAnswer.files.%Get(0)): tAnswer.files.%Get(0).%Get("name"), 1: "")
    Do $$$AssertEquals(tStatus, 200, "the reader lists the checks: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue(tId '= "", "the check is listed")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/logs/integrity?file=" _ tId, tReader, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "the page is answered as JSON")
    Do $$$AssertEquals(tStatus, 200, "and pages it: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("lines")) && (tAnswer.lines.%Get(0) = "No Errors were found."), "its report")
    Set tRefused = $Piece($Piece(..#PRINCIPALS, ",", 2), ":", 1)
    For tPath = "/logs/integrity/files", "/logs/integrity?file=" _ tId {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ tPath, tRefused, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Set tAnswer = ##class(OcuPilot.Test.DatabaseWrite).Parsed(tBody)
        Set tPair = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tStatus _ " " _ tPair, "403 %Admin_Operate:USE", tPath _ ": a reader without the pair is refused naming it: " _ $Extract(tBody, 1, 200))
    }
}

/// <p>The vendor query the log and the probe's removal read (AC7): its columns, in order, are
/// <parameter>QUERYCOLUMNS</parameter>.</p>
Method TestTheIntegrityQueryColumnsArePinned()
{
    Set tColumns = ""
    Set tQuery = $Parameter(..#LOG, "INTEGRITYQUERY")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(tQuery)
        For tI = 1:1:tRS.GetColumnCount() {
            Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tRS.GetColumnName(tI)
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tColumns = ex.DisplayString()
    }
    Do $$$AssertEquals(tColumns, ..#QUERYCOLUMNS, "SYS.BackgroundIntegrity:ListIntegrityTasks answers the columns the log reads")
}

/// <p>Create the probe database <var>pName</var>, filled with about <var>pMB</var> megabytes when
/// given, and answer its directory.</p>
Method AddProbe(pName As %String, pMB As %Integer = 0) As %String
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", pName), pName _ " is created")
    If pMB > 0 Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Fill", pName, pMB), pName _ " is filled")
    Quit $ClassMethod(..#PROBE, "DirectoryOf", pName)
}

/// <p>Run the Databases list's <code>integrity</code> action on <var>pId</var> with the values
/// <var>pValues</var>, answering <code>http code</code> and the envelope in <var>pAnswer</var>.</p>
ClassMethod Act(pId As %String, pValues As %DynamicObject = "", Output pAnswer As %String) As %String
{
    Set pAnswer = ""
    Set tBody = {"action": "integrity"}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .pAnswer, .tStatus)
    If $$$ISERR(tSC) Quit "error " _ $System.Status.GetErrorText(tSC)
    Set tCode = ""
    Set tParsed = ##class(OcuPilot.Test.DatabaseWrite).Parsed(pAnswer)
    If (+tStatus >= 400) && $IsObject(tParsed) Set tCode = tParsed.%Get("code")
    Quit tStatus _ " " _ tCode
}

/// <p>The screen's values naming no global, as the flow sends them.</p>
ClassMethod NoGlobals() As %DynamicObject
{
    Quit {"Globals": "[]"}
}

/// <p>The screen's values naming the probe global alone, as the flow sends them.</p>
ClassMethod FillValues() As %DynamicObject
{
    Set tValues = {}
    Do tValues.%Set("Globals", "[""OcuProbe184Fill""]", "string")
    Quit tValues
}

/// <p>Check the database in <var>pDirectory</var> through the shipped port, as seeding, answering the
/// port's status.</p>
ClassMethod Check(pDirectory As %String) As %Integer
{
    Kill tQuery
    Set tQuery("dir") = pDirectory
    Set tSC = ##class(OcuPilot.Port.DatabasePort).Invoke("Database.Actions", "INTEGRITYCHECK", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit +$Get(tHttp)
}

/// <p>The newest check's report lines as a <class>%List</class>, its id in <var>pCheck</var>.</p>
ClassMethod NewestLines(Output pCheck As %String) As %List
{
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Page("integrity", "", "", "", .tPage, .tHttp, .tFault)
    Set pCheck = $Select($IsObject($Get(tPage)): tPage.%Get("check"), 1: "")
    Quit ..Lines($Get(tPage))
}

/// <p>A page's lines as a <class>%List</class>.</p>
ClassMethod Lines(pPage As %DynamicObject) As %List
{
    Set tLines = ""
    If '$IsObject(pPage) || '$IsObject(pPage.%Get("lines")) Quit ""
    Set tIterator = pPage.%Get("lines").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tLines = tLines _ $ListBuild(tLine)
    }
    Quit tLines
}

/// <p>Whether a member of <var>pLines</var> starts with <var>pStart</var>.</p>
ClassMethod AnyStarts(pLines As %List, pStart As %String) As %Boolean
{
    Set tFound = 0
    For tI = 1:1:$ListLength(pLines) {
        If $Extract($ListGet(pLines, tI), 1, $Length(pStart)) = pStart Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>Whether a member of <var>pLines</var> holds <var>pText</var>.</p>
ClassMethod AnyHolds(pLines As %List, pText As %String) As %Boolean
{
    Set tFound = 0
    For tI = 1:1:$ListLength(pLines) {
        If $ListGet(pLines, tI) [ pText Set tFound = 1 Quit
    }
    Quit tFound
}

/// <p>The code of the fault <var>pFault</var>, or <code>""</code>.</p>
ClassMethod Code(pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    Quit pFault.%Get("code")
}

/// <p>Create the throwaway roles and the accounts that hold them, each with the install namespace's
/// code read and its entry's grants, and read each grant back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tI = 1:1:$Length(..#PRINCIPALS, ",") {
            Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = $Piece(tEntry, ":", 2)
            Set tGrants = $Translate($Piece(tEntry, ":", 3, *), ";", ",")
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the integrity log reader (throwaway)", tCode _ "," _ tGrants, "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot integrity test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DatabaseIntegrity; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            For tPair = "%Admin_Operate:USE", "%DB_IRISSYS:READ", "%Admin_Manage:USE" {
                Set tWanted = (tGrants [ ($Piece(tPair, ":", 1) _ ":" _ $Extract($Piece(tPair, ":", 2))))
                If ($SYSTEM.Security.CheckUserPermission(tUser, $Piece(tPair, ":", 1), $Piece(tPair, ":", 2)) = 1) '= tWanted {
                    Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grant " _ tPair _ " did not read back as declared")
                    Quit
                }
            }
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the two principals and their roles; a failing status when either survives.</p>
ClassMethod RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ",") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ",", tI), ":", 1)
            Set tRole = $Piece($Piece(..#PRINCIPALS, ",", tI), ":", 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseIntegrity left the principal " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

}
