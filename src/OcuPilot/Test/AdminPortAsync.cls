/// <p>AD-26's two async entries through <method>OcuPilot.Port.AdminPort.Invoke</method>, against
/// the real vendor endpoints: <code>Database.SysCRUD</code> <code>INFO</code>, which
/// <code>ShouldRunAsync()</code> hands off, and <code>Security.Audit.Record</code>
/// <code>LIST</code>, which queues its own task. Each resolves to an ordinary success, and the
/// task row it queued is gone afterwards.</p>
/// <p>It also pins the refusal of the mutating-and-async combination (DW-1279), which is driven
/// through <class>OcuPilot.Test.EndpointFixture</class> because no vendor endpoint queues a
/// <code>PUT</code>, and that the only mutating pairs admitted to the queue are
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter>.</p>
/// <p>Runs through <class>OcuPilot.Test.PortFixture</class> with no canned answer, so the real
/// poll and delete run. Needs <code>%Admin_Operate:U</code> and <code>%Admin_Secure:U</code>, a
/// mounted globals database for the test namespace, and auditing enabled. Each test queues one
/// vendor task row, which the port deletes; the row count read through the port is asserted
/// unchanged.</p>
Class OcuPilot.Test.AdminPortAsync Extends %UnitTest.TestCase
{

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

/// <p>AD-26 as amended 2026-09-24: the queued writes the port admits are exactly
/// <code>Security.Audit.Record</code> <code>COPY</code> and <code>PURGE</code>, each a mutating
/// pair, and the probe pair the refusal above is driven with is not one of them, so the refusal is
/// still what every other mutating request that would queue meets.</p>
/// <p>Mutation (Rule 19): add <code>OcuPilotProbeAsyncWrite/PUT</code> to
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter> -> this and the refusal above go
/// red.</p>
Method TestOnlyTheNamedQueuedWritesAreAdmitted()
{
    Set tQueued = $ListFromString($Parameter("OcuPilot.Port.AdminPort", "QUEUEDWRITES"))
    Do $$$AssertEquals($ListToString(tQueued), "Security.Audit.Record/COPY,Security.Audit.Record/PURGE", "the admitted queued writes are exactly the audit copy and purge")
    For tI = 1:1:$ListLength(tQueued) {
        Set tPair = $List(tQueued, tI)
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating($Piece(tPair, "/", 1), $Piece(tPair, "/", 2)), tPair _ " is a mutating pair")
    }
    Do $$$AssertTrue('##class(OcuPilot.Test.PortFixture).IsQueuedWrite("OcuPilotProbeAsyncWrite", "PUT"), "and the probe pair is not admitted")
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

}
