/// <p>AD-26's two async entries through <method>OcuPilot.Port.AdminPort.Invoke</method>, against
/// the real vendor endpoints: <code>Database.SysCRUD</code> <code>INFO</code>, which
/// <code>ShouldRunAsync()</code> hands off, and <code>Security.Audit.Record</code>
/// <code>LIST</code>, which queues its own task. Each resolves to an ordinary success, and the
/// task row it queued is gone afterwards.</p>
/// <p>It also pins the refusal of the mutating-and-async combination (DW-1279), which is driven
/// through <class>OcuPilot.Test.EndpointFixture</class> because no vendor endpoint queues a
/// <code>PUT</code>, and that the only mutating pairs admitted to the queue are
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter>, and that a disk operation not admitted
/// there is refused before it queues (<class>OcuPilot.Test.PortFixtureUnqueued</class>).</p>
/// <p>Runs through <class>OcuPilot.Test.PortFixture</class> with no canned answer, so the real
/// poll and delete run. Needs <code>%Admin_Operate:U</code> and <code>%Admin_Secure:U</code>, a
/// mounted globals database for the test namespace, and auditing enabled. Each test queues one
/// vendor task row, which the port deletes; the row count read through the port is asserted
/// unchanged. Where the journal file list names no closed file, the journal check's test first
/// switches the journal file to close one (<method>OcuPilot.Test.JournalProbe.EnsureClosedFile</method>),
/// only when <parameter>JOURNALVARIABLE</parameter> reads <code>1</code>, and otherwise that test
/// fails; the file it closes is kept.</p>
Class OcuPilot.Test.AdminPortAsync Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the journal switch a list without a closed file needs.</p>
Parameter JOURNALVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

/// <p>AD-35, DW-1279: a mutating request against an endpoint that would queue is refused
/// <b>before</b> the vendor's task row is written, and a read against the same endpoint reaches
/// the vendor's own handoff instead -- so the refusal is the mutating half and not the async
/// branch.</p>
/// <p>It is driven through <class>OcuPilot.Test.EndpointFixture</class>, whose
/// <code>ShouldRunAsync()</code> answers 1 under its <code>async</code> mode, because no vendor
/// endpoint queues a <code>PUT</code>: the only admitted mutating types that queue are the
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter> pairs, so the refusing branch has
/// nothing on the instance to run against and the fixture is what gives it a real body to
/// refuse.</p>
/// <p>Mutation (Rule 19): remove the <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter>
/// check from <method>OcuPilot.Port.AdminPort.Sequence</method>'s async branch -- the two log
/// assertions go red. <b>The log line is the only witness, and the ordering is not asserted
/// here.</b> The port calls <code>SaveRequestBody</code> on the vendor's own
/// <parameter>OcuPilot.Port.AdminPort.ASYNCTASKENDPOINTCLASS</parameter> instance and never on the
/// endpoint, so no fixture method of this class can observe whether the guard ran before or after
/// it; a guard moved after that call would leave every assertion below green.</p>
Method TestAMutatingRequestThatWouldQueueIsRefusedBeforeTheTaskRowIsWritten()
{
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("async")
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsResource(1)
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(1)

    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("OcuPilotProbeAsyncWrite", "PUT", , {"Password": "hunter2"}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the port refuses the mutating async combination")
    Do $$$AssertTrue(##class(OcuPilot.Test.EndpointFixture).Recorded("trace") [ "ShouldRunAsync", "the async branch was reached: " _ ##class(OcuPilot.Test.EndpointFixture).Recorded("trace"))
    ; The reason is the port's own, kept for the log rather than put on the wire (AD-39), so this is
    ; where it names the method it refused.
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "PUT", "the log names the request method it refused: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "task row", "and why: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))

    ; The same fixture, same async answer, a read: nothing is refused before the handoff, so the
    ; refusal above is about the mutating half rather than about queueing at all. The handoff
    ; itself is the vendor's and cannot wrap this fixture, so what is asserted here is that the
    ; guard did not fire -- the two real async reads above are where a completed handoff is pinned.
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).SetMode("async")
    Set tReadSC = ##class(OcuPilot.Test.PortFixture).Invoke("OcuPilotProbeAsyncWrite", "GET", , , .tReadResult, .tReadHttp, .tReadFault)
    Do $$$AssertStatusNotOK(tReadSC, "the vendor's own handoff cannot wrap a fixture endpoint, so the read fails later")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") '[ "task row", "but not at the mutating guard, which this read never trips: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
}

