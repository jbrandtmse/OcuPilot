/// <p>AD-26's two async entries through <method>OcuPilot.Port.AdminPort.Invoke</method>, against
/// the real vendor endpoints: <code>Database.SysCRUD</code> <code>INFO</code>, which
/// <code>ShouldRunAsync()</code> hands off, and <code>Security.Audit.Record</code>
/// <code>LIST</code>, which queues its own task. Each resolves to an ordinary success, and the
/// task row it queued is gone afterwards.</p>
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
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
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
