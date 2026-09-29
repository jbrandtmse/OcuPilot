/// <p>Pins Story 18.4's disk operations on Database details on both callers of each tool (AD-53): the
/// screen's row action (<class>OcuPilot.Test.DatabaseActionFixture</class>) and the agent's mint and
/// confirm (<class>OcuPilot.Test.DatabaseConfirm</class>) -- one method per row of the spec's Part A
/// matrix: each operation's recorded call and body and its real effect, the three state refusals and the
/// vendor's own conflict, the argument rules, the started answer past the port's bound over a recording
/// port and over a real queued task, the governance baseline, the port's own read, bodies and scripts,
/// and an admin API compact listed once by Background tasks (DW-1821).</p>
/// <p>A write that should happen goes through <class>OcuPilot.Test.DatabaseRecordPort</class>, which
/// records every call <class>OcuPilot.Port.DatabasePort</class> makes and sends it; a refused leg writes
/// through <class>OcuPilot.Test.DatabaseAcceptPort</class>, which sends no write, so a removed rule shows
/// as a recorded write and never as a changed database.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, auditing on, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, fills,
/// mounts, dismounts, truncates, compacts, defragments and deletes probe databases
/// (<class>OcuPilot.Test.DatabaseActionProbe</class>) and sets the governance policy.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe object is removed by exact
/// name before all, after each and after all, and a survivor fails the class.</p>
Class OcuPilot.Test.DatabaseActions Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseActionProbe";

Parameter ACTION = "OcuPilot.Test.DatabaseActionFixture";

Parameter WRITE = "OcuPilot.Test.DatabaseWrite";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter ACCEPT = "OcuPilot.Test.DatabaseAcceptPort";

Parameter TIMEOUT = "OcuPilot.Test.DatabaseTimeoutPort";

Parameter QUEUED = "OcuPilot.Test.DatabaseQueuedPort";

Parameter SCREEN = "osmgmt.databasedetails";

Parameter NAME = "OCUPROBE184A";

/// <p>The five Database details tools, each <code>&lt;action&gt;:&lt;class&gt;</code>.</p>
Parameter TOOLS = "mount:OcuPilot.Screen.Tool.DatabaseMount,dismount:OcuPilot.Screen.Tool.DatabaseDismount,truncate:OcuPilot.Screen.Tool.DatabaseTruncate,compact:OcuPilot.Screen.Tool.DatabaseCompact,defragment:OcuPilot.Screen.Tool.DatabaseDefragment";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseActions creates, mounts, dismounts, truncates, compacts and deletes databases on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotDatabaseProhibited
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do $ClassMethod(..#RECORD, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object and task is removed")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe database, after OcuPilot.Test.DatabaseActions"))
    Quit tSC
}

/// <p>Dismount and mount (AC1): the screen's dismount sends <code>DISMOUNT</code> with no body to the
/// database's directory and the database reads dismounted, with a <code>DatabaseChange</code> audit row
/// recorded; the screen's read-only mount sends <code>{"ReadOnly":true}</code> and the database reads
/// mounted read-only; the agent's dismount and plain mount do the same, the mount sending
/// <code>{}</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionBody</method> sends <code>{}</code>
/// for a read-only mount -> the read-only leg's body and state go red.</p>
Method TestDismountAndMountOnBothCallers()
{
    Set tDirectory = ..AddProbe()
    Set tSince = $ZDateTime($ZTimeStamp, 3, , 3)
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $$$AssertEquals(..Act("dismount", tDirectory), "200 ", "the screen's dismount answers 200")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Database.Actions/DISMOUNT", "one write, the dismount")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "TargetOf", "Database.Actions/DISMOUNT") _ "|" _ $ClassMethod(..#RECORD, "BodyOf", "Database.Actions/DISMOUNT"), tDirectory _ "|", "to the database's directory, with no body")
    Do $$$AssertEquals(..StateOf(tDirectory, "Mounted"), "false", "the database reads dismounted")
    Do $$$AssertTrue(..AuditRows(tSince) > 0, "and the instance recorded a DatabaseChange audit row")

    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(..Act("mount", tDirectory, {"ReadOnly": "true"}), "200 ", "the screen's read-only mount answers 200")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/MOUNT"), {"ReadOnly": true}.%ToJSON(), "sending ReadOnly")
    Do $$$AssertEquals(..StateOf(tDirectory, "Mounted") _ "|" _ ..StateOf(tDirectory, "ReadOnly"), "true|true", "the database reads mounted read-only")

    Do $$$AssertStatusOK(..Enable("osmgmt.databasedetails.dismount", "osmgmt.databasedetails.mount"), "the agent's two keys are enabled")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.DatabaseDismount", tDirectory, {}), "200 ", "the agent's dismount is minted and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes") _ "|" _ ..StateOf(tDirectory, "Mounted"), "Database.Actions/DISMOUNT|false", "sending the dismount, and the database reads dismounted")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.DatabaseMount", tDirectory, {}), "200 ", "the agent's plain mount is minted and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/MOUNT"), "{}", "sending an empty body")
    Do $$$AssertEquals(..StateOf(tDirectory, "Mounted") _ "|" _ ..StateOf(tDirectory, "ReadOnly"), "true|false", "the database reads mounted for reading and writing")
}