/// <p>AD-26 as amended 2026-09-24, 2026-09-28, 2026-09-29 and 2026-10-01: the queued writes the port
/// admits are exactly <code>Security.Audit.Record</code> <code>COPY</code> and <code>PURGE</code>,
/// <code>Namespace.Namespace</code> <code>MAPPINGS</code>, Story 18.4's six
/// <code>Database.Actions</code> operations, <code>Namespace.Namespace</code> <code>INTEROP</code> and
/// Story 18.5's <code>Journal.File</code> <code>INTEGRITYCHECK</code> and Story 18.20's <code>ECP.DataServer</code>
/// <code>SERVERACTION</code>, each a mutating pair, and the probe pair the refusal above
/// is driven with is not one of them, so the refusal is still what every other mutating request that
/// would queue meets.</p>
/// <p>Mutation (Rule 19): add <code>OcuPilotProbeAsyncWrite/PUT</code> to
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter> -> this and the refusal above go
/// red.</p>
Method TestOnlyTheNamedQueuedWritesAreAdmitted()
{
    Set tQueued = $ListFromString($Parameter("OcuPilot.Port.AdminPort", "QUEUEDWRITES"))
    Do $$$AssertEquals($ListToString(tQueued), "Security.Audit.Record/COPY,Security.Audit.Record/PURGE,Namespace.Namespace/MAPPINGS,Database.Actions/TRUNCATE,Database.Actions/COMPACT,Database.Actions/DEFRAGMENT,Database.Actions/EXPANDVOL,Database.Actions/MODIFYSIZE,Database.Actions/INTEGRITYCHECK,Namespace.Namespace/INTEROP,Journal.File/INTEGRITYCHECK,ECP.DataServer/SERVERACTION", "the admitted queued writes are exactly the audit copy and purge, the copy of mappings, the six disk operations, the enable of interoperability, the journal integrity check and the ECP data server status change")
    For tI = 1:1:$ListLength(tQueued) {
        Set tPair = $List(tQueued, tI)
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating($Piece(tPair, "/", 1), $Piece(tPair, "/", 2)), tPair _ " is a mutating pair")
    }
    Do $$$AssertTrue('##class(OcuPilot.Test.PortFixture).IsQueuedWrite("OcuPilotProbeAsyncWrite", "PUT"), "and the probe pair is not admitted")
}

