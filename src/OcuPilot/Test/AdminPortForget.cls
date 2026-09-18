/// <p><method>OcuPilot.Port.AdminPort.ForgetTask</method>'s privilege guard (DW-1025): a caller who
/// cannot write the database the vendor's async-task rows live in leaves the row alone and logs
/// nothing.</p>
/// <p><b>Falsifiable although <code>%UnitTest</code> runs as <code>%All</code>.</b> The guard is
/// driven through <method>OcuPilot.Test.PortFixture.SetHoldsPair</method>, and what it is read off
/// is whether the delete was <i>attempted</i>: <code>%DeleteId</code> on an id no row carries
/// always fails, and the failure is logged, so a missing id distinguishes "skipped" from
/// "attempted" without a real row to destroy. The same guard against a real least-privileged
/// principal is
/// <method>OcuPilot.Test.WireSecurityRead.TestAnUnprivilegedAsyncReadLeavesNoProtectInTheConsoleLog</method>.</p>
/// <p>Needs nothing of the instance: no row is created, none is deleted, and the log write is
/// captured by <class>OcuPilot.Test.LogProbe</class> rather than reaching
/// <file>messages.log</file>.</p>
Class OcuPilot.Test.AdminPortForget Extends %UnitTest.TestCase
{

/// <p>An id no async-task row carries, so the delete behind the guard always fails and is always
/// logged. Letters and digits only: it travels as an IdKey value, not as a path.</p>
Parameter MISSINGGUID = "OcuPilotForgetProbe00000000";

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

/// <p>AC9 -- without the pair the delete is not attempted and nothing is logged; with it the
/// delete runs and its failure is logged as before. Both legs, because either alone is satisfied by
/// a method that never deletes anything at all.</p>
/// <p>Mutation (Rule 19): remove the guard from
/// <method>OcuPilot.Port.AdminPort.ForgetTask</method> and recompile the package -&gt; the first
/// leg's two assertions go red, while the second stays green.</p>
Method TestAnUnprivilegedCallerSkipsTheDeleteAndLogsNothing()
{
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Do ##class(OcuPilot.Test.PortFixture).ForgetTask(..#MISSINGGUID)
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "a caller without the pair logs nothing at all: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("event"), "", "so nothing was handed to the console write at all, and no line would have reached the file this story's screen displays")

    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(1)
    Do ##class(OcuPilot.Test.PortFixture).ForgetTask(..#MISSINGGUID)
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "an async task row could not be removed", "a caller holding the pair still attempts the delete, and a missing id is still reported: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
}

/// <p>AC9 -- <parameter>OcuPilot.Port.AdminPort.ASYNCTASKPAIR</parameter> names the resource of the
/// database the vendor's own storage puts those rows in, at <code>WRITE</code>. Derived from the
/// instance -- the <code>DataLocation</code>'s <code>^^:ds:</code> dataset, then that database's
/// configured directory, then its resource -- so a vendor build that moved the rows reddens this
/// rather than leaving the guard checking a resource nothing is stored under.</p>
/// <p>Mutation (Rule 19): change the parameter's resource to <code>%DB_IRISSYS</code> -&gt; the
/// resource assertion goes red naming both.</p>
Method TestTheDeclaredPairNamesTheDatabaseTheRowsLiveIn()
{
    Set tPair = $Parameter("OcuPilot.Port.AdminPort", "ASYNCTASKPAIR")
    Do $$$AssertEquals($Piece(tPair, ":", 2), "WRITE", "the declared permission is WRITE, which is what a delete needs: " _ tPair)

    ; Read before the switch: OcuPilot's own classes are not visible from %SYS, so $Parameter
    ; answers "" there and the query below would scan the whole storage table for nothing.
    Set tTaskClass = $Parameter("OcuPilot.Port.AdminPort", "ASYNCTASKCLASS")
    Do $$$AssertTrue(tTaskClass '= "", "the port names the vendor's async-task class: " _ tTaskClass)

    Set tOrigNS = $NAMESPACE
    Set tResource = ""
    Set tDataset = ""
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLocation = ""
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare("SELECT DataLocation FROM %Dictionary.CompiledStorage WHERE %EXACT(parent) = ?")
        If $$$ISERR(tSC) Quit
        Set tRs = tStmt.%Execute(tTaskClass)
        While tRs.%Next() {
            Set tLocation = tRs.%GetData(1)
        }
        ; ^|"^^:ds:<database>"|<global> -- the dataset is named in the storage itself, so the rows
        ; do not follow the namespace's own global mapping.
        Set tDataset = $Piece($Piece(tLocation, ":ds:", 2), """", 1)
        If tDataset = "" Quit
        Set tDbObj = ##class(Config.Databases).Open(tDataset)
        If '$IsObject(tDbObj) Quit
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If $IsObject(tSysDb) Set tResource = tSysDb.ResourceName
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tResource = "the derivation failed: " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS

    Do $$$AssertTrue(tDataset '= "", "the vendor's storage names the dataset its rows live in: " _ tDataset)
    Do $$$AssertEquals(tResource, $Piece(tPair, ":", 1), "and the declared resource is that database's own (" _ tDataset _ ")")
}

}