/// <p>The three state refusals (AC4): a mount of a mounted database is refused 409
/// <code>DATABASE.MOUNTED</code>; a dismount, truncate, compact or defragment of a dismounted one 409
/// <code>DATABASE.DISMOUNTED</code>; a truncate, compact or defragment of one mounted read-only 409
/// <code>DATABASE.READONLY</code> -- on the screen, at the mint with the code's sentence, and at a
/// confirm whose target moved since the mint -- and no write reaches the port.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionViolations</method> ignores
/// <code>Mounted</code> -> each dismounted leg is a write the accept port records, and this goes red.</p>
Method TestTheStatesAnOperationForbidsAreRefused()
{
    Set tDirectory = ..AddProbe()
    Do $$$AssertStatusOK(..Enable("osmgmt.databasedetails.mount", "osmgmt.databasedetails.dismount", "osmgmt.databasedetails.truncate", "osmgmt.databasedetails.compact", "osmgmt.databasedetails.defragment"), "the agent's keys are enabled")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Do ..Refused("mount", tDirectory, "", "DATABASE.MOUNTED")
    Set tProposal = ..Minted("OcuPilot.Screen.Tool.DatabaseTruncate", tDirectory, {"TargetSize": 0})
    Do $$$AssertTrue($IsObject(tProposal), "a truncate is minted while the database is mounted")

    Do $$$AssertStatusOK(..Mount(tDirectory, "DISMOUNT"), "the database is dismounted")
    For tAction = "dismount", "truncate:TargetSize:0", "compact:TargetFreeSpace:0", "defragment" {
        Do ..Refused($Piece(tAction, ":", 1), tDirectory, $Piece(tAction, ":", 2, 3), "DATABASE.DISMOUNTED")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "409 PROPOSAL.TARGETCHANGED", "the truncate minted while it was mounted is refused at its confirm")

    Do $$$AssertStatusOK(..Mount(tDirectory, "MOUNT", 1), "the database is mounted read-only")
    For tAction = "truncate:TargetSize:0", "compact:TargetFreeSpace:0", "defragment" {
        Do ..Refused($Piece(tAction, ":", 1), tDirectory, $Piece(tAction, ":", 2, 3), "DATABASE.READONLY")
    }
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
}

/// <p>Truncate (AC1): the screen's truncate to 60 of an 80 MB database sends
/// <code>{"TargetSize":60}</code> and the file reads 60 MB; the agent's truncate to 0 sends
/// <code>{"TargetSize":0}</code> and returns the rest. Each is queued, read once and forgotten: no task
/// of the caller's is left, and no second read is logged.</p>
/// <p>Mutation (Rule 19): drop <code>Database.Actions/TRUNCATE</code> from
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter> -> the port refuses the queued write and
/// this goes red.</p>
Method TestTruncateSendsItsTargetAndShrinksTheFile()
{
    Set tDirectory = ..AddProbe(80)
    Set tAlerts = $ClassMethod(..#PROBE, "SecondReads")
    Do $$$AssertTrue(tAlerts >= 0, "messages.log is read (" _ tAlerts _ ")")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $$$AssertEquals(..Act("truncate", tDirectory, {"TargetSize": "60"}), "200 ", "the screen's truncate answers 200")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/TRUNCATE"), {"TargetSize": 60}.%ToJSON(), "sending the target")
    Do $$$AssertEquals(..StateOf(tDirectory, "Size"), 60, "the file reads 60 MB")
    Do $$$AssertStatusOK(..Enable("osmgmt.databasedetails.truncate"), "the agent's key is enabled")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.DatabaseTruncate", tDirectory, {"TargetSize": 0}), "200 ", "the agent's truncate to 0 is minted and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/TRUNCATE"), {"TargetSize": 0}.%ToJSON(), "sending 0")
    Do $$$AssertTrue(..StateOf(tDirectory, "Size") < 60, "and the file returned its unused space (" _ ..StateOf(tDirectory, "Size") _ " MB)")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 0, "each queued truncate was read once and its row deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SecondReads"), tAlerts, "and no second read of an ended task was logged")
}