/// <p>AD-26, AD-35 (Story 18.4): a port that does not admit the six queued disk operations refuses each
/// of the three whose own <code>Run()</code> queues a task
/// (<parameter>OcuPilot.Port.AdminPort.SELFQUEUEDTYPES</parameter>) before their semantics or
/// <code>Run()</code>, naming why in the log, with no task row left; the three
/// <code>ShouldRunAsync()</code> hands off meet the async branch's refusal the first test pins. Every
/// request names a directory that holds no database, so nothing would change were one sent.</p>
/// <p>Mutation (Rule 19): remove the self-queued refusal from
/// <method>OcuPilot.Port.AdminPort.Sequence</method> -> the three self-queued legs reach the endpoint,
/// which refuses the absent directory, and this goes red.</p>
Method TestAnUnadmittedDiskOperationIsRefusedBeforeItQueues()
{
    Set tBefore = ..TaskCount()
    Do $$$AssertTrue(tBefore >= 0, "the task list reads before the calls (" _ tBefore _ ")")
    Set tAbsent = $Piece(..GlobalsDirectory(), "/", 1, *-2) _ "/ocuprobe184absent/"
    For tCase = $ListBuild("COMPACT", "{""TargetFreeSpace"":0}", "own Run()"), $ListBuild("DEFRAGMENT", "", "own Run()"), $ListBuild("INTEGRITYCHECK", "databases", "own Run()") {
        Set tType = $List(tCase, 1)
        Set tBody = $List(tCase, 2)
        If $Extract(tBody) = "{" Set tBody = ##class(%DynamicObject).%FromJSON(tBody)
        If tBody = "databases" {
            Set tBody = {"Databases": [{}]}
            Do tBody.Databases.%Get(0).%Set("Directory", tAbsent, "string")
        }
        Kill tQuery
        If tType '= "INTEGRITYCHECK" Set tQuery("dir") = tAbsent
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Set tSC = ##class(OcuPilot.Test.PortFixtureUnqueued).Invoke("Database.Actions", tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tType _ ": refused when it is not admitted")
        Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ $List(tCase, 3), tType _ ": at the refusal that names the queue: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    }
    Do $$$AssertEquals(..TaskCount(), tBefore, "and no task row was queued")
}

/// <p>How many async task rows this user owns, read through the port's own
/// <code>AsyncResult</code> list. <code>-1</code> when the list cannot be read or is not an
/// array.</p>
Method TaskCount() As %Integer
{
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("AsyncResult", "LIST", , , .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit -1
    If 'tRows.%IsA("%DynamicArray") Quit -1
    Quit tRows.%Size()
}

/// <p>The directory of the globals database the test namespace maps to.</p>
Method GlobalsDirectory() As %String
{
    Quit $Piece(##class(%SYS.Namespace).GetGlobalDest($NAMESPACE), "^", 2)
}

/// <p>Database directory info, handed off by <code>ShouldRunAsync()</code>, is polled to an
/// ordinary success carrying the task's result, labelled under the stub URL, and leaves no row.</p>
Method TestDatabaseInfoIsPolledToAnOrdinarySuccess()
{
    Set tBefore = ..TaskCount()
    Do $$$AssertTrue(tBefore >= 0, "the task list reads before the call (" _ tBefore _ ")")
    Set tQuery("dir") = ..GlobalsDirectory()
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Database.SysCRUD", "INFO", .tQuery, , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the info call succeeds")
    Do $$$AssertEquals(tHttp, 200, "as a 200, not the 202 that queued it")
    Do $$$AssertTrue($IsObject(tResult) && tResult.%IsA("%DynamicObject"), "the result is the task's object")
    If $IsObject(tResult) {
        Do $$$AssertEquals(tResult.%Get("Mounted"), 1, "describing the mounted database")
        Do $$$AssertTrue(tResult.%Get("Blocks") > 0, "with its block count")
    }
    Do $$$AssertTrue($Extract(##class(OcuPilot.Test.PortFixture).Recorded("taskName"), 1, 17) = "GET /v2/ocupilot/", "the task is labelled under the stub URL: " _ ##class(OcuPilot.Test.PortFixture).Recorded("taskName"))
    Do $$$AssertEquals(..TaskCount(), tBefore, "the queued row is gone")
}

/// <p>The audit record list, which queues its own task inside <code>Run()</code>, is polled to an
/// ordinary success carrying at most <code>maxRows</code> rows, and leaves no row.</p>
Method TestTheSelfQueuedAuditListIsPolledToAnOrdinarySuccess()
{
    Set tBefore = ..TaskCount()
    Do $$$AssertTrue(tBefore >= 0, "the task list reads before the call (" _ tBefore _ ")")
    Set tQuery("maxRows") = 1
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Security.Audit.Record", "LIST", .tQuery, , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the audit list succeeds")
    Do $$$AssertEquals(tHttp, 200, "as a 200, not the 202 that queued it")
    Do $$$AssertTrue($IsObject(tResult) && tResult.%IsA("%DynamicArray"), "the result is the task's rows")
    If $IsObject(tResult) {
        Do $$$AssertTrue(tResult.%Size() <= 1, "no more rows than maxRows (" _ tResult.%Size() _ ")")
    }
    Do $$$AssertTrue($Extract(##class(OcuPilot.Test.PortFixture).Recorded("taskName"), 1, 17) = "GET /v2/ocupilot/", "the task is labelled under the stub URL: " _ ##class(OcuPilot.Test.PortFixture).Recorded("taskName"))
    Do $$$AssertEquals(..TaskCount(), tBefore, "the queued row is gone")
}

/// <p>AD-26, AD-39's fifth exception (Story 18.5): a real queued journal integrity check, its finished
/// poll answered by <class>OcuPilot.Test.JournalConsolePort</class>, answers 200 with
/// <code>{Result, console}</code>: two lines as written; 200 lines whole; 201 lines cut to
/// <parameter>OcuPilot.Port.AdminPort.CONSOLEMAXLINES</parameter>, the last U+2026; and a failed check
/// that wrote lines its lines with <code>failed</code> true, each with nothing logged. A failed check
/// that wrote no line is a logged fault with no answer. No task row is left.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.AdminPort.AwaitTask</method>'s failed-with-lines
/// branch -&gt; the failed leg answers a fault and goes red; drop the cut from
/// <method>OcuPilot.Port.AdminPort.Consoled</method> -&gt; the 201-line leg goes red; drop that
/// branch's line count -&gt; the no-line leg answers 200 and goes red; cut at the cap rather than
/// above it -&gt; the 200-line leg goes red.</p>
Method TestAJournalChecksConsoleIsAnsweredCutAndOnFailure()
{
    Set tPort = "OcuPilot.Test.JournalConsolePort"
    Set tTaskClass = $Parameter("OcuPilot.Port.AdminPort", "ASYNCTASKCLASS")
    Set tSC = ##class(OcuPilot.Test.JournalProbe).EnsureClosedFile($System.Util.GetEnviron(..#JOURNALVARIABLE) = 1)
    Do $$$AssertStatusOK(tSC, "the journal file list names a closed file: " _ $System.Status.GetErrorText(tSC))
    Set tFile = ##class(OcuPilot.Test.JournalIntegrity).ClosedFile()
    Do $$$AssertTrue(tFile '= "", "a closed journal file is listed")
    If tFile = "" Quit
    Set tBefore = ..TaskCount()
    ; state parameter, lines armed, failed flag expected, lines kept, last line expected
    Set tCases = $ListBuild($ListBuild("STATEFINISHED", 2, 0, 2, "line 2"), $ListBuild("STATEFINISHED", 200, 0, 200, "line 200"), $ListBuild("STATEFINISHED", 201, 0, 200, $Char(8230)), $ListBuild("STATEFAILED", 3, 1, 3, "line 3"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tLabel = $List(tCase, 1) _ " with " _ $List(tCase, 2) _ " lines"
        Do $ClassMethod(tPort, "Clear")
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Do $ClassMethod(tPort, "Arm", $Parameter(tTaskClass, $List(tCase, 1)), $List(tCase, 2))
        Kill tQuery
        Set tQuery("file") = tFile
        Set tResult = ""
        Set tSC = $ClassMethod(tPort, "Invoke", "Journal.File", "INTEGRITYCHECK", .tQuery, {"CheckDetails": false}, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tLabel _ " answers")
        Do $$$AssertEquals(tHttp, 200, tLabel _ " as a 200")
        Set tConsole = []
        If $IsObject(tResult) && (tResult.%GetTypeOf("console") = "array") Set tConsole = tResult.%Get("console")
        Do $$$AssertEquals(tConsole.%Size(), $List(tCase, 4), tLabel _ ": the lines kept")
        Do $$$AssertEquals(tConsole.%Get(0), "line 1", tLabel _ ": in order")
        Do $$$AssertEquals($Select(tConsole.%Size() > 0: tConsole.%Get(tConsole.%Size() - 1), 1: ""), $List(tCase, 5), tLabel _ ": a cut console ends with U+2026")
        Do $$$AssertEquals(''$Select($IsObject(tResult): tResult.%Get("failed"), 1: 0), $List(tCase, 3), tLabel _ ": failed only when the check failed")
        Do $$$AssertTrue($IsObject(tResult) && $IsObject(tResult.%Get("Result")), tLabel _ ": with the task's result")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", tLabel _ ": nothing logged")
    }
    Do $ClassMethod(tPort, "Clear")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do $ClassMethod(tPort, "Arm", $Parameter(tTaskClass, "STATEFAILED"), 0)
    Kill tQuery
    Set tQuery("file") = tFile
    Set tResult = ""
    Set tSC = $ClassMethod(tPort, "Invoke", "Journal.File", "INTEGRITYCHECK", .tQuery, {"CheckDetails": false}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ $Get(tHttp) _ " " _ $IsObject($Get(tResult)), "0 500 0", "a failed check that wrote no line is a fault with no answer")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") '= "", "and its fault is logged")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do $ClassMethod(tPort, "Clear")
    Do $$$AssertEquals(..TaskCount(), tBefore, "no queued row is left")
}

}