/// <p>The argument rules (AC4): a truncate's target at or above the size, negative, fractional or not a
/// number is refused 422 <code>DATABASE.TARGETSIZE.SHAPE</code> on <code>TargetSize</code>, and a
/// compact's target above the free space 422 <code>DATABASE.TARGETFREE.SHAPE</code> on
/// <code>TargetFreeSpace</code>, on the screen and at the mint, with no write sent.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionViolations</method> accepts a
/// <code>TargetSize</code> at the current size -> the accept port records a truncate and this goes
/// red.</p>
Method TestTheArgumentRulesRefuseBeforeAnyVendorCall()
{
    Set tDirectory = ..AddProbe(20)
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Set tSize = ..StateOf(tDirectory, "Size")
    For tValue = tSize, tSize + 5, "-1", "1.5", "abc" {
        Set tValues = {}
        Do tValues.%Set("TargetSize", tValue _ "", "string")
        Do $$$AssertEquals(..Act("truncate", tDirectory, tValues, .tAnswer), "422 DATABASE.VALIDATION", tValue _ ": the screen's truncate is refused")
        Do $$$AssertEquals(..Violation(tAnswer), "TargetSize:DATABASE.TARGETSIZE.SHAPE", tValue _ ": on TargetSize")
    }
    Set tArgs = {}
    Do tArgs.%Set("TargetSize", tSize, "number")
    Do $$$AssertTrue(..MintProblem("OcuPilot.Screen.Tool.DatabaseTruncate", tDirectory, tArgs) [ "'TargetSize'", "the mint refuses a target at the size on TargetSize")
    Set tFree = ..StateOf(tDirectory, "FreeSpace")
    Set tValues = {}
    Do tValues.%Set("TargetFreeSpace", ((tFree \ 1) + 5) _ "", "string")
    Do $$$AssertEquals(..Act("compact", tDirectory, tValues, .tAnswer), "422 DATABASE.VALIDATION", "the screen's compact above the free space is refused")
    Do $$$AssertEquals(..Violation(tAnswer), "TargetFreeSpace:DATABASE.TARGETFREE.SHAPE", "on TargetFreeSpace")
    Set tArgs = {}
    Do tArgs.%Set("TargetFreeSpace", (tFree \ 1) + 5, "number")
    Do $$$AssertTrue(..MintProblem("OcuPilot.Screen.Tool.DatabaseCompact", tDirectory, tArgs) [ "'TargetFreeSpace'", "and the mint")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
}

/// <p>Compact and defragment (AC1, AC2): the screen's compact sends <code>{"TargetFreeSpace":n}</code>
/// and the agent's defragment sends no body; each is queued, finishes within the port's bound and is
/// answered finished, read once, with its row deleted and no second read logged.</p>
/// <p>Mutation (Rule 19): the self-queued refusal ignores <code>QUEUEDWRITES</code> -> the port
/// refuses the admitted compact and this goes red.</p>
Method TestCompactAndDefragmentAreQueuedAndFinish()
{
    Set tDirectory = ..AddProbe()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Fill", ..#NAME, 20), "the database is filled and half freed")
    Set tAlerts = $ClassMethod(..#PROBE, "SecondReads")
    Do $$$AssertTrue(tAlerts >= 0, "messages.log is read (" _ tAlerts _ ")")
    Set tFree = ..StateOf(tDirectory, "FreeSpace") \ 1
    Do $$$AssertTrue(tFree > 1, "it has free space to compact (" _ tFree _ " MB)")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tValues = {}
    Do tValues.%Set("TargetFreeSpace", (tFree \ 2) _ "", "string")
    Do $$$AssertEquals(..Act("compact", tDirectory, tValues, .tAnswer), "200 ", "the screen's compact answers 200")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/COMPACT"), {"TargetFreeSpace": (tFree \ 2)}.%ToJSON(), "sending the target")
    Do $$$AssertEquals(..Member(tAnswer, "continues"), "", "and it finished within the bound")
    Do $$$AssertStatusOK(..Enable("osmgmt.databasedetails.defragment"), "the agent's key is enabled")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.DatabaseDefragment", tDirectory, {}), "200 ", "the agent's defragment is minted and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes") _ "|" _ $ClassMethod(..#RECORD, "BodyOf", "Database.Actions/DEFRAGMENT"), "Database.Actions/DEFRAGMENT|", "sending no body")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 0, "each queued task was read once and its row deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SecondReads"), tAlerts, "and no second read of an ended task was logged")
}

/// <p>Started (AC2): an operation still running at the port's bound is answered started on both
/// callers -- the screen's 200 with <code>continues</code> true and the read-back <code>unchecked</code>
/// <code>running</code>, the agent's confirm the same -- and the task is never polled.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.Action</method> drops the started
/// conversion -> both callers answer 503 <code>PORT.TIMEOUT</code> and this goes red.</p>
Method TestAnOperationStillRunningAtTheBoundHasStarted()
{
    Set tDirectory = ..AddProbe(20)
    Set ^||OcuPilotDatabaseWritePort = ..#TIMEOUT
    Do $$$AssertEquals(..Act("truncate", tDirectory, {"TargetSize": "10"}, .tAnswer), "200 ", "the screen's truncate answers 200")
    Do $$$AssertEquals(..Member(tAnswer, "continues"), 1, "continuing on the instance")
    Do $$$AssertEquals(..ReadBack(tAnswer), "unchecked|running", "its read-back unchecked, running")
    Do $$$AssertStatusOK(..Enable("osmgmt.databasedetails.truncate"), "the agent's key is enabled")
    Set tProposal = ..Minted("OcuPilot.Screen.Tool.DatabaseTruncate", tDirectory, {"TargetSize": 10})
    Do $$$AssertTrue($IsObject(tProposal), "the agent's truncate is minted")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("continues") _ "|" _ tResult.%Get("readBack").%Get("verdict") _ "|" _ tResult.%Get("readBack").%Get("reason"), 1: ""), "1|unchecked|running", "continuing, its read-back unchecked, running")
    Do $$$AssertTrue($ClassMethod(..#TIMEOUT, "CallTypes") '[ "AsyncResult", "and no task was polled")
}

/// <p>Started over a real queued task (AC2): a defragment of a filled database, answered started after
/// the port's one poll, is the screen's 200 with <code>continues</code> true and its read-back
/// <code>unchecked</code> <code>running</code>; the port polls it no more, and its async task row is
/// left to the vendor's worker, until the task has ended and is read once and forgotten, with no second
/// read logged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AdminPort.AwaitTask</method> forgets the task at its
/// bound -> the row is gone at the answer and this goes red.</p>
Method TestAStartedOperationLeavesItsTaskToTheWorker()
{
    Set tDirectory = ..AddProbe()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Fill", ..#NAME, 20), "the database is filled and half freed")
    Set tAlerts = $ClassMethod(..#PROBE, "SecondReads")
    Do $$$AssertTrue(tAlerts >= 0, "messages.log is read (" _ tAlerts _ ")")
    Do $ClassMethod(..#QUEUED, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#QUEUED
    Do $$$AssertEquals(..Act("defragment", tDirectory, "", .tAnswer), "200 ", "the screen's defragment answers 200")
    Do $$$AssertEquals(..Member(tAnswer, "continues") _ "|" _ ..ReadBack(tAnswer), "1|unchecked|running", "started: continuing, its read-back unchecked, running")
    Set tPolls = $ClassMethod(..#QUEUED, "Polls")
    Set tGuid = $ClassMethod(..#QUEUED, "LastTask")
    Do $$$AssertEquals(tPolls, 1, "the port polled its task once, within its bound")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 1, "its async task row is left to the worker")
    Do $$$AssertEquals($ClassMethod(..#QUEUED, "Polls"), tPolls, "and the port polls it no more after its answer")
    Do $$$AssertEquals($ClassMethod(..#QUEUED, "Settle", tGuid), "Finished", "it finishes in the background and is read once")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 0, "and its row is deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SecondReads"), tAlerts, "and no second read of an ended task was logged")
}

/// <p>The vendor's own conflict (AC4): a mount the vendor answers 409, of a database the port read as
/// dismounted, is refused 409 <code>DATABASE.MOUNTED</code> with that code's sentence.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.Action</method> drops the mount's 409
/// mapping -> the vendor's conflict answers <code>PORT.CONFLICT</code> and this goes red.</p>
Method TestAVendorConflictOnAMountIsTheMountedRefusal()
{
    Set tDirectory = ..AddProbe()
    Do $$$AssertStatusOK(..Mount(tDirectory, "DISMOUNT"), "the database is dismounted")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $ClassMethod(..#RECORD, "FailOn", "Database.Actions/MOUNT", 409)
    Do $$$AssertEquals(..Act("mount", tDirectory, {"ReadOnly": "false"}, .tAnswer), "409 DATABASE.MOUNTED", "the vendor's 409 is the mounted refusal")
    Do $$$AssertEquals(..Member(tAnswer, "reason"), ##class(OcuPilot.Api.DatabaseError).ReasonFor("DATABASE.MOUNTED"), "with its sentence")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Database.Actions/MOUNT", "after the one call the vendor refused")
}

/// <p>An admin API compact paused while it runs (AC10, DW-1821): a compact started through the port and
/// paused is listed by Background tasks' port once, on the caller's admin API row, naming its database;
/// then it is canceled through that row, settled -- read once when it has ended -- and forgotten, with
/// no second read logged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.BackgroundTaskPort.Linked</method> drops
/// <method>OcuPilot.Port.BackgroundTaskPort.TaskLinks</method> -> the compact is listed on a database row
/// and this goes red.</p>
Method TestAPausedAdminCompactIsListedOnceOnItsAdminRow()
{
    Set tDirectory = ..AddProbe()
    Set tAlerts = $ClassMethod(..#PROBE, "SecondReads")
    Do $$$AssertTrue(tAlerts >= 0, "messages.log is read (" _ tAlerts _ ")")
    Set tSC = $ClassMethod(..#PROBE, "PausedAdminCompact", ..#NAME, .tGuid, .tTaskId, 200)
    Do $$$AssertStatusOK(tSC, "a compact is started through the port and paused")
    If $$$ISERR(tSC) Quit
    Kill tQuery
    Set tQuery("maxRows") = 1000
    Set tSC = ##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "Background tasks' port lists the tasks")
    Set tListed = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If ##class(OcuPilot.Port.DatabasePort).SameDirectory(tRow.%Get("Database"), tDirectory) Set tListed = tListed _ $ListBuild(tRow.%Get("Source") _ "|" _ tRow.%Get("Id"))
        }
    }
    Do $$$AssertEquals($ListToString(tListed), "Admin API|" _ tGuid, "once, on its admin API row, with its database")
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Admin API", tGuid))
    Set tSC = ##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask", "CANCEL", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "the compact is canceled through its admin API row")
    Set tState = $ClassMethod(..#QUEUED, "Settle", tGuid)
    Do $$$AssertTrue($ListFind($ListBuild("Finished", "Failed", "Canceled"), tState), "its task ends and is read once (" _ tState _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 0, "and its row is deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SecondReads"), tAlerts, "and no second read of an ended task was logged")
}

/// <p>Governance (AC8): at the baseline each of the five tools' agent confirm is refused
/// <code>GOVERNANCE.DISABLED</code> with no write sent, while the screen's own dismount proceeds.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.databasedetails.compact</code> enters the baseline
/// <code>true</code> -> its confirm proceeds and this goes red.</p>
Method TestAtTheBaselineTheAgentIsRefusedAndTheScreenProceeds()
{
    Set tDirectory = ..AddProbe(20)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tEntry = $Piece(..#TOOLS, ",", tI)
        Set tClass = $Piece(tEntry, ":", 2)
        Set tArgs = {}
        If $Piece(tEntry, ":", 1) = "truncate" Do tArgs.%Set("TargetSize", 0, "number")
        If $Piece(tEntry, ":", 1) = "compact" Do tArgs.%Set("TargetFreeSpace", 0, "number")
        If $Piece(tEntry, ":", 1) = "mount" Do $$$AssertStatusOK(..Mount(tDirectory, "DISMOUNT"), "the database is dismounted for the mount")
        Set tProposal = ..Minted(tClass, tDirectory, tArgs)
        Do $$$AssertTrue($IsObject(tProposal), $Parameter(tClass, "TOOLNAME") _ ": minted")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, $Parameter(tClass, "TOOLNAME") _ ": its confirm is refused as disabled by policy")
        If $Piece(tEntry, ":", 1) = "mount" Do $$$AssertStatusOK(..Mount(tDirectory, "MOUNT"), "and mounted again")
    }
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no agent write reached the port")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $$$AssertEquals(..Act("dismount", tDirectory), "200 ", "the screen's dismount proceeds")
    Do $$$AssertEquals(..StateOf(tDirectory, "Mounted"), "false", "and dismounts it")
}

/// <p>The port's own read, bodies and scripts (AD-51, AD-59): <code>STATE</code> answers the declared
/// fields for a directory and for a configuration name, the canonical set and its members not mounted
/// for a set, and 404 for a directory the instance does not configure; each operation's body is the
/// matrix's; and each operation's script is the vendor call to its route with that body, a grow's and
/// an Add a volume's keyed by name addressed to the directory their payload carries.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.Snippet</method> ignores the payload's
/// directory -> the name-keyed legs answer no step and go red.</p>
Method TestThePortsOwnReadBodiesAndScripts()
{
    Set tDirectory = ..AddProbe()
    Set tState = $ClassMethod(..#PROBE, "State", tDirectory)
    Do $$$AssertEquals(..Keys(tState), "Directory,Mounted,ReadOnly,Size,MaxSize,FreeSpace,ResourceName,NewVolumeDirectory,NewVolumeThreshold,Dismounted,TargetSize,TargetFreeSpace,InitialSize,Globals", "STATE answers the declared fields and the arguments' placeholders")
    Kill tQuery
    Set tQuery("name") = ..#NAME
    Do $$$AssertStatusOK(##class(OcuPilot.Port.DatabasePort).Invoke("Database.Actions", "STATE", .tQuery, "", .tByName, .tHttp, .tFault), "by configuration name")
    Do $$$AssertEquals($Select($IsObject($Get(tByName)): tByName.%Get("Directory"), 1: ""), tDirectory, "naming the configuration's directory")
    Set tOther = $Piece(##class(%SYS.Namespace).GetGlobalDest($NAMESPACE), "^", 2)
    Set tSet = [(tDirectory), (tOther), (tDirectory)]
    Kill tQuery
    Set tQuery("dir") = tSet.%ToJSON()
    Do $$$AssertStatusOK(##class(OcuPilot.Port.DatabasePort).Invoke("Database.Actions", "STATE", .tQuery, "", .tSetState, .tHttp, .tFault), "for a set")
    Do $$$AssertEquals($Select($IsObject($Get(tSetState)): tSetState.%Get("Directory") _ "|" _ tSetState.%Get("Dismounted"), 1: ""), ##class(OcuPilot.Port.DatabasePort).CanonicalSet(tSet.%ToJSON()) _ "|", "answering the canonical set and no member dismounted")
    Kill tQuery
    Set tQuery("dir") = $ClassMethod(..#PROBE, "DirectoryFor", "absent")
    Set tSC = ##class(OcuPilot.Port.DatabasePort).Invoke("Database.Actions", "STATE", .tQuery, "", .tAbsent, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "an unconfigured directory is 404")

    Set tBodies = "MOUNT|ReadOnly|true|{""ReadOnly"":true},MOUNT|||{},TRUNCATE|TargetSize|60|{""TargetSize"":60},COMPACT|TargetFreeSpace|30|{""TargetFreeSpace"":30},EXPANDVOL|InitialSize|5|{""InitialSize"":5},MODIFYSIZE|Size|120|{""Size"":120}"
    For tI = 1:1:$Length(tBodies, ",") {
        Set tRow = $Piece(tBodies, ",", tI)
        Kill tQuery
        If $Piece(tRow, "|", 2) '= "" Set tQuery($Piece(tRow, "|", 2)) = $Piece(tRow, "|", 3)
        Set tBody = ##class(OcuPilot.Port.DatabasePort).ActionBody($Piece(tRow, "|", 1), tState, .tQuery)
        Do $$$AssertEquals($Select($IsObject(tBody): tBody.%ToJSON(), 1: ""), $Piece(tRow, "|", 4), $Piece(tRow, "|", 1) _ ": its body")
    }
    For tType = "DISMOUNT", "DEFRAGMENT" {
        Kill tQuery
        Do $$$AssertEquals(##class(OcuPilot.Port.DatabasePort).ActionBody(tType, tState, .tQuery), "", tType _ ": no body")
    }
    Set tRoutes = "MOUNT=/database-dir/mount,DISMOUNT=/database-dir/dismount,TRUNCATE=/database-dir/truncate,COMPACT=/database-dir/compact,DEFRAGMENT=/database-dir/defragment,EXPANDVOL=/database-dir/expand-volume,MODIFYSIZE=/database-dir/modify-size,INTEGRITYCHECK=/database-dir/integrity-check"
    For tI = 1:1:$Length(tRoutes, ",") {
        Set tType = $Piece($Piece(tRoutes, ",", tI), "=", 1)
        Kill tQuery
        Set tQuery("dir") = $Select(tType = "INTEGRITYCHECK": [(tDirectory), (tOther)].%ToJSON(), 1: tDirectory)
        Set tQuery("TargetSize") = 1
        Set tSteps = ##class(OcuPilot.Port.DatabasePort).Snippet("Database.Actions", tType, .tQuery, "", {"origin": "https://example.invalid", "user": "probe"})
        Set tText = $Select($IsObject(tSteps) && (tSteps.%Size() = 1): tSteps.%Get(0).%Get("text"), 1: "")
        Do $$$AssertTrue(tText [ $Piece($Piece(tRoutes, ",", tI), "=", 2), tType _ ": its script is the vendor call to its route (" _ tText _ ")")
        If tType = "INTEGRITYCHECK" Do $$$AssertTrue((tText [ "Databases") && (tText '[ "dir="), tType _ ": with the set in the body and no directory in the query")
    }
    ; Keyed by name, as Local databases' grow and Add a volume are: addressed to the payload's directory.
    Set tContext = {"origin": "https://example.invalid", "user": "probe", "payload": {}}
    Do tContext.payload.%Set("Directory", tDirectory, "string")
    For tRow = "MODIFYSIZE|Size|120|/database-dir/modify-size?dir=", "EXPANDVOL|InitialSize|5|/database-dir/expand-volume?dir=" {
        Kill tQuery
        Set tQuery("name") = ..#NAME
        Set tQuery($Piece(tRow, "|", 2)) = $Piece(tRow, "|", 3)
        Set tSteps = ##class(OcuPilot.Port.DatabasePort).Snippet("Database.Actions", $Piece(tRow, "|", 1), .tQuery, "", tContext)
        Set tText = $Select($IsObject(tSteps) && (tSteps.%Size() = 1): tSteps.%Get(0).%Get("text"), 1: "")
        Do $$$AssertTrue((tText [ ($Piece(tRow, "|", 4) _ $ZConvert(tDirectory, "O", "URL"))) && (tText [ ("{""" _ $Piece(tRow, "|", 2) _ """:" _ $Piece(tRow, "|", 3) _ "}")), $Piece(tRow, "|", 1) _ " by name: one step to the payload's directory, with its body (" _ tText _ ")")
    }
}

/// <p>A probe database <parameter>NAME</parameter> made and grown to <var>pMB</var> megabytes when
/// given, answering its directory.</p>
Method AddProbe(pMB As %Integer = 0) As %String
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", ..#NAME), "a probe database is created")
    If pMB > 0 Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Grow", ..#NAME, pMB), "and grown to " _ pMB _ " MB")
    Quit $ClassMethod(..#PROBE, "DirectoryOf", ..#NAME)
}

/// <p>Refuse <var>pAction</var> on <var>pDirectory</var> with the value <var>pValue</var>
/// (<code>&lt;name&gt;:&lt;value&gt;</code>, or <code>""</code>) on the screen and at the mint, each with
/// <var>pCode</var>.</p>
Method Refused(pAction As %String, pDirectory As %String, pValue As %String, pCode As %String)
{
    Set tValues = ""
    Set tArgs = {}
    If pValue '= "" {
        Set tValues = {}
        Do tValues.%Set($Piece(pValue, ":", 1), $Piece(pValue, ":", 2), "string")
        Do tArgs.%Set($Piece(pValue, ":", 1), +$Piece(pValue, ":", 2), "number")
    }
    If pAction = "mount" Set tValues = {"ReadOnly": "false"}
    Do $$$AssertEquals(..Act(pAction, pDirectory, tValues), "409 " _ pCode, pAction _ ": the screen's action is refused " _ pCode)
    Set tClass = ..ToolClass(pAction)
    Do $$$AssertEquals(..MintProblem(tClass, pDirectory, tArgs), ##class(OcuPilot.Api.DatabaseError).ReasonFor(pCode), pAction _ ": and the mint, with the code's sentence")
}

/// <p>The tool class carrying Database details' action <var>pAction</var>.</p>
ClassMethod ToolClass(pAction As %String) As %String
{
    For tI = 1:1:$Length(..#TOOLS, ",") {
        If $Piece($Piece(..#TOOLS, ",", tI), ":", 1) = pAction Quit
    }
    Quit $Piece($Piece(..#TOOLS, ",", tI), ":", 2)
}

/// <p>Run Database details' action <var>pAction</var> on <var>pDirectory</var> with the declared values
/// <var>pValues</var>, answering <code>http code</code> and the envelope in <var>pAnswer</var>.</p>
ClassMethod Act(pAction As %String, pDirectory As %String, pValues As %DynamicObject = "", Output pAnswer As %String) As %String
{
    Set pAnswer = ""
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pDirectory, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .pAnswer, .tStatus)
    If $$$ISERR(tSC) Quit "error " _ $System.Status.GetErrorText(tSC)
    Set tCode = ""
    Set tParsed = ##class(OcuPilot.Test.DatabaseWrite).Parsed(pAnswer)
    If (+tStatus >= 400) && $IsObject(tParsed) Set tCode = tParsed.%Get("code")
    Quit tStatus _ " " _ tCode
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pDirectory</var> with <var>pArgs</var>, or
/// <code>""</code>.</p>
ClassMethod Minted(pToolClass As %String, pDirectory As %String, pArgs As %DynamicObject) As %DynamicObject
{
    Set tArgs = ##class(%DynamicObject).%FromJSON(pArgs.%ToJSON())
    Do tArgs.%Set($ClassMethod(pToolClass, "IdArgument"), pDirectory, "string")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(pToolClass, pDirectory, tArgs, .tProposal, .tHttp, .tProblem)
    Quit $Get(tProposal)
}

/// <p>The problem the mint of <var>pToolClass</var> for <var>pDirectory</var> with <var>pArgs</var>
/// refuses with, or <code>minted</code>.</p>
ClassMethod MintProblem(pToolClass As %String, pDirectory As %String, pArgs As %DynamicObject) As %String
{
    Set tArgs = ##class(%DynamicObject).%FromJSON(pArgs.%ToJSON())
    Do tArgs.%Set($ClassMethod(pToolClass, "IdArgument"), pDirectory, "string")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(pToolClass, pDirectory, tArgs, .tProposal, .tHttp, .tProblem)
    If $IsObject($Get(tProposal)) Quit "minted"
    Quit $Get(tProblem)
}

/// <p>Mint and confirm <var>pToolClass</var>'s proposal, answering <code>http code</code>.</p>
ClassMethod Agent(pToolClass As %String, pDirectory As %String, pArgs As %DynamicObject) As %String
{
    Set tProposal = ..Minted(pToolClass, pDirectory, pArgs)
    If '$IsObject(tProposal) Quit "not minted: " _ ..MintProblem(pToolClass, pDirectory, pArgs)
    Quit ##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal)
}

/// <p>Enable the governance keys named, over the snapshot this class took.</p>
ClassMethod Enable(pKeys... As %String) As %Status
{
    Kill tSettings
    For tI = 1:1:$Get(pKeys) {
        Set tSettings(pKeys(tI)) = "enabled"
    }
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Mount (<var>pType</var> <code>MOUNT</code>, read-only when <var>pReadOnly</var>) or dismount the
/// database in <var>pDirectory</var> through the shipped port, as seeding.</p>
ClassMethod Mount(pDirectory As %String, pType As %String, pReadOnly As %Boolean = 0) As %Status
{
    Kill tQuery
    Set tQuery("dir") = pDirectory
    If pReadOnly Set tQuery("ReadOnly") = "true"
    Quit ##class(OcuPilot.Port.DatabasePort).Invoke("Database.Actions", pType, .tQuery, "", .tResult, .tHttp, .tFault)
}

/// <p>The rendered <var>pField</var> of the database in <var>pDirectory</var>'s <code>STATE</code>.</p>
ClassMethod StateOf(pDirectory As %String, pField As %String) As %String
{
    Set tState = $ClassMethod(..#PROBE, "State", pDirectory)
    If '$IsObject(tState) Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(tState.%Get(pField), tState.%GetTypeOf(pField))
}

/// <p>How many <code>%System/%System/DatabaseChange</code> audit rows the instance recorded at or after
/// <var>pSince</var> (UTC, <code>YYYY-MM-DD HH:MM:SS</code>), read on the audit master map with
/// <code>%NOINDEX</code> on the event predicates, since the <code>Event</code> indexes lag by about a
/// minute (the <class>OcuPilot.Test.State</class> precedent). An empty answer is asked again for up to
/// five seconds.</p>
ClassMethod AuditRows(pSince As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tStatement = ##class(%SQL.Statement).%New()
        If $$$ISOK(tStatement.%Prepare("SELECT COUNT(*) FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%System' AND %NOINDEX EventType = '%System' AND %NOINDEX Event = 'DatabaseChange'")) {
            For tWait = 1:1:50 {
                Set tResult = tStatement.%Execute(pSince)
                If tResult.%Next() Set tCount = +tResult.%GetData(1)
                If tCount > 0 Quit
                Hang 0.1
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = 0
    }
    Quit tCount
}

/// <p>The first violation of the envelope <var>pAnswer</var>, <code>field:code</code>.</p>
ClassMethod Violation(pAnswer As %String) As %String
{
    Set tParsed = ##class(OcuPilot.Test.DatabaseWrite).Parsed(pAnswer)
    If '$IsObject(tParsed) || '$IsObject(tParsed.%Get("detail")) || '$IsObject(tParsed.detail.%Get("violations")) Quit ""
    Set tRow = tParsed.detail.violations.%Get(0)
    If '$IsObject(tRow) Quit ""
    Quit tRow.field _ ":" _ tRow.code
}

/// <p>The answer <var>pAnswer</var>'s <var>pName</var>, rendered.</p>
ClassMethod Member(pAnswer As %String, pName As %String) As %String
{
    Set tParsed = ##class(OcuPilot.Test.DatabaseWrite).Parsed(pAnswer)
    If '$IsObject(tParsed) Quit ""
    Quit tParsed.%Get(pName)
}

/// <p>The answer <var>pAnswer</var>'s read-back, <code>verdict|reason</code>.</p>
ClassMethod ReadBack(pAnswer As %String) As %String
{
    Set tParsed = ##class(OcuPilot.Test.DatabaseWrite).Parsed(pAnswer)
    If '$IsObject(tParsed) || '$IsObject(tParsed.%Get("readBack")) Quit ""
    Quit tParsed.readBack.%Get("verdict") _ "|" _ tParsed.readBack.%Get("reason")
}

/// <p>The top-level names of <var>pObject</var>, comma-separated, in order.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

}
